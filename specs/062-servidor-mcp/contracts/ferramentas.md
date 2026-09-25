# Contrato: as quatro ferramentas do primeiro corte

**Transporte**: MCP sobre HTTP, em `/mcp`. **Autenticação**: o token da 061, no cabeçalho
`Authorization`. `/mcp` passa pela **mesma pipeline** da API,
`pipe_through [:api, :api_autenticada]`, que autentica, limita e registra, nessa ordem.

O tenant vem **do token**. Nenhuma ferramenta aceita `tenant_id`, e uma que aceitasse seria o
achado A01-2 da avaliação da 061 com outro nome.

---

## Antes da ferramenta: o que a camada HTTP responde

*Acrescentado em 2026-09-24, na reconciliação com o código.* Três respostas acontecem **antes**
de o protocolo MCP começar. Por isso elas **não** saem como erro JSON-RPC, e o cliente precisa
tratá-las no nível HTTP:

| HTTP | Quando | Corpo |
|---|---|---|
| `401` | sem token, token malformado, inexistente, revogado ou expirado | o formato único da 061 (`{"error":{"code":"unauthorized",…}}`), idêntico ao de `/api/v1`. Ver [`061/contracts/erro.md`](../../061-api-publica/contracts/erro.md) |
| `429` | o token passou de 120 chamadas por minuto (`api.access.thresholds`, regra `rate_limit`) | o formato único, com o limite, a janela e quanto falta para ela reabrir |
| `404` | subcaminho de `/mcp` (`/mcp/nada`) | **o formato único da 061**, `{"error":{"code":"not_found",…}}`. O `forward` entrega `/mcp/*` à porta, e a porta casa só `/mcp` exato (R10). Medido em 2026-09-25 |
| `404` | caminho **ao lado** de `/mcp` (`/mcpx`) | não casa a rota, e cai no `404` do site, que hoje é a página HTML: o defeito do [#943](https://github.com/The-Band-Solution/theband/issues/943) |
| `405` | `GET` ou `DELETE` em `/mcp` | com `protocol_mode: :modern_only` não há sessão, e por isso não há stream por `GET` nem encerramento por `DELETE`. **O corpo é o da `ex_mcp`**, `{"error":"Method not allowed"}`, e não o formato único: o `405` da 061 diz *"This API is read-only"*, que seria falso para um `GET` |
| `403` | pedido com cabeçalho `Origin` | a `ex_mcp` recusa toda origem de navegador fora de `allowed_origins`, que é vazia. Cliente MCP não manda `Origin`; navegador manda |

**O limite é um só por token.** `/mcp` e `/api/v1` gastam o **mesmo** limite, e é isso que a Q4
decidia. Dois limites para o mesmo token dariam duas respostas para *"por que recusou"*.

**O que a revisão 2026-07-28 do protocolo exige de cada requisição**, medido contra a `ex_mcp`
1.5.0 em 2026-09-25, e não presumido:

| Cabeçalho | Quando | Sem ele |
|---|---|---|
| `mcp-protocol-version: 2026-07-28` | sempre | a requisição não é da revisão moderna, que é a única aceita (`:modern_only`) |
| `mcp-method` | sempre, com o método JSON-RPC | `400`, JSON-RPC `-32020` |
| `mcp-name` | em `tools/call`, com o nome da ferramenta | `400`, JSON-RPC `-32020` |

E o `_meta` do pedido leva `io.modelcontextprotocol/protocolVersion`, `clientCapabilities` e
`clientInfo`. **`tools/list` volta em ordem alfabética**, e não na do registro.

**Só quatro métodos chegam à biblioteca**: `server/discover`, `tools/list`, `tools/call` e
`notifications/cancelled`. *Corrigido em 2026-09-25:* a primeira lista trazia `initialize`,
`notifications/initialized` e `ping`, que não existem na revisão 2026-07-28, e recusava
`server/discover`, que é como um cliente moderno descobre o servidor. O resto, incluindo `subscriptions/listen`, `resources/*`,
`prompts/*` e `logging/*`, recebe o erro JSON-RPC de método inexistente **antes** da `ex_mcp`
(T016). Nenhuma resposta de `/mcp` sai em stream.

**Cada mensagem do protocolo conta**: `server/discover`, `tools/list` e as notificações gastam o
limite como qualquer chamada de ferramenta, porque cada uma é uma requisição HTTP. Com 120 por
minuto a folga é grande, mas quem integra precisa saber.

---

## `tools/list` — a lista é fechada

Exatamente quatro. Não há ferramenta genérica, não há filtro livre, não há campo de ordenação
vindo de argumento (FR-023).

Cada descrição declara **o que a ferramenta não responde**, com a mesma disciplina do
`what_this_is_not` que o schema da base de conhecimento exige (FR-022).

---

## `team_roster`

> Quem pertence a esta equipe, e por qual afirmação.
>
> **Não responde** quanto cada pessoa trabalhou, nem quem lidera: pertencer e desempenhar
> são coisas distintas, e a segunda tem ferramenta própria.

**Argumento**: `team_id` (string, obrigatório).

```json
{
  "state": "checked",
  "value": {
    "people": [
      { "person_id": "…", "name": "Arthur", "login": "Eskriy", "situation": "current",
        "direct": true,
        "memberships": [
          { "team_id": "…", "team_name": "LEDS - ConectaFapes", "origin": "declared",
            "role": { "code": "dev", "name": "Desenvolvimento" }, "current": true }
        ] }
    ],
    "totals": { "current": 48, "left": 0, "mistakes": 0 }
  },
  "composition": {
    "is_composed": true,
    "parts": ["SQUAD BLUE", "SQUAD GREEN", "SQUAD PINK"],
    "note": "O roster de uma equipe composta é a equipe MAIS as partes com composição vigente."
  },
  "window": null,
  "origin": "observed",
  "rule": null,
  "measurement_id": null,
  "limitations": ["…lidas da base…"],
  "misinterpretations": ["…lidas da base…"],
  "collected_at": "2026-09-09T21:43:37Z"
}
```

**`origin` vive no vínculo, não na pessoa**: alguém pode ser observado numa equipe e declarado
noutra, e as duas afirmações valem ao mesmo tempo. Medido: 31 `declared` e 19 `observed` na
mesma equipe.

**`current`, `left` e `mistakes` nunca se somam.** *Saiu* diz que o vínculo existiu e
terminou; *equívoco* diz que nunca devia ter sido afirmado.

---

## `team_open_work`

> O que cada pessoa da equipe tem aberto agora, e há quanto tempo.
>
> **Não responde** quanto cada uma entregou, nem compara pessoas: as linhas não compartilham
> denominador, e ordenar por elas produz ranking que a plataforma recusa.

```json
{
  "state": "checked",
  "value": {
    "by_person": [
      { "person_id": "…",
        "tasks": [ { "issue_id": "…", "title": "…", "open_for_days": 98, "stale": true,
                     "concept": "sro.intended_scrum_development_task" } ] }
    ],
    "totals": { "members": 31, "open": 23 }
  },
  "window": null,
  "origin": "observed",
  "collected_at": "…"
}
```

**Pessoa sem tarefa aberta não vira linha com zero**: ela não aparece em `by_person`, e
`totals.members` diz quantas existem. Somar as duas leituras responderia outra pergunta.

---

## `team_review_wait`

> Quanto o trabalho desta equipe espera pela primeira revisão humana.
>
> **Não responde** se a revisão foi boa, nem quem revisa mais: conta o tempo até a primeira
> posição tomada, e nada sobre o conteúdo dela.

```json
{
  "state": "checked",
  "value": {
    "reviewed": { "count": 23, "median_hours": 0.2 },
    "waiting":  { "count": 79, "median_days": 46 },
    "truncated": false
  },
  "window": { "days": 56, "from": "2026-07-27T…", "to": "2026-09-21T…" },
  "origin": "derived",
  "rule": { "id": "…", "version": 1 },
  "limitations": ["…"],
  "misinterpretations": ["…"],
  "collected_at": "…"
}
```

### As duas leituras não se somam, e esta é a ferramenta que prova por que

Medido na equipe `LEDS - ConectaFapes` em 2026-09-21, pela rota HTTP equivalente: **23**
revisadas com mediana de **0,2 h**, e **79** aguardando com mediana de **46 dias**.

Um campo único teria respondido **`0.2`** — e um agente relataria *"doze minutos"* sobre 102
solicitações das quais 79 esperam há mês e meio.

- omitir as em curso faria a medida **melhorar quanto pior a equipe estivesse**;
- contá-las como zero afirmaria revisão instantânea;
- `median_hours: null` quando nenhuma foi revisada, e `median_days: null` quando nenhuma
  espera. **Nunca zero.**

`truncated: true` diz que a lista foi cortada — e uma mediana sobre 200 de 500 é outra medida
com o mesmo rótulo.

---

## `team_stale_work`

> O que está parado na equipe, e há quanto tempo, segundo o limiar declarado.
>
> **Não responde** de quem é a culpa, nem se a parada é problema: uma tarefa parada pode
> estar esperando decisão de fora.

```json
{
  "state": "checked",
  "value": {
    "stale": 18,
    "open": 23,
    "stale_after_days": 90,
    "items": [ { "issue_id": "…", "title": "…", "open_for_days": 546,
                 "conversation": "silence", "acts": 0 } ]
  },
  "window": null,
  "origin": "derived",
  "rule": { "id": "profile.thresholds", "version": 1 },
  "collected_at": "…"
}
```

**`stale_after_days` viaja junto**: *parada* não é adjetivo, é um corte em dias, e sem ele o
número não diz nada.

**`conversation` separa quatro casos** que uma lista achataria: `not_collected` (o repositório
não teve comentário coletado — **lacuna da coleta**), `silence` (foi coletado, e ninguém
falou), `recent` e `old`. Sem os dois primeiros apartados, lacuna da coleta leria como
silêncio da equipe, e alguém cobraria uma pessoa por uma conversa que a plataforma nunca
olhou.

---

## A recusa, em qualquer das quatro

**Recusa é resposta, nunca exceção e nunca lista vazia** (FR-013).

```json
{ "state": "refused", "value": null, "reason": "fora_do_alcance" }
```

`reason` fica no vocabulário da **regra**, o mesmo que o log usa. Traduzir criaria um segundo
nome para a mesma cláusula, e quem lê o log deixaria de falar a mesma língua de quem lê a
resposta.

**Hoje só existe uma razão de recusa: `fora_do_alcance`.** Corrigido em 2026-09-24. A versão
anterior deste contrato listava também `escopo_de_equipe` e `vinculo_vigente`, e esses são
caminhos de **concessão**. `pode_ver_equipe/3` devolve `{:ok, :admin | :escopo_de_equipe |
:escopo_da_organizacao | :vinculo_vigente}` ou `{:nao, :fora_do_alcance}`, e nada além disso.

**Equipe inexistente também é `fora_do_alcance`.** É a mesma razão do `404` da 061: distinguir
*"não existe"* de *"existe e você não alcança"* deixaria quem chama descobrir, cruzando ids, o
que há no tenant.

**A paridade é tripla e provada por teste** (FR-004): o que a tela recusa, a API recusa e o
MCP recusa, pelo **mesmo veredito e pela mesma razão**. A **forma** da recusa é própria de cada
porta: a tela mostra a recusa, a API responde `404`, e o MCP devolve `state: "refused"`. Três
portas com três vereditos diferentes para o mesmo dado é o mesmo furo contado três vezes.

**A recusa não é leitura.** Ela sai em HTTP `200`, porque é resultado de ferramenta. Por isso
o registro de leitura **não** a grava como acesso concedido, e ela vai para o registro de
recusa. Ver `tasks.md`, T022.

### Uma diferença deliberada em relação à 061

A API responde `404` para fora de alcance, porque ali a resposta é HTTP e um `403`
confirmaria que a equipe existe.

Aqui a recusa é **resposta de ferramenta**, e não erro de protocolo: um agente que recebe
erro de transporte não sabe distinguir *não pode ver* de *o servidor caiu* — e relataria a
segunda.
