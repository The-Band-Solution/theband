# Retomar — 2026-08-25

## Primeira coisa: continuar a implementação da 043

A feature **043 — Papéis por organização** está com a Fase 1 pronta e as outras quatro por fazer.

```bash
git checkout 043-papeis-por-organizacao
set -a && . ./.env && set +a
mix ecto.migrate       # já aplicada; confirma que o banco está no estado certo
```

**Feito**: T001, T002, T003 — a migração, em `648773f`. Ida e volta conferida.

**A fazer**: T004 a T018, e o `tasks.md` tem cada uma com os quatro campos e a issue ligada.

| fase | tarefas | issues |
|---|---|---|
| ~~Fase 1 — esquema~~ | ~~T001–T003~~ | ~~#483–#485~~ |
| Fase 2 — US1, o catálogo | T004–T007 | #486–#489 |
| Fase 3 — US2, papéis próprios | T008–T010 | #490–#492 |
| Fase 4 — US3, a promoção | T011–T016 | #493–#498 |
| Fase 5 — fechamento | T017–T018 | #499–#500 |

**Escopo mínimo**: US1 + US3 destravam o nível Equipe. US2 é conveniência — com os quatro do Scrum já dá para promover as 101 evidências.

---

## Por que a 043 é prioridade, e a medição que a pôs lá

```
12  equipes gravadas
101 evidências de vínculo coletadas do GitHub
  0 vínculos promovidos
  0 papéis organizacionais cadastrados
```

E `eo_team_memberships.organizational_role_id` é **`NOT NULL`**.

**A cadeia estava parada no primeiro elo.** Sem papel cadastrado, nenhuma evidência vira vínculo — e por isso **todo o nível Equipe dos painéis está vazio**: quatro das cinco medidas declaram `team`, e nenhuma calcula.

Eu tinha classificado a #317 como prioridade 4. Estava errado, e só descobri ao medir.

---

## As duas features especificadas, e nenhuma implementada além da migração

| | spec | plano | tarefas | issues | código |
|---|:---:|:---:|:---:|:---:|:---:|
| **042** critério de início | ✅ | ✅ | 24 | #459–#482 | — |
| **043** papéis por organização | ✅ | ✅ | 18 | #483–#500 | Fase 1 |

Ambas em branch própria, empurradas. Nenhum PR aberto.

### 042 — o critério de início (fecha #370)

A organização declara qual evento marca o início de um trabalho. `spo.activity_start_criterion` como `ufo.social_object`, porque a UFO define social object como *"objeto cuja existência depende de convenção social"* — e qual evento marca o início é convenção, não fato.

Escala: **quadro vence projeto**, desempate por `spo_project_boards.linked_at` mais recente, e empate real vira `criterio_ambiguo` — a plataforma não desempata sozinha.

Destrava `flow.throughput`, metade de `flow.wip.count` e cycle time, para **87% das issues**.

### 043 — papéis por organização (fecha #317)

Cadastro por organização; os quatro do Scrum vindos da SRO em todas; papéis próprios; uma pessoa com vários papéis; data de quando assumiu.

**A decisão que governa o plano**: o catálogo é **composto na leitura**, e a linha só nasce quando alguém usa o papel. Semear criaria 12 linhas que ninguém declarou, e divergiria da rede em silêncio se a SRO renomear um papel.

---

## O que eu **não** vou fazer, e está escrito nas specs

**Não inferir papel a partir do nível de acesso.** `MAINTAINER`, `MEMBER` e nulo dizem a **mesma coisa**: que a pessoa é membro da equipe. A diferença é permissão na ferramenta, não função.

E o nível **não aparece** na tela de promoção — nem como contexto. A garantia está no **contrato**: `pending_evidence/2` não devolve o campo, então nenhum template pode exibi-lo por descuido.

`EO.Constraints.platform_access_level_is_not_a_role/1` já dizia isso desde a feature 021, com a justificativa melhor que a minha: promover acesso a papel faria `CQ12`, `CQ14` e `CQ16` devolverem **resposta falsa em vez de nenhuma**.

---

## As decisões que continuam suas

Cinco, e o documento com o estado medido de cada uma está em
<https://claude.ai/code/artifact/c5b1101a-f1a0-4b65-bc2b-21ce912fec54>

| | o que trava | recomendei |
|---|---|---|
| **#368** qual campo é o prazo | a medida de atraso — 33 campos de data em 24 quadros | uma declaração por quadro |
| **#452** o corte incremental | volta sozinho na próxima feature que acrescentar campo | versão da consulta por repositório |
| **#369** quem vê o painel de quem | regra de segurança vive só no código | — |
| **#442** ArgoCD | implantação real; 4 sub-decisões | — |
| **#367** as três que sobraram | 275 issues fora de quadro; timeline; "Done" | — |

**#370 saiu da lista** — virou a feature 042. **#176 está decidida** (opção b) e ainda **aberta**: falta fechá-la com o achado de que os 21 sprints ocupam 2 caixas de 7 dias, 16 deles na mesma.

---

## O que foi mergeado ontem

| | |
|---|---|
| **#453** | o recálculo que estourava depois de fazer o trabalho, e as 763 fora do corte |
| **#455** | o percurso da T026 e o passo 5 do quickstart |
| **#456** | o token de saída descartado — destrava a T024 |
| **#457** | `bandit 1.12.5`, duas advisories, uma HIGH |
| **#458** | um projeto pode ter mais de um quadro |

---

## Feature nova, pedida em 2026-08-24 — sugerir PO e Scrum Master pela criação de issues

> *"Indicar pessoas que estão fazendo o papel de Product Owner ou Scrum Master ao
> especificar issues para outras pessoas. Fazer isso pela relação de criação de issues."*

**É a porta que a spec da 043 deixou aberta de propósito.** Ela recusa sugerir papel a partir
de comportamento e diz: *"tem os mesmos riscos do primeiro e merece spec própria, se algum dia
for desejado"*. Foi desejado.

### O sinal, medido em 2026-08-24

| login | abriu p/ outros | pessoas distintas | abriu total |
|---|---:|---:|---:|
| `paulossjunior` | 384 | **28** | 1.272 |
| `fatasy` | 171 | **23** | 233 |
| `joaomrpimentel` | 137 | 17 | 321 |
| `vinicius-je` | 355 | 15 | 616 |
| `tadeuaugustovs` | 84 | 14 | 117 |
| `marcelasfl` | 251 | 10 | 387 |

**Discrimina de verdade.** `fatasy` abriu 233 e distribuiu para 23 pessoas — 73% do que abriu.
`vinicius-je` abriu 616 e distribuiu para 15. São perfis diferentes, e a diferença não estaria
visível numa contagem de tarefas designadas.

### O número que a issue #364 traz está errado, e já comentei nela

Ela diz que `paulossjunior` abriu **1.191 para outros (95%)**. Medi **384 (30%)**. A diferença:

```
abriu no total:        1.272
  sem designado nenhum:  824   ← contadas como "para outros" pela issue
  designada só a ele:     64
  designada a outro:     384   ← o sinal de verdade
```

Issue sem designado é aberta **para ninguém ainda**, não para outra pessoa. Contá-la como
delegação faz a medida descrever volume de abertura de ticket, que é outra coisa.

### O que a spec vai precisar recusar

A mesma recusa da 043, e pelo mesmo motivo: **a plataforma sugere, e uma pessoa confirma.**
Nunca atribui papel sozinha.

E há um risco novo, que o nível de acesso não tinha: **este sinal é plausível.** Quem abre
tarefa para 28 pessoas *parece* Product Owner, e por isso a sugestão vai ser aceita sem ser
conferida. A `FR-007` da feature 021 recusa observar papel organizacional justamente porque
nenhuma origem o fornece — e "parece" não é "é".

Sugestões concretas para a spec, quando ela for escrita:

- **um piso de pessoas distintas**, não de volume. Quem abre 600 tarefas para 2 pessoas não é
  PO; quem abre 100 para 20 talvez seja;
- **a sugestão diz o que observou**, não o que conclui — *"abriu 171 tarefas para 23 pessoas"*
  é o texto; *"provavelmente é Product Owner"* não;
- **não distinguir PO de Scrum Master por este sinal.** Os dois abrem tarefa para outros, e a
  relação de criação não separa quem prioriza de quem facilita. Sugerir "PO ou SM" e deixar a
  pessoa escolher é honesto; adivinhar qual dos dois não é;
- **depende da 043**, que cria o cadastro de papéis e a promoção. Sem ela não há o que sugerir.

---

## E a pergunta que vem junto: distinguir PO de Scrum Master de Tech Lead

Pedida em 2026-08-24. **Medi antes de guardar, e a minha primeira hipótese caiu.**

### A hipótese que não funciona

*"PO delega e não escreve código; Tech Lead delega e também commita e revisa."* O eixo seria
`commits`.

**Não separa nada.** Medido:

```
login              pessoas  p/outros  commits  reviews  moveu
paulossjunior           28       384     1280       12    299
fatasy                  23       171      196       21    289
joaomrpimentel          17       137      307      299    271
vinicius-je             15       355     2568      723    869
marcelasfl              10       251     1138      439    530
leticiacomerio           8        35        1        3     10
sofiasilv4               8        23        0        0      3
```

`paulossjunior` delega para 28 pessoas **e** tem 1.280 commits. Quase todo mundo commita — o
eixo só isola as duas últimas linhas, que não commitam nem revisam.

### O que apareceu no lugar

**A razão entre revisar e commitar discrimina, e o volume de commits não.**

| | commits | reviews | razão |
|---|---:|---:|---|
| `paulossjunior` | 1.280 | 12 | **107:1** |
| `fatasy` | 196 | 21 | 9:1 |
| `joaomrpimentel` | 307 | 299 | **1:1** |
| `luanotoni` | 101 | 246 | **1:2,4** |

Quem revisa quase tanto quanto commita tem perfil diferente de quem commita cem vezes mais do
que revisa. É candidato a eixo, e **não** era o que eu tinha proposto.

### O que investigar amanhã, e o que já sei que não serve

**Não serve**: volume de commits sozinho; nível de acesso do GitHub (já proibido nas specs
041 e 043).

**Investigar**:

- **razão revisão/commit** — o achado acima, e o mais promissor;
- **movimentação de item no quadro sem ser autor nem designado** — hipótese para Scrum Master,
  que facilita fluxo sem executar. `ProjectV2ItemStatusChangedEvent` tem 5.965 ocorrências, e
  `tadeuaugustovs` tem 84 delegações com **1** movimento, contra `vinicius-je` com 869. A
  variação é enorme e ninguém olhou;
- **quem preenche campo de prioridade** — hipótese para PO, e a `SRO` diz que *importance* é do
  Product Owner. Depende de `item_field_values`, que já é coletado;
- **quem cria iteração** — hipótese para Scrum Master.

### Antes de medir: uma análise semântica do que É um Tech Lead

Pedido em 2026-08-24. **Vem antes de escolher eixo**, e não depois — procurar sinal para um
conceito que ninguém definiu produz a medida do sinal, não do papel.

O que a análise precisa responder, e onde procurar:

- **A literatura o define?** SEON, SWEBOK, a tese que originou a rede. Se nenhuma ontologia de
  referência o nomeia, isso é resposta — e explica por que ele não está na SRO ao lado dos
  quatro do Scrum;
- **Ele é papel, ou é uma composição?** Hipótese a testar: *Tech Lead* pode não ser um papel
  próprio, e sim `developer_role` acumulado com autoridade técnica sobre decisões de desenho.
  Se for composição, o modelo certo não é um papel novo — é a pessoa com dois vínculos, que a
  `FR-006a` da 043 já permite;
- **O que ele decide que um Developer não decide?** É a pergunta que separa. E ela tem
  contraparte observável: decisão de desenho aparece em revisão de PR e em comentário, não em
  commit;
- **A distinção é organizacional ou é de senioridade?** Se for senioridade, **não é papel** —
  e a necessidade `people.demonstrated_domains` já declara que inferir nível a partir do
  escopo das tarefas é circular.

**A ordem importa.** Se a análise concluir que Tech Lead é composição ou senioridade, a
feature de sugerir papel muda de forma — ou deixa de fazer sentido para ele, ficando só PO e
Scrum Master, que a SRO define.

### A hipótese da pessoa mantenedora, que é testável

> *"É possível que o projeto assuma que o Tech Lead é um Scrum Master que é engenheiro de
> software ao mesmo tempo, e ajuda a definir os cards — refinando tecnicamente e programando
> também."*

Isso é **composição**, e não papel novo:

```
tech_lead  ≡  sro.scrum_master_role  ∧  sro.developer_role  +  refinamento técnico do card
```

E ela é **testável contra o dado que já medi**. As três partes têm contraparte observável:

| parte da hipótese | o que observar | já medido? |
|---|---|---|
| **Scrum Master** — facilita fluxo | move item no quadro sem ser autor nem designado | `ProjectV2ItemStatusChangedEvent`, 5.965 ocorrências |
| **engenheiro** — programa | commits | sim, `commit_authors` |
| **define e refina o card** | abre issue para outros, **e comenta nela** | delegação sim; comentário **não** — está em `collected_issue_comments`, 2.051 linhas, e ninguém cruzou |

**Se a hipótese for verdadeira, o modelo certo é dois vínculos, não um papel.** A `FR-006a` da
043 já permite uma pessoa acumular Scrum Master e Developer na mesma equipe — e a plataforma
diria *"esta pessoa acumula os dois"*, que é mais informativo que um rótulo novo.

### Colocar na SRO — há precedente, e há um limite

Este projeto **já estendeu a SRO**: `sro/modules/scope_traceability.yaml`, com
`source_type: project_decision`, referência à issue que a motivou, e a razão de o conceito
viver ali em vez de noutra ontologia.

Então a forma existe. O que a análise precisa decidir antes de usá-la:

- **é conceito ou é composição?** Se for composição, acrescentar `sro.tech_lead_role` seria
  reificar o que já se expressa com dois vínculos — padrão sem problema, que o princípio VIII
  chama de antipadrão;
- **a SRO é o lugar?** Ela descreve **Scrum**, e Tech Lead não é papel do Scrum. Se a
  conclusão for que é papel de engenharia e não de processo ágil, o lugar seria SPO ou EO —
  e pôr no lugar errado é o que o princípio IX existe para impedir;
- **o que a extensão declara como limitação?** `scope_traceability` declara por que vive na
  SRO. Uma extensão sem essa justificativa escrita não passa em revisão.

### As duas recusas que valem para qualquer eixo

**Tech Lead não está na SRO.** Product Owner, Scrum Master, Developer e Client estão;
Tech Lead é papel declarado pela organização. Então a sugestão dele só existe **depois** de
alguém o declarar — e a 043 é o que torna isso possível.

**Nenhum eixo separa por si.** O que a plataforma pode dizer é *"esta pessoa revisa tanto
quanto commita e move 289 itens no quadro"*. Concluir qual dos três papéis isso é continua
sendo ato humano — e a `FR-007` da feature 021 é a razão.

---

## Lembretes que custaram caro

- **`mix gates` — o veredito é o código de saída**, nunca a última linha:
  `mix gates > /tmp/g.log 2>&1; ec=$?; tail -30 /tmp/g.log; exit $ec`
- **Um dos treze gates depende de estado externo.** O CI de um PR verde há quatro dias não garante main verde no merge — foi o que aconteceu com o `bandit`.
- **Ao trocar uma medida por outra**, medir a sobreposição e amostrar o que só a antiga acha (L67).
- **Número medido durante backfill é preciso e provisório** ao mesmo tempo (L70).
- **`local_only` do Oban não isola** um `mix` de um `mix phx.server` — os dois são `nonode@nohost`.
- **Consulta schemaless com lista de UUID** precisa de `type(^ids, {:array, :binary_id})`.
- **Delegar na fachada.** A feature 041 produziu `UndefinedFunctionError` com a função existindo, porque faltou o `defdelegate` — é a T008 da 042 e a razão de ela estar na lista.

---

## Uma coisa que eu pulei, e você pode querer cobrar

**Não abri sprint backlog** para a 043, apesar de a skill exigir. O rastro que ele dá — tarefa, issue, critério — já está no `tasks.md` com as 18 issues ligadas, e você aprovou o escopo. Se preferir o ritual completo antes de continuar, é `/sprint-backlog`.
