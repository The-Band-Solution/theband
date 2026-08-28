# Contrato — Catálogo de mensagens e verificador

Escrito ANTES da primeira função pública (constituição VI). Se a implementação
mostrar que o contrato errou, o contrato é corrigido no mesmo commit, com a razão.

## O catálogo

### Domínios

| Domínio | O que carrega | Arquivo |
|---|---|---|
| `errors` | recusas, falhas, validações — o que responde a algo que deu errado | `priv/gettext/<locale>/LC_MESSAGES/errors.po` |
| `sistema` | confirmações, avisos, estados de operação — o que responde a algo que deu certo ou está em curso | `priv/gettext/<locale>/LC_MESSAGES/sistema.po` |

Texto de tela estática (títulos, rótulos de seção, legendas de gráfico) NÃO entra
nestes domínios neste sprint — está nas pendências por tela (research R7).

### Regras do msgid

1. **msgid = a frase que a tela mostra**, na língua em que está hoje (research R2).
   Nunca chave abstrata (`auth.invalid`), nunca frase "normalizada" que mude um
   byte do que a tela mostrava — mudança de texto é decisão separada da migração.
2. **Interpolação por placeholder nomeado**: `gettext("Renamed to %{nome}.", nome: x)`.
   Concatenação e `#{}` dentro do msgid são proibidos — o verificador reprova.
3. **Decisão de vocabulário migra junto** (FR-007): comentário `#. ` (extracted
   comment, via `# comentário` no `.po` e comentário no ponto de extração) com a
   razão registrada. Ex.: `#. "Checks", nunca "CI" — decisão da feature 044`.
4. **Mensagens de segurança da 045**: o texto é o exato de hoje. A recusa única
   vem de UM ponto (`mensagem_unica/0` no session_controller); o teste
   byte-idêntico (`login_test.exs`) não muda (FR-004).

### API de uso (código de aplicação)

```elixir
use Gettext, backend: TheBandWeb.Gettext   # nos módulos web (já vem via TheBandWeb)

dgettext("errors", "Board not found.")
dgettext("sistema", "Sync started.")
dgettext("sistema", "Renamed to %{nome}. The code is unchanged.", nome: papel.name)
```

- Módulos de domínio (`lib/the_band/**`) NÃO chamam gettext: devolvem átomos ou
  tuplas de motivo (`{:error, :sem_chave}`, `{:below_floor, %{...}}`), e a camada
  web traduz o motivo em frase. Isso já é o padrão da casa (`recusa/1` na página
  da pessoa) e vira regra: **mensagem é responsabilidade da borda**.

### Configuração

```elixir
# config/config.exs
config :gettext, :default_locale, "en"
config :the_band, TheBandWeb.Gettext, allowed_locales: ["en", "pt"]
```

Trocar o idioma padrão da plataforma = trocar a linha do `:gettext` (FR-005).
[Corrigido em 2026-08-28, na implementação: o contrato original punha
`default_locale` na config do backend — que é COMPILE-TIME (o teste de idioma
reprovou com ela e passou com a do app `:gettext`, a única lida em runtime).
Erro de contrato corrigido no mesmo commit, com esta razão.] Lacuna no idioma
ativo cai no msgid — texto legível por construção, nunca chave crua.

## O verificador — `mix mensagens.verificar`

### Veredito

- **Passa** (exit 0): nenhum ralo de mensagem com literal fora de gettext.
- **Reprova** (exit 1): imprime uma linha por achado — `lib/...ex:LINHA: put_flash
  com literal fora do catálogo` — e o total no fim.

### O que é ralo de mensagem (v1)

1. `put_flash(conn_ou_socket, :error | :info, ARG)` — em qualquer módulo de
   `lib/the_band_web/`.
2. `ARG` reprovado quando: string literal; interpolação (`"... #{x} ..."`);
   concatenação (`<>`) contendo literal.
3. `ARG` aprovado quando: chamada `gettext/dgettext/ngettext/dngettext`; variável
   ou chamada de função (a frase nasceu noutro lugar — o verificador segue ralos,
   não fluxo de dados; a função de origem é auditável por leitura).

### O que NÃO é (fronteira declarada)

Texto em HEEx (`~H`), `@doc`, log (`Logger.*`), mensagem de exceção (`raise`,
`ArgumentError`), `IO.puts` de mix task. A definição pertence ao verificador
(Key Entities da spec) e amplia por sprint — nunca por regex larga.

### Integração no gate

Entrada em `@gates` de `lib/mix/tasks/gates.ex`, após `credo`:

```elixir
{"mensagens no catálogo", {:mix, ["mensagens.verificar"]}},
```

## O relatório de lacunas — `mix mensagens.lacunas`

- Lê `priv/gettext/*/LC_MESSAGES/*.po`; lista, por idioma e domínio, os msgids com
  `msgstr ""` (não traduzidos). Exit 0 sempre — relatório, não gate (FR-006:
  enumerável, nunca silencioso; a spec não exige pt completo).
- Saída: `pt/errors: 12 lacunas`, seguido das chaves, uma por linha.

## Testes que provam o contrato

| Invariante | Teste |
|---|---|
| Verificador reprova literal plantado | `test/mix/tasks/mensagens_verificar_test.exs` — fixture com `put_flash(:error, "x")` reprova com arquivo:linha |
| Verificador aprova gettext e variável | mesmo arquivo — os dois casos passam |
| Recusa única byte-idêntica sobrevive | `test/the_band_web/live/login_test.exs` — INALTERADO (SC-004) |
| Editar .po muda a tela | teste de tela com `Gettext.put_locale` + msgstr de fixture |
| Lacunas enumeradas | `test/mix/tasks/mensagens_lacunas_test.exs` — .po de fixture com 1 lacuna aparece nomeada |
