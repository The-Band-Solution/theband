# Contrato — a idade da credencial (064/T017 e T019, FR-016, FR-018, FR-019)

**Escrito em 2026-10-03, antes do código.** Acrescenta um módulo público,
`TheBand.Credenciais.Idade`, e duas colunas em `ai_provider_credentials`. A tela que pede a troca
(T018, FR-017) **não** está aqui: ela espera protótipo aprovado.

## O problema, medido

As duas credenciais de terceiro — `tool_credentials` e `ai_provider_credentials` — têm
`validated_at`, e **nenhuma** tem a data em que o segredo atual passou a valer:

| credencial | o que acontece hoje na troca | o que se perde |
|---|---|---|
| de ferramenta (`Sources`) | a troca é **outra linha**: `add_credential/3` cria a nova, e a antiga é desativada ou destruída. Nenhum caminho reescreve o `secret` de uma linha existente | nada — cada linha tem o próprio `validated_at`, que é a data em que **aquele** segredo foi gravado |
| de provedor de modelos (`AI.put/3`) | `insert_or_update` **sobre a mesma linha**, e `validated_at` vira `agora` | a data em que o segredo anterior passou a valer; e, quando a pessoa grava **a mesma chave** de novo (para trocar o modelo, por exemplo), a contagem zera sem que segredo nenhum tenha sido trocado |

O segundo caso é o defeito que a FR-018 descreve: sem a data da troca, a cobrança não sabe se a
anterior foi atendida — e regravar a mesma chave a faz achar que foi.

## A API

```elixir
defmodule TheBand.Credenciais.Idade do
  @type estado :: :no_prazo | :vencida | :idade_desconhecida
  @type credencial :: TheBand.Sources.ToolCredential.t() | TheBand.AI.ProviderCredential.t()

  @spec estado(credencial(), DateTime.t()) :: estado()
  @spec em_uso_desde(credencial()) :: DateTime.t() | nil
  @spec limite_em_meses() :: pos_integer()
end
```

### `em_uso_desde/1` — desde quando o segredo atual vale

| credencial | resposta |
|---|---|
| `%ToolCredential{validated_at: v}` | `v` — a linha nunca troca de segredo, então a validação é o início |
| `%ProviderCredential{secret_set_at: s}` com `s` preenchido | `s` |
| `%ProviderCredential{secret_set_at: nil, validated_at: v}` | `v` — linha anterior a esta migração; até a primeira troca, a validação é a melhor data que existe, e é a data em que aquela chave foi gravada |
| sem nenhuma das duas | `nil` |

### `estado/2` — a classificação

| `em_uso_desde/1` | `estado/2` |
|---|---|
| `nil` | `:idade_desconhecida` — **nunca** `:no_prazo`: ausência de data não é prova de juventude (FR-019) |
| `desde`, e `agora` passou de `desde + 3 meses` | `:vencida` |
| `desde`, e `agora` não passou de `desde + 3 meses` | `:no_prazo` |

Três meses são meses de **calendário** (`DateTime.shift/2`), e não 90 dias: "registrada em 4 de
setembro" vence em 4 de dezembro, que é o que a pessoa lê na tela. "Passar de" é estrito: no
instante exato do limite, ainda está no prazo.

Uma data **no futuro** (relógio adiantado de quem gravou) dá `:no_prazo`. Não é ausência — a data
existe —, e tratá-la como vencida pediria troca de um segredo gravado agora.

`agora` é argumento, e não leitura do relógio dentro da função: a regra é pura, e a tela e o
teste passam o mesmo instante.

### `limite_em_meses/0`

O prazo, **num lugar só** (Feita quando da T017). A tela que disser "pedimos a troca a cada três
meses" lê daqui.

## O que muda em `AI.put/3` (T019)

Duas colunas em `ai_provider_credentials`, ambas `utc_datetime`, anuláveis:

| coluna | o que é |
|---|---|
| `secret_set_at` | quando o segredo **atual** foi gravado. Zera a contagem |
| `previous_secret_set_at` | o `em_uso_desde/1` do segredo **substituído**, gravado no momento da troca. É "a data anterior não é perdida" da T019 |

| situação em `put/3` | `secret_set_at` | `previous_secret_set_at` |
|---|---|---|
| primeira gravação do tenant | `agora` | `nil` — não houve anterior |
| chave **diferente** da gravada | `agora` | `em_uso_desde/1` da credencial antes da troca |
| a **mesma** chave, de novo | `em_uso_desde/1` de antes da gravação — o mesmo valor, se já preenchido; o `validated_at` **anterior**, se nulo | inalterado |

**Emendado em 2026-10-03, achado do Design ao desenhar a T018.** A primeira versão dizia
"inalterado" na mesma chave. Numa linha anterior à migração (`secret_set_at` nulo), `put/3`
reescreve `validated_at` com `agora`, `em_uso_desde/1` cai nele, e a idade voltava a zero sem
troca — o que a FR-018 proíbe. Fixar `secret_set_at` no início que valia antes da gravação fecha
o caso. Resta um canto declarado: linha com **as duas** datas nulas, regravada com a mesma chave,
passa a contar da regravação — `put/3` sempre grava `validated_at`, e nenhuma linha assim existe
por esse caminho.

A comparação entre a chave gravada e a nova é feita em memória, com `Plug.Crypto.secure_compare/2`,
dentro de `AI`; nenhuma das duas sai do módulo, e o resultado não é registrado em lugar nenhum.

**Emendado em 2026-10-03 pela avaliação de segurança**
([seguranca-idade-da-credencial.md](../seguranca-idade-da-credencial.md)), antes do código:

- **achado 1**: a primeira gravação não compara nada — a linha vazia tem `secret: nil`, e
  `secure_compare/2` com `nil` levantaria `FunctionClauseError` com a chave nova nos argumentos.
  Uma cláusula própria para a linha nova, e a comparação só entre dois binários;
- **achado 2**: as duas datas **não** entram no `cast` de `ProviderCredential.changeset/2`. São
  calculadas em `put/3` e postas por `Ecto.Changeset.change/2`; vindas de quem chama, uma data
  recente forjada esconderia uma credencial vencida;
- **a ordem verificar → comparar** é mantida: comparar antes de o provedor aceitar faria `put/3`
  responder, para uma chave inválida, se ela é a gravada.

`validated_at` continua sendo **quando a origem confirmou a chave** — e é atualizado em toda
gravação, como hoje. Ele deixa de ser a fonte da idade assim que `secret_set_at` existe.

**Linhas existentes não são preenchidas pela migração.** O `nil` em `secret_set_at` cai, em
`em_uso_desde/1`, no `validated_at`, que é a data em que aquela chave foi gravada — preencher
copiaria o mesmo valor e esconderia que a data é inferida.

## Quem pôs a chave, e o rastro de cada ato (#1221)

**Emendado em 2026-10-05, antes do código.** Esta seção fecha o R1 de
[seguranca-c1-mesma-chave.md](../seguranca-c1-mesma-chave.md) e cumpre as nove condições do
parecer [docs/seguranca/2026-10-05-1221-troca-da-chave-do-modelo.md](../../../docs/seguranca/2026-10-05-1221-troca-da-chave-do-modelo.md).
Até aqui, `put/3` sobrescrevia `declared_by_user_id` a cada gravação, mesmo quando a chave era a
mesma, e nem `put/3` nem `delete` deixavam evento. Depois de um incidente, não havia como saber
quem trocou nem quem removeu a chave do tenant.

### A classificação é uma só

`put/3` classifica o ato **uma vez**, depois de `verify/2` aceitar. Essa classificação decide as
datas da tabela acima, o declarante e o evento (condição 7):

| ato | quando | `declared_by_user_id` | evento |
|---|---|---|---|
| `:primeira` | o tenant não tem linha deste provedor | o ator (`nil` se o ator não vier) | `tipo=:primeira` |
| `:troca` | `mesma_chave?/2` é falso | o ator | `tipo=:troca` |
| `:mesma_chave` | `mesma_chave?/2` (`secure_compare`) é verdadeiro | **o anterior, mantido** | `tipo=:mesma_chave`, com o ator que regravou |

O declarante sai do `cast` e é posto por `Ecto.Changeset.change/2`, como as datas. É `change/2`,
**nunca** `force_change/3`. Na mesma chave, o valor é igual ao do registro lido, e o Ecto descarta
a mudança. Por isso, sob concorrência, uma `:mesma_chave` obsoleta não regrava o declarante
antigo por cima de uma troca recém-commitada (condição 9, S4).

### A remoção recebe o ator

```elixir
@spec delete(Tenant.t(), Ecto.UUID.t() | nil, String.t()) :: :ok | {:error, :not_found}
def delete(tenant, actor_user_id \\ nil, provider \\ "openai")
```

**A assinatura muda.** Antes era `delete(tenant, provider \\ "openai")`. Os dois chamadores,
`AILive.Index` e `test/the_band/ai_test.exs`, passam só o tenant, e nenhum passa o provedor. A
tela passa a mandar `current_user.id`. Sem linha a remover, `delete` devolve
`{:error, :not_found}` e **não** emite evento, porque nada foi removido (condição 1, S1).

### O evento

```elixir
@spec TheBand.Tenants.AccessEvents.chave_do_modelo(
        :primeira | :troca | :mesma_chave | :removida,
        Ecto.UUID.t(),
        Ecto.UUID.t() | nil
      ) :: :ok
```

A linha sai em `:warning`, pela mesma via de `conta_da_organizacao/5`:

```text
acesso: ato administrativo · ato=:chave_do_modelo tipo=:troca tenant_id="…" actor_user_id="…"
```

- **Guardas fechadas, sem `extra`** (condição 2, S2): `tipo` precisa estar na lista dos quatro
  átomos, `tenant_id` é binário e `actor_user_id` é binário ou `nil`. Qualquer outra forma levanta
  `FunctionClauseError`.
- **Só depois do commit** (condição 4): a linha sai quando `insert_or_update` devolve `{:ok, _}`
  ou quando `Repo.delete` conclui. Recusa do provedor, modelo desconhecido e erro de changeset não
  emitem.
- **Ator nulo não suprime a linha** (condição 8): ela sai com `actor_user_id=nil`.
- **O `tenant_id` é o do tenant que agiu**, e a classificação só lê a linha dele (condição 6).

### O que o evento não carrega, e por quê

| ausência | por quê |
|---|---|
| a chave, qualquer trecho dela, hash, prefixo ou `last_four` | a assinatura não aceita, só átomo e ids (condição 5). `last_four` aparece na tela, mas no log seria parte do segredo copiada para um lugar que quem opera `/ai` não controla |
| o modelo escolhido | não é segredo, mas ninguém pediu. Se for preciso, é a R-c do parecer, em issue própria |
| o motivo da recusa do provedor | a recusa não emite evento nesta correção. É a R-b do parecer, em issue própria, e a string do provedor nunca entra |

### Como se prova

Os casos ficam em `test/the_band/ai_test.exs`, com `capture_log` no nível padrão do teste
(`:warning`). Cada um é visto reprovando com o defeito injetado:

1. as três classificações e o declarante de cada uma. Defeitos a injetar: tirar a chamada do
   evento; devolver o declarante ao `cast`, para que seja sobrescrito na mesma chave;
2. a remoção emite com o ator, e a remoção sem linha não emite. Defeito: tirar a chamada em
   `delete`;
3. a recusa do provedor e o erro de changeset não emitem. Defeito: emitir antes do
   `insert_or_update`;
4. em `:debug`, nenhuma parte do segredo aparece na linha nem no log. A chave de teste termina fora
   do hexadecimal. Defeito: `last_four` nos campos do evento;
5. com dois tenants, o evento de A não cita B, e a linha de B não muda;
6. a mesma classificação decide as datas e o evento;
7. com ator nulo, a linha sai com `actor_user_id=nil`;
8. as guardas de `AccessEvents.chave_do_modelo/3` recusam átomo fora da lista, string e struct.

## O que não muda

- **A coleta.** Nenhum caminho de coleta, nem de geração, consulta `estado/2`. Credencial vencida
  continua funcionando (FR-016: pedir, e não impedir). Expirar transformaria a política em queda
  de serviço num dia que ninguém escolheu.
- **A credencial de ferramenta.** Não ganha coluna: a troca dela já é uma linha nova, com
  `validated_at` novo — a data da troca fica registrada (FR-018). A antiga continua com a data
  dela enquanto existir, **desativada**. Se quem administra a **remove**, a data vai junto com o
  segredo: remover é apagar a credencial por decisão explícita (feature 001), e guardar a data de
  um segredo que não existe mais não serve à cobrança, que olha só as credenciais vigentes. Não
  viola a FR-018, que pede a data **da troca**, e não o histórico das anteriores.
- **O segredo.** Nada aqui lê, imprime ou compara o segredo fora de `AI.put/3`.
- **A chave do ambiente (`API_KEY`).** Fica **fora** de `Idade`: ela é do processo, não tem
  linha nem data, e a plataforma não sabe quando foi posta. A tela da T018, quando existir, a
  mostra como **idade desconhecida** — nunca como no prazo (achado 3 da avaliação).

## O que a API não expõe, e por quê

- **Nenhum `vencida?/1` booleano.** Booleano junta `:idade_desconhecida` com `:no_prazo` — é
  exatamente o erro que a FR-019 proíbe.
- **Nenhum "dias restantes" em número.** Sem data, o número seria `0` ou `nil` na mão de quem
  formata a tela, e `0` é o fallback silencioso que a casa recusa. Quem quer a duração calcula a
  partir de `em_uso_desde/1`, e o `nil` o obriga a tratar a ausência.
- **Nenhuma consulta "credenciais vencidas do tenant".** Não há consumidor; nasce com a tela que
  precisar dela (T018).

## Como se prova

`test/the_band/credenciais/idade_test.exs`:

1. data de 4 meses atrás → `:vencida`; de ontem → `:no_prazo`; para os dois tipos de credencial;
2. **`nil` → `:idade_desconhecida`, e o teste afirma `!= :no_prazo`**. Defeito a injetar: a
   cláusula do `nil` devolvendo `:no_prazo` — o teste reprova;
3. T019: credencial de modelo com `validated_at` de 4 meses → `:vencida`; `AI.put/3` com chave
   diferente → `:no_prazo`, `secret_set_at` gravado e `previous_secret_set_at` igual à data
   antiga. Com a **mesma** chave, continua `:vencida`. Defeito a injetar: `put/3` sem gravar
   `secret_set_at` na troca — o teste reprova;
4. achados 1 e 2: a primeira gravação passa sem comparar (defeito: sem a cláusula da linha nova e
   sem a guarda de binário — `FunctionClauseError`); o changeset não aceita as datas (defeito:
   as duas no `cast` — o teste reprova).
