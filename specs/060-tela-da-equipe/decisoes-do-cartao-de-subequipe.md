# O cartão de subequipe — a matiz, os números e o que sai

Veredito de Design, 2026-09-09. Vale para a seção *Squads at a glance* (implementada como
*Teams inside this one*) da aba Dashboard de `/teams/:id` — `numeros_do_cartao/1`,
`faisca_do_cartao/1` e o markup da seção em `lib/the_band_web/live/teams_live/show.ex`.

A régua é o protótipo aprovado em 2026-09-07,
[`prototipo/team-dashboard-structure.html`](prototipo/team-dashboard-structure.html)
(`.../0be1668f-3afa-4668-bfb2-c77fae11d941`), e a decisão de record de 2026-09-08,
[`prototipo/marca-do-conceito.md`](prototipo/marca-do-conceito.md).

---

## 0. O que foi medido na base antes de decidir

Três das cinco decisões mudaram depois de olhar o dado. As consultas rodaram no banco de
desenvolvimento em 2026-09-09, direto no Postgres.

| fato | valor real | consequência |
|---|---|---|
| subequipes vigentes da maior equipe composta | **3** — `LEDS - ConectaFapes`; a segunda composta, `DADOS`, tem **1** | N é aberto no modelo e pequeno no dado |
| nomes das três subequipes | **SQUAD BLUE · SQUAD GREEN · SQUAD PINK** | mata a decisão 1 |
| membros vigentes | GREEN 8 · BLUE 6 · PINK 5 (e **31 diretos** na equipe inteira) | os números do protótipo eram reais |
| itens abertos com responsável | GREEN 410 · BLUE 300 · PINK 273 (diretos: 24) | |
| abertos além do limiar de 90 d | GREEN **214** · BLUE **183** · PINK **151** | 52 % a 61 % do estoque — muda a decisão 2 |
| solicitações de código na janela de 56 d | PINK 183 · GREEN 120 · BLUE 87 | |
| mediana de espera pela 1ª revisão humana | BLUE **0,29 h** (66 revisadas, 21 esperando) · GREEN **1,85 h** (110, 10) · PINK **0,16 h** (145, 38) | a medida existe por subequipe |
| vínculos declarados equipe → projeto (`spo_project_teams`) | **0 de 3 subequipes**; só `LEDS - ConectaFapes` e `teste` têm um | mata a taxa do pipeline no cartão |

Duas ressalvas sobre esses números, porque medida sem ressalva mente:

- a mediana acima **não separa cerimônia** — o `process_antipatterns` retira release e
  back-merge, e a mediana só de código será **maior** que a de cima. A ordem entre as três
  subequipes é o que interessa aqui, e ela vem do mesmo cálculo para as três;
- `paradas` foi contado por `external_created_at`, como a tela conta.

E um achado de percurso: na primeira consulta usei `author_type='human'` e obtive **zero
revisões em 390 solicitações**. O valor na base é `'User'` — é o que `@humano` em
`lib/the_band/quality.ex:25` diz. Registro porque o falso zero era exatamente convincente, e
seria "limitação declarada sem olhar o dado" ao contrário: dado olhado com a chave errada.

---

## 1. A matiz por subequipe **não entra**

### O que o protótipo aprovado de facto faz — e por que a tensão é real

A matiz de subequipe aparece em **cinco** lugares do protótipo aprovado, não um:

| lugar | forma | colide? |
|---|---|---|
| borda esquerda de 4 px do cartão | trilho | **não** — nenhuma marca de evidência é trilho de cartão |
| curva "fechado" da faísca | traço de 2 px num gráfico | **não** — e a legenda declara: *"closed, cumulative (in the squad's colour)"* |
| `chip.s1/s2/s3` em *Problems now* | pílula com borda e texto na matiz | **sim, grave** |
| `pill-sq` na tabela de revisão e nos títulos de *People* | quadrado sólido de 0,6 rem | **sim** |
| `pill-sq` na tabela de *Squads* da Estrutura | idem | **sim** |

A colisão não é abstrata, é aritmética de matiz. `--s1:#00897a` é verdete (`#1f6f68`) mais
saturado — matiz 173° contra 175°. `--s2:#a35c00` é âmbar (`#8a5a0c`) mais saturado — 34°
contra 38°. `--s3:#4a5bbf` é a família do `info` azul. Os três "novos" eixos são versões
saturadas de três dos quatro semânticos.

Onde a forma separa, a colisão fica contida: um trilho de cartão e um traço de gráfico são
formas que a família da evidência nunca usa. Onde a forma **não** separa, ela quebra:
`<span class="chip s2">GREEN</span>` é uma pílula de borda e texto âmbar — indistinguível de
`badge-warning badge-outline`, que **nesta mesma tela** significa `stale`. E `pill-sq` é
0,6 rem, radius 2 px, preenchimento sólido: a geometria exata de `.marca .am`.

Então a leitura honesta do protótipo é que a matiz de subequipe não é um quarto eixo — na
faísca ela é **verdete flexionado**, substituindo a primária num lugar só, e a legenda diz
isso. Nos chips ela é um quarto eixo, e ali está errada.

### Por que a resposta é "não", e não "só no trilho e na curva"

Quatro razões, em ordem de força.

1. **O dado real torna a matiz falsa.** As três subequipes que existem chamam-se BLUE, GREEN
   e PINK. Atribuir `--s1` (verde-azulado) a *SQUAD BLUE* e `--s2` (marrom-laranja) a *SQUAD
   GREEN* põe na tela um cartão chamado BLUE com trilho verde e um chamado GREEN com trilho
   marrom. Não é hipótese: são os únicos nomes de subequipe que este produto já teve.
   Identidade visual que contradiz o nome é pior que ausência de identidade visual.

2. **Nenhuma estratégia de geração para N sobrevive.** As três que existem:
   - **ciclo** (`s1,s2,s3,s1…`): duas subequipes na mesma tela com a mesma matiz — afirma
     identidade falsa, que é pior que não afirmar nada;
   - **hash do id**: estável e arbitrário, e *inconsertável* sem trocar o id — é como BLUE
     ganha marrom para sempre;
   - **ordem**: a ordem é por trabalho parado (FR-044), e ela **muda**. Uma matiz que se move
     quando o número muda não é identidade.

3. **Contraste em dois temas não se gera, se cura à mão.** O próprio protótipo precisou
   sobrescrever `--s3` no escuro (`#4a5bbf` → `#8b98e8`) e deixou `s1`/`s2` iguais nos dois.
   Três matizes já pediram uma correção manual por tema; N pediriam N×2 valores que alguém
   teria de manter. Isso não é geração, é paleta curada — e paleta curada sem dono apodrece.

4. **A casa já respondeu a esta pergunta, há um dia.** `marca-do-conceito.md`, 2026-09-08:
   *"Não há matiz livre nesta paleta — é o argumento central desta decisão."* A família do
   conceito pediu matiz e recebeu **forma e preenchimento neutro**: `badge-neutral`,
   `badge-soft`, `badge-dash`, e clay só para o defeito. O protótipo `team-people.html` do
   mesmo dia implementa exatamente isso em `.cc-epic/.cc-us/.cc-task/.cc-bug/.cc-nil`. A
   família da subequipe é a mesma pergunta uma semana depois. Duas respostas opostas para a
   mesma pergunta é como um design system deixa de ser um.

### O que distingue os cartões no lugar dela

| canal | classe / forma | o que afirma |
|---|---|---|
| **o nome** | `text-sm font-semibold` (grotesk, via `@layer base`) | a única chave única que a subequipe tem |
| **o trilho, sem matiz** | `border-l-4 border-l-base-300` nos cartões de subequipe; **sem trilho** no cartão de membros diretos | trilho = *a composição declara esta parte*; a ausência dele = *este é o resto* |
| **a ordem** | parado ↓, já escrita na copy da seção | responde 057 SC-005 sem pintar nada |
| **a forma da faísca** | as duas curvas | é o que o gestor de facto lê num relance, e a matiz competia com ela |
| **a porta** | `open SQUAD GREEN →` nos três; `see the 31 people →` no de diretos | o que é interativo parece interativo |

**Por que a ausência de cor não é perda.** Em todos os cinco usos, a matiz estava ao lado do
nome que ela codificava — `<span class="chip s2">GREEN</span>` tem a palavra GREEN dentro.
Cor redundante com o texto que a acompanha e colidente com uma escala semântica é prejuízo
líquido. O co-referenciamento entre as seis seções da página se faz pelo nome, que já está em
todas elas.

### O que muda, então, nos chips de subequipe (fora do cartão)

Hoje o nome de squad é `badge-ghost` — um dos sete significados de `badge-ghost` que
`marca-do-conceito.md` registrou como defeito, e no escuro um buraco (`#0f1513` mais escuro
que a base `#151b19`).

**Passa a `badge-soft`**: mesmo tratamento que a família do conceito recebeu, pela mesma razão
— fundo definido nos dois temas, nenhuma matiz semântica, distinguível de todo badge de estado
da tela por forma, inclusive em monocromático.

| onde | classe |
|---|---|
| chip de squad na coluna `squads` da Estrutura | `badge badge-sm badge-soft` |
| quebra por subequipe em *Problems now* | `badge badge-xs badge-soft` |
| membro direto (a marca oposta) | `badge badge-sm badge-neutral badge-outline` — como já está |

### Tokens `--s1/--s2/--s3` em `assets/css/app.css`: **não acrescentar**

Registro explícito porque a próxima pessoa vai alcançá-los. Eles não entram em `app.css`, não
entram em `@theme`, e não entram como `[data-theme]`. A razão está nos quatro pontos acima, e
o lugar dela é o comentário de `numeros_do_cartao/1`.

---

## 2. `stopped` **sai do cartão e fica na tabela**, como chave de ordenação visível

### Por que não fica no cartão

O cartão tem três vãos numéricos e nenhum lugar para o limiar. Um `stopped 214` sem *"abertas
há mais de 90 dias, limiar declarado em `profile.thresholds.stale_open_work`"* é um número cujo
significado o leitor adivinha — e a base de conhecimento é explícita sobre o que esse número
**não** diz: *"A listagem não afirma atraso nem culpa: a origem não registra prazo."* Uma
ressalva dessa importância não cabe num rótulo de 0,68 rem, e a tela aprovada já tem a seção
construída para fatos com limiar: *Problems now*, onde o cartão *tasks open beyond the stop
threshold* traz o número **com o limiar escrito** e a quebra por subequipe.

### Por que não sai da tela

FR-044 manda ordenar cartões **e** linhas por trabalho parado, decrescente; 057 SC-005 exige
que o gestor identifique em menos de 30 s qual subequipe tem mais trabalho parado. Cartões
ordenados por um número invisível fazem a resposta depender de confiança numa ordenação que a
tela não mostra. Logo: fica **na tabela**, como última coluna, que é onde a ordenação se
verifica em números alinhados.

### E o âmbar sai do número

`text-warning` condicional a `paradas > 0` está **ligado nas três subequipes** hoje (214, 183,
151). Uma condição sempre verdadeira não é informação, é mancha permanente — e âmbar nesta
casa é derivado/obsoleto, enquanto um item parado é **contado**, não derivado.

| elemento | classe | razão |
|---|---|---|
| número da coluna | `text-right font-mono tabular-nums` — **sem matiz condicional** | a ordenação ranqueia; a cor não ranqueia nada quando acende para todos |
| cabeçalho da coluna | `stopped · open > 90 d` | o limiar viaja com o número |
| nota de pé da tabela | o nome da regra + a ressalva da base | *"the threshold is declared in `profile.thresholds.stale_open_work`; open that long, not late — the source records no deadline"* |

A marca `.parada` **por item** (seção *People*) continua clay tracejado, como o protótipo
aprovado define (`.parada{color:var(--clay);border:1.5px dashed var(--clay)}`) — clay porque
precisa de destino, tracejado porque a origem não registra prazo. A divergência hoje na tela
(`stale` em âmbar) já está registrada em `marca-do-conceito.md` §5 e **não** é re-decidida aqui.

---

## 3. `members` **vai para o cabeçalho**. Confirmado

Razão: `members` não é medida do trabalho, é propriedade da subequipe. No vão numérico ele
compete com as medidas e obriga a ler três rótulos para achar os dois que são sobre trabalho. No
cabeçalho ele é o que o cartão precisa ser — *quem isto é*, antes de *como vai*.

| elemento | classe |
|---|---|
| linha do cabeçalho | `flex items-baseline justify-between gap-2` |
| nome | `text-sm font-semibold` |
| `6 members` | `font-mono text-[0.67rem] tracking-[0.06em] uppercase text-base-content/70` |

Essa última linha é a receita de `.rot` do protótipo traduzida para `app.css`. Contraste
calculado: claro ≈ 6,0:1, escuro ≈ 8,6:1 — os dois passam AA.

**Ambiguidade da estrutura aprovada que resolvo aqui**, para o QA não marcar falso defeito:
FR-043 exige que toda medida traga a composição *N membros — X observados sem papel declarado,
Y declarados*. No cartão a composição é a **forma curta** (`6 members`); a quebra
observados/declarados vive na coluna `team` da tabela (`eq-sub` do protótipo: *"6 observed · 0
declared"*) e sob cada medida da seção *Time to first review*. O cartão não repete a quebra.

---

## 4. A mistura de conceitos **não entra no cartão**

**Antes da razão de desenho, o fato**: a mistura **não está no protótipo aprovado**. Não há
`.mix`, não há `.tot`, e não há TASK/US/BUG/EPIC em nenhum lugar de
`team-dashboard-structure.html`. O cartão aprovado tem exatamente cabeçalho, três vãos
numéricos, faísca e a porta. O trecho citado no pedido vem de
[`prototipo/team-people.html`](prototipo/team-people.html) — protótipo de **2026-09-08**, de
**outra aba** (*Flow per person*), **aguardando aprovação**, onde a mistura aparece dentro do
bloco expandido de **uma pessoa**, sob os quatro gráficos dela, e traz a própria frase que a
delimita:

> *"The composition of the number, not the list of items — the list is on the Dashboard, and
> this tab does not repeat it (FR-088)."*

Nunca foi cartão de subequipe, e nunca foi aprovada.

As razões de desenho, se ela fosse proposta:

1. **É agregação nova sem nome.** No nível da pessoa a mistura é a composição de um número que
   aquela aba já apresenta. No cartão seria um `GROUP BY` da promoção por subequipe — medida
   nova na tela, e o princípio IV pede nome na base antes do código.
2. **O elemento é em forma de total, numa tela cuja regra central é "nenhum total".** A classe
   chama-se literalmente `.tot` e renderiza `235 open`. Mesmo sendo total *da subequipe* e não
   *entre* subequipes, a forma convida à leitura que FR-044 proíbe.
3. **Não muda a decisão que o cartão existe para apoiar.** O cartão é uma porta, e a pergunta é
   *abro esta?*. Doze números novos (4 conceitos × 3 cartões) numa seção de comparação em
   relance respondem uma pergunta que se faz **depois** de abrir.
4. **Seria o quarto lugar da mesma tela a mostrar a família do conceito.** A marca por item já
   está em *People*; a composição por pessoa está na aba nova. Um terceiro nível de agregação
   da mesma taxonomia é onde o leitor deixa de saber qual número seguir.

Se a pessoa mantenedora quiser a composição do estoque por subequipe, o lugar é a **tela da
própria subequipe** — que já lista os itens com a marca de conceito em cada um.

---

## 5. `median wait` **entra**; `pipeline` **não entra** — e o cartão passa a ter duas medidas

### As duas não são invenções: são as colunas herdadas da 057

A tabela aprovada da 057 (`team-of-teams.html`, linha 132) é
`team | people | closed 8w | **CI success** | **1st review**`. FR-041 manda que o cartão traga
"as mesmas medidas da tabela". Então `median wait` e `pipeline` no cartão da 060 **são** as
colunas da 057 carregadas para dentro dele. A implementação de hoje fez o oposto: descartou as
duas e acrescentou `stopped`.

E a spec 060 já as devia por subequipe, independentemente do cartão — linhas 61-62:
*Waiting for first review* e *Pipeline success rate*, ambas **"Dashboard, por subequipe quando
composta"**. Nenhuma das duas é trabalho novo criado pelo cartão.

### `median wait` entra

- **Existe no dado real, por subequipe, hoje**: 0,29 h / 1,85 h / 0,16 h sobre 66 / 110 / 145
  solicitações revisadas. É a segunda pergunta do gestor depois de *quanto está aberto*.
- **A consulta é por subequipe, e não agrupada** — e isto é decisão de desenho, não detalhe de
  implementação: `Quality.team_time_to_first_review/3` traz linhas com `limit: 200` e calcula a
  mediana em Elixir. Com 390 solicitações nas três subequipes, **uma consulta agrupada com
  limite compartilhado truncaria a mediana em silêncio** — o defeito que o próprio código já
  documenta (PR #798) e que a tela já sabe declarar (*"the medians above are over what is
  shown"*). Três chamadas com limite próprio cada é o caminho honesto. PINK está em 183 de 200:
  o aviso de truncamento **vai** disparar, e é bom que dispare.
- **O rótulo diz o recorte**: `median wait` no cartão; a seção *Time to first review* mantém a
  separação código × cerimônia e a composição. O cartão não repete nenhuma das duas.

| elemento | classe |
|---|---|
| número | `font-mono text-[1.05rem] font-medium tabular-nums` |
| rótulo | `font-sans text-[0.68rem] text-base-content/70` |
| ausência (nenhuma revisada na janela) | `font-sans text-[0.8rem] text-base-content/60` com o texto **`no review yet`** — nunca `0 h` |

### `pipeline` não entra

**O dado real decide**: `spo_project_teams` tem zero linhas para as três subequipes. Só a
equipe inteira e `teste` têm vínculo declarado. Logo `Verification.team_pipeline_rate/3`
devolve `{:sem_projeto, _}` para **3 de 3** subequipes, e o terceiro vão de cada cartão diria
*"no project"* nos três — a mesma frase, três vezes, ocupando um terço da linha numérica.

A recusa é estado de primeira classe nesta casa, e é por isso mesmo que ela não vai no cartão:
a tela aprovada **já lhe deu lugar próprio**, com o motivo anexado, na seção *Pipeline success
rate* —

> `SQUAD PINK` · **no declared project — no rate** · *the link team → project is what the rate
> follows* · *refusal is a first-class state: no number without a path*

Repetir num vão de 0,68 rem o que um cartão de recusa diz com a razão junto não é honestidade a
mais, é a mesma afirmação quatro vezes, e a versão curta é a pior das quatro.

**Uma consulta agrupada também não existe aqui**, e não deve existir: `team_pipeline_rate/3`
consulta os vínculos ela mesma, de propósito, porque a opção `:vinculos` deixava
`team_pipeline_rate(tenant, equipe_A, vinculos: vínculos_de_B)` devolver a taxa de B com o
rótulo de A (revisão de segurança do PR #798). Uma versão agrupada reabriria isso. Por
subequipe, quando a seção for feita.

### O que o cartão mostra no lugar: **nada — são dois vãos, não três**

A casa escreve ausência, nunca zero — e ausência é o **valor** que falta, não a **medida** que
não existe. Declarando o cartão com duas medidas, não há terceira ausência a nomear. E a regra
que isso preserva vale mais: três cartões com 3/3/2 vãos não alinham, e a seção deixa de ser um
objeto repetido.

`pipeline` também **não volta** quando algum vínculo for declarado. Um lugar por medida: a taxa
vive na seção dela, por subequipe. Cartão que muda de forma conforme a declaração melhora é
cartão que nunca se aprende a ler.

### A regra que o QA aplica em vez de "as mesmas medidas" ao pé da letra

FR-041 lido como *"todas as medidas da tabela"* proibiria qualquer resumo. A intenção — dita
pelo próprio comentário de `numeros_do_cartao/1` — é que cartão e tabela **não discordem**.
Então a régua é:

1. todo número do cartão aparece na tabela, com **o mesmo valor**, janela e definição;
2. o cartão **não** mostra número que a tabela não tenha;
3. subconjunto é permitido; divergência de valor é defeito.

| | cartão | tabela |
|---|---|---|
| `members` | cabeçalho | coluna |
| `open items` | vão 1 | coluna `open` |
| `median wait` | vão 2 | coluna `median wait` |
| `closed · 8w` | — | coluna |
| `stopped · open > 90 d` | — | coluna (chave da ordem) |
| taxa do pipeline | — | — (seção própria, por subequipe) |

---

## 6. A faísca: as duas curvas, e o âmbar que precisa sair

Está na seção decidida e o pedido a nomeia, então decido.

Hoje: escopo em `text-primary`, feito em **`text-warning`**. O protótipo aprovado é o oposto, e
a legenda dele declara: *"opened, cumulative"* em `--tinta-2` (tinta neutra) e *"closed,
cumulative"* em `--verdete`.

O âmbar tem de sair: âmbar nesta casa é derivado e obsoleto, e trabalho **fechado** não é nem
um nem outro — é o ato observado da ferramenta, que é precisamente o que verdete significa.

| curva | classe | largura | extra |
|---|---|---|---|
| aberto, acumulado | `text-base-content/50` | `stroke-width="1.2"` | — |
| fechado, acumulado | `text-primary` | `stroke-width="1.8"` | ponto final `fill-primary`, `r="1.6"` |

A distinção **não é só por cor** (055 FR-002): largura diferente e só uma das curvas tem o ponto
final.

**A legenda voltou a faltar.** O protótipo tem `leg-g` uma vez sob a grade dos cartões; a
implementação não tem nenhuma. Duas curvas sem rótulo numa caixa de 100 × 28 não se leem. Uma
legenda por seção, não por cartão: `opened, cumulative` · `closed, cumulative`.

A frase de ausência atual — *"Nothing opened or closed in this window — the items below are
stock, not movement"* — **fica como está**. Ela é melhor que a do protótipo e a razão dela está
escrita no código.

---

## 7. A estrutura aprovada do cartão, seção a seção — a régua do QA

Ordem dos cartões: parado ↓ (GREEN, BLUE, PINK hoje), e o de membros diretos por último.

| # | elemento | conteúdo | classe / forma |
|---|---|---|---|
| 1 | moldura | — | `rounded-lg border border-base-300 bg-base-100 p-4`; **`border-l-4 border-l-base-300`** nos cartões de subequipe, **sem trilho** no de membros diretos |
| 2 | cabeçalho | nome + `N members` | `flex items-baseline justify-between gap-2`; nome `text-sm font-semibold`; rótulo `font-mono text-[0.67rem] tracking-[0.06em] uppercase text-base-content/70` |
| 3 | faísca | duas curvas + ponto final | §6; `nil` → a frase de estoque |
| 4 | números | **dois** vãos: `open items`, `median wait` | `grid grid-cols-2 gap-2`; §5 |
| 5 | porta | `open SQUAD GREEN →` / `see the 31 people →` | `font-sans text-[0.72rem] text-primary` |
| 6 | legenda da seção | uma vez, sob a grade | §6 |

Recusas e ausências que o QA confere neste cartão: `median wait` sem revisão → **`no review
yet`**, nunca `0 h`; subequipe sem movimento → a frase de estoque, nunca faísca reta; o cartão
de membros diretos **não é porta** para `/teams/:id`, e sim âncora para *People*; nenhum vão de
total; nenhum trilho colorido.

---

## 8. Consequências fora da seção decidida — para o PO levar, não para eu decidir sozinho

A regra de §6 não pode valer para a faísca e não para o gráfico grande da mesma tela.

| onde | hoje | pela regra |
|---|---|---|
| burn grande, curva de escopo | `text-primary` | `text-base-content/50` — é a linha de escopo, não uma afirmação observada |
| burn grande, curva de feito | **`text-warning`** | `text-primary` |
| burn grande, rótulos numéricos | `text-primary` / `text-warning` | acompanham as curvas |
| faixa hachurada (região derivada) | `text-primary` a 0,38 | hachura **neutra**, como o protótipo (`leg-g i.hach` em `--tinta-2`): a faixa é geometria — a distância entre duas curvas medidas —, e hachurar em primária afirma "derivado observado" |
| `Prometido × Entregue` | mesmo par | mesmo par corrigido |

**Recomendação**: entra na mesma republicação, porque uma regra de matiz que vale para um
gráfico e não para o vizinho não é regra.

---

## 9. CSS novo: **nenhum**

Nenhum token novo em `assets/css/app.css`, nenhuma entrada em `@theme`, nada em
`TheBandWeb.UI`. Tudo acima sai de `base-100`, `base-200`, `base-300`, `base-content`,
`primary` e das formas `badge-soft` / `badge-neutral` / `badge-outline` / `badge-dash` que já
existem.

Registro pelo contrário, que é o que precisa ficar escrito: **`--s1`, `--s2` e `--s3` não devem
ser acrescentados** a `app.css`. É a decisão 1, e sem ela escrita no comentário de
`numeros_do_cartao/1` a próxima pessoa alcança a paleta de subequipe de novo — como alcançou o
verdete na família do conceito.

---

## 10. Medidas novas que pedem YAML: **nenhuma**

O cartão só **perde** elementos. As duas medidas que ficam já têm nome declarado:

| na tela | nome na base |
|---|---|
| `open items` | contagem distinta de itens abertos com responsável — a mesma da tabela |
| `median wait` | `review.time_to_first_review.duration` (spec 058) |
| `stopped · open > 90 d` (tabela) | `profile.thresholds.stale_open_work`, `stale_days: 90` — conferido em `priv/knowledge_base/rules/profile_thresholds.yaml:105` |

`median wait` por subequipe **não** é medida nova: a medida é a mesma, muda a **composição**
sobre a qual foi calculada — e ADR 0008 exige que a composição seja dita, não que a medida seja
renomeada. Princípio IV satisfeito sem acréscimo.

---

## 11. O que isto muda no protótipo aprovado — republicação pendente

Estas decisões alteram o cartão aprovado em 2026-09-07. Pela regra da casa, o protótipo é
republicado **no mesmo endereço** (`.../0be1668f-3afa-4668-bfb2-c77fae11d941`) **antes** de o
código mudar, e o PO registra no item do backlog.

| # | mudança no protótipo | decisão |
|---|---|---|
| 1 | trilhos e curvas perdem `--s1/--s2/--s3`; `chip.s1/s2/s3` e `pill-sq` viram chip neutro | 1 |
| 2 | cartão de membros diretos perde o trilho | 1 |
| 3 | vão do `pipeline` sai do cartão — de três vãos para dois | 5 |
| 4 | números do cartão passam a reais: GREEN 8/410/1,9 h · BLUE 6/300/0,3 h · PINK 5/273/0,2 h · diretos 31/24/`no review yet` | 0 |
| 5 | tabela por subequipe ganha `stopped · open > 90 d` com o limiar e a ressalva da base | 2 |
| 6 | ausência de `median wait` passa a `no review yet` | 5 |
| 7 | par de cores das curvas, e a legenda, também no burn grande e no Prometido × Entregue | 6, 8 |

Os três arquivos da spec (`prototipo/team-dashboard-structure.html`, `prototipo/README.md`,
`prototipo/PROMPT.md` §3) são atualizados na mesma republicação.

### Pergunta aberta — para o PO levar

**A ordem das duas medidas no cartão.** `open items · median wait` (estoque primeiro, como na
tabela) ou `median wait · open items` (a medida que varia entre subequipes primeiro — 0,16 h a
1,85 h é uma ordem de magnitude, enquanto 273 a 410 é meio fator)?

**Recomendo `open items · median wait`**: a ordem do cartão deve ser a da tabela, senão a
comparação entre as duas apresentações exige reordenar de cabeça. A variação maior fica visível
de qualquer forma, porque são só duas colunas.

---

## 12. O que não foi verificado

- **Não abri a tela.** Nada foi renderizado: nem `badge-soft` nos chips de squad, nem
  `text-base-content/50` a 1,2 px de traço numa faísca de 28 px de altura, nem os dois vãos em
  `grid-cols-2` no cartão estreito. Foram raciocinados a partir do CSS dos dois temas.
- **Os contrastes foram calculados, não medidos**, e o cálculo é meu: `text-base-content/70`
  ≈ 6,0:1 (claro) e 8,6:1 (escuro); `text-base-content/50` na curva ≈ 3,4:1 — abaixo de AA para
  **texto**, e é por isso que a curva também difere em largura e ponto final, e a legenda
  nomeia as duas.
- **A mediana que medi inclui cerimônia.** A da tela separa release e back-merge pela regra
  `process_antipatterns`, e será maior. A ordem entre as três subequipes vem do mesmo cálculo
  para as três, e é dela que a decisão depende.
- **Não medi a taxa do pipeline por subequipe** — não havia o que medir: zero vínculos
  declarados. Se algum for declarado amanhã, a decisão 5 não muda (a taxa continua na seção
  própria), mas o número de recusas na tela muda.
- **Não conferi `badge-soft` no build.** A classe não estava em uso em `lib/the_band_web/` até
  a decisão de 2026-09-08; os `@source` de `app.css` cobrem esse caminho, então deve ser gerada
  ao ser escrita — inferido, não observado.
- **Não olhei as outras telas com chip de squad.** `/teams` (índice) e `/people/:id` podem
  mostrar nome de subequipe; a decisão 1 vale para elas pela mesma razão, e não as conferi.
- **`team-people.html` continua aguardando aprovação** e não foi alterado por este veredito. A
  família `.cc` dele já obedece à decisão de 2026-09-08 — foi conferida, e é coerente.
