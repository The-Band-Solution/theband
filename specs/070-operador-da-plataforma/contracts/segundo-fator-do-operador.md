# Contrato — `TheBand.Platform.SegundoFator`

FR-016, O16, A16. Decisão da pessoa mantenedora em 2026-10-01: **TOTP nesta feature**
([seguranca-autenticacao.md](../seguranca-autenticacao.md), "Decisões"). Desenho em
[research.md](../research.md) R13; colunas em [data-model.md](../data-model.md) §1 e §1a.

> **Biblioteca decidida pela T009 (2026-10-01): `{:nimble_totp, "== 1.0.0"}`**, com a justificativa
> no `plan.md` ("Technical Context") e a comparação em research R13 (AGENTS.md §3). Emendado por
> T011 com essa escolha. A avaliação de segurança própria do TOTP (T010, `seguranca-totp.md`) foi
> feita por quem não escreveu este desenho; as emendas dela estão aplicadas aqui (T2 em T010; T6 e
> T8 em T011, 2026-10-01).

Depende de: nenhuma ontologia. **Funções puras**: nenhuma lê nem grava o banco. Quem grava é
`Credentials`, dentro da transação com `FOR UPDATE` (efeito na borda, decisão no núcleo, AGENTS.md
§7.7).

## Parâmetros fixos, cada um com a razão

| parâmetro | valor | razão |
|---|---|---|
| algoritmo | HMAC-SHA1 | é o que os aplicativos autenticadores aceitam sem configuração; RFC 6238 §1.2 |
| passo | 30 s | idem |
| dígitos | 6 | idem |
| janela | **±1 passo** | tolera relógio de celular atrasado sem abrir mais que 90 s |
| segredo | 20 bytes de `:crypto.strong_rand_bytes/1` | RFC 4226 §4, R6: 160 bits |
| códigos de recuperação | 10, cada um com **16 bytes** aleatórios em base32 sem padding (**26 caracteres**, com hífen a cada 4 para leitura) | **128 bits** cada; uso único. ASVS V2.6.2 pede ≥112 bits para dispensar o sal (seguranca-totp.md, T2; eram 80 bits) |

## `gerar_segredo() :: TheBand.Segredo.t()`

## `uri(segredo :: TheBand.Segredo.t(), email :: String.t()) :: TheBand.Segredo.t()`

`otpauth://totp/The%20Band%20Platform:<email>?secret=<base32>&issuer=The%20Band%20Platform`. Volta
como `Segredo.t()` porque carrega o segredo.

Montada com `NimbleTOTP.otpauth_uri/3`.

**Sem QR code nesta feature — decidido pela pessoa mantenedora em 2026-10-01**, opção (a) do
protótipo T012 (`prototipo/README.md`), como a T009 recomendou. A tela mostra o segredo em base32
para digitar no aplicativo, e a URI `otpauth://` em texto, para copiar. NimbleTOTP não gera QR, e um
QR exigiria uma segunda dependência (research R13), ou um serviço externo que receberia o segredo.
Não há `qr_svg/1`; um QR no futuro é feature com dependência justificada no `plan.md` e avaliação
de segurança própria.

## `conferir(segredo :: TheBand.Segredo.t(), codigo :: TheBand.Segredo.t(), ultimo_passo :: non_neg_integer() | nil, agora :: DateTime.t()) :: {:ok, passo :: non_neg_integer()} | {:error, :codigo_errado | :reusado}`

- **a janela ±1 é do chamador**: `NimbleTOTP.valid?/3` confere um instante só, então `conferir/4`
  faz **três chamadas**, com `time:` em `agora - 30`, `agora` e `agora + 30`, e devolve o passo
  (`div(t, 30)`) da chamada que aceitou;
- **a comparação em tempo constante é a de `NimbleTOTP.valid?/3`** (`bxor` dígito a dígito, research
  R13). Este módulo não compara código nenhum por conta própria, e não usa
  `Plug.Crypto.secure_compare/2`;
- **contra reuso**: um código cujo passo seja `<= ultimo_passo` devolve `{:error, :reusado}`, mesmo
  correto. As três chamadas levam `since: ultimo_passo * 30` (`since` é um **instante**, e não um
  passo; com `ultimo_passo` nulo, sem `since`). Como `valid?/3` devolve só `false` nos dois casos,
  `:reusado` e `:codigo_errado` se distinguem refazendo as três chamadas sem `since`: aceito sem
  ele e recusado com ele é `:reusado`. Para fora, `Credentials` dá aos dois a mesma recusa única.
  Quem grava o passo aceito é `Credentials`, na mesma transação com `FOR UPDATE` na linha do
  operador; sem o lock, dois envios paralelos do mesmo código passariam os dois;
- `valid?/3` só casa binário de 6 bytes: o código chega já normalizado por `classificar/1`;
- `agora` é argumento, e não `DateTime.utc_now/0` por dentro, para o teste fixar o relógio sem
  depender da hora (lição L46).

## `classificar(texto :: TheBand.Segredo.t()) :: :totp | :recuperacao | :malformado`

Seis dígitos, com espaços retirados, são `:totp`. Vinte e seis caracteres base32, com hífens
retirados e minúsculas, são `:recuperacao` (T2). O resto é `:malformado`, que `Credentials` recusa com a
recusa única e o custo do hash.

**Só ASCII, e conferido antes de normalizar (seguranca-totp.md, T6).** A forma é decidida por
`~r/\A[0-9]{6}\z/` e `~r/\A[A-Za-z2-7]{26}\z/`, **sem** a flag `u` e **sem** `\d`: com `u`, `\d`
aceita dígitos não ASCII (`"١٢٣٤٥٦"`), que `valid?/3` recusaria mas que contariam como
`:segundo_fator_errado` no limite de T1 em vez de `:malformado`. `\z`, e não `$`, que casa antes de
um `\n` final. A retirada é só de espaço e hífen ASCII (`" "` e `"-"`), e a minúscula é
`String.downcase(texto, :ascii)` **depois** da conferência: o `downcase` Unicode leva o sinal de
Kelvin (`U+212A`) a `"k"`, e um código fora do alfabeto viraria um código do alfabeto.

## `gerar_codigos_de_recuperacao() :: [TheBand.Segredo.t()]`

## `resumo(codigo :: TheBand.Segredo.t()) :: binary()`

`sha256` do código **normalizado** (sem hífen, minúsculo). É o que vai para
`platform_operator_recovery_codes.code_hash`. SHA-256 sem sal, e não Bcrypt, porque são **128 bits**
aleatórios: ASVS V2.6.2 dispensa o sal a partir de 112 bits (seguranca-totp.md, T2). Com 80 bits,
como estava, o sal por código seria obrigatório.

## O consumo do código de recuperação (em `Credentials`, e não aqui)

`UPDATE platform_operator_recovery_codes SET used_at = now() WHERE operator_id = $1 AND
code_hash = $2 AND used_at IS NULL AND invalidated_at IS NULL RETURNING id`, conferindo **uma**
linha. `used_at` é **só** uso; a nova definição, o reinício e a nova concessão marcam
`invalidated_at` nos vigentes (`data-model.md` §1a; seguranca-totp.md, T8). Dois envios paralelos
do mesmo código: exatamente um passa. O consumo acontece **só depois** de a senha conferir e de a
concessão vigente ser confirmada; senha errada com código válido não o gasta (seguranca-totp.md, C12).
Código errado ou já usado, com a senha certa, sobe `second_factor_failures` (T1). O uso gera `AccessEvents.operador_recuperacao_usada/2`, com
quantos restam, em `:warning`.

## O fluxo de cadastro (emenda T012, 2026-10-01)

Decisão da pessoa mantenedora sobre o protótipo (`prototipo/README.md`, Q3 (b), contra a
recomendação do Design): o cadastro só se conclui **depois** de o operador confirmar que guardou os
códigos de recuperação, com uma caixa e um `POST` a mais (`POST /platform/setup/recovery-codes`,
`rotas-da-plataforma.md`). São três passos, e não dois:

| passo | função em `Credentials` | o que grava | a entrada vale? |
|---|---|---|---|
| 1. senha | `definir_senha/3` | senha; segredo TOTP pendente; código de cadastro | não |
| 2. código TOTP | `confirmar_segundo_fator/3` | `totp_last_used_step`; o `sha256` dos dez códigos; **código de guarda** (novo); anula o código de cadastro | **não** |
| 3. guarda dos códigos | `concluir_cadastro/2` (nova) | `totp_confirmed_at`; sobe `password_epoch`; encerra as sessões do operador; anula o código de guarda | **sim**, a partir daqui |

**A escolha: o segundo fator e os códigos de recuperação passam a valer só no passo 3.** O passo 2
prova que o aplicativo tem o segredo, mas não habilita nada: `totp_confirmed_at` continua nulo, e
`autenticar/3` já recusa com `totp_confirmed_at IS NULL` (`:sem_segundo_fator`), o que recusa
também os códigos de recuperação, sem coluna nova para eles.

**A razão.** Se o segundo fator valesse no passo 2, a confirmação da guarda não decidiria nada: o
operador que fechasse a aba entraria do mesmo jeito, e a caixa seria cerimônia. Valendo só no passo
3, **código de recuperação mostrado e não confirmado nunca vira credencial**: se a aba fechou com os
códigos na tela, o caminho é o comando de reinício, que gera dez novos e invalida os anteriores. O
preço é o mesmo já aceito entre os passos 1 e 2 (`credenciais-do-operador.md`, "abandonar o
cadastro"): sem entrada até `Release.reiniciar_credencial_do_operador/2`.

**O código de guarda é distinto do código de cadastro**, com colunas próprias
(`ack_code_hash`, `ack_code_expires_at`; em `data-model.md` §1, com o `CHECK` de par e o `CHECK`
que só admite o código de guarda entre os passos 2 e 3: `totp_confirmed_at` nulo, `totp_secret` e
`totp_last_used_step` preenchidos, código de cadastro anulado). Reaproveitar as colunas do
código de cadastro faria o código do passo 2 abrir o passo 3 sem o TOTP ter sido conferido. Mesma
forma do de cadastro: 20 bytes, `sha256` no banco, **10 minutos**, uso único, consumo atômico sob
`FOR UPDATE` (A1, A5), campo oculto `acknowledgement_token` no corpo do `POST`, nunca na URL.

**O contrato de `concluir_cadastro/2` está num lugar só**:
[credenciais-do-operador.md](credenciais-do-operador.md), seção `concluir_cadastro/2` — assinatura, concessão vigente (A14), consumo atômico (A5), custo do
hash (A3), a caixa `codes_stored` conferida pelo controller e não recebida como argumento, e a regra
de nunca devolver os códigos. Este arquivo descreve o **fluxo**; quem o implementa lê a função lá.

Emendas que este fluxo pediu, **feitas em 2026-10-01**: `credenciais-do-operador.md`
(`confirmar_segundo_fator/3` deixou de gravar `totp_confirmed_at`, de subir `password_epoch` e de
encerrar sessões, e emite o código de guarda; `concluir_cadastro/2` nova, com o contrato completo;
`autenticar/3` recusa com `totp_confirmed_at` nulo **antes** de olhar código de recuperação) e
`data-model.md` §1 (as duas colunas e os dois `CHECK`).

## O que a API NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| leitura do segredo gravado | o segredo sai uma vez, no cadastro; depois, só `conferir/4` o usa |
| janela configurável | um parâmetro a mais é um lugar a mais para alargar a janela sem revisão |
| SMS, e-mail ou push como segundo fator | dependência de entrega, e a segurança da conta mais poderosa na caixa de outra pessoa |
| regenerar só os códigos de recuperação | regenerar é refazer o cadastro pelo comando de reinício, que é um caminho só |
| "lembrar este navegador" | FR-016: a cada entrada |
