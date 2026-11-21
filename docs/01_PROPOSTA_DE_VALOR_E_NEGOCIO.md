# 💎 01 — Proposta de Valor, Estratégia de Startup e Economia

## 1. Declaração de Posicionamento

> Para **jogadores adultos (18–35+ anos)** que buscam relacionamentos amorosos ou conexões afetivas profundas sem precisar esconder ou justificar sua paixão por games, o **NEXUS DUO** é uma plataforma de relacionamento Mobile e Web que transforma **compatibilidade de jogos, horários livres e estilo de comunicação** em encontros leves e autênticos — começando na lobby e evoluindo para a vida real.

Diferente do Tinder (superficialidade visual), do Bumble (fricção de conversa fria) ou de apps nichados datados como Kippo/Boo (excesso de paywalls, UI poluída ou baixa densidade local no Brasil), o **NEXUS DUO** combina **design de luxo escuro**, **verificação antifraude on-device gratuita**, **criptografia de ponta a ponta** e **mecânicas psicológicas anti-ghosting**.

---

## 2. Value Proposition Canvas (VPC)

### 👤 Perfil do Cliente (Customer Profile)

| Dimensão | Detalhamento Profundo |
|---|---|
| **Tarefas (Customer Jobs)** | Encontrar parceiro(a) romântico(a) que respeite e compartilhe o hobby gamer; achar um "Duo fixo" no mesmo horário; sair do "oi, tudo bem?" sem constrangimento; sentir segurança real contra perfis falsos e toxicidade. |
| **Dores (Pains)** | Preconceito em apps tradicionais ("jogar videogame é infantil"); fadiga de swipe; matches que nunca respondem (ghosting); assédio/machismo contra mulheres em lobbies abertos; paywalls agressivos para ver quem deu like; medo de expor endereço ou foto em apps inseguros. |
| **Ganhos (Gains)** | Primeiro "encontro" sem pressão (uma partida casual no Discord/jogo); saber de imediato se os horários batem; ver rank/jogos verificados sem mentira; interface linda que dá orgulho de compartilhar o "Gamer Card" nos Stories. |

### 🎁 Mapa de Valor (Value Map)

| Dimensão | Como o NEXUS DUO Entrega |
|---|---|
| **Produtos & Serviços** | App Mobile Flutter + Web App "2º Monitor" Next.js; Algoritmo de Match por Gamer DNA + Programação Dinâmica de Horários; Lobby Efêmero "Duo Agora"; Chat E2EE com *Co-op Icebreakers*; Verificação Liveness + OCR de Rank. |
| **Aliviadores de Dor (Pain Relievers)** | Elimina conversa vazia via quebra-gelo contextual; bloqueia fakes via *Selfie Liveness* gratuito; combate toxicidade com selos positivos de Fair Play ("GG Badges") e moderação proativa; protege privacidade com *Location Fuzzing* (nunca mostra coordenadas exatas). |
| **Criadores de Ganho (Gain Creators)** | *Daily Loot Drop* curado às 20h (horário nobre gamer); *Gamer DNA Shareable Card* pronto para Instagram/TikTok/Discord (viralidade orgânica); compatibilidade percentual transparente ("94% Match — 14h/semana em comum"). |

---

## 3. Lean Canvas (Startup Execution Blueprint)

| Bloco | Definição |
|---|---|
| **1. Problema** | 1) Apps tradicionais penalizam o perfil gamer; 2) Ghosting acima de 70% em apps de namoro; 3) Toxicidade e catfish afastam mulheres e jogadores casuais. |
| **2. Segmentos de Clientes** | Early adopters: gamers 18–32 anos no Brasil (Valorant, LoL, Fortnite, Genshin, Minecraft, Stardew Valley, CS2, FIFA/EA FC, RPGs) ativos em Discord, Twitch e TikTok. |
| **3. Proposta Única de Valor (UVP)** | *"Seu Duo no Jogo. Seu Match na Vida."* — O primeiro relacionamento que começa jogando junto, com segurança verificada e zero toxicidade. |
| **4. Solução** | Match por afinidade de jogos + horários livres (DP) + Lobby "Duo Agora" + Chat E2EE + OCR de Rank + Web 2º Monitor. |
| **5. Canais (CAC = R\$ 0)** | Compartilhamento orgânico do *Gamer DNA Card* no Instagram/TikTok/X; bots/convites em servidores Discord parceiros; SEO programático no Next.js ("Encontre seu Duo de Valorant em São Paulo"); micro-criadores de conteúdo gamer. |
| **6. Fontes de Receita (Pós-MVP)** | Freemium ético (sem bloquear chat ou match): **NEXUS Pass** (R\$ 14,90–24,90/mês) com filtros avançados de elo/horário, molduras animadas no Gamer Card, *Undo* ilimitado e destaques de Lobby; parcerias com marcas de periféricos/eventos. |
| **7. Estrutura de Custos** | **MVP: R\$ 0,00/mês** (Supabase Free Tier + Vercel/Cloudflare Pages Free + GitHub Actions/Releases + Shorebird Free + Google ML Kit On-Device + APIs gratuitas). |
| **8. Métricas-Chave (KPIs)** | North Star: **Matches que jogam ou trocam $\ge 10$ mensagens em 48h** (*Meaningful Duo Rate*). Secundárias: Retenção D1/D7/D30, % Perfis Verificados, Tempo até 1ª resposta, K-Factor viral. |
| **9. Vantagem Injusta** | Algoritmo de sobreposição de agenda real (DP) + Web App de 2º Monitor sincronizada + E2EE nativo + arquitetura de custo marginal próximo de zero. |

---

## 4. Análise Competitiva

| Concorrente | Pontos Fortes | Fraquezas Críticas | Como o NEXUS DUO Vence |
|---|---|---|---|
| **Tinder / Bumble** | Alta base de usuários | Superficial, paywall pesado, cultura de swipe infinito, não filtra jogos/horários | Foco em afinidade real de jogos + horários + *Co-op First Date* |
| **Boo** | Usa MBTI/personalidade, tem aba gamer | Interface poluída, paywall precoce, experiência web pesada | UI *Cyber-Velvet* limpa, sem paywall predatório no core, Web 2º Monitor rápida |
| **Kippo** | Estética gamer divertida | Alta taxa de contas inativas no Brasil, sem E2EE, foco confuso entre rede social e namoro | Foco claro em conexão afetiva real, verificação Liveness/OCR e privacidade forte |
| **GamerLink / Noobly** | Bom para achar squad (LFG) | Não é focado em relacionamento afetivo, UX utilitária | Combina busca afetiva + modo "Duo Agora" com design premium |

---

## 5. Economia & Escalabilidade (Unit Economics)

### Fase 0 — MVP & Validação (0 a 5.000 MAU)
- **Infraestrutura:** **R\$ 0,00/mês**
  - Supabase Free Tier: até **50.000 MAU** no Auth, 500 MB DB, 1 GB Storage, 5 GB Egress, 200 conexões Realtime simultâneas.
  - Otimização econômica crítica: compressão client-side para **WebP (max 80 KB/foto, max 4 fotos/perfil = 320 KB/usuário)** + embeddings compactos `vector(128)` (~512 bytes/usuário) -> **500 MB de banco comportam facilmente 50.000+ perfis e milhões de swipes!**
  - Cache agressivo de capas de jogos via URLs CDN oficiais do IGDB/Steam (zero consumo do nosso Storage/Egress para capas de jogos!).
- **Custo de IA / Visão Computacional / OCR:** **R\$ 0,00/mês** (100% executado na CPU/NPU do celular/navegador do próprio usuário).

### Fase 1 — Tração (5.000 a 50.000 MAU)
- Upgrade apenas quando necessário: Supabase Pro (~US\$ 25/mês) + Cloudflare R2 (10 GB grátis + zero egress fee!).
- Break-even estimado: apenas **12 assinantes pagos** do NEXUS Pass já cobrem 100% do Supabase Pro!

### Fase 2 — Escala (100.000+ MAU)
- Read Replicas PostgreSQL, particionamento de tabela `swipes` e `messages` por data/região, CDN Cloudflare com edge caching, monetização híbrida (assinatura cosmética + eventos patrocinados).
