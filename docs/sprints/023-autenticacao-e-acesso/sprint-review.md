# Sprint 023 — Review

**Período**: 2026-08-28 (aberto e fechado no mesmo dia)
**Feature**: [045-autenticacao-e-acesso](../../specs/045-autenticacao-e-acesso/spec.md)
**PRs**: [#562](https://github.com/The-Band-Solution/theband/pull/562) (feature, squash),
[#564](https://github.com/The-Band-Solution/theband/pull/564) (fix schema do perfil),
[#565](https://github.com/The-Band-Solution/theband/pull/565) (complemento pós-squash),
[#566](https://github.com/The-Band-Solution/theband/pull/566) (barra dos checks) e
[#567](https://github.com/The-Band-Solution/theband/pull/567) (/ai operacional — ressalva da aceitação)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3 |
| Tarefas | 14 | 14 |
| Entregáveis aceitos | 3 | 3 |

## O que foi feito

| Tarefa | Issue | Entregável | Aceito |
|---|---|---|---|
| T001–T003 | [#548](https://github.com/The-Band-Solution/theband/issues/548)–[#550](https://github.com/The-Band-Solution/theband/issues/550) | Baseline limpo, bcrypt justificado, migrações com seed que preserva a visão dos admins (3 = 1 admin × 3 orgs, conferido) | sim |
| T004–T005 | [#551](https://github.com/The-Band-Solution/theband/issues/551)–[#552](https://github.com/The-Band-Solution/theband/issues/552) | Auth (recusa única, throttle, temporária) e Access (união com origem, veredito com motivo, FR-022) conforme contratos | sim |
| T006–T008 | [#553](https://github.com/The-Band-Solution/theband/issues/553)–[#555](https://github.com/The-Band-Solution/theband/issues/555) | Login do protótipo, sessão versionada com destino preservado, /accounts com temporária de uma vez | sim |
| T009–T011 | [#556](https://github.com/The-Band-Solution/theband/issues/556)–[#558](https://github.com/The-Band-Solution/theband/issues/558) | /access-scopes com derivados em hachura, veredito único nas telas, FR-023 com recorte | sim |
| T012–T014 | [#559](https://github.com/The-Band-Solution/theband/issues/559)–[#561](https://github.com/The-Band-Solution/theband/issues/561) | /profile, verificação contra a origem, gates e PR no padrão | sim |

**Aceitação**: product-owner em 2026-08-28 — 24 cenários com evidência, 43 testes da
suíte reexecutados, 6 avulsos (incluindo a varredura SC-001: 27 rotas, 100%
protegidas), SQL no dev, capturas. **3/3 aceitas**, com duas ressalvas levadas à
pessoa mantenedora e resolvidas na hora:

1. **/ai é operacional** — FR-023 vale como escrito (decisão de 2026-08-28); a chave
   segue uma por tenant. Corrigido no PR #567 com nota na spec.
2. **Gestão da marca de administrador** (fatia de FR-008) não entregue — devolvida ao
   backlog como lacuna nomeada ([#568](https://github.com/The-Band-Solution/theband/issues/568)),
   com o guarda de FR-009 a nascer testado junto dela.

## O que não foi feito

A fatia "conceder e revogar o papel de administrador" de FR-008 — devolvida ao
backlog por decisão registrada (#568). Nada mais ficou de fora.

## Defeitos encontrados e consertados no caminho

- **Generate again com 400**: schema do perfil fora do modo strict do provider —
  issue [#563](https://github.com/The-Band-Solution/theband/issues/563), PR #564, com
  guardião recursivo que reprova o próximo campo esquecido no commit.
- **Settings que "não abria"**: o dropdown abria cortado pelo `overflow-x-auto` da
  barra (defeito da 046) — PR #565, com a lição L73 sobre o diagnóstico.
- **Arthur sem dashboards**: o escopo organization alcançava 4/88 — pertença agora é
  equipe promovida ∪ evidência vigente; 84/88, PR #565.

## Evidências

- Gates locais 13/13 com EXIT no log (L60); CI verde em todos os PRs (gates +
  cobertura).
- Fluxo real no dev: temporária→tranca→definitiva→liberado; recusa única;
  login por username do GitHub.
- Capturas em evidência de sessão (sign-in, access-scopes, profile, accounts,
  página da pessoa antes/depois, menu aberto).
- Revisão independente adversarial no #562: 1 achado real (grant sem conferir
  conta/ator contra o tenant), corrigido com violações testadas nos dois sentidos.

## Dívida gerada

- Concessão órfã: implementada e exibida, sem teste dedicado.
- SC-004 (<30s) atestado em uso, não instrumentado.
- Aprovação formal de PR (`pulls/N/reviews`) segue vazia — revisão vive em
  comentário; **#564 foi mergeado sem revisor pedido** (violação registrada,
  irrecuperável).
- Specs 047 (mensagens), 048 (botão sem chave) e 049 (entrar com GitHub)
  especificadas durante o sprint e contidas no backlog.

## Lições deste sprint

No [registro acumulado](../licoes-aprendidas.md): **L72** (a API de iterations
substitui a lista inteira), **L73** (`isVisible` não vê corte por overflow — a prova
é a imagem, olhada), **L74** (a árvore de trabalho decide o que o dev server serve),
**L75** (squash-merge abre janela para commits órfãos), e **L38 anotada como defesa
que funcionou** (o guardião de custo reprovou o veredito novo antes de existir tela
lenta).
