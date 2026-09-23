# Contrato: `GET /api/v1/teams/:id`, `/members` e `/measures`

As três rotas que a [spec 061](../spec.md) previa (FR-021) e a primeira fatia não entregou.
Fecham a assimetria: pessoa tinha listagem **e** detalhe; equipe tinha só listagem.

A listagem `GET /api/v1/teams` está em [`api-v1-teams.md`](api-v1-teams.md).

---

## O veredito, e onde ele morde

O detalhe filtra por `Tenants.pode_ver_equipe/3`, e ele tem **quatro caminhos de
permissão** — não um:

| Veredito | Quem |
|---|---|
| `admin` | administração do tenant |
| `escopo_de_equipe` | concessão sobre esta equipe |
| `escopo_da_organizacao` | concessão sobre a organização da equipe |
| `vinculo_vigente` | quem é membro |
| `fora_do_alcance` | ninguém dos acima — **404** |

**Recusa é `404`, e não `403`.** Um `403` confirmaria que a equipe existe, e para quem varre
isso é metade da resposta. É a mesma escolha do detalhe de pessoa, pela mesma razão.

O alcance é o de **quem criou o token** — não há identidade de API separada.

---

## `GET /api/v1/teams/:id`

```json
{
  "data": {
    "id": "52bbaf2a-c197-4370-9cfd-004e106a4a0d",
    "name": "LEDS - ConectaFapes",
    "slug": "leds-conectafapes",
    "origin": "observed",
    "provenance": {
      "source_system": "github",
      "source_instance": "https://github.com",
      "external_id": "T_kwDO…",
      "first_observed_at": "2026-09-04T04:00:52Z",
      "last_observed_at": "2026-09-09T21:43:37Z",
      "no_longer_observed_at": null
    },
    "organization": { "id": "309acd61-…", "login": "leds-conectafapes", "name": "LEDS - ConectaFapes" },

    "composition": {
      "is_composed": true,
      "parts": [
        { "team_id": "e3cbe87d-…", "name": "SQUAD BLUE",  "since": "2026-09-08T19:59:09Z" },
        { "team_id": "49daae41-…", "name": "SQUAD GREEN", "since": "2026-09-08T19:59:09Z" },
        { "team_id": "2c41895c-…", "name": "SQUAD PINK",  "since": "2026-09-08T19:59:09Z" }
      ],
      "note": "The roster of a composed team is the team plus its parts with a current composition. There is one definition of *who belongs here*, and every count below uses it."
    },

    "roster": { "current": 48, "left": 0, "mistakes": 0 },
    "memberships_pending_role": 0,

    "access": { "reason": "admin" }
  }
}
```

### `roster.current` é maior que o número de vínculos diretos, e está certo

Medido em 2026-09-21: a equipe tem **31** vínculos de evidência diretos e `current` diz
**48**. A diferença são as três subequipes. O alcance é declarado em `composition`, e é o
mesmo que `/members` percorre — um cabeçalho que contasse por evidência sobre uma lista que
conta por alcance daria dois números para a mesma pergunta.

### `left` e `mistakes` nunca se somam a `current`

*Saiu* e *foi equívoco* são afirmações diferentes: a primeira diz que o vínculo existiu e
terminou; a segunda, que nunca devia ter sido afirmado. Somá-las apagaria a distinção que
a revogação existe para manter — **revogar marca, nunca apaga**.

---

## `GET /api/v1/teams/:id/members`

O dado mais pedido, segundo a spec: o vínculo **com a origem**.

```json
{
  "data": [
    {
      "person_id": "11faf7ae-…",
      "name": "Arthur",
      "login": "Eskriy",
      "situation": "vigente",
      "direct": true,
      "squads": [],
      "memberships": [
        {
          "membership_id": "e0488b87-…",
          "team_id": "52bbaf2a-…",
          "team_name": "LEDS - ConectaFapes",
          "origin": "declared",
          "role": { "id": "538b5b9e-…", "code": "dev", "name": "Desenvolvimento" },
          "started_at": null,
          "ended_at": null,
          "declared_at": "2026-09-05T02:54:22Z",
          "mistake": null,
          "current": true,
          "direct": true
        }
      ]
    }
  ],
  "page": { "has_next": false, "next_cursor": null, "total": null, "total_note": "…" }
}
```

### `origin` por vínculo, e não por pessoa

Uma pessoa pode ter vínculo **observado** numa equipe e **declarado** noutra, e as duas
afirmações valem ao mesmo tempo. Por isso a marca vive no vínculo.

| `origin` | Significa |
|---|---|
| `observed` | a origem afirmou — veio da coleta |
| `declared` | alguém declarou nesta plataforma |

### `mistake` não é o mesmo que `ended_at`

`ended_at` diz *saiu*. `mistake` diz *nunca devia ter sido afirmado*, e carrega a razão.
Achatá-los faria história virar erro, e erro virar história.

### A API fala uma língua

O domínio escreve em português — `:declarado`, `:observado`, `:vigente` — e a API devolve
`declared`, `observed`, `current`. Casados um a um, e não traduzidos por tabela: átomo novo
no domínio reprova no teste em vez de sair cru na resposta.

**A primeira implementação errou isto**: usou `to_string/1` e devolveu `declarado` ao lado
de uma listagem que já dizia `declared`.

A exceção é `access.reason`, que fica no vocabulário da **regra** — `escopo_de_equipe`,
`vinculo_vigente`. Ele nomeia qual das quatro cláusulas concedeu, e traduzir criaria um
segundo nome para a mesma cláusula: quem lê o log e quem lê a resposta deixariam de falar
a mesma coisa.

### Quem declarou **não** sai

O campo é um endereço de e-mail, e e-mail é o dado que esta API exclui de propósito — nas
pessoas, pela mesma razão. Devolvê-lo aqui porque a consulta já o carrega desfaria a
decisão por acidente.

---

## `GET /api/v1/teams/:id/measures`

O que a integração leva para painel próprio.

```json
{
  "data": {
    "window": { "days": 56, "from": "2026-07-27T00:00:00Z", "to": "2026-09-21T00:00:00Z" },

    "work": {
      "members": 31,
      "open": 23,
      "closed_in_window": 3,
      "stale": 18,
      "stale_after_days": 90,
      "no_work": false,
      "note": "`open` and `closed_in_window` are never summed: one is a state now, the other a count over a window."
    },

    "open_by_person": [
      {
        "person_id": "…",
        "tasks": [
          { "issue_id": "23354808-…", "external_id": "I_kwDO…",
            "title": "[Dados] Auditar divergências…",
            "concept": "sro.intended_scrum_development_task",
            "open_for_days": 98, "stale": true }
        ]
      }
    ],

    "time_to_first_review": {
      "items": [
        { "change_request_id": "…", "number": 2775, "title": "[FIX] A promoção exige…",
          "opened_at": "2026-09-03T19:34:47Z", "author_person_id": "…", "author_login": "…",
          "state": "waiting", "waited_hours": null, "waiting_for_days": 18 },
        { "change_request_id": "…", "number": 2740, "title": "…",
          "opened_at": "2026-09-01T…", "author_person_id": "…", "author_login": "…",
          "state": "reviewed", "waited_hours": 0.2, "waiting_for_days": null }
      ],
      "reviewed": { "count": 23, "median_hours": 0.2 },
      "waiting":  { "count": 79, "median_days": 46 },
      "medians_note": "Two medians, side by side and never summed…",
      "limit": 200,
      "truncated": false,
      "truncated_note": "When true, the list was cut, and any statistic over it answers a different question than the same statistic over the whole."
    },

    "skills": {
      "members": 31,
      "with_profile": 0,
      "without_profile": [ { "person_id": "…", "name": "Arthur" } ],
      "competencies": [],
      "coverage_note": "Whoever has no profile is **named**, never summed as zero. Absence of a profile is absence of reading, so team coverage is a floor and never a ceiling.",
      "summary": [
        { "type": "sem_perfil", "text": "31 de 31 membros ainda sem perfil — a cobertura real pode ser maior, nunca menor." }
      ]
    }
  }
}
```

### Duas medianas, e a razão medida

**Esta foi a correção que a implementação impôs ao contrato.** A primeira versão desta
página previa um campo `seconds` por espera e uma mediana só. A função do domínio devolve
um **estado**:

| `state` | Campo com valor | Significa |
|---|---|---|
| `reviewed` | `waited_hours` | a espera terminou, e levou tanto |
| `waiting` | `waiting_for_days` | a espera **não terminou**, e já leva tanto |

Um campo único afirmaria que a segunda terminou. E omitir as em curso seria pior: a mediana
**melhoraria quanto pior a equipe estivesse**, porque as que ninguém revisou são justamente
as que mais interessam. Contá-las como zero afirmaria revisão instantânea.

O número que fecha o argumento, medido nesta base em 2026-09-21, na equipe
`LEDS - ConectaFapes`:

| | Quantas | Mediana |
|---|---:|---:|
| revisadas | 23 | **0,2 h** |
| aguardando | 79 | **46 dias** |

Uma mediana só teria respondido *"12 minutos"* sobre 102 solicitações das quais 79 esperam
há mês e meio.

### `truncated` não é detalhe de paginação

A lista de esperas é cortada num limite, e **uma mediana sobre 200 de 500 é outra medida**,
apresentada com o mesmo rótulo. Foi achado da revisão de segurança do PR #798. Por isso a
resposta diz que cortou, e diz o que isso significa.

### `without_profile` vem NOMEADO

É a FR-004 da feature 029: quem não tem perfil aparece com nome, nunca somado como zero.
Ausência de perfil é ausência de **leitura** — a cobertura da equipe é um **piso**.

Medido em 2026-09-21 nesta base: **31 de 31 sem perfil**, e por isso `competencies` vem
vazio. Não é que a equipe não tenha competências; é que ninguém as leu.

### O que esta rota NÃO carrega

- **os cartões de *Problemas agora*** — dependem de uma cadeia de carregadores da tela
  (anomalias da estrutura, pessoas do detalhe) que esta fatia não replica. Item próprio;
- **a aba *Flow per person*** — a série por membro é sua própria rota;
- **a escolha da janela**: 56 dias, fixos e **declarados** em `window`.

---

## Medido em 2026-09-21, contra a base local

Equipe `LEDS - ConectaFapes`, pela rota, com o servidor no ar:

| Leitura | Valor |
|---|---|
| composição | composta, com SQUAD BLUE, GREEN e PINK |
| `roster.current` | **48** — contra **31** vínculos de evidência diretos; a diferença são as subequipes |
| `/members` | 48 linhas, 31 diretas e 17 via subequipe |
| origem dos vínculos | 31 `declared`, 19 `observed` — uma pessoa pode ter os dois |
| `work` | 23 abertas, **18 paradas**, 3 fechadas na janela |
| esperas | 102 — 23 revisadas (0,2 h) e 79 aguardando (46 dias) |
| `skills` | 31 membros, **0 com perfil**, 31 nomeados sem perfil, 0 domínios |
| e-mail no corpo | nenhum |

As duas últimas linhas são ausências, e estão aqui de propósito.
