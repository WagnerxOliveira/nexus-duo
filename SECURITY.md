# 🔐 Política de Segurança e Privacidade — NEXUS DUO

Aplicativos de relacionamento lidam com dados altamente sensíveis (identidade, localização aproximada, preferências pessoais e conversas privadas). Segurança no **NEXUS DUO** é requisito arquitetural inegociável (*Security & Privacy by Design*).

---

## 1. Pilares de Segurança Implementados

1. **Zero-Trust Database (Supabase RLS):**
   - Acesso direto ao banco é governado exclusivamente por **Row Level Security** vinculada ao `auth.uid()` do JWT validado.
   - A chave `service_role` **nunca** existe no cliente Flutter ou no bundle Next.js — apenas em Edge Functions server-side quando estritamente necessário.
2. **Criptografia de Ponta a Ponta (E2EE) no Chat:**
   - Acordo de chaves via **X25519 (ECDH)** e cifragem autenticada **AES-256-GCM** com nonce único de 96 bits por mensagem.
   - Chaves privadas permanecem no **Android Keystore / iOS Keychain** (`flutter_secure_storage`) e em **WebCrypto `CryptoKey` não-exportável** na Web.
3. **Privacidade Geográfica (Anti-Stalking):**
   - Coordenadas exatas jamais são expostas em respostas de API para outros usuários.
   - O cálculo de distância ocorre server-side via RPC com arredondamento e *fuzzing* geográfico mínimo de 3 km.
4. **Anti-Catfish & Integridade de Perfis:**
   - Verificação de vivacidade (*Selfie Liveness*) processada on-device (sem envio de vídeo biométrico bruto para terceiros).
   - Verificação de integridade de atualizações APK via hash `SHA-256` publicado nas GitHub Releases.
5. **Conformidade LGPD / GDPR:**
   - Coleta mínima de dados (*Data Minimization*).
   - Direito de exportação (JSON) e exclusão completa (*Right to be Forgotten* com `ON DELETE CASCADE` + limpeza de Storage).

---

## 2. Reporte Responsável de Vulnerabilidades

Caso encontre qualquer falha de segurança (RLS bypass, vazamento de PII, XSS, falha criptográfica ou abuso de API):

1. **Não** abra uma Issue pública descrevendo o exploit.
2. Utilize a aba **GitHub Security Advisories** privada no repositório `WagnerxOliveira/nexus-duo` (*Report a vulnerability*).
3. Inclua passos reproduzíveis, impacto estimado e, se possível, sugestão de mitigação.
4. Prazo alvo de triagem: **até 48 horas**.

---

## 3. Checklist de Segredos (Proibido no Git)

Nunca versione:
- `.env`, `.env.local`, `.env.production`
- `*.jks`, `*.keystore`, `key.properties` (chaves de assinatura Android)
- `SUPABASE_SERVICE_ROLE_KEY`, `TWITCH_CLIENT_SECRET`, `DISCORD_CLIENT_SECRET`, `STEAM_API_KEY`
- Tokens pessoais do GitHub ou credenciais de banco
