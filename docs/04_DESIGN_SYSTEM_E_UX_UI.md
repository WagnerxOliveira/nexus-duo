# 🎨 04 — Design System, UX/UI, Tipografia e Responsividade

## 1. Direção de Arte: *"Cyber-Velvet & Obsidian Neon"*

O maior erro de aplicativos gamers é parecer um site de campeonato de 2012 (fundo preto `#000000` chapado, verde limão radioativo, fontes ilegíveis e excesso de bordas).  
O maior erro de apps de relacionamento é parecer genérico e estéril.

O **NEXUS DUO** funde o **luxo editorial noturno** (conforto OLED, profundidade por camadas translúcidas *glassmorphism*, gradientes sutis de atmosfera, fotos grandes e respeitadas) com **micro-assinaturas gamer de precisão** (badges de afinidade, anéis de progresso neon controlados, ícones geométricos afiados e feedback háptico).

---

## 2. Sistema de Cores (Design Tokens Semânticos — WCAG AA/AAA)

Todos os tokens viverão em `packages/design-tokens/tokens.json` e serão compilados tanto para **Flutter (`ThemeData` / `ThemeExtension`)** quanto para **Next.js (`Tailwind CSS variables`)**.

| Token | Hex | Uso Semântico | Contraste c/ Texto Primário |
|---|---|---|---|
| `bg.void` | `#080A0F` | Fundo base OLED da aplicação | — |
| `bg.surface` | `#111521` | Cards principais, sheets, barra lateral Web | — |
| `bg.elevated` | `#191F31` | Modais, dropdowns, balões de chat recebidos | — |
| `border.subtle` | `rgba(255,255,255,0.08)` | Divisores elegantes de 1px | — |
| `border.glow` | `rgba(139,92,246,0.45)` | Borda de foco / Card em destaque / Match | — |
| `brand.primary` | `#8B5CF6` | Electric Violet — CTA primário, identidade | AA+ com `#FFFFFF` |
| `brand.secondary` | `#EC4899` | Neon Magenta — Like, Química, Coração/Match | AA+ com `#FFFFFF` |
| `brand.gradient` | `linear(135deg, #8B5CF6, #EC4899)` | Botão de Match, anel de 90%+ afinidade | — |
| `accent.cyber` | `#06B6D4` | Cyber Cyan — Online agora, Lobby Duo, Selo Verificado | AAA em fundo escuro |
| `semantic.success` | `#10B981` | Compatibilidade alta ($\ge 85\%$), Rank verificado | AAA em fundo escuro |
| `semantic.warning` | `#F59E0B` | Alerta de agenda parcial, lembrete gentil | AAA em fundo escuro |
| `semantic.danger` | `#EF4444` | Denúncia, bloqueio, erro crítico | AA+ |
| `text.primary` | `#F8FAFC` | Títulos, nomes, mensagens principais | **17.4:1** (WCAG AAA) |
| `text.secondary` | `#94A3B8` | Bios, legendas, subtítulos, horários | **6.8:1** (WCAG AA+) |
| `text.muted` | `#64748B` | Timestamps, placeholders, metadados | **4.6:1** (WCAG AA) |

> **Regra de Ouro Visual:** No máximo **10% da tela** pode ter cores vibrantes/neon. **90% da tela** é composta por superfícies profundas (`bg.void`/`bg.surface`), fotografia humana de alta qualidade e tipografia cristalina.

---

## 3. Tipografia Matemática & Posicionamento Impecável de Textos

A beleza de uma interface moderna está 70% na **tipografia, ritmo vertical e respiro (whitespace)**.

### 3.1 Font Pairing
- **Display & Headings:** `Space Grotesk` (geométrica, contemporânea, forte personalidade tech/gamer sem perder sofisticação).
- **Body & UI:** `Plus Jakarta Sans` (altíssima legibilidade em telas pequenas, números limpos, acentuação impecável em português brasileiro).
- **Mono (Elo, Match %, IDs, Timestamps):** `JetBrains Mono` com `font-variant-numeric: tabular-nums` (os números nunca "pulam" horizontalmente em contadores!).

### 3.2 Escala Tipográfica Modular (Razão `1.200` — Minor Third)
| Papel | Tamanho | Line-Height | Weight | Letter-Spacing | Uso |
|---|---|---|---|---|---|
| `display.xl` | `32px` (mobile) / `44px` (web) | `1.15` | `700` | `-0.03em` | Tela de Match ("É DUO!"), Hero Web |
| `heading.lg` | `24px` | `1.20` | `700` | `-0.02em` | Nome + Idade no Card, Títulos de Tela |
| `heading.md` | `18px` | `1.30` | `600` | `-0.01em` | Seções ("Jogos Favoritos", "Horários") |
| `body.lg` | `16px` | `1.50` | `400` | `0em` | Bio do perfil, mensagens de chat |
| `body.md` | `14px` | `1.45` | `500` | `0em` | Subtítulos, chips, descrições secundárias |
| `label.sm` | `12px` | `1.30` | `600` | `+0.04em` | Badges, tags de jogo, status "ONLINE" |
| `mono.stat` | `14px–20px` | `1.10` | `700` | `-0.02em` | `94% MATCH`, `12h/sem`, `Platina II` |

### 3.3 Regras Rígidas de Posicionamento de Textos (Zero Quebra Feia / Zero Overflow)
1. **Regra de Comprimento de Linha (`Measure`):** Blocos de texto corrido (bio, prompts, mensagens longas) têm largura máxima estrita de **`55ch` a `65ch`** (no Web, centralizados ou contidos em colunas) para leitura sem fadiga ocular.
2. **Hierarquia sobre Fotografia (Scrim Obrigatório):** Nunca colocar texto branco direto sobre foto. Sempre aplicar um gradiente vertical suave (`linear-gradient(to top, rgba(8,10,15,0.95) 0%, rgba(8,10,15,0.55) 45%, transparent 100%)`) nos 45% inferiores do Match Card para garantir contraste AAA independente da foto do usuário.
3. **Proteção contra Overflow (Flutter & Web):**
   - Nomes longos sempre envolvidos em `Expanded`/`Flexible` com `maxLines: 1` e `TextOverflow.ellipsis` (`truncate` no Tailwind).
   - Tags/Chips de jogos usam `Wrap` (Flutter) / `flex-wrap` (Web) com espaçamento constante de `8px` (`spacing: 8, runSpacing: 8`), nunca em `Row` fixa sem scroll.
   - Respeito ao escalonamento de fonte de acessibilidade do SO: no Flutter usar `MediaQuery.textScalerOf(context).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.35)` mantendo layouts elásticos!
4. **Grid de Espaçamento de 4px/8px:** Margens laterais padronizadas (`16px` mobile compacto, `20px` mobile padrão, `32px` tablet/desktop). Todo padding interno de card é múltiplo de `8px` (`16px` ou `24px`).

---

## 4. Responsividade Multi-Plataforma (Mobile + Tablet + Web 2º Monitor)

| Breakpoint | Largura | Layout Padrão | Experiência Otimizada |
|---|---|---|---|
| **Mobile Compact** | `< 380px` | 1 coluna, Bottom Navigation (4 abas), Cards full-bleed | Operação 100% com um polegar (*Thumb Zone*) |
| **Mobile Standard** | `380px – 599px` | 1 coluna, Bottom Nav flutuante glassmorphic | Experiência nativa Flutter 60/120fps |
| **Tablet / Foldable** | `600px – 1023px` | Navigation Rail lateral esquerda + Conteúdo centralizado (`max-w-680px`) ou Split-View no Chat | Aproveitamento inteligente de tela sem esticar cards |
| **Web Desktop (2º Monitor)** | `1024px – 1439px` | **3 Colunas:** Rail de Navegação (`80px`) + Lista de Matches/Lobby (`320px`) + Palco Principal (Deck ou Chat E2EE) | Ideal para ficar aberto ao lado do jogo enquanto busca fila! |
| **Ultrawide** | `≥ 1440px` | Container máximo `1440px` centralizado + Painel direito de *Gamer DNA / Detalhes do Match* | Zero espaço vazio desperdiçado |

---

## 5. Arquitetura de Telas do MVP (Especificação Visual)

1. **Splash & Welcome Cinemático:** Fundo com aura radial roxo/ciano sutil animada, logo minimalista NEXUS DUO, 2 botões claros ("Entrar com Discord" destaque + "Continuar com Email/Google") e promessa clara de privacidade.
2. **Onboarding em 4 Passos Rápidos (< 90s):**
   - *Passo 1:* Identidade básica (Nome/Nick, Data de Nascimento 18+, Gênero, O que busca, Cidade/Localização segura).
   - *Passo 2:* Seleção visual de **Top 5 Jogos** (busca instantânea via catálogo IGDB/RAWG com capas em grid 3 colunas) + Plataformas (PC, PS5, Xbox, Switch, Mobile).
   - *Passo 3:* **Gamer DNA & Horários** — sliders intuitivos (*Casual <-> Competitivo*, *Call de Voz <-> Só Chat*) + seletor tátil de horários livres da semana (Manhã/Tarde/Noite/Madrugada por dia).
   - *Passo 4:* Fotos (com compressão automática WebP) + convite opcional de **Selfie Liveness** (selo verificado) e **Print de Rank (OCR)**.
3. **Descoberta — Deck "Daily Loot Drop":**
   - Card vertical elegante ocupando 78% da altura, foto principal com scrim perfeito, **Anel de Match Score** no topo direito (`94%`), Nome + Idade + Selo Verificado Cyan + Distância aproximada (`~8 km`).
   - Pílulas de **Jogos em Comum** destacadas com brilho sutil + Badge de Agenda (`6h livres em comum`).
   - Scroll vertical suave no próprio card revela: Prompt respondido, *Gamer DNA Radar/Bars*, Rank verificado via OCR e *GG Badges*.
   - Barra de ações na *Thumb Zone*: Passar (`X`), Super Convite/Duo (`🎮`), Curtir (`💜`).
4. **Celebração de Match ("IT'S A DUO!"):**
   - Avatares dos dois perfis convergindo em anel gradiente Violeta/Magenta, exibição imediata da compatibilidade e **3 botões de Co-op Icebreaker prontos** para iniciar o papo em 1 toque.
5. **Lobby "Duo Agora" (Efêmero 2h):**
   - Feed em tempo real de matches ou perfis compatíveis que marcaram *"Disponível para jogar agora"*, mostrando o jogo escolhido, modo (Casual/Ranked/Co-op) e tempo restante da lobby.
6. **Chat E2EE em Tempo Real:**
   - Indicador discreto de cadeado (`Criptografado de ponta a ponta`), bolhas com alto contraste, botão rápido *"Chamar pro Jogo / Enviar Link Lobby"*, *blur* protetor em imagens recebidas e avaliação pós-partida com *GG Badges*.
7. **Perfil & Gamer DNA Card Compartilhável:**
   - Visual estilo "carta holográfica colecionável" gerada no cliente para exportar em formato Stories (`9:16`) com QR Code / link `nexusduo.app/u/@nick` — motor de crescimento orgânico custo zero!
8. **Central de Privacidade, Segurança & Atualizações:**
   - Status da versão instalada, verificação instantânea de nova Release no GitHub/OTA, exportação de dados LGPD e exclusão de conta.
