# 🤝 Guia de Contribuição — NEXUS DUO

Obrigado pelo interesse em construir o **NEXUS DUO**. Este projeto segue padrões sênior de engenharia, segurança, acessibilidade e qualidade de código.

---

## 1. Fluxo de Branches (Git Flow Pragmático)

| Branch | Finalidade | Proteção |
|---|---|---|
| `main` | Produção estável. Cada tag `vX.Y.Z` gera Release + APK + Deploy Web | Apenas via PR aprovado + CI verde |
| `develop` | Integração contínua das features da sprint | Apenas via PR com testes passando |
| `feat/<escopo>-<descricao>` | Nova funcionalidade (ex.: `feat/match-dp-schedule`) | Merge via squash em `develop` |
| `fix/<escopo>-<descricao>` | Correção de bug (ex.: `fix/chat-e2ee-nonce`) | Merge via squash em `develop` |
| `security/<descricao>` | Correção de segurança / RLS | Revisão obrigatória de segurança |
| `docs/<descricao>` | Atualizações de arquitetura e documentação | Revisão leve |

---

## 2. Padrão de Commits (Conventional Commits)

Use sempre o formato: `<tipo>(<escopo>): <descrição imperativa e objetiva>`

- `feat(mobile):` nova funcionalidade no app Flutter
- `feat(web):` nova funcionalidade no app Next.js
- `feat(db):` nova migration, função RPC ou policy RLS no Supabase
- `fix(security):` correção de vulnerabilidade ou criptografia
- `perf(algo):` otimização algorítmica ou de índice SQL
- `test(e2e):` adição ou correção de testes automatizados
- `docs(arch):` atualização de documentação ou ADRs
- `chore(ci):` ajustes em GitHub Actions, releases ou dependências

---

## 3. Padrões Obrigatórios de Engenharia

1. **Clean Architecture + OOP Estrito:**
   - Regras de domínio (`domain/`) não podem importar pacotes de UI ou SDKs externos.
   - Use **Encapsulamento** (campos privados, Value Objects imutáveis, fábricas validadas) e **Polimorfismo** (interfaces/contratos para provedores de jogos, estratégias de match e criptografia).
2. **Design System & Responsividade:**
   - Jamais use cores hardcoded fora de `packages/design-tokens`.
   - Toda nova tela deve ser validada em mobile compacto (`360x800`), mobile grande (`430x932`), tablet (`768x1024`) e desktop (`1440x900`).
3. **Banco de Dados Zero-Trust:**
   - Nenhuma tabela nova pode ser criada sem `ENABLE ROW LEVEL SECURITY` e políticas explícitas de `SELECT`, `INSERT`, `UPDATE`, `DELETE`.
   - Toda migration deve possuir teste automatizado de isolamento de tenant/usuário.
4. **Qualidade (Definition of Done):**
   - `dart analyze` = **0 issues**.
   - `flutter test` = **100% passando** (cobertura de domínio $\ge 85\%$).
   - `npm run lint && npm run typecheck && npm test` = **100% passando**.
   - Nenhum segredo, token, `.env` ou chave privada commitada no repositório.
