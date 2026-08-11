# Data Model — editar e remover ferramentas conectadas

**Feature**: 003 · **Base**: [ADR 0004](../../docs/adr/0004-modelo-de-informacao-one-table-per-kind.md) · **Research**: [research.md](research.md)

Nenhum conceito de ontologia entra ou muda. `connected_tools` e `tool_credentials` são
infraestrutura da plataforma, não conceitos de EO — verificado: não aparecem em
`priv/knowledge_base/`. Por isso este modelo **não** é derivado do derivador, e dizê-lo
explicitamente evita a confusão que a feature 002 pagou para desfazer.

## O que entra

### `tool_observation_events` — nova, append-only

Registra o que **ocorreu** com a observação de uma ferramenta. O estado atual não mora
aqui: é derivado do último evento (ADR 0004 D7).

| Coluna | Tipo | Nulo | Por que existe |
|---|---|---|---|
| `id` | uuid | não | |
| `tenant_id` | uuid | não | escopo explícito, como em toda tabela |
| `connected_tool_id` | uuid | não | de qual ferramenta |
| `event` | string | não | `ended` ou `resumed` |
| `occurred_at` | timestamp | não | quando |
| `actor_user_id` | uuid | **sim** | quem — FR-009. Anulável porque uma retomada pode vir de um processo, e inventar um autor seria pior que declarar que não há |
| `reason` | text | sim | o que a pessoa escreveu, quando escreveu |
| `impact` | jsonb | sim | quantos registros foram marcados, gravado no instante do encerramento |
| `inserted_at` | timestamp | não | |

**Sem `updated_at`, de propósito.** Evento não é atualizado: se um encerramento foi
registrado errado, a correção é um evento novo. Ter a coluna convidaria a reescrever o
passado, que é o que a D7 proíbe.

**`impact` guarda o que foi contado no momento**, e não o que uma consulta de hoje
devolveria. As duas coisas divergem com o tempo — uma coleta posterior muda os números
—, e o que interessa no registro é o que a pessoa viu antes de confirmar.

**Índice**: `(tenant_id, connected_tool_id, occurred_at desc)` — a derivação do estado
sempre pede o último evento de uma ferramenta.

**Sem restrição de alternância.** Dois `ended` seguidos não são proibidos pelo banco: o
encerramento é idempotente, e uma segunda tentativa registra que alguém tentou. Proibir
faria a segunda tentativa falhar com erro de integridade em vez de ser reconhecida como
não-operação.

## O que muda

### `connected_tools` — nada na identidade, nada de estado novo

**Nenhuma coluna é acrescentada.** Isso é decisão, não omissão: o estado de observação é
situação derivada dos eventos, e materializá-lo criaria o terceiro lugar para discordar
que a D7 nomeia.

`tool_type`, `instance_url` e `organization_login` permanecem **imutáveis** — são a
identidade, e o índice de unicidade é sobre elas com `NULLS NOT DISTINCT`. FR-019
proíbe alterá-las, e a proibição vive no changeset: campos que não entram no `cast` não
podem ser alterados por caminho nenhum.

`status` continua como está — `active` / `needs_attention` —, com a dívida declarada no
plano. Esta feature não a amplia.

### `tool_credentials` — passa a ser removível

`label` passa a ser editável isoladamente. O segredo, os escopos e `validated_at` não —
renomear não revalida, e permitir alterá-los pelo mesmo caminho faria um rótulo trocado
parecer uma revalidação.

**Remover apaga a linha.** Não há coluna de descarte: um segredo descartado que continua
na base é um segredo que pode vazar. `syncs.credential_id` é `ON DELETE SET NULL`, então
o histórico de coletas sobrevive perdendo apenas qual credencial usou — perda declarada
em R3.

### `eo_teams`, `eo_people`, `eo_team_membership_evidence` — nenhuma coluna nova

A marca de não mais observado já existe nas três. O encerramento passa a ser a **segunda
causa** de aplicá-la, e a causa fica declarada na base de conhecimento, não numa coluna.

**Por que não uma coluna de causa.** Foi considerada: `no_longer_observed_reason`. Duas
razões contra. A informação já é derivável — um registro marcado cuja ferramenta tem
evento `ended` posterior à última coleta foi marcado por decisão; os demais, por
ausência. E acrescentar a coluna em três tabelas para responder o que a corrente já
responde criaria três lugares para discordarem.

## Quem é marcado, exatamente

É o núcleo da feature, e a primeira versão da spec errava aqui. A regra, por tipo de
registro:

| Registro | Marcado quando |
|---|---|
| **equipe** | pertence à organização encerrada. Direto: `organization_id` responde |
| **equipe derivada** | idem, e nunca apagada — ela existiu (FR-010) |
| **vínculo de evidência** | aponta para equipe da organização encerrada |
| **pessoa** | **todos** os vínculos dela apontam para organizações não observadas |

**A pessoa é o caso difícil**, e a razão está em R2: ela tem uma linha e uma
proveniência, e `source_instance` é o mesmo `https://github.com` para as três
organizações. Não existe "a pessoa daquela ferramenta". Existe o vínculo.

Com os números de hoje, encerrar `ifesserra-lab`:

```text
equipes marcadas         1   (a derivada da organização)
vínculos marcados        5
pessoas marcadas         4   as exclusivas
pessoas mantidas         1   Paulo — está em The-Band-Solution e leds-conectafapes
credenciais destruídas   as da ferramenta
payloads apagados        0
```

## Estado derivado

```text
observação de uma ferramenta =
  último evento é `ended`  → encerrada
  último evento é `resumed` → vigente
  nenhum evento            → vigente
```

"Nenhum evento é vigente" é o que faz as três ferramentas atuais continuarem observadas
sem migração de dado — o estado ausente significa "nunca foi encerrada", que é a verdade.

**A derivação existe num lugar só.** A tela e o filtro de coleta usam o mesmo caminho, e
é o que o risco do plano nomeia: dois caminhos discordariam, e a plataforma passaria a
coletar do que a tela mostra como encerrado.
