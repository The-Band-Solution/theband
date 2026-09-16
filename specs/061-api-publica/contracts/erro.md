# Contrato: o formato único de erro

FR-020 — **um** formato para todos os códigos. O cliente escreve um tratador, não seis.

```json
{
  "error": {
    "code": "unauthorized",
    "message": "The credential presented is not usable.",
    "request_id": "F9wq-8Kx2mN"
  }
}
```

| Campo | Sempre presente? | Para quê |
|---|---|---|
| `code` | sim | string estável, em inglês, para o cliente ramificar sem ler prosa |
| `message` | sim | frase para quem depura. **Nunca** diz qual das causas ocorreu |
| `request_id` | sim | é por ele que quem opera acha o motivo real no log interno (SC-004) |

## Os códigos desta fatia

| HTTP | `code` | Quando |
|---|---|---|
| `401` | `unauthorized` | cabeçalho ausente, malformado, token inexistente, revogado ou expirado |
| `404` | `not_found` | recurso que **não existe para este token** — inclusive recurso de outro tenant (FR-030, SC-014) |
| `405` | `method_not_allowed` | qualquer método além de `GET` e `HEAD` (SC-006) |
| `500` | `internal_error` | falha não prevista. `message` genérica, `request_id` é o que resolve |

## A recusa uniforme, e por que ela é byte a byte

**Token inexistente, revogado e expirado produzem a mesma resposta** — FR-016. SC-003
verifica comparando as três, e a única diferença admitida é `request_id`.

O motivo de não distinguir: `401 "token revoked"` confirma a quem testa credencial
roubada que ela **existiu**, e `401 "token expired"` confirma que existiu e quando.
As duas são resposta útil a quem varre.

**O motivo real vai para o log interno**, recuperável pelo `request_id`. Calar para o
cliente não é calar para quem opera — é o princípio XI.

## `404` e não `403` para recurso de outro tenant

FR-030. `403` afirma *"isto existe e você não pode"*, e essa afirmação é vazamento de
existência: cruzando identificadores, quem chama descobre o que há no outro tenant sem
nunca receber um byte de conteúdo.

## Nenhum corpo em `HEAD`

`HEAD` responde os mesmos cabeçalhos de `GET` e corpo vazio, como manda o HTTP.
