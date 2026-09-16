# Contrato: `GET /api/v1/teams`

A única rota desta fatia. Prova o caminho inteiro — cabeçalho, verificação em tempo
constante, leitura de estado, carimbo de uso, recorte por tenant, serialização.

## Requisição

```
GET /api/v1/teams?page_size=50&after=<cursor>
Authorization: Bearer tb_api_<id_publico>_<segredo>
```

| Parâmetro | Obrigatório? | Padrão | Máximo |
|---|---|---|---|
| `page_size` | não | 50 | 200 (FR-018) |
| `after` | não | — | cursor opaco da página anterior |

**O token só é aceito no cabeçalho `Authorization`.** Em query string, em corpo ou em
cookie: não é lido, e a requisição recebe o `401` uniforme. Query string vaza para log
de servidor e para histórico de navegador.

## Resposta `200`

```json
{
  "data": [
    {
      "id": "480a9d04-42c7-4b30-b52c-006200be323f",
      "name": "Plataforma",
      "slug": "plataforma",
      "origin": "declared",
      "source_system": null,
      "collected_at": null
    },
    {
      "id": "e3cbe87d-4933-487d-9f16-83021650e575",
      "name": "LEDS",
      "slug": "leds",
      "origin": "observed",
      "source_system": "github",
      "collected_at": "2026-09-14T03:11:20Z"
    }
  ],
  "page": {
    "has_next": true,
    "next_cursor": "eyJpZCI6ImUzY2I...",
    "total": null,
    "total_note": "This API does not count collections. An estimated total is worse than an absent one."
  }
}
```

### `origin` — a marca que não se perde na porta

Cada equipe diz se é **observada** na origem ou **declarada** na plataforma. É a
distinção que a plataforma inteira existe para manter, e entregá-la sem a marca a
destruiria exatamente no ponto de entrega — com o agravante de o consumidor previsto
ser um modelo, que afirmaria o dado sem ela.

| `origin` | Significa |
|---|---|
| `observed` | veio de uma ferramenta conectada, e `source_system` diz qual |
| `declared` | foi declarada por uma pessoa nesta plataforma; `source_system` é `null` |

### `total` é `null`, e vem com a razão junto

Q5: a resposta **não traz total**, traz *tem próxima página*, e **diz que não traz**.
Total estimado é pior que total ausente. O campo `total_note` viaja junto para que
quem lê a resposta crua entenda o `null` sem abrir documentação — é a mesma regra da
ausência escrita.

## O recorte

As equipes são as **do tenant do token**, no mesmo recorte que a conta dona vê na
tela — FR-026.

> **Declarado, para ninguém supor o contrário:** a tela `/teams` recorta **por
> tenant** e não filtra por `Access`. Portanto esta rota também não. Não é frouxidão
> da API: é a mesma resposta que a pessoa vê logada. Se a tela passar a filtrar, esta
> rota muda junto, e o teste de contrato apanha a divergência.

## As recusas

| Situação | Resposta |
|---|---|
| sem `Authorization` | `401` — ver [erro.md](./erro.md) |
| token inexistente, revogado ou expirado | `401`, **byte a byte igual** ao acima |
| conta dona desativada ou removida | `401` — o token não sobrevive à conta de quem herda o alcance |
| `POST`, `PUT`, `PATCH`, `DELETE` | `405` |
| equipe de outro tenant em `/api/v1/teams/<id>` | `404` — mas **essa rota é da fatia seguinte** |

## Coleção vazia

`200` com `"data": []`. E a distinção é dita: *nada encontrado* não é o mesmo que
*não coletado*. Um tenant sem equipe nenhuma recebe lista vazia, nunca `404`.

## O efeito colateral aceito

Toda requisição atendida **carimba `last_used_at`**. É escrita numa rota `GET`, e é
deliberada: sem ela a tela não responde *"esta integração ainda é usada?"*, e token
que ninguém sabe se é usado ninguém revoga.

A escrita **não serializa as chamadas** (Q6) — chamadas concorrentes com o mesmo token
são permitidas, e o carimbo é o mais recente.

## O que esta rota NÃO devolve

**Medida nenhuma.** Por isso as ressalvas obrigatórias de FR-022, FR-023 e FR-024
**não aparecem aqui** — elas entram com a primeira rota que devolve medida, junto com
o dado que as exige. Escrevê-las agora seria desenho sem o problema.
