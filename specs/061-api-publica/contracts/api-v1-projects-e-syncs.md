# Contrato: `GET /api/v1/projects` e `GET /api/v1/syncs`

As duas últimas rotas da FR-021. Com elas a lista do primeiro corte fecha.

| Recurso | Rota | Tela de origem |
|---|---|---|
| projetos | `GET /api/v1/projects` | `/projects` |
| sincronizações | `GET /api/v1/syncs` | `/syncs` |

Recusa, paginação e formato de erro seguem [`erro.md`](erro.md) e
[`api-v1-teams.md`](api-v1-teams.md).

---

## `GET /api/v1/projects`

Um projeto é **declarado** nesta plataforma: alguém o cria e liga repositórios, quadros,
organizações e equipes a ele. Não é coletado.

```json
{
  "data": [
    {
      "id": "…",
      "name": "Conecta Fapes",
      "phase": "execution",
      "parent": { "id": "…", "name": "…" },
      "started_on": "2025-03-01",
      "ended_on": null,

      "issues": {
        "direct": 2756,
        "via_subproject": 0,
        "note": "Never summed. An issue reached through a subproject is not a second issue.",
        "denominator_note": "`issues` counts through the project's repositories; `start_criterion.total` counts through its boards. They do not share a denominator and must not be compared."
      },

      "start_criterion": {
        "total": 2756,
        "with_instant": 2100,
        "no_criterion": 400,
        "event_not_collected": 256,
        "ambiguous": [],
        "note": "Three distinct absences, never one total. *No criterion declared*, *criterion declared and the event was never collected*, and *more than one instant matched* need different things done about them — an aggregate would tell nobody what to do."
      },

      "organizations": [ { "id": "…", "login": "leds-conectafapes", "name": "…" } ],
      "teams": [ { "team_id": "…", "name": "IA", "origin": "observed" } ],
      "repositories": [ { "repository_id": "…", "linked_at": "2026-09-05T02:54:22Z" } ],
      "boards": [ { "board_id": "…", "name": "…" } ]
    }
  ],
  "page": { "has_next": false, "next_cursor": null, "total": 2, "total_note": "…" }
}
```

### `start_criterion` são TRÊS ausências, e nunca um total

É a FR-004/FR-009 da spec que criou a tela. Uma issue pode estar sem instante de início por
três razões diferentes, e cada uma pede uma ação diferente:

| Campo | Significa | O que se faz |
|---|---|---|
| `no_criterion` | ninguém declarou o critério daquele quadro | declarar |
| `event_not_collected` | o critério existe, e o evento nunca foi coletado | coletar, ou rever o critério |
| `ambiguous` | mais de um instante casou | desempatar — e vem com a **lista**, não com a contagem |

`with_instant` é o que tem resposta. **Somar os quatro num "sem instante" diria a quem
integra que há um problema, e não qual.**

### Os dois totais NÃO compartilham denominador — e foi a medição que mostrou

`issues.direct` conta pelos **repositórios** do projeto. `start_criterion.total` conta pelos
**quadros**. São caminhos diferentes, e um projeto pode ter um sem o outro.

Medido em 2026-09-22 nesta base:

| Projeto | `issues.direct` | `start_criterion.total` | Quadros |
|---|---:|---:|---:|
| ConectaFapes | **2 756** | **0** | 0 |
| Valida | 0 | **498** | 1 |

Quem lê os dois lado a lado sem a advertência conclui que **2 756 issues estão sem critério
de início**. O que há é que o projeto não tem quadro declarado, e a contagem do critério não
alcança repositório.

Por isso `denominator_note` viaja no objeto, e não em documentação que ninguém abre.

### `teams[].origin` é marca, e não booleano

A consulta guarda `declared: true|false`. A API devolve `observed` ou `declared`, o mesmo
vocabulário das outras rotas. Booleano no lugar do relator é antipadrão declarado nesta casa
— aqui ele fica na fronteira de dentro, e não sai.

### `issues.direct` e `via_subproject` não se somam

Uma issue alcançada por subprojeto não é uma segunda issue. Somar contaria duas vezes.

### O custo, declarado — e por que ele é aceito

**Cada projeto custa ~6 consultas**: as issues, o critério de início, organizações, equipes,
repositórios e quadros. A rota **não** as faz em lote, e isso contraria a L38 na letra.

A razão de ser aceito, e ela é específica desta coleção:

- **projetos são declarados por gente, não coletados.** Medido em 2026-09-22 nesta base: **2**
  projetos. A coleção não cresce com a coleta — cresce com decisões humanas;
- as seis leituras são **agregações por projeto** (contagens e estados), e não junções. A
  forma em lote exigiria seis funções novas de domínio para uma coleção de dois elementos —
  que é abstrair para um caso que não existe;
- **`page_size` é limitado a 50 aqui**, e não a 200 como nas outras rotas. O teto é o
  reconhecimento do custo.

**O que fica pior, escrito**: se um dia um tenant declarar centenas de projetos, esta rota
degrada linearmente, e o conserto será escrever as seis leituras em lote. Há teste que mede
o custo por projeto, para que o crescimento seja **decidido** e não descoberto.

---

## `GET /api/v1/syncs`

Responde *"o dado está atualizado?"* — que toda integração pergunta antes de confiar em
qualquer número das outras rotas.

```json
{
  "data": [
    {
      "id": "…",
      "status": "completed",
      "started_at": "2026-09-09T21:40:12Z",
      "finished_at": "2026-09-09T21:43:39Z",

      "records": {
        "collected": 41863, "created": 1794, "updated": 302, "skipped": 88,
        "note": "Four readings of the same run, never summed: a record collected may be created, updated or skipped."
      },

      "gaps": {
        "repositories_skipped": 2,
        "repositories_unreachable": 1,
        "skip_reasons": ["…"],
        "memberships_pending_role": 0,
        "note": "A run that finished is not a run that reached everything. These are what it did not reach, and they are here so that `completed` is never read as *complete*."
      },

      "error_reason": null,
      "interrupted_by_person": false
    }
  ],
  "page": { "has_next": true, "next_cursor": "…", "total": null, "total_note": "…" }
}
```

### `completed` não quer dizer *completo*

Esta é a razão de a rota existir com o bloco `gaps`. Uma coleta pode terminar com status
`completed` e **não ter alcançado** repositórios — por limite de cota, por permissão, por
indisponibilidade da origem.

Quem integra e lê só o `status` conclui que o dado está inteiro. `repositories_unreachable`
e `repositories_skipped` são o que impede essa leitura, e por isso viajam no mesmo objeto —
não atrás de uma segunda chamada.

**É a mesma regra que a plataforma aplica a si mesma**: ausência escrita, nunca zero
silencioso.

### `interrupted_by_person` não é o mesmo que `status: "interrupted"`

O campo se chamava `interrupted`, e a medição mostrou por que não podia.

Existe coleta com `status: "interrupted"` e **nenhuma pessoa por trás**: o reconciliador a
encerrou porque *"o processo que a executava não existe mais"*. Um campo chamado
`interrupted` devolvendo `false` ao lado daquele status faria quem integra escolher em qual
acreditar.

O nome diz o que o campo sabe: **foi interrompida por alguém**. Se não foi, a razão está em
`error_reason`.

### Os quatro contadores de registro não se somam

`collected` é o que a origem devolveu. `created`, `updated` e `skipped` são o que se fez com
cada um — e um registro coletado cai em exatamente um dos três. Somar os quatro contaria a
coleta duas vezes.

### O que NÃO sai

| Fora | Por quê |
|---|---|
| `credential_id` | é o elo para a credencial, e credencial é segredo. A rota devolve **qual ferramenta**, nunca qual chave |
| qualquer valor de token ou chave | a API que os lista é a API que os vaza — FR-021, "fica fora" |
| `interrupted_by_user_id` | identifica pessoa por id interno numa rota que não tem por que o fazer. `interrupted_by_person: true` responde a pergunta sem isso |

---

## O que fecha, e o que não

Com estas duas, **as seis linhas da FR-021 estão entregues**: equipes, membros, medidas,
pessoas, projetos e sincronizações.

Fica fora, como a spec já declarava: qualquer escrita; contas, concessões e papéis;
credenciais e ferramentas conectadas; provedor e chaves de AI; dados brutos coletados.

---

## Medido em 2026-09-22, contra a base local

Pelas rotas, com o servidor no ar.

**`/projects`** — 2 projetos, e os dois mostram coisas diferentes:

| | ConectaFapes | Valida |
|---|---|---|
| issues diretas | 2 756 | 0 |
| critério: total / com instante / evento não coletado | 0 / 0 / 0 | 498 / 490 / **8** |
| organizações | `leds-conectafapes` | `leds-conectafapes` |
| equipes | 3 — duas `observed`, uma `declared` | 1 `observed` |
| repositórios / quadros | 16 / **0** | 4 / 1 |

**`/syncs`** — e a linha do meio é a razão de o bloco `gaps` existir:

| Status | Coletados | Criados | Atualizados | Repositórios pulados |
|---|---:|---:|---:|---:|
| `completed` | 5 495 | 63 | 298 | 0 |
| `completed` | 480 | 0 | 203 | **121** |
| `interrupted` | 0 | 0 | 0 | 0 |

**Uma coleta `completed` que não alcançou 121 repositórios.** Quem lê só o status conclui que
o dado está inteiro.

E a terceira linha é a que renomeou o campo: `status: "interrupted"` com
`interrupted_by_person: false`, e `error_reason` dizendo *"o processo que a executava não
existe mais"*.

Nenhum `credential_id` e nenhum `interrupted_by_user_id` no corpo.
