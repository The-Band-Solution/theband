# Quickstart — validar a 047 de ponta a ponta

Pré-requisitos: dev server no ar (`set -a && source .env && set +a && mix phx.server`),
banco de dev com seeds.

## 1. A frase vem do catálogo (US1/SC-002)

```bash
# editar a tradução pt de uma recusa em priv/gettext/pt/LC_MESSAGES/errors.po
# (ex.: "Board not found." → msgstr "Quadro não encontrado.")
mix compile   # recompila só o catálogo
```

Com `Gettext.put_locale("pt")` forçado num teste (ou `default_locale: "pt"`
temporário em config), a tela mostra a frase editada — sem tocar código de
aplicação. Esperado: a frase nova aparece; voltar a config restaura.

## 2. O verificador reprova literal plantado (US1/SC-001)

```bash
# plantar num LiveView: put_flash(socket, :error, "mensagem plantada")
mix mensagens.verificar > /tmp/verificador.log 2>&1; echo "EXIT=$?" >> /tmp/verificador.log
```

Esperado: `EXIT=1` e a linha `lib/...:N: put_flash com literal fora do catálogo`.
Remover o plantio; `EXIT=0`. (Forma L60: veredito dentro do log.)

## 3. A recusa única continua única (US1 cenário 3 / SC-004)

```bash
MIX_ENV=test mix test test/the_band_web/live/login_test.exs
```

Esperado: verde, arquivo INALTERADO pela feature (git diff vazio nele).

## 4. Lacunas enumeradas, nunca silenciosas (US3/SC-003)

```bash
mix mensagens.lacunas
```

Esperado: `en`: 0 lacunas (msgid é a própria frase); `pt`: N lacunas, cada msgid
nomeado, por domínio.

## 5. Gates completos

```bash
mix gates > /tmp/gates_047.log 2>&1; echo "EXIT=$?" >> /tmp/gates_047.log
tail -20 /tmp/gates_047.log
```

Esperado: 14 gates verdes (os 13 + `mensagens no catálogo`), `EXIT=0` no log.
