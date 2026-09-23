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
      "competencies": [
        { "domain": "Kubernetes deployments and environment operations", "completed_tasks": 18 },
        { "domain": "OpenTelemetry and SigNoz observability", "completed_tasks": 13 }
      ],
      "competencies_note": null,
      "collected_at": "2026-09-04T04:00:49Z",
      "no_longer_observed_at": null
    }
  ],
  "page": { "has_next": true, "next_cursor": "…", "total": null, "total_note": "…" }
}
```

**`email` não sai.** A tela não o mostra e nenhum requisito o pediu. Acrescentá-lo porque a
coluna existe no banco alargaria o alcance da rota sem razão.

### `competencies`: `null` e `[]` são afirmações diferentes

É a FR-023, e é a distinção mais fácil de perder:

| Valor | Significa |
|---|---|
| `null` | **não houve leitura** — nenhum perfil foi gerado para esta pessoa; `competencies_note` diz isso |
| `[]` | **houve leitura, e nada foi demonstrado** — há perfil, e nenhum domínio tem tarefa concluída |

Achatar as duas em `[]` transformaria lacuna do registro em julgamento da pessoa.

A célula é `completed_tasks`: tarefa **concluída**. Entrega, nunca promessa — tarefa aberta é
intenção e não demonstra nada, e por isso um destaque com zero tarefas concluídas não é
competência e não aparece.

Aqui vai a forma **curta**. A evidência issue por issue está no detalhe: 80 pessoas × 3
competências × 3 números na listagem seria payload sem consumidor.

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

    "profile": {
      "origin": "derived",
      "origin_note": "Written by a language model from the collected record…",
      "generated_at": "2026-09-16T09:23:30Z",
      "model": "gpt-5.4-mini-2026-03-17",
      "period": { "from": "2025-03-01", "to": "2026-09-01" },
      "tasks_closed_since": 0,
      "regeneration_pending": false,
      "citations_removed": 0,

      "competencies": [
        {
          "domain": "payment worksheet and remittance UI",
          "completed_tasks": 10,
          "demonstrated": "worked across folha and payment-remittance screens…",
          "evidence_issue_numbers": [1181, 1289, 1639],
          "periods": [2, 3],
          "most_recent_period": "2026-06"
        }
      ],
      "skills": ["front-end feature scaffolding", "Nuxt UI screen refactoring"],
      "gaps": [],

      "summary": { "strengths": "…", "evolution": "…", "attention": "…" },
      "allocation": [
        { "from": "2025-03", "to": "2025-08", "domain": "…", "demonstrated": "…", "completed_tasks": 13 }
      ],
      "trajectory": [
        { "period": 1, "months": "2025-03 to 2025-08", "text": "…", "cited_tasks": ["…"] }
      ],
      "recommendations": ["…"],

      "limits": {
        "beyond_reach": "36 completed tasks were written by someone else and 22 by harianadm…",
        "team_not_person": "The text followed the project-wide expansion in description size…",
        "wrote_for_others": { "o_texto_mostra": "There is no evidence of writing tasks for other people here…" }
      },

      "evolution_over_time": {
        "generations": [
          { "generated_at": "2026-09-16T09:23:30Z",
            "competencies": { "payment worksheet and remittance UI": 10 } }
        ],
        "note": "One point per generation, oldest first. A month with no generation is absent, never interpolated…"
      }
    },
    "profile_note": null,

    "discussion_participation": { "items": [], "limit": 20 },
    "changes": {
      "opened": [], "reviewed": [], "merged": [], "commits": [],
      "limit": 10,
      "note": "Four lists, never summed. Opening, reviewing, merging and committing are distinct acts…"
    },

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
  ],

  "stale_open": {
    "stale_after_days": 90,
    "items": [
      { "id": "afe25107-…", "number": 77, "title": "…", "type": "issue",
        "days_open": 546, "repository": "…", "own_authorship": false,
        "conversation": "silencio", "acts": 0, "last_act": null }
    ]
  },

  "issues": {
    "items": [
      { "id": "4e833a00-…", "number": 1181, "title": "…", "state": "OPEN",
        "issue_type": null, "repository_id": "1d838224-…" }
    ],
    "limit": 25,
    "note": "The screen's first page. Searching and paging the whole assigned list is its own resource, and does not exist yet."
  }
}
```

### `profile` — derivado, e com as ressalvas que ele faz sobre si

**A marca `derived` viaja no corpo**, e não só na documentação: o consumidor previsto é
outro modelo, que afirmaria o texto como fato se a marca ficasse de fora.

**`competencies` não é `skills`.** As primeiras têm contagem de tarefas concluídas e a
evidência issue por issue; as segundas são rótulos que o modelo escreveu, sem contagem e
sem evidência. Tratá-los como equivalentes daria a mesma autoridade a um domínio com 18
tarefas e a uma palavra solta.

**`limits` não é decoração.** São as três ressalvas que o perfil faz sobre si mesmo: o que
o registro não alcança, o que é do time e não da pessoa, e se houve escrita para outros.
Entregar o perfil sem elas entregaria conclusão sem limite.

**`tasks_closed_since` é a idade do perfil** (FR-016). Sem ela, um perfil de dezembro
parece atual em junho.

**`evolution_over_time` tem um ponto por geração, da mais antiga para a mais recente.** Mês
sem geração não entra: interpolar afirmaria observação que não houve (feature 029, FR-003).

### O que fica FORA do veredito, e por quê

`discussion_participation` e `changes` vêm **sempre** — na tela elas vivem em *Where this
came from*, que não é o painel que o veredito protege. Protegê-las aqui estreitaria o
alcance pela porta do transporte, que é o mesmo erro de alargá-lo.

`stale_open` e `issues` ficam **dentro** de `work`, porque na tela estão dentro do painel.

Toda lista truncada carrega o próprio `limit`: sem ele, quem integra conclui que aquilo é
tudo.

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

- **a busca e a paginação da lista de issues** — vem a primeira página de 25, como a tela;
  percorrer a lista inteira com busca e ordenação é recurso próprio;
- **a escolha da escala** e o recorte por período;
- **quem declarou cada papel** — o campo é um e-mail, e e-mail não sai por esta rota;
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
| `profile` | **2 das 80 pessoas têm perfil** — `harianadm` e `AndreCoelhoS` |
| competências de `AndreCoelhoS` | 5 domínios, 56 tarefas concluídas somadas (18 em Kubernetes, 15 em provisionamento, 13 em observabilidade, 7 em Helm, 3 em Vault) |
| `competencies` das outras 78 | `null`, com a razão escrita — ausência de leitura, não de habilidade |
| `stale_open` | 29 paradas, corte de 90 dias, todas com conversa `silencio` |
| custo, permitido × recusado | o recusado consulta **menos**, e há teste que reprova se deixar de consultar menos |

As três últimas linhas são ausências, e estão aqui de propósito: um contrato que só mostra
o caso cheio não diz o que acontece no caso vazio, que é o comum nesta base.
