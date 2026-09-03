# O projeto pertence a uma organização

**Decidido em 2026-09-01.** Ainda não é spec — é o elo que falta, a premissa que
ele vence, e o que ele custa.

## O modelo, como a pessoa mantenedora o declarou

> *"A organização tem um ou mais projetos. Um projeto tem uma ou mais equipes.
> Uma equipe pode trabalhar em um ou mais projetos."*
>
> E, quando perguntada sobre o projeto entre organizações:
> *"o projeto entre organizações não existe"*

## O que a plataforma implementa hoje

| relação | estado |
|---|---|
| organização → 1..N projetos | **não existe** — nem na ontologia, nem em `spo_projects` |
| projeto → 1..N equipes | existe, em `spo_project_teams` |
| equipe → 1..N projetos | existe — a mesma tabela é N-N |

Duas das três estão de pé. **A que falta é a primeira**, e ela é a que dá
organização ao projeto.

## A premissa vencida

A ontologia registra por que a relação `equipe → organização` ficou no subkind
`eo.organizational_team`, e não no kind `eo.team`:

> *"`eo.project_team` liga-se a um projeto — um conceito de SPO —, não a uma
> organização. Pôr a relação em `eo.team` obrigaria toda equipe de projeto a ter
> organização, **o que é falso em projeto entre organizações**."*

**Esse caso deixou de existir por decisão.** A justificativa perde a premissa —
como aconteceu com a #367, que afirmava que a plataforma não lia campo de quadro
depois de a #181 ter entregue exatamente isso.

**Isso não obriga a mudar a decisão**, e vale dizer por quê: com o projeto tendo
organização, a equipe de projeto **deriva** a organização pelo projeto. Manter a
relação no subkind evita **dois caminhos** para a mesma verdade — e duas fontes
que podem divergir é o defeito que este projeto persegue. O que muda é a razão,
não a decisão, e a razão precisa ser corrigida no YAML.

## O que o elo destrava

**A permissão por escopo de projeto deixa de esbarrar no vazio.** Hoje, quem tem
escopo `project` não tem organização alguma para escolher — e por isso não
consegue declarar equipe organizacional, mesmo quando é isso que o mundo pede.
Com o elo, a organização do projeto é conhecida.

**O que ele NÃO destrava**, e precisa estar dito: **autoridade não sobe**. Ter
escopo num projeto não passa a autorizar declarar a estrutura da organização
inteira — a organização é maior que o projeto. O elo torna a organização
*conhecida*, não *concedida*.

## O que ele custa

- **migração** em `spo_projects`, com a coluna obrigatória;
- **o que já foi coletado fica sem organização** até alguém declarar. Os projetos
  existentes não têm de onde derivá-la, e preencher por adivinhação — pelo nome,
  pelo repositório mais comum — é exatamente o erro que a #514 e a #368
  estabeleceram como proibido;
- **a coleta**: o GitHub não entrega "organização do projeto" como fato. O quadro
  pertence a uma organização ou a uma pessoa, e disso não se conclui o projeto;
- **a correção da razão** no `organizational_structure.yaml`.

## A pergunta que a spec vai ter de responder

**Projeto sem organização é recusado, ou é lacuna declarada?**

Obrigatória na criação e **nula no que já existe** é a resposta honesta — a mesma
forma que a plataforma usa para toda ausência: nulo, nunca zero, e a tela diz que
falta. Fazer a coluna obrigatória para todos exigiria inventar o dado de 5.216
issues de projetos já coletados.

## Onde isto encosta na 055

**Não bloqueia.** A feature 055 entrega com a regra restrita — escopo
`organization` declara equipe organizacional naquela organização; escopo
`project` declara `project_team` naquele projeto. Quando o elo existir, a regra
pode ser revista, e a revisão será menor do que construir as duas juntas.
