# Sprint 034 — o servidor MCP

**Período**: 2026-09-24 a 2026-10-07 (proposto)
**Feature**: [062 — o servidor MCP](../../../specs/062-servidor-mcp/spec.md)
**Plano**: [plan.md](../../../specs/062-servidor-mcp/plan.md) · **Tarefas**: [tasks.md](../../../specs/062-servidor-mcp/tasks.md) · **Segurança**: [autoavaliação](../../../specs/062-servidor-mcp/seguranca.md), [revisão independente](../../../specs/062-servidor-mcp/seguranca-revisao-independente.md), [R3](../../../specs/062-servidor-mcp/r3-cowlib-alcance.md)

## Objetivo do sprint

Um agente conectado por MCP pergunta sobre uma equipe e recebe a resposta **com a ressalva no
mesmo objeto**. A recusa sai como resposta, e toda leitura concedida fica registrada, com a
ferramenta e a equipe.

## O que veio antes, e por que este sprint começa agora

Em 2026-09-24, a pessoa mantenedora pediu *"garanta que tudo está seguro antes de fazer o
MCP"*. Antes de abrir este sprint:

| PR | O quê |
|---|---|
| [#944](https://github.com/The-Band-Solution/theband/pull/944) | o plano reconciliado com o código, o inventário de segurança, a revisão independente (T009) e as tarefas reescritas |
| [#945](https://github.com/The-Band-Solution/theband/pull/945) | N5: o token de organização suspensa deixava de ser recusado. **Estava em produção** |
| [#946](https://github.com/The-Band-Solution/theband/pull/946) | H2-R: o perfil escrito pelo modelo ficava fora do veredito. **Estava em produção** |

Também antes: o token de produção exposto ao proxy TLS foi revogado, e não leu nada depois
das medições.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), as que se aplicam a este sprint:

| Lição | Como está sendo aplicada |
|---|---|
| **L79** — agente com árvore compartilhada não troca de branch | reincidiu em 2026-09-24, ao preparar este sprint. Trabalho em outro branch, com agente de fundo ativo, vai para `git worktree` |
| **L21** — função pública sem consumidor não é funcionalidade | cada ferramenta só conta como feita com o cliente MCP real chamando-a (T030) |
| **L77** — verificador novo nasce com teste que não passa por ele | toda guarda nova (T008, T016, as três do R3 no T001) é provada com defeito injetado |
| **L81** — fechar o contraexemplo não fecha a classe | o R6 é tratado como classe: o caminho único do T006, e não uma checagem por ferramenta |
| **L91 / L96 / L99** — o passo sem gate some; conferir issue por issue | as 26 issues são fechadas uma a uma, com a evidência na issue (constituição, princípio VII) |
| **L95** — pedir revisor não é obter revisão | a lacuna de revisão é declarada em cada PR, e nunca marcada como cumprida |
| **L108** — feature sem sprint backlog | este documento existe antes da primeira linha de código |

**Uma lição nova, a registrar ao fechar este sprint**: no zsh, `$VAR` sem aspas não se divide
em palavras. Uma lista de arquivos passada assim ao `mix test` vira **um** caminho, que o `mix`
ignora sem aviso quando há outros caminhos válidos. Um "149 passed" foi dado sem que 17
arquivos rodassem. Use `${=VAR}`, ou `"$@"` depois de `set --`.

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2). As 30 issues
estão no projeto.

**Iteration: não atribuída, e é limitação declarada.** O campo tem uma só iteração ativa, a
*Sprint 026 — Herança e a produção*, de 2026-09-19, com 7 dias. A numeração do projeto (026)
já divergia da deste diretório (034). E criar iteração pela API **recria as existentes**
(L11, L72), o que tiraria a iteração dos itens já atribuídos. A saída é criar a iteração
*Sprint 034* pela interface do GitHub, que acrescenta sem recriar, e só então atribuir.

**Tipos**: a organização tem só `Task`, `Bug` e `Feature`. Épico e user story seguem o padrão
da casa, **por label** (`epic`, `us`) e por hierarquia de sub-issues. Criar os tipos `Epic` e
`User Story` muda a configuração da organização, e fica como decisão à parte.

## Épico e user stories

| # | User story | Label | Épico | Issue | Priority | Estimate | Tarefas |
|---|---|---|---|---|---|---|---|
| — | 062: o servidor MCP | epic | — | [#947](https://github.com/The-Band-Solution/theband/issues/947) | P1 | — | 14 diretas, e as 3 US |
| US1 | O agente responde sobre a equipe sem perder a ressalva | us | [#947](https://github.com/The-Band-Solution/theband/issues/947) | [#948](https://github.com/The-Band-Solution/theband/issues/948) | P1 | — | 6 |
| US2 | A recusa é resposta, e concorda com as outras portas | us | [#947](https://github.com/The-Band-Solution/theband/issues/947) | [#949](https://github.com/The-Band-Solution/theband/issues/949) | P1 | — | 3 |
| US3 | A leitura fica registrada, e o abuso é detectável | us | [#947](https://github.com/The-Band-Solution/theband/issues/947) | [#950](https://github.com/The-Band-Solution/theband/issues/950) | P1 | — | 3 |

`Priority` P1 vem do `tasks.md`, onde as três user stories são P1. **`Estimate` está em
branco, e isso quer dizer desconhecido, não zero.** A complexidade não foi estimada, e
inventar um número mediria como se a estimativa tivesse sido feita.

## Tarefas

| # | Tarefa | Atende | Tipo | Issue | Estimate | Estado |
|---|---|---|---|---|---|---|
| T001 | Travar a dependência do protocolo | épico | Task | [#951](https://github.com/The-Band-Solution/theband/issues/951) | — | feito |
| T002 | Criar o esqueleto do contexto MCP | épico | Task | [#952](https://github.com/The-Band-Solution/theband/issues/952) | — | feito |
| T003 | Expor a medida da base de conhecimento | épico | Task | [#953](https://github.com/The-Band-Solution/theband/issues/953) | — | feito |
| T004 | Montar o envelope de proveniência | épico | Task | [#954](https://github.com/The-Band-Solution/theband/issues/954) | — | feito |
| T005 | Nomear os três estados da ausência | épico | Task | [#955](https://github.com/The-Band-Solution/theband/issues/955) | — | feito |
| T006 | Abrir o registro de ferramentas — e fazer dele o caminho único | épico | Task · security | [#956](https://github.com/The-Band-Solution/theband/issues/956) | — | feito |
| T016 | Fechar a lista de métodos do protocolo, antes da biblioteca | épico | Task · security | [#957](https://github.com/The-Band-Solution/theband/issues/957) | — | feito |
| T007 | Servir o MCP autenticado | épico | Task · security | [#958](https://github.com/The-Band-Solution/theband/issues/958) | — | feito |
| T008 | Guardar a fronteira do banco | épico | Task | [#959](https://github.com/The-Band-Solution/theband/issues/959) | — | feito |
| T010 | Responder quem está na equipe | US1 | Task | [#960](https://github.com/The-Band-Solution/theband/issues/960) | — | feito |
| T011 | Responder o que cada um tem aberto | US1 | Task | [#961](https://github.com/The-Band-Solution/theband/issues/961) | — | feito |
| T012 | Responder a espera por revisão | US1 | Task | [#962](https://github.com/The-Band-Solution/theband/issues/962) | — | feito |
| T013 | Responder o que está parado | US1 | Task | [#963](https://github.com/The-Band-Solution/theband/issues/963) | — | feito |
| T014 | Marcar o texto de terceiro no schema | US1 | Task · security | [#964](https://github.com/The-Band-Solution/theband/issues/964) | — | feito |
| T015 | Declarar o que cada ferramenta não responde | US1 | Task | [#965](https://github.com/The-Band-Solution/theband/issues/965) | — | a fazer |
| T017 | Recusar como resposta, nunca como erro | US2 | Task | [#966](https://github.com/The-Band-Solution/theband/issues/966) | — | a fazer |
| T018 | Provar a paridade das três portas | US2 | Task | [#967](https://github.com/The-Band-Solution/theband/issues/967) | — | a fazer |
| T019 | Recusar token revogado na chamada seguinte | US2 | Task | [#968](https://github.com/The-Band-Solution/theband/issues/968) | — | a fazer |
| T021 | Registrar a leitura no ponto do veredito | US3 | Task · security | [#969](https://github.com/The-Band-Solution/theband/issues/969) | — | feito |
| T022 | A recusa de equipe é registrada, e não vira leitura — no MCP e na API | US3 | Task · security | [#970](https://github.com/The-Band-Solution/theband/issues/970) | — | feito |
| T024 | Provar que o limite é um só por token | US3 | Task · security | [#971](https://github.com/The-Band-Solution/theband/issues/971) | — | feito |
| T027 | Varrer o objeto inteiro por segredo | épico | Task · security | [#972](https://github.com/The-Band-Solution/theband/issues/972) | — | feito |
| T028 | Medir o custo contra a rota HTTP | épico | Task | [#973](https://github.com/The-Band-Solution/theband/issues/973) | — | a fazer |
| T029 | Escrever o que o cliente precisa saber | épico | Task | [#974](https://github.com/The-Band-Solution/theband/issues/974) | — | a fazer |
| T030 | Provar ponta a ponta com um cliente | épico | Task | [#975](https://github.com/The-Band-Solution/theband/issues/975) | — | a fazer |
| T031 | Fechar os gates | épico | Task | [#976](https://github.com/The-Band-Solution/theband/issues/976) | — | a fazer |

A T009 (a revisão independente) está **feita**, e não tem issue: foi entregue no #944. As
tarefas **T023 e T025 foram removidas** em 2026-09-24, e os números ficam reservados.

## Fora do escopo deste sprint

Tudo o que o `tasks.md` declara em *Fora desta fatia*:
- as outras 73 perguntas de competência;
- OAuth;
- escrita por MCP;
- cache;
- o servidor como processo separado;
- a era legada do protocolo;
- o limite de corpo do `Plug.Parsers` (R9).

## Riscos e dependências

- **A `ex_mcp` 1.5.0 é jovem, e sai uma versão por semana.** A versão fica fixada, e a camada
  fina é o que torna a troca um trabalho de adaptador.
- **A exceção do `cowlib` no gate** vale só enquanto o adapter for o Bandit. As três guardas
  do T001 são o que a torna segura.
- **O T021 e o T022 mexem em código da 061 em produção** (`ApiReadLog`, `TeamController`).
  `api_read_log_test.exs` tem de continuar verde sem alteração.
- **Nenhum cliente MCP real foi conferido na revisão 2026-07-28 do protocolo.** O
  `:modern_only` depende disso, e o T030 é onde se descobre.
- **A suíte inteira não roda com o servidor dev de pé.** Os gates rodam com ele parado, ou no
  CI.

## Definition of Done do sprint

- [ ] `mix gates` sai com 0, lido pelo código de saída
- [ ] base de conhecimento válida
- [ ] as 26 issues fechadas com evidência, ou repriorizadas com justificativa
- [ ] o cliente MCP real chamando as quatro ferramentas (T030)
- [ ] `sprint-review.md` escrito
- [ ] `licoes-aprendidas.md` atualizado, com a lição do zsh
