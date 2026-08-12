# Pesquisa — Feature 009: a marca de inacessível se cura

Seis questões. Quatro foram respondidas **medindo o repositório** — quem chama o quê, e o que cada
número já significa —, e duas dessas medidas mudaram a decisão.

| Questão | O que a medida mudou |
|---|---|
| R1 | `list_collectable/2` tem **um** consumidor real: a decisão pode mudar de nome sem propagar |
| R4 | o mecanismo de "pulado" **incrementa `records_collected`**, então não serve para contar repositório |

---

## R1 — Onde a separação entre excluído e inacessível vive

**Medido**: `list_collectable/2` é chamada em **um** lugar de produção —
`github_work_items.ex:115`. As outras ocorrências são o `defdelegate`, a própria definição e três
comentários que citam o nome.

**Decisão**: `list_collectable/2` **passa a rejeitar só o excluído**, e o nome deixa de mentir. Não
há função nova: a que existe passa a significar o que o nome já dizia — *"o que a coleta deve
consultar"*.

**Razão**: com um consumidor, mudar a semântica é mudar o comportamento **daquele** ponto, e é
exatamente o comportamento que a feature quer mudar. Criar `list_collectable_including_unreachable/2`
ao lado deixaria duas funções cujo nome não distingue nada — e a antiga viraria a que ninguém
deveria usar, sem nada impedindo.

**O que fica pior**: qualquer chamador futuro passa a receber repositório inacessível na lista. É
mitigado pelo nome — "coletável" significa "a coleta deve tentar" — e pelo teste que fixa a
diferença entre os dois casos.

**Recusado**: parâmetro `include_unreachable: true`. Booleano em opção que só tem um chamador é
generalidade especulativa, e o `AGENTS.md` §7.7 nomeia o antipadrão.

**Recusado**: filtrar no chamador em vez de na consulta. Poria a regra de "o que se coleta" dentro
da ingestão, e ela é da camada de plataforma — CMPO decide o que está sob observação.

---

## R2 — Como a natureza do erro é julgada

**Decisão**: `Client.transient?/1` ganha **uma cláusula** para `{:graphql_errors, errors}`, que
delega a um julgamento privado por erro. **Nenhum módulo novo, nenhuma função pública nova.**

**Razão**: a pergunta *"esta falha se repete?"* já tem um lugar — é `transient?/1`, e é o que a
coleta consulta antes de marcar. Um módulo `ErrorClassifier` acrescentaria um salto para ler a
mesma decisão, e o princípio X decide contra.

**A regra, e ela é conservadora na direção certa**:

| erro da origem | natureza | por quê |
|---|---|---|
| `type: NOT_FOUND` | **permanente** | o repositório não existe, ou o token não o alcança |
| `type: FORBIDDEN` | **permanente** | falta escopo, e escopo não muda sozinho |
| `type: RATE_LIMITED` | transitória | e a pausa já a trata antes de chegar aqui |
| mensagem "Something went wrong… Please include `<id>`" | **transitória** | falha interna da origem, com identificador de incidente |
| erro sem `type` e sem essa assinatura | **permanente** | o desconhecido é tratado como permanente, e a razão está abaixo |

**Por que o desconhecido é permanente, e não o contrário**: marcar de menos deixaria repositório
apagado sendo consultado a cada coleta, para sempre. E o custo de marcar de mais **deixou de ser
permanente** nesta feature — a coleta seguinte tenta de novo. É a ordem certa: primeiro tornar a
marca reversível, depois classificar melhor.

**Numa lista com naturezas mistas, vence o permanente** — FR-008. A origem pode responder um
`NOT_FOUND` para um campo e uma falha interna para outro; tratar como transitória faria a
plataforma insistir num recurso que não existe.

**O que fica pior**: a classificação passa a depender do **texto** da mensagem para o caso interno,
e texto de terceiro muda. Mitigação: o teste usa o payload **real** que produziu a 39ª marca, e o
critério é a assinatura estável — "Something went wrong while executing your query" com
identificador de incidente. Se a origem mudar a frase, a marca volta a ser criada — e a coleta
seguinte a limpa, porque a cura agora existe.

---

## R3 — Como preservar o começo do problema sem coluna nova

**Medido**: nenhum teste depende do comportamento atual de `mark_inaccessible/3`, que sobrescreve
`inaccessible_since` a cada falha.

**Decisão**: `mark_inaccessible/3` grava a data **só quando não há marca**. Havendo, atualiza o
motivo e **preserva** a data.

**Razão**: "desde quando" e "por que na última vez" são informações diferentes, e as duas já têm
lugar. Sobrescrever a data faz um repositório inacessível há dez dias parecer novo em cada coleta —
e aí ninguém consegue distinguir problema crônico de falha de agora.

**O que fica pior**: a data deixa de responder "quando foi a última tentativa". Aceito: a última
tentativa é a última coleta, que o registro de sincronização já datou.

**Recusado**: coluna `last_attempt_at`. Responderia uma pergunta que o registro de sincronização já
responde, e acrescentaria um lugar a escrever em cada falha.

---

## R4 — Onde vive o número de repositórios não alcançados (FR-014)

**Medido**, e a medida eliminou a opção óbvia:

```elixir
{:skipped, reason} ->
  %{
    records_collected: sync.records_collected + 1,   # ← incrementa TAMBÉM o coletado
    records_skipped: sync.records_skipped + 1,
    skip_reasons: Map.update(sync.skip_reasons, reason, 1, &(&1 + 1))
  }
```

**Decisão**: coluna nova em `syncs` — `repositories_unreachable`, inteiro, com padrão zero.

**Por que não `skip_reasons`**, que era o caminho mais curto e já aparece na tela: contar
repositório ali incrementaria `records_collected` e `records_skipped`, que contam **registros**.
Trinta e nove repositórios não alcançados viriam somados como se fossem 39 registros coletados — e
a soma que a tela exibe passaria a estar errada.

**Misturar unidade num contador é como um número certo começa a mentir**, e este projeto já pagou
por isso: a contagem por sync somava o tenant inteiro e mostrava 135 ao lado de uma coleta de 14.

**As três perguntas:**

**Qual problema concreto resolve?** Nenhum lugar diz quantos repositórios a coleta não alcançou.
Trinta e nove caíram em 2026-08-11 e a execução concluiu com **sucesso** e 100% de progresso —
porque o denominador conta só o que a plataforma decidiu olhar.

**O problema existe agora?** Sim, e é medido: 39 repositórios, 899 issues, e a tela dizia
"concluída".

**O que fica pior?** Uma coluna a mais para escrever, e um número que só esta feature grava. Se
alguém esquecer de incrementá-lo, ele fica zero — e zero aqui **afirma** que tudo foi alcançado. É
o defeito da L32 esperando acontecer, e a mitigação é o teste: uma coleta em que tudo falha exige o
número igual à contagem de repositórios.

**Padrão zero é correto neste caso**, e é a exceção que confirma a regra: "zero repositórios não
alcançados" é o estado normal de uma coleta que funcionou, e não uma ausência de informação.

---

## R5 — O que a tela passa a dizer

**Decisão**: a **mesma célula** de estado, com o texto ampliado — `unreachable since <data>` — e o
motivo abaixo, no mesmo padrão que a lista de sincronizações já usa para o motivo do encerramento.

**Nenhuma coluna nova.** A coluna de estado responde "o que a plataforma sabe sobre este
repositório", e desde quando faz parte da resposta.

**Razão**: `unreachable` sozinho lê como abandono — e era verdade até esta feature. Com a data, quem
lê distingue falha de agora de problema crônico; com o motivo, decide se age.

**O que fica pior**: a célula cresce, e numa tabela de 135 linhas isso empurra a largura. Mitigação:
a data vai em formato curto, e o motivo aparece com a fonte reduzida — o mesmo tratamento que a
organização recebe na linha da issue.

**Recusado**: coluna "desde quando" para todos os repositórios. Estaria vazia em 96 das 135 linhas,
e ausência desenhada como coluna vazia é pior que ausência nomeada no lugar onde importa.

**Recusado**: dizer na tela que "a plataforma tenta de novo a cada coleta" em cada linha. Repetir a
mesma frase 39 vezes gasta a atenção que o motivo precisa ter. A frase entra **uma vez**, no
cabeçalho da seção, e é FR-011.

---

## R6 — O custo da tentativa, e o que o torna aceitável

**Medido**: 39 repositórios marcados hoje. Cada tentativa é **uma** consulta de issues — a primeira
página. Se falhar, é uma consulta perdida; se alcançar, é a coleta que devia ter acontecido.

E a distribuição pesa a favor: **33 dos 39 têm zero issues na origem**, então a consulta que os
alcança devolve uma página vazia e termina. Só 6 têm issues, e desses, 2 concentram 879.

**O custo real por coleta**: até 39 consultas a mais, num orçamento de 5 000 pontos por hora que a
coleta inteira já consome com 121 repositórios. É **menos de um terço** do que a coleta já faz, e o
limite de taxa tem pausa própria — `pause_needed?/1`, com margem de duas vezes o custo.

**O que fica pior**: uma organização com muitos repositórios permanentemente apagados na origem
pagaria consulta por cada um, para sempre. Aceito, e o critério de revisão é claro: se isso
incomodar, a saída é **classificar melhor o erro** — `NOT_FOUND` já é permanente — e não voltar a
desistir por tempo.
