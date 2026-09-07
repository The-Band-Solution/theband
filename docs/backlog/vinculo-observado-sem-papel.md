# O vínculo observado sem papel — a versão 2 de `github.team_membership_evidence`

**Decidido em 2026-09-06** pela pessoa mantenedora, a partir de diagnóstico medido.
Não é spec: as specs são a emenda da [055](../../specs/055-equipes-declaradas/spec.md)
e a da [058](../../specs/058-medidas-da-equipe/spec.md), da mesma data. Esta nota
diz o que a regra `priv/knowledge_base/rules/github_team_membership_evidence.yaml`
precisa passar a afirmar, e por quê.

**O YAML não é editado aqui.** A base é de quem responde pela ontologia, e o
princípio IV da constituição exige que a mudança semântica entre pelo YAML **antes**
de qualquer código a implementar. Esta nota é o que a versão 2 tem de onde partir.

## O motivo, medido

Medido pela pessoa mantenedora em 2026-09-06, contra a organização
`leds-conectafapes`:

| O que | Quanto |
|---|---:|
| equipes do GitHub coletadas | 8 |
| evidências de vínculo coletadas | 59, em 49 pessoas — bate com a origem |
| vínculos vigentes nessas 8 equipes | **0** |
| solicitações de mudança nos últimos 56 dias | 1 077 |
| das quais abertas por autor que só tem evidência pendente | **838 (78%)** |

A regra fez o que dizia. O que ela dizia produziu, contra dado real, uma plataforma
que sabe quem está em cada time e mede como se não soubesse: as 8 equipes disparam
`structure.ap02.team_with_no_members` com 49 pessoas na origem, e 78% das
solicitações do período não pertencem a equipe nenhuma para efeito de medida.

## O que a versão 1 afirma hoje

| Campo | v1 |
|---|---|
| `does_not_materialize` | `eo.organizational_role` e **`eo.team_membership`** — "depende do papel; sem ele o relator estaria incompleto, e uma alocação sem papel não responde nenhuma das perguntas que a alocação existe para responder" |
| `observed_link.persisted_as` | `team_membership_evidence` |
| `observed_link.promotion` | `to: eo.team_membership`, `requires: organizational_role_assigned` |
| `gap_reporting.metric` | `memberships_pending_role` — "vínculos observados sem papel atribuído" |
| `temporal_limitation` | `started_at` e `ended_at` nulos; "só é possível saber que o vínculo existia no momento da coleta" |

Metade disso continua certa: o GitHub não expõe papel, `MAINTAINER` e `MEMBER` são
nível de acesso, e promovê-los a papel faria CQ12, CQ14 e CQ16 devolverem resposta
falsa. O que precisa mudar é a frase *"uma alocação sem papel não responde nenhuma
das perguntas que a alocação existe para responder"*. Ela responde **quem está na
equipe** — a pergunta de toda medida de nível `team` — e não responde **em que
papel** — a pergunta de `sro.cq14` e `sro.cq16`. A v1 tratou as duas como uma, e
por isso negou a primeira para proteger a segunda.

## O que a versão 2 precisa dizer

Campo a campo. O texto é proposta; a redação final é de quem mantém a base, e os
nomes de campo novos são sugestão — o que importa é o que cada um afirma.

**`version: 2`**, com `provenance.source_type: maintainer_decision`, a data e a
medição acima como `reference`.

**`materializes`** ganha o relator:

```yaml
- concept: eo.team_membership
  from: team.members.node × organization.teams.nodes
  confidence: high
  note: >
    Materializado com o papel DECLARADAMENTE AUSENTE — organizational_role_id
    nulo —, sem autor de declaração e com started_at nulo. A participação é fato
    observado, com proveniência; o papel não é. Ver role_is_absent_by_design.
```

**`does_not_materialize`** mantém `eo.organizational_role`, com a mesma razão, e
**remove** `eo.team_membership`. Em seu lugar entra a justificativa do desvio:

```yaml
role_is_absent_by_design:
  pt-BR: >
    eo.team_membership é relator que media pessoa, equipe e papel, e
    eo.membership_to_play_role declara o papel como exatamente um. A plataforma
    materializa o relator com o papel DESCONHECIDO — nulo, nunca padrão — por
    três razões. (1) A participação no time é fato observado, com proveniência,
    e negá-lo por não se conhecer o papel produziu equipes de zero membros com
    49 pessoas na origem. (2) Toda medida de nível team depende do conjunto de
    membros, e nenhuma depende do papel. (3) Nulo aqui é desconhecido, no mesmo
    sentido em que started_at nulo é desconhecido: não é "sem papel", é "papel
    não declarado". O que a v1 protegia continua protegido: nenhum papel é
    inferido de MAINTAINER ou MEMBER, e sro.cq12, sro.cq14 e sro.cq16 continuam
    devolvendo NENHUMA resposta — não uma falsa — para os vínculos sem
    declaração.
```

**`observed_link`** continua descrevendo a evidência — `observed_at`,
`platform_access_level`, a proveniência —, que passa a apontar para o vínculo que
materializou (feature 021, FR-009). O que muda é a promoção:

```yaml
role_declaration:            # substitui observed_link.promotion
  on: eo.team_membership     # o vínculo já existe; nada é criado
  by: quem administra o tenant
  sets: [organizational_role_id, declared_by_user_id, started_at]   # o último opcional
  note: >
    Declarar o papel não cria vínculo: preenche o que a coleta deixou nulo. A
    partir daí o vínculo carrega declaração, e a coleta não o toca mais (055,
    FR-016). Um segundo papel para a mesma pessoa na mesma equipe nasce como
    vínculo declarado adicional (043, FR-006a). Nenhum papel vem pré-selecionado
    (043, FR-012).
```

**`ended_by_absence`**, novo:

```yaml
ended_by_absence:
  pt-BR: >
    Quando uma coleta não encontra a pessoa no time, o vínculo observado recebe
    ended_at igual ao instante dessa coleta. A data é LIMITADA PELA CADÊNCIA da
    coleta: diz quando a plataforma deixou de ver, não quando a pessoa saiu.
    Vínculo com declaração não é encerrado pela coleta; a discordância entre o
    que a coleta mostra e o que está declarado fica visível (055, FR-012). Se a
    origem voltar a mostrar a pessoa, nasce vínculo novo — os períodos coexistem.
```

**`gap_reporting.metric: memberships_pending_role`** — mantém o nome e muda o
referente: **vínculos vigentes sem papel declarado**. A nota já diz "informação,
não erro"; continua verdadeira.

**`temporal_limitation`** — `started_at` nulo continua, e pela mesma razão. `ended_at`
deixa de ser "sempre nulo": passa a ser preenchido pela ausência, com a limitação
de cadência. *"Quem estava no time em determinado sprint"* continua não respondível
para o passado anterior à primeira coleta — e passa a ser respondível, na
granularidade da coleta, dali em diante.

**`limitations`**, além das que a v1 já tem:

- `sro.cq14` e `sro.cq16` seguem sem resposta para vínculos sem papel declarado; a
  tela diz quantos são (058, FR-026).
- A cardinalidade declarada de `eo.membership_to_play_role` é `target: one`; o dado a
  viola enquanto o papel não é declarado. Ver a tabela abaixo.
- A data de fim por ausência é limitada pela cadência: duas coletas separadas por
  uma semana produzem um fim com uma semana de incerteza.
- A migração inicial promove evidências cuja `observed_at` é a data em que a
  plataforma foi ligada, não quando a pessoa entrou — `started_at` fica nulo por
  isso (043, FR-019).

## A razão ontológica, dita sem enfeite

`eo.team_membership` é relator: existe porque media pessoa, equipe e papel, e a EO o
declara com papel obrigatório — `eo.membership_to_play_role`, `target: one`. Uma
alocação **no mundo** tem papel; a ontologia está certa. O que a plataforma não tem
é **conhecimento** do papel — e a v1 respondeu à falta de conhecimento negando a
existência do relator. Esse é o erro: confundiu *não sei qual* com *não há*.

A v2 materializa o relator com o papel **declaradamente desconhecido**. É a mesma
convenção que a plataforma já usa para `started_at`: nulo é o que não se sabe, nunca
zero e nunca padrão (princípio VIII). O custo é declarado, e é triplo: enquanto o
papel não é declarado, as perguntas sobre papel não têm resposta; a cardinalidade
declarada não é satisfeita pelo dado; e a tela precisa dizer isso onde a medida
aparece.

**Não é o antipadrão do booleano no lugar do relator.** O relator está lá, com
temporalidade, proveniência e a possibilidade de acúmulo. O que falta é um dos
mediados, e a falta é nomeada — o que é o oposto de escondê-la num booleano.

## O que mais a base precisa decidir — não é desta nota

| Onde | O que | Quem decide |
|---|---|---|
| `eo.membership_to_play_role` | `target: one` contra dado com papel nulo. Duas saídas: **(a)** `zero_or_one`, com `provenance: project_decision` marcando o desvio da SEON como já se fez em `eo.organizational_team_belongs_to_organization`; **(b)** manter `one` e declarar na regra que o dado é relator **incompleto por desconhecimento**, não relação opcional. (b) é mais fiel à SEON; (a) é o que a ADR 0004 (D4, modelo derivado) exige **se** o derivador tira `NOT NULL` da cardinalidade — conferir antes de escolher | Ontologia |
| `github_default_team.yaml` | tem o mesmo `does_not_materialize: eo.team_membership`, para a equipe derivada. A decisão de hoje fala em times do GitHub; a derivada acompanha ou não? | pessoa mantenedora |
| `mappings/github/eo/team_membership_evidence.yaml` | a limitação "sem papel atribuído pelo tenant, o vínculo não é promovido" deixa de ser verdade; e `target.concept` continua `eo.person` ou passa a existir mapeamento para `eo.team_membership` | Ontologia |
| `structure_antipatterns.yaml`, `limits` | "vigência é declaração" deixa de ser verdade: vigência passa a ser observada **ou** declarada. `ap02` deixa de disparar para as 8 equipes — é o efeito esperado, e a nota precisa dizer que veio da regra, não de gente nova | Ontologia |
| `measurements/*` de nível `team` | a limitação *calculada sobre vínculos cujo papel pode não estar declarado* entra no YAML antes da tela (058, FR-026e) | Ontologia |
| índice `eo_team_memberships_vigente_index` | `UNIQUE (tenant, pessoa, equipe, papel) WHERE ended_at IS NULL` não garante um vínculo observado por par pessoa–equipe: nulo é distinto de nulo. 055, FR-013a exige a garantia | implementação |
| `docs/architecture/modelo-de-dados.md` | "o que foi observado e ainda não virou alocação" e a seção *Por que existe uma tabela de evidência separada* ficam históricas | Arquitetura |
| `docs/rfc/0001`, Q9 | histórica; não editar — a pergunta foi respondida por esta decisão | — |

## A ordem

1. YAML v2 da regra, e as decisões da tabela acima que a v2 precisa — cardinalidade
   e equipe derivada.
2. `mix knowledge.validate` verde.
3. Migração de dados e código.
4. Tela, com a composição (058, FR-026).

Código antes do YAML seria a semântica embutida na coleta que o princípio IV
proíbe — e foi exatamente para isso não acontecer que a v1 existia.
