# Retomar — estado em 2026-08-11, 16h30

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

## Onde o trabalho parou

**Sprint 004 fechado com sucesso.** PR [#138](https://github.com/The-Band-Solution/theband/pull/138)
verde, revisor `the-band` pedido, 29 issues fechadas, 218 testes, nove gates.

A plataforma coleta e classifica o trabalho de duas organizações:

```
135 repositórios · 4455 issues · 4455 promoções vigentes · 1614 vínculos
```

## Defeito conhecido, e sem caminho pela interface

**Job `discarded` deixa o `sync` em `running` para sempre.** O índice único
`syncs_one_running_per_tool_index` então bloqueia qualquer coleta nova daquela ferramenta, e
não existe botão para destravar — só SQL:

```sql
UPDATE syncs SET status='interrupted', finished_at=now(),
  error_reason='interrompida: o processo que a executava não existe mais'
WHERE status='running';
```

Vai acontecer com qualquer job que esgote as tentativas. As duas correções possíveis: um
`Oban.Telemetry` handler no evento de descarte, ou marcar como interrompido ao carregar a
tela todo `sync` `running` cujo job não está mais executando. A segunda é mais simples e não
depende de o handler estar registrado.

## Feito — a barra com percentual

**Concluída.** O denominador vem da origem: `repositories.totalCount` e `issues.totalCount`,
guardados em `sync_checkpoints.expected_count`.

```
████████████████████  100%   208 de 208
organização 1 │ pessoas │ equipes │ repositórios 14 │ issues 194 │ promoção 4463
```

Onde a origem não informa total, a barra **não aparece** — a fase mostra contagem e estado.

Hoje a tela `/sincronizacoes` mostra **seis fases** com contagem, e não percentual — e o
comentário no código explica por quê: a paginação é por cursor, e a plataforma não sabe
quantas páginas existem antes de pedir a última.

**O pedido é percentual, e ele é atendível — com uma decisão sobre o denominador:**

| Denominador possível | O que ele afirma | Custo |
|---|---|---|
| fases concluídas / 6 | progresso do **processo**, não do volume | zero; é o que já existe, expresso em % |
| `totalCount` da origem | progresso do **volume** | uma consulta a mais por entidade; o GitHub fornece `totalCount` em `issues` e `repositories` |
| contagem da coleta anterior | estimativa | mente na primeira coleta e quando o volume muda |

A segunda é a honesta e é viável: `issues(first: n) { totalCount }` já vem nas consultas que
existem em `priv/connectors/github/queries/issues.graphql`. **Guardar o total no checkpoint**
e dividir dá percentual real por entidade.

O que **não** fazer: percentual sobre denominador inventado. É a família da L22 — número que
parece informação e não é.

## Depois disso, a fila

| # | O que | Estado |
|---|---|---|
| 1 | **Percentual na barra** | pedido, interrompido |
| 2 | **Plano da feature 005** | `research.md` com **sete** decisões; falta `plan.md`, `data-model.md`, `contracts/`, `quickstart.md`. Backlog: épico [#139](https://github.com/The-Band-Solution/theband/issues/139), US [#140](https://github.com/The-Band-Solution/theband/issues/140) a [#143](https://github.com/The-Band-Solution/theband/issues/143) |
| 3 | **Plano da feature 006** | spec pronta (34 FR), nada do plano |
| 4 | Sprint 005 | abrir depois dos planos |

### A decisão de ordem entre 005 e 006, e a razão

**005 primeiro.** Ela recalcula sobre payload preservado, **sem nenhuma requisição à
origem**, e promove até 3440 issues. A 006 exige coletar campos novos das 4455.

## As duas features especificadas

**005 — regras de mapeamento por organização** (45 FR, 17 SC, 4 US)
Regex e texto simples, prévia antes de gravar, recálculo sem recoleta. O catálogo de padrões
**já existe** em `priv/knowledge_base/rules/github_issue_pattern_catalog.yaml`, com três
seções: 3 regras de tipo declarado, 7 padrões de título, e **8 padrões que NÃO são tipo**.

A decisão central do `research.md`: **catálogo em YAML lido no boot, regra da organização no
banco lida por consulta** — porque regra cadastrada pela tela precisa valer sem restart.

E a tela **vive na sincronização** (FR-050 a FR-052), decidido em 2026-08-11: a lacuna nasce
da coleta, e quem acabou de sincronizar está a um clique de resolver. Como **componente com
cabeçalho próprio**, alcançado pela organização — o princípio X não permite misturá-la ao
relatório de execução.

**006 — detalhe da issue e decomposição** (34 FR, 13 SC, 4 US)
Corpo, autor, designados, rótulos, estado. E a decomposição com as duas relações
**separadas**: épico **compõe-se de** user story; user story **é atendida por** tarefa. Somar
as duas conta esforço duas vezes.

## O que o dado real mostra, e que vale ter na cabeça

```
3403  issues sem tipo na origem     76% — a leds-conectafapes quase não usa tipos
2911  delas com prefixo no título   [TASK] 1024 · [FEATURE] 111 · [US] 60
1409  prefixo que É tipo
1274  prefixo que é ÁREA            [Devops] 340 · [Back-end] 256 · [QA] 97
  37  tipo declarado desconhecido   Chore 17 · Refactor 16 · Hotfix 4
  41  tarefas cujo pai é ÉPICO      viola sro.rule07
   3  tarefas sem pai               viola sro.rule07
```

**Quase metade dos prefixos não é tipo.** É a razão da US4 da 005 — "não mapear o que não é
tipo" — e do catálogo trazer os padrões de área **para serem recusados**.

## Dívida declarada, com destino

| O quê | Situação |
|---|---|
| `connected_tools.status` materializa situação | contra a D7; **não ampliada** — a 004 não criou `sro_user_stories.status` |
| `refused_links` como previsão | 4 linhas, todas `out_of_scope`, **nenhuma por ciclo**. O critério de reversão do plano continua valendo |
| RSRO e SYS_SWO sem estereótipo | 15 conceitos. Era 16; a regra da fronteira exigiu **um** |
| Paridade Elixir/Python | 4 verificações contra 12 |
| Iteration no Projects v2 | não existe para os sprints 003 e 004. Criar mexe na configuração que causou a L11 |
| Aprovação de revisão | bloqueada por ferramenta: com uma identidade, o autor não aprova |
| Reparo do dado da L19 | acontece na próxima coleta real de cada organização |

## Como rodar

```bash
docker compose up -d
export THE_BAND_MASTER_KEY=$(mix the_band.gen_key)   # a original foi perdida
mix phx.server                                        # localhost:4000
mix gates                                             # os nove
```

**A chave original do banco de desenvolvimento não existe mais.** O PAT cifrado com ela é
ilegível; o caminho é encerrar e retomar a observação com token novo, em `/ferramentas`. Ver
[deployment.md](../deployment.md).

**Para enfileirar coleta sem a chave**: `mix run --no-start` sobe só o Repo, e o servidor no
ar executa o job com a chave dele. Script de exemplo ficou em `/tmp/refazer.exs` desta sessão
— ele tem a organização **fixa** em `The-Band-Solution`, o que já causou confusão.

## Documentos que valem ler antes de mexer

| Documento | Para quê |
|---|---|
| [modelo-de-dados.md](../architecture/modelo-de-dados.md) | por que o esquema tem essa forma — ele é **derivado** |
| [deployment.md](../deployment.md) | as 12 variáveis, e as armadilhas de cada uma |
| [licoes-aprendidas.md](licoes-aprendidas.md) | 26 lições. As quatro últimas são o mesmo defeito |
| constituição v1.4.0 | dez princípios; IX e X foram acrescentados hoje |
