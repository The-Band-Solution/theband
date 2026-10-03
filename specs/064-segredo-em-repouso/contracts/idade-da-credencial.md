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
| a **mesma** chave, de novo | inalterado | inalterado |

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

## O que não muda

- **A coleta.** Nenhum caminho de coleta, nem de geração, consulta `estado/2`. Credencial vencida
  continua funcionando (FR-016: pedir, e não impedir). Expirar transformaria a política em queda
  de serviço num dia que ninguém escolheu.
- **A credencial de ferramenta.** Não ganha coluna: a troca dela já é uma linha nova, com
  `validated_at` novo, e a antiga continua com a data dela.
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
