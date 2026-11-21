# 📋 09 — Escopo do MVP, Product Backlog & Roadmap de Escala

Um MVP de produto real não é um protótipo descartável: é o **menor conjunto de funcionalidades completas, lindas, seguras e testadas** capaz de entregar valor real desde o Dia 1 e escalar sem reescrita.

---

## 1. Matriz de Priorização MoSCoW

### ✅ MUST HAVE (MVP v1.0 — Lançamento Real)
- **M1 — Autenticação & Segurança Base:** Login/Cadastro via Email e Discord OAuth2 (Supabase Auth), verificação obrigatória 18+, proteção RLS Zero-Trust em 100% das tabelas.
- **M2 — Onboarding Imersivo (< 90s):** Perfil com fotos comprimidas WebP (remoção de EXIF), Top 5 jogos via catálogo (seed + IGDB/RAWG), plataformas, sliders de *Gamer DNA* e matriz semanal de horários livres (`schedule_mask`).
- **M3 — Motor de Match Híbrido (v1):** Pré-filtro PostGIS (com *Location Fuzzing*), `pgvector` `vector(128)`, Programação Dinâmica de sobreposição contínua de horários e scoring multi-objetivo com transparência no card (`Match %` + `Xh/sem em comum`).
- **M4 — Descoberta "Daily Loot Drop":** Deck fluido de cartões em Mobile (Flutter) e Web (Next.js 2º Monitor), com ações *Passar*, *Curtir* e *Super Duo* (com nota rápida) e tela de celebração de Match com 3 *Co-op Icebreakers*.
- **M5 — Chat em Tempo Real com E2EE:** Mensagens cifradas de ponta a ponta (`X25519 + AES-256-GCM`) sincronizadas entre Mobile e Web, indicador de leitura, blur protetor em imagens e atalho para copiar Discord/Gamertag.
- **M6 — Lobby Efêmero "Duo Agora":** Criar e visualizar lobbies de 2h para jogar agora com matches/perfis compatíveis.
- **M7 — Anti-Catfish & OCR On-Device (Mobile):** Verificação gratuita de vivacidade (*Selfie Liveness* via ML Kit) + leitor OCR de print de rank/gamertag.
- **M8 — Segurança do Usuário & LGPD:** Bloquear/Desfazer match em 1 toque, denunciar, filtros de privacidade, exportação e exclusão completa de conta.
- **M9 — Design System *Cyber-Velvet* + Responsividade Total:** 100% aderente a `packages/design-tokens` em Mobile, Tablet e Web Desktop.
- **M10 — GitHub Releases + Auto-Update no Celular:** CI/CD gerando APK assinado + checksum `SHA-256` + verificador nativo de atualização no Flutter (+ suporte Shorebird OTA).

### 🟡 SHOULD HAVE (v1.5 — Retenção & Viralidade)
- **S1 — Gamer DNA Shareable Card:** Exportação de imagem `9:16` para Instagram Stories/TikTok + página pública SEO `/u/@username` no Next.js com `og:image` dinâmico.
- **S2 — GG / Fair Play Badges:** Avaliação positiva pós-partida entre matches.
- **S3 — Sync Steam / OpenDota:** Importação automática de horas jogadas e jogos favoritos.
- **S4 — Cofre Multi-Dispositivo E2EE (Argon2id):** Sincronização segura da chave privada entre Mobile e Web via frase-cofre.

### 🔵 COULD HAVE (v2.0 — Escala & Monetização Ética)
- **C1 — NEXUS Pass (Freemium Ético):** Molduras animadas no card, filtros avançados por elo/horário exato, *Undo* ilimitado.
- **C2 — Modo "Eventos & Campeonatos de Duos":** Micro-torneios casais/duos organizados pela comunidade.
- **C3 — Two-Tower ML Ranking:** Re-treino semanal offline dos embeddings com base em *Meaningful Duo Rate*.
- **C4 — Build iOS / App Store & Google Play:** Publicação oficial mantendo OTA Shorebird.

### ❌ WON'T HAVE (Fora do MVP para Proteger Foco & Custo Zero)
- Servidor próprio de voz/vídeo (WebRTC/TURN caro) — resolvido via Deep Link Discord/Jogo.
- Feed estilo rede social/TikTok genérico (dilui o foco em conexão 1:1).
- Paywalls agressivos bloqueando leitura de chat ou envio de mensagens.

---

## 2. Épicos e User Stories (Critérios de Aceitação em Gherkin)

### Épico 1 — Fundação, Identidade, Design Tokens & Ambiente
- **US-01:** *Como engenheiro, quero um monorepo padronizado com Design Tokens compartilhados entre Flutter e Next.js para garantir identidade visual única.*
  - **Dado** o arquivo `packages/design-tokens/tokens.json` atualizado
  - **Quando** o script `build-tokens` é executado
  - **Então** os temas Dart (`app_tokens.g.dart`) e CSS (`tokens.css`) são gerados sem erros e compilam nos dois apps.

### Épico 2 — Banco Supabase Zero-Trust & Auth
- **US-02:** *Como usuário, quero criar conta com Discord ou Email confirmando ter 18+ anos para acessar a plataforma com segurança.*
  - **Dado** um usuário não autenticado com data de nascimento indicando idade `< 18`
  - **Quando** tenta finalizar o cadastro
  - **Então** tanto a UI quanto a constraint SQL do PostgreSQL bloqueiam a criação do perfil.
- **US-03:** *Como especialista de segurança, quero garantir via RLS que nenhum usuário acesse mensagens ou coordenadas exatas de terceiros.*
  - **Dado** dois usuários A e B que não possuem match ativo (ou onde B bloqueou A)
  - **Quando** o token JWT de A tenta consultar `messages` ou `profiles` de B
  - **Então** o PostgreSQL retorna `0` linhas e bloqueia qualquer `INSERT/UPDATE`.

### Épico 3 — Onboarding, Gamer DNA, Liveness & OCR
- **US-04:** *Como gamer, quero selecionar meus jogos favoritos e meus horários livres semanais em menos de 90 segundos.*
  - **Dado** que estou no passo de horários do onboarding
  - **Quando** seleciono blocos de horários na grade semanal
  - **Então** o app encapsula a agenda em `WeeklyScheduleMask` (`bigint[3]`) e salva no perfil com feedback visual imediato.
- **US-05:** *Como jogadora, quero verificar minha identidade por Selfie Liveness gratuita e meu rank por print (OCR) para exibir selos de confiança.*
  - **Dado** que abro a câmera de verificação no app Flutter
  - **Quando** completo os 3 desafios de vivacidade (piscar, virar rosto, sorrir)
  - **Então** o ML Kit valida localmente sem enviar vídeo bruto e ativa o selo `Player Verificado`.

### Épico 4 — Motor de Match (DP + pgvector) & Descoberta
- **US-06:** *Como usuário, quero ver perfis compatíveis ordenados por afinidade real de jogos e horas livres em comum.*
  - **Dado** que tenho 6 horas contínuas em comum e 2 jogos em comum com o Perfil X
  - **Quando** abro o *Daily Loot Drop*
  - **Então** o card exibe o Match Score percentual, os jogos em comum em destaque e o badge `6h livres em comum`, sem jamais expor latitude/longitude exatas.

### Épico 5 — Chat E2EE & Lobby "Duo Agora"
- **US-07:** *Como usuário com match, quero conversar com criptografia de ponta a ponta tanto no celular quanto no 2º monitor do PC.*
  - **Dado** que envio uma mensagem `"Bora um Valorant hoje às 21h?"` para meu match
  - **Quando** a linha é persistida na tabela `messages` no Supabase
  - **Então** o banco armazena apenas `ciphertext_b64` e `nonce_b64`, sendo ilegível no banco e decifrada corretamente no dispositivo do destinatário.
- **US-08:** *Como gamer livre agora, quero abrir uma Lobby "Duo Agora" válida por 2 horas para chamar meu match para jogar.*
  - **Dado** que crio uma lobby de *Valorant (Casual)*
  - **Quando** passam 2 horas sem renovação
  - **Então** a lobby expira automaticamente e deixa de aparecer no feed ativo.

### Épico 6 — Qualidade, CI/CD & Auto-Update Autônomo
- **US-09:** *Como usuário Android, quero ser avisado dentro do app quando existir uma nova versão no GitHub Releases e atualizar com segurança.*
  - **Dado** que estou na versão `1.0.0` e existe a release `v1.0.1` em `WagnerxOliveira/nexus-duo`
  - **Quando** abro o aplicativo
  - **Então** o updater compara as versões, valida o checksum `SHA-256` do APK baixado e aciona a instalação guiada (ou aplica patch OTA Shorebird silenciosamente).

---

## 3. Planejamento de Sprints (Execução Autônoma)

| Sprint | Foco Principal | Entregável Verificável |
|---|---|---|
| **Sprint 0** | Setup VSCode, Git/GitHub (`WagnerxOliveira/nexus-duo`), Monorepo, Design Tokens, CI inicial | Repositório remoto criado, pipelines rodando, tokens compilando |
| **Sprint 1** | Supabase Schema Completo, Índices, `pgvector`, PostGIS, Zero-Trust RLS, RPCs e testes `pgTAP` | Banco blindado + 100% testes de isolamento RLS verdes |
| **Sprint 2** | Core Flutter + Clean Architecture + OOP + E2EE + Auth + Onboarding + Design System *Cyber-Velvet* | App mobile compilando, onboarding completo e Golden Tests responsivos |
| **Sprint 3** | Motor de Match (DP + Scoring), Deck *Daily Loot Drop*, Chat E2EE Realtime, Lobby "Duo Agora", ML Kit Liveness & OCR | Fluxo completo Mobile de ponta a ponta testado |
| **Sprint 4** | Web App Next.js (Landing SEO + App 2º Monitor 3 colunas + Chat E2EE + Gamer Card `/u/@nick`) | Mobile e Web conversando em tempo real sobre o mesmo Supabase |
| **Sprint 5** | Ciclo Profundo de QA (Self-Healing), Playwright E2E, Build APK Assinado, GitHub Release `v1.0.0`, In-App Updater + Shorebird | Produto MVP v1.0 no ar, Release publicada e atualizável no celular |
