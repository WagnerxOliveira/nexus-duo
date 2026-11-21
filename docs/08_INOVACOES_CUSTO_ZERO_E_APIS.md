# 🚀 08 — Inovações de Custo Zero & Ecossistema de APIs Gratuitas

Uma startup de alto nível não vence queimando dinheiro em servidores caros — vence usando **engenharia criativa, efeitos de rede orgânicos e APIs gratuitas bem orquestradas**.

---

## 1. Catálogo de Inovações de Custo Zero (Diferenciais de Mercado)

| # | Inovação | Como Funciona | Impacto no Produto & Crescimento | Custo |
|---|---|---|---|---|
| 1 | **Gamer DNA Shareable Card (Viral Loop)** | Gera localmente (Canvas/RepaintBoundary) um card holográfico lindo `9:16` com Top 3 Jogos, Arquétipo Gamer ("Tático Tranquilo", "Cozy Explorador"), Horário Nobre e QR Code `nexusduo.app/u/@nick` pronto para Instagram Stories / TikTok / Discord. | Aquisição orgânica viral (CAC = R\$ 0) + orgulho identitário. | **R\$ 0** |
| 2 | **Lobby Efêmero "Duo Agora" (2h)** | Usa Supabase Realtime Presence/Postgres para listar matches e perfis compatíveis disponíveis *agora* para 1 partida. Expira automaticamente em 2h. | Resolve a ansiedade do 1º encontro e aumenta em 3x a conversão Match $\to$ Interação Real. | **R\$ 0** |
| 3 | **Co-op Icebreaker Automático** | Motor determinístico + templates contextuais geram 3 quebra-gelos personalizados usando os jogos e horários em comum do casal logo na tela de Match. | Combate o ghosting e elimina o "oi, tudo bem?" sem gastar 1 centavo com API de LLM! | **R\$ 0** |
| 4 | **OCR de Print de Rank/Gamertag** | Leitura on-device (`ML Kit` / `Tesseract.js`) de screenshots de jogos para auto-preencher perfil e dar selo de Rank Verificado. | Reduz fricção no onboarding e evita mentiras no perfil. | **R\$ 0** |
| 5 | **Web App "Modo 2º Monitor"** | Interface Next.js ultra-leve em 3 colunas com notificações de aba (*Document Title badge* + som sutil opcional) pensada para rodar ao lado de jogos no PC. | Diferencial único frente a Tinder/Bumble (que ignoram o desktop gamer). | **R\$ 0** |
| 6 | **Deep Link 1-Toque para Jogos & Discord** | Dentro do chat, botão "Chamar pro Discord / Copiar Riot ID / Abrir Perfil Steam" via deep links nativos (`discord://`, `steam://`). | Zero custo de servidor de voz/WebRTC no MVP usando a infra que gamers já amam! | **R\$ 0** |
| 7 | **Auto-Update Autônomo via GitHub Releases + Shorebird** | O app Flutter consulta a última Release no GitHub, valida `SHA-256` e oferece atualização in-app (ou aplica patch OTA Dart silencioso via Shorebird). | Distribuição direta sem depender de taxas/demoras de loja no MVP. | **R\$ 0** |

---

## 2. Mapa Técnico de APIs Gratuitas para o NEXUS DUO

Todas as chamadas que exigem `Client Secret` ou `API Key` passam por **Supabase Edge Functions** com **Cache em PostgreSQL (`games_catalog`)** para jamais expor chaves no app e respeitar limites de taxa!

| API | Finalidade no App | Custo / Limite Gratuito | Autenticação | Estratégia de Cache (Zero Desperdício) |
|---|---|---|---|---|
| **IGDB (Twitch)** *(Primária)* | Catálogo oficial de jogos, capas HD, gêneros, plataformas, modos (Co-op/Multiplayer) | **100% Grátis** (4 req/s) | Twitch OAuth2 Client Credentials (Edge Function) | Sincroniza Top 2.000 jogos populares em `games_catalog` + busca on-demand com cache permanente no Postgres |
| **RAWG API** *(Fallback)* | Catálogo complementar (500k+ jogos, tags indie/cozy) | **Grátis** até 20.000 req/mês (com atribuição) | API Key na Edge Function | Usada apenas se jogo não existir no cache local nem no IGDB |
| **Discord OAuth2** | Login 1-clique + importação de avatar/username verificado | **100% Grátis** | OAuth2 nativo suportado pelo **Supabase Auth**! | Zero código customizado de auth — nativo no painel Supabase |
| **Steam Web API** | Importar biblioteca de jogos e horas jogadas (perfil público) | **100% Grátis** (100k req/dia) | Steam OpenID + API Key (Edge Function) | Sync sob demanda (máx. 1x a cada 24h por usuário) |
| **OpenDota API** | Estatísticas e rank automático de Dota 2 | **100% Grátis** (sem chave obrigatória) | Pública (fair-use) | Cache de 24h por conta vinculada |
| **Riot Data Dragon** | Assets estáticos (ícones de campeões/elos de LoL/Valorant) | **100% Grátis** (CDN estática sem limite de chave) | Pública | URLs diretas em CDN (0 bytes no nosso Storage!) |

---

## 3. Proteção Econômica do Supabase Free Tier (Engenharia de Sobrevivência)

Para que o produto rode com **custo R\$ 0,00** durante todo o MVP e early traction sem atingir tetos precocemente:

1. **Zero Imagens Pesadas no Storage:**
   - Fotos de perfil são redimensionadas no cliente para no máximo `1080x1350` e comprimidas em **WebP qualidade 78%** ($\approx 50\text{–}85\text{ KB}$ por foto).
   - Capas de jogos **nunca** são copiadas para o nosso Storage — usamos URLs diretas das CDNs oficiais (IGDB/Steam) com `cached_network_image` no Flutter e `next/image` / cache HTTP no Web.
2. **Realtime Econômico (Limite: 200 conexões simultâneas / 2M msgs/mês):**
   - O canal WebSocket Realtime só conecta quando o app está em **primeiro plano** (*foreground*) nas telas de **Chat** ou **Lobby "Duo Agora"** — desconecta automaticamente em background ou na tela de Descoberta!
   - Isso permite suportar **~2.000 a 4.000 usuários diários ativos** dentro do limite de 200 conexões simultâneas!
3. **Egress Protegido (Limite: 5 GB/mês):**
   - Paginação cursor-based (20 mensagens por página), payloads enxutos (`select` explícito de colunas — nunca `SELECT *`), cache local no dispositivo (Hive/SQLite ou Riverpod persistente) para perfis já carregados.
4. **Prevenção de Pausa por Inatividade (7 dias no Free Tier):**
   - Workflow GitHub Actions `keepalive-staging.yml` executa uma consulta leve `SELECT 1` a cada 4 dias no ambiente de staging/MVP.
