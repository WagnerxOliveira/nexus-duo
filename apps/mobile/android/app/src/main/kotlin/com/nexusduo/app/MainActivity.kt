package com.nexusduo.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val installerChannel = "com.nexusduo.app/apk_installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, installerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSupportedAbis" -> {
                        result.success(Build.SUPPORTED_ABIS.toList())
                    }
                    "getInstalledBuildInfo" -> {
                        try {
                            val pkgInfo = getInstalledPackageInfo()
                            val infoMap = mapOf<String, Any?>(
                                "packageName" to packageName,
                                "versionName" to (pkgInfo.versionName ?: "1.1.0"),
                                "versionCode" to extractLongVersionCode(pkgInfo),
                                "signingCertSha256" to extractCertSha256(pkgInfo),
                                "supportedAbis" to Build.SUPPORTED_ABIS.toList()
                            )
                            result.success(infoMap)
                        } catch (e: Exception) {
                            result.error("BUILD_INFO_FAILED", e.message, null)
                        }
                    }
                    "getAvailableStorageBytes" -> {
                        try {
                            val statFs = StatFs(cacheDir.path)
                            result.success(statFs.availableBytes)
                        } catch (e: Exception) {
                            result.error("STORAGE_CHECK_FAILED", e.message, null)
                        }
                    }
                    "verifyApkPackage" -> {
                        val filePath = call.argument<String>("filePath")
                        try {
                            result.success(verifyApkFile(filePath))
                        } catch (e: Exception) {
                            result.error("APK_VERIFY_FAILED", e.message, null)
                        }
                    }
                    "canRequestPackageInstalls" -> {
                        val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                        result.success(allowed)
                    }
                    "openUnknownAppSourcesSettings" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val settingsIntent = Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                ).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(settingsIntent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_OPEN_FAILED", e.message, null)
                        }
                    }
                    "installApk" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrBlank()) {
                            result.error("INVALID_PATH", "APK file path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val apkFile = File(filePath)
                            if (!apkFile.exists() || apkFile.length() <= 0L) {
                                result.error("FILE_NOT_FOUND", "APK file does not exist or is empty", null)
                                return@setMethodCallHandler
                            }

                            val apkUri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                apkFile
                            )
                            val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                            }
                            try {
                                startActivity(viewIntent)
                            } catch (_: ActivityNotFoundException) {
                                @Suppress("DEPRECATION")
                                val installFallback = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                                    data = apkUri
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                                }
                                startActivity(installFallback)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun signingFlagBitmask(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
    }

    private fun getInstalledPackageInfo(): PackageInfo {
        val flags = signingFlagBitmask()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(flags.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, flags)
        }
    }

    private fun getArchivePackageInfo(apkPath: String): PackageInfo? {
        val flags = signingFlagBitmask()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageArchiveInfo(
                apkPath,
                PackageManager.PackageInfoFlags.of(flags.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageArchiveInfo(apkPath, flags)
        }
    }

    private fun extractLongVersionCode(info: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    private fun extractCertSha256(info: PackageInfo): String {
        val rawCertBytes: ByteArray? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo
            val certs = when {
                signingInfo == null -> null
                signingInfo.hasMultipleSigners() -> signingInfo.apkContentsSigners
                else -> signingInfo.signingCertificateHistory ?: signingInfo.apkContentsSigners
            }
            certs?.firstOrNull()?.toByteArray()
        } else {
            @Suppress("DEPRECATION")
            info.signatures?.firstOrNull()?.toByteArray()
        }

        if (rawCertBytes == null || rawCertBytes.isEmpty()) return ""
        val digest = MessageDigest.getInstance("SHA-256").digest(rawCertBytes)
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun verifyApkFile(filePath: String?): Map<String, Any?> {
        if (filePath.isNullOrBlank()) {
            return mapOf(
                "valid" to false,
                "errorCode" to "FILE_NOT_FOUND",
                "message" to "Caminho do APK não informado."
            )
        }
        val apkFile = File(filePath)
        if (!apkFile.exists() || apkFile.length() <= 0L) {
            return mapOf(
                "valid" to false,
                "errorCode" to "FILE_NOT_FOUND",
                "message" to "Arquivo APK não encontrado ou vazio no cache."
            )
        }

        val archiveInfo = getArchivePackageInfo(apkFile.path)
            ?: return mapOf(
                "valid" to false,
                "errorCode" to "INVALID_APK",
                "message" to "O arquivo baixado não é um pacote Android (.apk) válido."
            )

        if (archiveInfo.packageName != packageName) {
            return mapOf(
                "valid" to false,
                "errorCode" to "PACKAGE_MISMATCH",
                "packageName" to archiveInfo.packageName,
                "message" to "Pacote incompatível (${archiveInfo.packageName})."
            )
        }

        val installedInfo = getInstalledPackageInfo()
        val archiveCode = extractLongVersionCode(archiveInfo)
        val installedCode = extractLongVersionCode(installedInfo)

        if (archiveCode <= installedCode) {
            return mapOf(
                "valid" to false,
                "errorCode" to "VERSION_NOT_NEWER",
                "packageName" to archiveInfo.packageName,
                "versionCode" to archiveCode,
                "versionName" to (archiveInfo.versionName ?: ""),
                "message" to "Esta versão (build $archiveCode) não é mais recente que a instalada (build $installedCode)."
            )
        }

        val apkCert = extractCertSha256(archiveInfo)
        val installedCert = extractCertSha256(installedInfo)
        if (apkCert.isNotEmpty() && installedCert.isNotEmpty() && apkCert != installedCert) {
            val shortApk = apkCert.take(12)
            val shortInstalled = installedCert.take(12)
            return mapOf(
                "valid" to false,
                "errorCode" to "SIGNATURE_MISMATCH",
                "packageName" to archiveInfo.packageName,
                "versionCode" to archiveCode,
                "versionName" to (archiveInfo.versionName ?: ""),
                "apkCertSha256" to apkCert,
                "installedCertSha256" to installedCert,
                "message" to "Conflito de assinatura do aplicativo (instalado: $shortInstalled... vs atualização: $shortApk...)."
            )
        }

        return mapOf(
            "valid" to true,
            "packageName" to archiveInfo.packageName,
            "versionCode" to archiveCode,
            "versionName" to (archiveInfo.versionName ?: ""),
            "apkCertSha256" to apkCert,
            "installedCertSha256" to installedCert
        )
    }
}
