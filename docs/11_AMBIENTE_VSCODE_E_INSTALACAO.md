# 💻 11 — Ambiente VSCode, Diagnóstico da Máquina & Guia de Instalação Multi-OS

## 1. Diagnóstico Real do Ambiente Local (Auditoria Windows 11)

Auditoria executada diretamente na estação de trabalho atual (`c:\00_projeto_gamer_match`):

| Ferramenta | Status | Versão / Caminho Detectado | Observação |
|---|---|---|---|
| **Sistema Operacional** | ✅ Ativo | Windows 11 | Workspace em `c:\00_projeto_gamer_match` |
| **Flutter SDK** | ✅ Instalado | `3.47.5` (channel `stable`) — `C:\flutter\bin\flutter.bat` | Excelente! Versão atualíssima |
| **Dart SDK** | ✅ Instalado | `3.13.4` — `C:\flutter\bin\dart.bat` | Suporte completo a Dart 3 patterns/sealed classes |
| **Node.js & npm** | ✅ Instalado | `v24.19.0` — `C:\Program Files\nodejs\node.exe` | Pronto para Next.js, Tailwind, Vitest e Playwright |
| **Git** | ✅ Instalado | `2.54.0.windows.1` | Pronto para commits/branches/tags |
| **GitHub CLI (`gh`)** | ✅ Instalado | `C:\Program Files\GitHub CLI\gh.exe` | Requer execução com acesso externo na 1ª autenticação (`gh auth status`) |
| **VS Code** | ✅ Instalado | `C:\Users\WagnerOliveira\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd` | `.vscode/extensions.json` e `settings.json` já configurados! |
| **Python** | ✅ Instalado | `Python 3.14` — `C:\Python314\python.exe` | Útil para scripts auxiliares de automação/assets |

---

## 2. Extensões VSCode Recomendadas (Já em `.vscode/extensions.json`)

Na fase de implementação, o agente instalará automaticamente via `code --install-extension` (ou o VSCode oferecerá instalação em 1 clique):

- **Flutter & Dart:** `Dart-Code.flutter`, `Dart-Code.dart-code`
- **Web / Next.js / Tailwind:** `dbaeumer.vscode-eslint`, `esbenp.prettier-vscode`, `bradlc.vscode-tailwindcss`
- **Produtividade & Diagnóstico:** `usernamehw.errorlens`, `EditorConfig.EditorConfig`, `tamasfe.even-better-toml`
- **Git & GitHub:** `eamodio.gitlens`, `GitHub.vscode-pull-request-github`
- **Banco PostgreSQL / Supabase:** `mtxr.sqltools`, `mtxr.sqltools-driver-pg`
- **Documentação & Diagramas:** `DavidAnson.vscode-markdownlint`, `bierner.markdown-mermaid`
- **Testes E2E:** `ms-playwright.playwright`
- **Ortografia PT-BR/EN:** `streetsidesoftware.code-spell-checker`, `streetsidesoftware.code-spell-checker-portuguese-brazilian`

---

## 3. Guia de Instalação & Execução (Windows 11, Linux & macOS)

> **Nota:** Os comandos abaixo serão executados automaticamente pelo agente na fase de implementação e servem também como documentação oficial de onboarding para qualquer desenvolvedor em Windows 11, Linux ou macOS.

### 3.1 Pré-requisitos Multi-OS
- **Windows 11:** Flutter 3.47+, Node.js 22+, Git, GitHub CLI (`gh`), Android Studio / Android SDK (cmdline-tools + platform-tools), Docker Desktop (opcional para Supabase local).
- **Linux (Ubuntu/Debian/Fedora):** Flutter SDK no `$PATH`, Node.js 22+ via `nvm`, `gh`, Android SDK, `libsecret` / `clang` / `cmake` / `ninja-build` (para build desktop Linux).
- **macOS (Apple Silicon / Intel):** Homebrew (`brew install node gh`), Flutter SDK, Xcode + CocoaPods (para build iOS), Android Studio.

### 3.2 Clonar e Configurar o Repositório
```bash
git clone https://github.com/WagnerxOliveira/nexus-duo.git
cd nexus-duo
```

### 3.3 Configurar Variáveis de Ambiente (`.env.example` -> `.env`)
Crie o arquivo de ambiente sem jamais versioná-lo no Git:

**Web (`apps/web/.env.local`):**
```env
NEXT_PUBLIC_SUPABASE_URL=https://SEU_PROJETO.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=SUA_ANON_KEY_PUBLICA
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

**Mobile (`apps/mobile/.env` ou `--dart-define-from-file=.env.json`):**
```json
{
  "SUPABASE_URL": "https://SEU_PROJETO.supabase.co",
  "SUPABASE_ANON_KEY": "SUA_ANON_KEY_PUBLICA",
  "GITHUB_REPO": "WagnerxOliveira/nexus-duo"
}
```

**Supabase Edge Functions Secrets (via `supabase secrets set`):**
- `TWITCH_CLIENT_ID` e `TWITCH_CLIENT_SECRET` (IGDB — gratuito em `dev.twitch.tv`)
- `RAWG_API_KEY` (opcional fallback — gratuito em `rawg.io/apidocs`)
- `STEAM_API_KEY` (opcional sync Steam — gratuito em `steamcommunity.com/dev/apikey`)

### 3.4 Gerar Design Tokens Compartilhados
```bash
node packages/design-tokens/build-tokens.mjs
```

### 3.5 Executar o Aplicativo Mobile (Flutter)
```bash
cd apps/mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run --dart-define-from-file=.env.json
```

### 3.6 Executar a Aplicação Web (Next.js — 2º Monitor & SEO)
```bash
cd apps/web
npm install
npm run lint
npm run typecheck
npm run test
npm run dev
```

### 3.7 Aplicar Migrations e Testar Segurança RLS no Supabase
```bash
npx supabase login
npx supabase link --project-ref SEU_PROJECT_REF
npx supabase db push
# Em ambiente local com Docker:
npx supabase start
npx supabase test db
```

---

## 4. Checklist Único de Contas Gratuitas (2 Minutos pelo Fundador)

Como segurança cibernética real **proíbe** o agente de criar contas ou burlar autenticação/CAPTCHA em seu nome, você só precisa garantir que tem acesso a:
1. **GitHub (`WagnerxOliveira`)** — já conectado no `gh` CLI (ou autenticar 1 vez com `gh auth login`).
2. **Supabase (Free Tier)** — criar 1 projeto gratuito em `supabase.com` e fornecer `SUPABASE_URL` + `SUPABASE_ANON_KEY` (ou `SUPABASE_ACCESS_TOKEN` para `supabase db push` automatizado).
3. **Discord Developer Portal (Opcional para Login Discord)** — copiar `Client ID` e `Client Secret` diretamente no painel *Auth -> Providers -> Discord* do Supabase.
4. **Shorebird (Opcional para OTA instantâneo)** — login gratuito em `console.shorebird.dev` para patches Dart sem novo APK.
5. **Vercel ou Cloudflare Pages (Grátis)** — conectar o repositório `WagnerxOliveira/nexus-duo` apontando para `apps/web`.
