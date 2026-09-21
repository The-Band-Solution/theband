# Contrato: `GET /api/v1/people` e `GET /api/v1/people/:id`

Duas rotas, e a diferença entre elas **não é tamanho**: é alcance.

| Rota | Espelha | Filtra por `Access`? |
|---|---|---|
| `GET /api/v1/people` | a tela `/people` | **não** — lista o tenant |
| `GET /api/v1/people/:id` | a tela `/people/:id` | **o painel de trabalho, sim** |

A listagem não filtra porque a tela não filtra. O detalhe filtra porque a tela filtra —
`Tenants.pode_ver/3`, issue #369 FR-012. Igualar as duas seria alargar ou estreitar o
alcance pela porta da API, e o alcance é decisão da plataforma, não do transporte.

**O alcance de um token é o de quem o criou.** Não há identidade de API separada: o plug
põe a pessoa dona do token em `current_user`, e o veredito é calculado sobre ela. Uma
credencial não vê mais do que quem a emitiu veria na tela.

**E-mail não sai por nenhuma das duas rotas.** Nem o da pessoa observada, nem o de quem
declarou um papel — a consulta de papéis carrega esse segundo, e devolvê-lo porque ele já
está à mão desfaria a decisão por acidente.

---

## `GET /api/v1/people` — a listagem

```
GET /api/v1/people?page_size=50&after=<cursor>
Authorization: Bearer tb_api_<id_publico>_<segredo>
```

Cada campo é uma coluna da tela `/people`. Paginação e `total: null` seguem
[`api-v1-teams.md`](api-v1-teams.md), e a recusa segue [`erro.md`](erro.md).

```json
{
  "data": [
    {
      "id": "01d71ecd-aba5-4fba-a5dd-4ae0f6c05398",
      "name": "João Vitor Cosmo",
      "login": "jvcosmo",
      "account_type": "person",
      "origin": "observed",
      "source_system": "github",
      "source_instance": "https://github.com",
      "external_id": "U_kgDOADxjNg",
      "organizations": [
        { "id": "309acd61-…", "login": "leds-conectafapes", "name": "LEDS - ConectaFapes" }
      ],
      "organizations_note": null,
      "collected_at": "2026-09-04T04:00:49Z",
      "no_longer_observed_at": null
    }
  ],
  "page": { "has_next": true, "next_cursor": "…", "total": null, "total_note": "…" }
}
```

**`email` não sai.** A tela não o mostra e nenhum requisito o pediu. Acrescentá-lo porque a
coluna existe no banco alargaria o alcance da rota sem razão.

**`organizations` vem das equipes.** Não há laço direto pessoa→organização nesta ontologia.
Quem não está em equipe alguma sai com a lista vazia e a razão em `organizations_note`
(`"no team — organisation unknown"`). Quem está em mais de uma sai **uma vez**, com todas —
e então somar pessoas por organização dá mais que o total. Está certo.

---

## `GET /api/v1/people/:id` — o detalhe

```
GET /api/v1/people/01d71ecd-aba5-4fba-a5dd-4ae0f6c05398
Authorization: Bearer tb_api_<id_publico>_<segredo>
```

`:id` é o **id da plataforma**, não o da origem. `404` quando não existe **ou** quando é de
outro tenant: as duas devolvem a mesma resposta, porque distingui-las diria a quem varre que
o id existe em algum lugar.

### O corpo, por inteiro

```json
{
  "data": {
    "id": "7620b87c-0fba-41c2-ab25-88caaf1595dd",
    "name": "Vinícius",
    "login": "vinicius-je",
    "account_type": "person",
    "origin": "observed",

    "provenance": {
      "source_system": "github",
      "source_instance": "https://github.com",
      "external_id": "U_kgDOBA1ivQ",
      "first_observed_at": "2026-09-04T04:00:49Z",
      "last_observed_at": "2026-09-04T04:00:49Z",
      "no_longer_observed_at": null
    },

    "organizations": {
      "by_membership": [
        { "id": "309acd61-…", "login": "leds-conectafapes", "name": "LEDS - ConectaFapes" }
      ],
      "by_work": [],
      "note": "Two different claims, never summed. `by_membership` climbs person → team → organisation. `by_work` is observed end to end: person → issue → repository → organisation. Someone who left before the platform started observing was never in a team, and the work stayed."
    },

    "teams": [
      {
        "team_id": "deb21f7c-…",
        "team_name": "PLATAFORMA",
        "organization_login": "leds-conectafapes",
        "platform_access_level": "MEMBER",
        "observed_at": "2026-09-04T04:00:52Z",
        "last_observed_at": "2026-09-09T21:43:37Z",
        "no_longer_observed_at": null,
        "promoted": false
      }
    ],

    "roles": [],
    "roles_note": "No role declared for this person. A role is declared on this platform, never observed at the source — an empty list means nobody declared one, not that the person has none.",

    "account": {
      "linked_user_id": null,
      "note": "No account on this platform is declared to be this observed person.",
      "link_coverage": { "accounts": 2, "declared": 0 }
    },

    "profile": null,
    "profile_note": "No profile has been generated for this person. When present it is `derived` — written by a language model from the collected record, and never an observation.",

    "access": { "can_see_work": true, "reason": null },
    "work": { }
  }
}
```

### `access` decide se `work` existe

`can_see_work` é o veredito de `Tenants.pode_ver/3` — a união do piso, dos derivados, das
concessões e da liderança declarada (feature 045, #369 FR-010/022).

Quando é `false`, **`work` é `null`** e `reason` diz qual dos casos é. O motivo não é
descartável: *"não declararam quem você é"* e *"ninguém foi declarado líder"* têm remédios
diferentes, e quem integra precisa mandar a pessoa ao lugar certo (FR-012g).

**A recusa é registrada**, como na tela: `AccessEvents.painel_recusado/4`. A FR-024 da spec
045 aceita o risco de agregação — alguém que alcança muitos itens reconstrói por acumulação
o que o veredito recusa direto — e aponta o registro de acesso como o caminho dele. Uma
rota de API que recusasse sem registrar abriria exatamente o caminho que a FR fecha, e com
menos atrito que a tela.

**As medidas não são calculadas quando o veredito é `não`.** Calcular a vazão de quem não
pode vê-la é fazer o trabalho do vazamento e depois esconder o resultado — o custo fica
igual e o dado existe em memória.

### `work`, quando existe

```json
{
  "assigned": 363,
  "authored": 662,
  "counts_note": "Never summed. Opening an issue and working on it are different acts, with different participations in the ontology.",
  "open_assigned": 164,
  "timeline_coverage": { "observed": 164, "total": 164 },

  "scale": "monthly",
  "series_by_period": [{ "period": "2025-01", "created": 3, "closed": 2 }],
  "burn": [{ "period": "2025-01", "scope": 3, "done": 2, "open": 1 }],

  "projection": { "type": "does_not_converge", "created": 169, "closed": 32 },
  "deadline": { "date": "2026-09-13", "source": "sprint", "without_time_box": 116 },

  "age_buckets": [
    { "label": "até 7d", "min_days": 0, "max_days": 7, "count": 0 },
    { "label": "7–30d", "min_days": 7, "max_days": 30, "count": 10 },
    { "label": "30–90d", "min_days": 30, "max_days": 90, "count": 35 },
    { "label": "90–180d", "min_days": 90, "max_days": 180, "count": 108 },
    { "label": "mais de 180d", "min_days": 180, "max_days": null, "count": 11 }
  ],

  "lead_time": { "count": 199, "median_days": 12, "p85_days": 96 },
  "verification": { "passed": 1035, "broke": 79, "other": 8, "unattributed_in_tenant": 4326 },
  "change_participation": {
    "opened": 808, "merged": 884, "reviewed": 666,
    "endorsed": 674, "objected": 62, "abstained": 30
  },
  "antipatterns": {
    "findings": [{ "id": "process.ap02.moved_after_closing", "count": 27 }],
    "assessed": 360,
    "not_assessed": 3
  },
  "repositories": [
    { "repository_id": "1d838224-…", "name": "conectafapes-project",
      "qualified_name": "leds-conectafapes/conectafapes-project",
      "assigned": 1, "authored": 0 }
  ]
}
```

#### As regras que o corpo carrega, e por quê

**`assigned` e `authored` nunca são somados**, e `counts_note` diz isso na resposta. Quem
abre uma issue não necessariamente trabalha nela.

**`scale` é `monthly` e não é escolhida pelo consumidor nesta fatia.** A tela oferece
semana, mês e ano; a rota fixa o mês e declara qual usou. Um parâmetro de escala é item
próprio — e uma resposta que não dissesse a escala faria a série significar coisas
diferentes sem avisar.

**`lead_time` é `null` quando não há issue concluída**, e `null` não é zero dias. É lead
time, e não cycle time: inclui o tempo em que ninguém tocou. Mediana e p85, nunca média —
uma issue parada por 422 dias move a média e não move a mediana.

**`projection.type`** é um de `converges`, `does_not_converge`, `beyond_observed`,
`no_open_work`, `no_data`, `too_close_to_call`. Cada um carrega os números que o sustentam.

**`deadline.date` é declarada, não projetada**: sai do fim da caixa de tempo.
`without_time_box` conta as issues abertas que não estão em caixa nenhuma — e é o número
que diz o quanto a data vale.

**`verification.unattributed_in_tenant` fica à parte** e não entra nas três primeiras: são
execuções que não casam com pessoa alguma, e somá-las afirmaria medida onde não há.

**`antipatterns.not_assessed` existe para não virar zero.** 3 issues não avaliadas não são
3 issues sem antipadrão.

**`timeline_coverage` é um par**, e a resposta traz os dois lados: `observed` de `total`.
Uma cobertura sem denominador é um número sem origem.

**Rótulos das faixas de idade saem da tela, em português**, e por isso vêm com
`min_days`/`max_days`: quem integra ordena e compara pelos limites, não pelo rótulo.

### O que esta rota **não** carrega

- **a lista de issues designadas** — a tela pagina 25 por vez, com busca e ordenação
  próprias. É recurso seu, e embuti-la aqui faria uma resposta sem teto;
- **as discussões e as mudanças** que a tela lista (limites 20 e 10) — mesma razão;
- **a escolha da escala** e o recorte por período;
- **escrita de qualquer espécie.** `POST`, `PUT`, `PATCH` e `DELETE` devolvem `405` com
  `Allow: GET, HEAD` (FR-017).

---

## Medido em 2026-09-21, contra a base local

Uma pessoa com trabalho de verdade (`vinicius-je`, 363 designadas), pela rota, com o
servidor no ar:

| Leitura | Valor |
|---|---|
| seções no corpo | 8, todas as da tela |
| `work.assigned` / `work.authored` | 363 / 662 — **não são os 808 de `change_participation.opened`** |
| `series_by_period` | 21 períodos, e `burn` os mesmos 21 |
| `organizations.by_work` | vazio: tudo em que trabalhou é organização de que já é membro |
| `roles` | vazio nesta base — ninguém declarou papel |
| `profile` | ausente nesta base |
| custo, permitido × recusado | o recusado consulta **menos**, e há teste que reprova se deixar de consultar menos |

As três últimas linhas são ausências, e estão aqui de propósito: um contrato que só mostra
o caso cheio não diz o que acontece no caso vazio, que é o comum nesta base.
