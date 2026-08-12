# Plano de implementação: a marca de inacessível se cura

**Feature**: `specs/009-marca-que-se-cura/` · **Branch**: `012-marca-que-se-cura`
**Spec**: [spec.md](spec.md) · **Pesquisa**: [research.md](research.md)
**Constituição**: v1.4.0, dez princípios · **Origem**: #213 e #214, Bug, P0

---

## Summary

O repositório que a coleta não alcançou volta a ser tentado, e falha do momento deixa de virar
decisão permanente. E a coleta passa a **dizer** quantos repositórios não alcançou.

Medido: **39 repositórios marcados, 899 issues dentro**, duas coletas concluídas depois da última
marca e **zero** limpezas.

## O que este plano corrige, e a forma do defeito

A correção da L29, no sprint 005, declarou: *"a cura é a própria coleta — alcançou, limpa."* A frase
estava certa e o caminho não existia:

```text
coletar_repositorios/2   descobre 121 → observa 121 → FILTRA os inacessíveis → devolve 82
coletar_issues/2         para cada um dos 82: pagina, e ao concluir → clear_inaccessible
                                              ↑
                              o inacessível nunca chega aqui
```

**Cura que pressupõe um passo que o filtro impede não é cura.** É o corolário que a L35 registrou, e
esta feature é a primeira aplicação dele.

## Technical Context

| | |
|---|---|
| Linguagem | Elixir 1.20.2 / OTP 29 |
| Framework | Phoenix 1.8.9 + LiveView |
| Persistência | Ecto + PostgreSQL 17 |
| Escala | 135 repositórios observados, **39 inacessíveis**, 4521 issues |
| Orçamento da origem | 5 000 pontos por hora, com pausa em `remaining < cost * 2` |

---

## Constitution Check

### I. Domínio organizado pelas ontologias — **conforme**

Nenhum conceito novo. A marca de inacessível já é estado de plataforma em `observed_repositories`, e
o que muda é **quem a limpa** e **quando a data é sobrescrita**.

### II. Fonte externa não é domínio — **conforme, e é o centro da feature**

A **natureza** do erro da origem é julgada na borda — `Integrations.GitHub.Client` —, e o domínio
recebe a resposta já traduzida: se repete, ou não. A forma do erro do GitHub não atravessa a
fronteira.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL) — **conforme, e ampliada**

`inaccessible_since` passa a ser proveniência de verdade: **quando o problema começou**, e não
quando alguém olhou por último. E `repositories_unreachable` registra o que a execução **não**
alcançou — proveniência da lacuna, que hoje não existe.

Idempotente: tentar de novo e falhar não muda a data; tentar e alcançar limpa a marca. Duas coletas
seguidas com a origem no ar produzem o mesmo estado.

### IV. Semântica declarada em YAML versionado — **não se aplica**

Nenhum conceito, regra ou mapeamento novo.

### V. Monólito modular multitenant — **conforme**

A mudança fica em `CMPO` (o que está sob observação), em `Client` (a natureza do erro) e em
`Ingestion` (o número não alcançado). Cada uma atrás da sua fronteira, e todas recebendo `%Tenant{}`
onde há consulta.

### VI. Spec Kit e sprint backlog antes do código — **conforme**

Spec, checklist, pesquisa, este plano, data-model, contrato e quickstart antes da primeira linha. É
a quarta feature seguida na ordem.

### VII. Quality gates e revisão independente — **conforme por construção**

Dez gates por `mix gates`. O contrato vem antes da mudança de assinatura, em
[contracts/](contracts/unreachable-recovery.md).

### VIII. Desenho que o problema justifica — **conforme, dois padrões e seis recusas**

Ver abaixo. **Nenhum módulo novo**, e a recusa mais importante é o classificador de erro como
módulo próprio.

### IX. Ontologias modulares e autônomas — **não se aplica**

A feature não atravessa fronteira entre ontologias.

### X. Responsabilidade única, em módulo e em tela — **conforme, e decidiu contra duas funções**

`list_collectable/2` continua respondendo uma coisa — *o que a coleta deve consultar* —, e passa a
responder **certo**. A alternativa era uma segunda função ao lado, com nome que não distinguiria
nada.

E a tela: a coluna de estado continua respondendo *o que a plataforma sabe deste repositório*. Desde
quando faz parte da resposta, e não é pergunta nova.

---

## Registro dos padrões introduzidos (princípio VIII)

### P1 — `syncs.repositories_unreachable`

**Qual problema concreto resolve?** Nenhum lugar diz quantos repositórios a execução não alcançou.
Trinta e nove caíram e a coleta concluiu com **sucesso e 100%**, porque o denominador conta só o que
a plataforma decidiu olhar.

**O problema existe agora?** Sim, medido: 39 repositórios, 899 issues, e a tela dizia "concluída".

**O que fica pior?** Uma coluna a mais para escrever, e zero nela **afirma** que tudo foi alcançado
— o defeito da L32 esperando acontecer. Mitigação: o teste de uma coleta em que tudo falha exige o
número igual à contagem de repositórios.

### P2 — `inaccessible_reason` sem limite arbitrário

**Qual problema concreto resolve?** A coluna é `varchar(255)`, o maior motivo gravado hoje tem **181**
caracteres, e o motivo da falha interna dá **~228** com o prefixo. Sem validação no changeset, um
texto maior vai ao banco e **levanta** — e o tratamento de erro da coleta só cobre changeset
inválido, então a fase cai.

**O problema existe agora?** A folga é de **27 caracteres**, num texto que a origem controla e que
carrega identificador de incidente de tamanho variável. E a feature multiplica a frequência de
escrita.

**O que fica pior?** `text` aceita qualquer coisa, inclusive um payload inteiro por engano.
Mitigação: a truncagem acontece na **borda**, onde a mensagem é montada, e a coluna deixa de ser a
defesa — ela nunca deveria ter sido, e é o que a L05 concluiu.

### P3 — A cláusula de erro de GraphQL em `transient?/1`

**Qual problema concreto resolve?** Falha interna da origem — HTTP 200 com erro no corpo — é
classificada como permanente, e criou uma marca no mesmo dia em que a correção anterior entrou.

**O problema existe agora?** Sim, uma marca de 2026-08-12 às 12:32:29.

**O que fica pior?** A classificação passa a depender do **texto** da mensagem, e texto de terceiro
muda. Mitigação: o teste usa o payload real, e a cura existe — se a origem mudar a frase, a marca
volta a ser criada e a coleta seguinte a limpa.

### Padrões **recusados**, e por quê

| Recusado | Por quê |
|---|---|
| módulo `ErrorClassifier` | a pergunta "esta falha se repete?" já tem lugar: `transient?/1` — R2 |
| segunda função `list_collectable_including_unreachable/2` | dois nomes que não distinguem nada, e a antiga viraria a que ninguém deve usar — R1 |
| opção `include_unreachable: true` | booleano em opção com um chamador só; antipadrão nomeado no `AGENTS.md` §7.7 |
| coluna `last_attempt_at` | o registro de sincronização já data a última tentativa — R3 |
| contar não alcançados em `skip_reasons` | o mecanismo incrementa `records_collected`, e 39 repositórios entrariam como 39 registros coletados — R4 |
| coluna "desde quando" para todos os repositórios | vazia em 96 das 135 linhas — R5 |
| desistir do repositório que falha há muito tempo | é o defeito que esta feature corrige; se virar ruído, o critério será a natureza do erro |

---

## Project Structure

```text
specs/009-marca-que-se-cura/
├── spec.md          14 FR, 10 SC, 3 user stories, 5 casos de borda
├── research.md      R1 a R6 — R1 e R4 mudaram de decisão pela medida
├── plan.md          este documento
├── data-model.md    uma coluna, e uma semântica corrigida
├── contracts/unreachable-recovery.md
├── quickstart.md    V1 a V8
└── checklists/requirements.md
```

```text
lib/the_band/ontology/seon/cmpo/queries.ex     list_collectable rejeita só o excluído
lib/the_band/ontology/seon/cmpo/commands.ex    mark_inaccessible preserva a data de início
lib/the_band/integrations/github/client.ex     transient? julga erro de GraphQL
lib/the_band/ingestion/github_work_items.ex    conta o não alcançado, e tenta o marcado
lib/the_band/ingestion.ex                      + tally do não alcançado
lib/the_band/ingestion/sync.ex                 + repositories_unreachable
lib/the_band_web/live/work_item_live/index.ex  desde quando, e o motivo
lib/the_band_web/live/sync_live/index.ex       quantos não foram alcançados
priv/repo/migrations/*_add_repositories_unreachable.exs
```

---

## Fases, e por que esta ordem

### F1 — A natureza do erro, e a coluna que aguenta o motivo

`transient?/1` julga erro de GraphQL, e `inaccessible_reason` deixa de ter limite arbitrário.

**Primeiro porque para de sangrar**: enquanto a classificação estiver errada, marcas novas nascem
erradas. E porque a feature faz a plataforma **escrever o motivo com muito mais frequência** — a
cada coleta que falhar, em vez de uma vez —, então o limite de 255 caracteres passa a ser exercitado.

**A ordem não é dependência técnica, e a versão anterior deste plano dizia que era.** Sem F1, um
repositório marcado por engano é tentado e limpo **na coleta seguinte**: não existe "a cura limpando
o que a coleta recria na mesma execução". As duas fases são necessárias, e poderiam ir em paralelo —
F1 vem primeiro porque marca nova errada é dano novo, e curar sem parar de sangrar é trabalho
repetido.

### F2 — A cura

`list_collectable/2` rejeita só o excluído, e `mark_inaccessible/3` preserva a data de início.

**Aqui os 39 voltam à coleta**, e é o valor central: SC-001 e SC-002 passam a valer.

### F3 — O número, e a tela

`repositories_unreachable` no registro de sincronização, e a lista dizendo desde quando e por quê.

**Por último**, porque é o que torna a lacuna **visível** — e a lacuna precisa existir para ser
medida.

---

## Riscos

| Risco | Mitigação |
|---|---|
| a cura limpar marca que a coleta recria no mesmo instante | F1 antes de F2: a classificação correta vem primeiro |
| repositório apagado consultado para sempre | `NOT_FOUND` é permanente, e o custo medido é uma consulta por coleta |
| zero em `repositories_unreachable` afirmar que tudo foi alcançado | teste com falha total exige o número igual à contagem de repositórios |
| a classificação depender de texto de terceiro | teste com o payload real; e a cura torna o erro reversível |
| **motivo maior que a coluna derrubar a coleta** | coluna vira `text`, e a truncagem fica na borda — L05 |
| **coleta interrompida deixar o número em zero** | o número é incrementado **a cada** falha, não no fim — a mesma regra do checkpoint |
| a célula de estado crescer na tabela | data curta, motivo em fonte reduzida — o mesmo tratamento da organização na linha da issue |
| exclusão ser desfeita por engano | excluído **nunca** é tentado; teste exige zero requisições por ele |

---

## Complexity Tracking

| Item | Custo | Aceito porque |
|---|---|---|
| uma coluna nova | um lugar a mais para escrever, e zero afirma sucesso | 39 repositórios caíram e a tela disse "concluída" |
| até 39 consultas a mais por coleta | menos de um terço do que a coleta já faz | 899 issues fora de circulação |
| classificação por texto de mensagem | quebra se a origem mudar a frase | a cura torna o erro reversível, e o teste usa o payload real |

---

## Reavaliação da constituição, pós-desenho

Dez princípios: oito conformes, dois não aplicáveis (IV e IX). **Três** padrões introduzidos, sete
recusados.

O princípio II é o que organiza a feature: a natureza do erro é julgada **na borda**, e o domínio só
recebe "se repete ou não". E o princípio X produziu as duas recusas que mantiveram o desenho pequeno
— nenhum módulo novo, nenhuma segunda função com nome que não distingue.
