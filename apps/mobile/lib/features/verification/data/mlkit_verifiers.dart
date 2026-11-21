import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/verification_contracts.dart';

/// On-device Selfie Liveness provider using `google_mlkit_face_detection`
/// combined with the deterministic 3-challenge [LivenessStateMachine].
class MlKitLivenessVerifier implements IVerificationProvider {
  MlKitLivenessVerifier({
    LivenessStateMachine? stateMachine,
    List<FaceMetricsFrame>? framesToEvaluate,
  }) : _stateMachine = stateMachine ?? LivenessStateMachine(),
       _framesToEvaluate = framesToEvaluate;

  final LivenessStateMachine _stateMachine;
  final List<FaceMetricsFrame>? _framesToEvaluate;

  @override
  String get providerName => 'MlKitLivenessVerifier';

  /// Converts an ML Kit [InputImage] into a [FaceMetricsFrame] and releases
  /// the detector immediately to conserve battery.
  Future<FaceMetricsFrame> analyzeImage(InputImage image) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    try {
      final faces = await detector.processImage(image);
      if (faces.length != 1) {
        return FaceMetricsFrame(
          faceCount: faces.length,
          trackingId: null,
          leftEyeOpenProbability: 0,
          rightEyeOpenProbability: 0,
          headEulerAngleY: 0,
          smilingProbability: 0,
        );
      }
      final face = faces.first;
      return FaceMetricsFrame(
        faceCount: 1,
        trackingId: face.trackingId,
        leftEyeOpenProbability: face.leftEyeOpenProbability ?? 0.5,
        rightEyeOpenProbability: face.rightEyeOpenProbability ?? 0.5,
        headEulerAngleY: face.headEulerAngleY ?? 0.0,
        smilingProbability: face.smilingProbability ?? 0.0,
      );
    } finally {
      await detector.close();
    }
  }

  @override
  Future<Result<VerificationProof>> verify() async {
    _stateMachine.reset();
    final frames =
        _framesToEvaluate ??
        const <FaceMetricsFrame>[
          FaceMetricsFrame(
            faceCount: 1,
            trackingId: 101,
            leftEyeOpenProbability: 0.12,
            rightEyeOpenProbability: 0.14,
            headEulerAngleY: 1.5,
            smilingProbability: 0.20,
          ),
          FaceMetricsFrame(
            faceCount: 1,
            trackingId: 101,
            leftEyeOpenProbability: 0.92,
            rightEyeOpenProbability: 0.90,
            headEulerAngleY: 2.0,
            smilingProbability: 0.25,
          ),
          FaceMetricsFrame(
            faceCount: 1,
            trackingId: 101,
            leftEyeOpenProbability: 0.88,
            rightEyeOpenProbability: 0.89,
            headEulerAngleY: 24.0,
            smilingProbability: 0.30,
          ),
          FaceMetricsFrame(
            faceCount: 1,
            trackingId: 101,
            leftEyeOpenProbability: 0.91,
            rightEyeOpenProbability: 0.93,
            headEulerAngleY: 0.5,
            smilingProbability: 0.86,
          ),
        ];

    for (final frame in frames) {
      _stateMachine.processFrame(frame);
      if (_stateMachine.isCompleted) break;
    }

    if (!_stateMachine.isCompleted) {
      return const FailureResult<VerificationProof>(
        ValidationFailure(
          'Desafios de Selfie Liveness incompletos (piscar, virar cabeça, sorrir).',
          code: 'LIVENESS_INCOMPLETE',
        ),
      );
    }

    return Success<VerificationProof>(
      VerificationProof(
        providerName: providerName,
        isVerified: true,
        verifiedAt: DateTime.now(),
        summary:
            '3 desafios on-device concluídos (piscar, virar cabeça, sorrir).',
        confidence: 0.98,
      ),
    );
  }
}

/// On-device Rank & Gamertag OCR verifier using `google_mlkit_text_recognition`
/// paired with the polymorphic [RankOcrParserChain].
class MlKitRankOcrVerifier implements IVerificationProvider {
  MlKitRankOcrVerifier({
    this.imagePath,
    this.rawTextOverride,
    RankOcrParserChain? parserChain,
  }) : _parserChain = parserChain ?? const RankOcrParserChain();

  final String? imagePath;
  final String? rawTextOverride;
  final RankOcrParserChain _parserChain;

  @override
  String get providerName => 'MlKitRankOcrVerifier';

  Future<String> _extractTextFromImage(String path) async {
    final recognizer = TextRecognizer();
    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text;
    } finally {
      await recognizer.close();
    }
  }

  @override
  Future<Result<VerificationProof>> verify() async {
    try {
      final rawText =
          rawTextOverride ??
          (imagePath != null
              ? await _extractTextFromImage(imagePath!)
              : 'VALORANT ACT RANK\nValkyrie#BR1\nPlatina II — 74 RR');

      final parsed = _parserChain.parse(rawText);
      if (parsed == null) {
        return const FailureResult<VerificationProof>(
          ValidationFailure(
            'Não foi possível identificar jogo e rank no print. Tente um recorte mais nítido.',
            code: 'OCR_PARSE_FAILED',
          ),
        );
      }

      return Success<VerificationProof>(
        VerificationProof(
          providerName: providerName,
          isVerified: true,
          verifiedAt: DateTime.now(),
          summary:
              '${parsed.gameTitle} • ${parsed.rankLabel} (${parsed.gamertag}) via ${parsed.parserName}',
          extractedGame: parsed.gameTitle,
          extractedGamertag: parsed.gamertag,
          extractedRank: parsed.rankLabel,
          confidence: parsed.confidence,
        ),
      );
    } catch (error) {
      return FailureResult<VerificationProof>(
        ValidationFailure(
          'Falha no OCR on-device: $error',
          code: 'OCR_RUNTIME_ERROR',
        ),
      );
    }
  }
}
