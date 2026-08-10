# Pesquisa — Fase 0

**Feature**: 002 — Pessoas e equipes separadas por organização observada
**Data**: 2026-08-10

Resolve as três pendências que a [análise ontológica](ontology-analysis.md)
deixou em aberto, mais as duas que apareceram ao escrever o plano. Cada uma traz
a decisão, a justificativa e as alternativas descartadas.

---

## R1 — Como a equipe derivada se identifica

**A pergunta**: a Application Reference exige `source_system`, `source_instance`,
`external_id` e `collected_at`. Uma equipe que não existe no GitHub não tem
identificador lá. O que se grava?

**Decisão**: a proveniência aponta para a **derivação**, não para o GitHub.

```text
source_system    the_band
source_instance  a instância que originou a coleta (https://github.com)
external_id      derived:default_team:<external_id da organização>
collected_at     o instante da coleta que a produziu
```

**Justificativa.** A Application Reference responde "de onde veio este registro".
A resposta honesta é: veio de uma derivação da plataforma sobre a organização
tal. Gravar `source_system: "github"` seria mentir na coluna que existe
justamente para não deixar mentir.

`source_instance` continua sendo a do GitHub de propósito: a derivação é
**daquela** instância. Duas instâncias com organizações homônimas produzem
equipes derivadas distintas, como devem.

O `external_id` determinístico é o que dá idempotência: reprocessar a mesma
organização produz o mesmo identificador, o upsert reconhece, e nada duplica.

**Consequência que o plano registra**: a distinção observado/derivado **não
precisa de coluna nova**. `source_system = "github"` é observada; qualquer outro
valor é derivada. É a leitura que FR-011 e FR-017 usam.

**Alternativa descartada**: coluna `origin` ou booleano `derived?` em `eo_teams`.
Seria repetir o F1 — inventar campo onde já existe um que responde, e um campo
inventado não vem do modelo derivado.

---

## R2 — Onde vive o vínculo da pessoa com a equipe derivada

**A pergunta**: `eo_team_membership_evidence` exige `platform_access_level`, com
`MAINTAINER` ou `MEMBER`. A origem não informa nível de acesso para um vínculo
que ela não conhece.

**Decisão**: mesma tabela, com `platform_access_level` **anulável**, e a coluna
de proveniência distinguindo a origem do vínculo.

```text
platform_access_level   NULL quando o vínculo é derivado
source_system           the_band, para o vínculo derivado
```

**Justificativa.** O vínculo derivado é o mesmo fato — esta pessoa está nesta
equipe — obtido por outro caminho. Separá-lo em tabela própria obrigaria toda
consulta de integrantes a unir duas fontes, e a primeira que esquecesse
produziria uma lista incompleta sem avisar.

Tornar a coluna anulável é a mudança certa porque **ausência é nula, nunca zero**
(constituição, princípio VIII): não existe nível de acesso para este vínculo, e
inventar `MEMBER` afirmaria o que a origem não afirma — o mesmo erro que a regra
`github.team_membership_evidence` recusa.

**Restrição que entra junto**: `platform_access_level` é obrigatório quando
`source_system = 'github'`. `check_constraint`, não `NOT NULL` — a
obrigatoriedade depende da origem.

**Alternativa descartada**: tabela separada para vínculo derivado. Rejeitada
pela consulta partida acima. **Segunda alternativa descartada**: gravar `MEMBER`
no derivado, para manter a coluna obrigatória. Rejeitada por inventar dado.

---

## R3 — Como a associação vira chave estrangeira na transformação

**A pergunta**: o derivador gera FK para `part_whole` e para relator. A relação
equipe↔organização é `association`, e uma associação de subkind elevado não
produz nada hoje.

**Decisão**: acrescentar a regra *associação com destino em kind e cardinalidade
`many → one` vira chave estrangeira na tabela do kind de origem*, com duas
qualificações.

| Situação | Resultado |
|---|---|
| origem é kind | FK `NOT NULL` se a cardinalidade do destino for `one` |
| origem é subkind elevado | FK **anulável**, mais `check_constraint` ligando a obrigatoriedade ao discriminador |

Para o caso concreto:

```text
eo_teams.organization_id  uuid NULL  → FK (association)
check: organization_id IS NOT NULL OR type <> 'organizational_team'
```

**Justificativa.** A relação parte de `eo.organizational_team`, que é subkind
elevado a `eo.team`. Uma FK `NOT NULL` obrigaria toda equipe de projeto a ter
organização, o que é falso — projeto entre organizações não tem uma só. A
obrigatoriedade é do subkind, e é isso que o `check_constraint` expressa.

**Alternativa descartada**: declarar a relação como `part_whole`, que já gera FK
sem tocar no derivador. É o risco R1 da análise ontológica: seria modelar de trás
para frente, e apagaria a distinção entre `eo.organizational_unit` — que é parte —
e `eo.team` — que é coletivo. **A relação é associação, e o derivador é que muda.**

---

## R4 — Como o retrofito recupera a organização sem consultar a origem

**A pergunta**: 10 equipes já coletadas estão sem organização. FR-023 proíbe
consultar o GitHub para corrigi-las.

**Decisão**: pela sincronização que as originou.

```text
eo_teams  →  raw_payloads (mesmo external_id e tipo)
          →  syncs.connected_tool_id
          →  connected_tools.organization_login
          →  eo_organizations (login, mesmo tenant e instância)
```

**Justificativa.** A ferramenta conectada **já sabe** qual organização estava
sendo observada — é campo obrigatório dela desde a correção de multi-organização.
O payload bruto preservado liga cada equipe à sincronização, e a sincronização à
ferramenta. Toda a corrente existe; falta percorrê-la.

É a mesma cadeia que FR-017 da feature 001 usa para reprocessar mapeamento
corrigido, e vale a mesma verificação: o teste roda **sem expectativa no Mox da
borda HTTP**, então qualquer chamada ao GitHub o derruba.

**Limitação declarada**: equipe cujo payload bruto tenha sido removido não pode
ser retrofitada, e entra no relatório de FR-024 como pendente com o motivo. Não
ocorre hoje — `raw_payloads` não é podado —, e o relatório existe para o dia em
que ocorrer.

---

## R5 — Quando a equipe derivada é criada, e quando deixa de existir

**A pergunta**: FR-004 cria a equipe quando há membro fora das equipes; FR-007
proíbe criá-la vazia. Quando isso é avaliado, e o que acontece quando a última
pessoa dela entra numa equipe observada?

**Decisão**: avaliada **ao fim de cada coleta**, depois de as equipes e os
integrantes terem sido processados.

- há membro da organização fora de toda equipe observada → a equipe derivada
  existe, e esses membros são vinculados a ela;
- não há → a equipe derivada **não é criada**;
- ela existia e deixou de ter integrantes → é marcada como **não mais observada**,
  como qualquer registro que some da origem. Não é apagada.

**Justificativa.** Avaliar ao fim é o único momento em que se sabe quem ficou de
fora — durante a coleta, a pessoa que ainda não teve sua equipe processada é
indistinguível da que não tem equipe nenhuma.

Marcar em vez de apagar segue a regra que já vale para todo o resto: a plataforma
preserva o histórico, e uma equipe que existiu e esvaziou é informação, não lixo.

**Alternativa descartada**: criar a equipe derivada sempre, e deixá-la vazia
quando não for necessária. Rejeitada por FR-007: registro sem referente. Além
disso faria a contagem de equipes derivadas crescer com o número de organizações,
sem significar nada.

---

## Pendências que não bloqueiam

**As perguntas de competência de EO exigem dado semeado?** Não para as três desta
feature — elas são estruturais e verificáveis contra o esquema. Perguntas que
exijam instância ficam para quando houver `examples/` de EO, como já existe para
SRO.

**Extrair um mecanismo comum entre a evidência observada e a derivada** — duas
ocorrências não justificam. A terceira justificaria (constituição, princípio VIII).
