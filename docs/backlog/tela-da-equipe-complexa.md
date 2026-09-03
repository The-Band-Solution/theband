# A tela da equipe complexa

Levantado em 2026-09-02, a partir de três observações da pessoa mantenedora sobre
a tela de equipe. **Ainda não é spec** — são as decisões tomadas e o defeito que
precisa ser corrigido antes de qualquer soma.

> *"a tela de equipe tem que ser focada na equipe. Se é uma equipe complexa
> (formada por duas ou mais equipes) ela mostra os indicadores das subequipes de
> forma resumida (...) e ao clicar na subequipe, ver o detalhe dela"*
>
> *"não some os indicadores de cada equipe — mostre separadamente"*
>
> *"se a pessoa saiu da equipe, as métricas dela não passam a contar depois que
> ela saiu"*

---

## 1. O defeito que vem antes de tudo: a medida ignora o vínculo

`Profiles.team_skills` monta os membros assim:

```elixir
defp membros(tenant, team_id) do
  EO.list_team_members(team_id, include_no_longer_observed: false)
```

Isso lê a **evidência** — o que o GitHub mostra hoje — e **ignora o vínculo
declarado**: não olha `started_at`, não olha `ended_at`, e não olha a invalidação
que a feature 055 criou.

**Dois defeitos, e o segundo é o grave:**

| # | o que acontece |
|---|---|
| 1 | quem saiu **continua contando depois** da saída, se o GitHub ainda o lista |
| 2 | `evolution/2` monta o conjunto de membros **de hoje** e o aplica a **todos os meses passados** — quando o GitHub para de listar alguém, a pessoa some **de janeiro também**, e o número de um mês fechado muda hoje |

O segundo é o mesmo defeito que o **SC-003 da 055** proíbe no vínculo,
acontecendo na medida.

**A regra tem duas metades, e a segunda é a que ninguém escreve:**

> As métricas de quem saiu **não contam depois** da saída — **e continuam
> contando antes**.

Filtrar por *"está na equipe hoje"* resolve o primeiro defeito e **piora** o
segundo. A correção é `membros/2` receber **uma data** e devolver quem estava na
equipe **naquela data**, pelo vínculo declarado — e `evolution/2` perguntar isso
mês a mês, em vez de reusar o conjunto de hoje.

**Antes desta correção, qualquer indicador de subequipe é número errado** — e um
painel composto por partes erradas é mais difícil de investigar que uma parte
errada.

---

## 2. Os indicadores aparecem SEPARADOS, e não somados

**Decisão de 2026-09-02.** Cada equipe mostra os seus números; **não há total**.

### Por que não somar

Somar as subequipes **não dá** o indicador da equipe quando alguém está em duas —
e isso não é hipótese. A ontologia declara que *"a mesma pessoa pode ser membro de
várias equipes ao mesmo tempo, com papéis diferentes em cada uma"*, e a medida
`flow.throughput.rate` **já declara a limitação** no nível pessoa:

> *"a mesma tarefa aparece uma vez por participante quando há mais de um
> responsável, e a soma dos níveis person não é igual ao nível sprint"*

Um total somado seria um número que **ninguém pode interpretar**: nem soma de
trabalho, nem contagem de gente.

### O que a decisão custa, e precisa estar na tela

**A pergunta "como vai o conjunto?" passa a não ter um número único.** Isso é
honesto — ela de fato não tem —, mas quem abre a tela procurando um total precisa
encontrar **a razão**, e não um espaço vazio.

---

## 3. A tela volta a fazer uma coisa (princípio X)

O `render` da tela da equipe tem hoje **490 linhas** e **seis seções**: estrutura,
pendências de papel, membros, projetos, cobertura de competências, evolução e
antipadrões. Ela cresceu por acréscimo — cada feature pôs a sua.

A constituição já proíbe: **princípio X, responsabilidade única em módulo e em
tela**.

E isso não é arrumação: **sem tirar coisa, os indicadores das subequipes entram
numa tela que já não cabe**. O foco é o que abre lugar para o item 2.

---

## A ordem, e ela não é negociável

1. **a medida respeita o período do vínculo** — sem isso, tudo abaixo é soma de números errados;
2. **o foco** — a tela volta a fazer uma coisa, e abre lugar;
3. **os indicadores por subequipe**, separados, com a razão de não haver total escrita;
4. **o clique** que leva ao detalhe da subequipe.

## Relação com a #397

A issue #397 pede o **rollup das competências** pela hierarquia. A decisão de
2026-09-02 responde a ela: **não haverá rollup somado**. O que haverá é a
apresentação lado a lado — e a issue precisa ser atualizada com isso, porque
ela hoje pede a soma.
