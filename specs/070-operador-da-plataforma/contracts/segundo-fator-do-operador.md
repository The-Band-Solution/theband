# Contrato — `TheBand.Platform.SegundoFator`

FR-016, O16, A16. Decisão da pessoa mantenedora em 2026-10-01: **TOTP nesta feature**
([seguranca-autenticacao.md](../seguranca-autenticacao.md), "Decisões"). Desenho em
[research.md](../research.md) R13; colunas em [data-model.md](../data-model.md) §1 e §1a.

> **Desenho, e não decisão de biblioteca.** A implementação do RFC 6238 (NimbleTOTP, ou HMAC sobre
> `:crypto`) é escolhida pela tarefa de pesquisa de dependência do `tasks.md`, com a justificativa
> escrita no `plan.md` (AGENTS.md §3). Este contrato vale para as duas escolhas. **Nenhuma linha
> deste módulo é escrita antes da avaliação de segurança própria do TOTP**, feita por quem não
> escreveu este desenho.

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
| códigos de recuperação | 10, cada um com 10 bytes aleatórios em base32 (16 caracteres, com hífen a cada 4 para leitura) | 80 bits cada; uso único |

## `gerar_segredo() :: TheBand.Segredo.t()`

## `uri(segredo :: TheBand.Segredo.t(), email :: String.t()) :: TheBand.Segredo.t()`

`otpauth://totp/The%20Band%20Platform:<email>?secret=<base32>&issuer=The%20Band%20Platform`. Volta
como `Segredo.t()` porque carrega o segredo.

**Sem QR code nesta forma.** A tela mostra o segredo em base32 para digitar no aplicativo, e a URI
para copiar. Um QR exige biblioteca de geração; se a pesquisa de dependência recomendar uma, ela
entra com justificativa própria no `plan.md`, e este contrato ganha `qr_svg/1`.

## `conferir(segredo :: TheBand.Segredo.t(), codigo :: TheBand.Segredo.t(), ultimo_passo :: non_neg_integer() | nil, agora :: DateTime.t()) :: {:ok, passo :: non_neg_integer()} | {:error, :codigo_errado | :reusado}`

- calcula o passo atual de `agora`, e compara o código contra os passos `atual - 1`, `atual` e
  `atual + 1`, com `Plug.Crypto.secure_compare/2`;
- **contra reuso**: um código cujo passo seja `<= ultimo_passo` devolve `{:error, :reusado}`, mesmo
  correto. Quem grava o passo aceito é `Credentials`, na mesma transação com `FOR UPDATE`; sem o
  lock, dois envios paralelos do mesmo código passariam os dois;
- `agora` é argumento, e não `DateTime.utc_now/0` por dentro, para o teste fixar o relógio sem
  depender da hora (lição L46).

## `classificar(texto :: TheBand.Segredo.t()) :: :totp | :recuperacao | :malformado`

Seis dígitos, com espaços retirados, são `:totp`. Dezesseis caracteres base32, com hífens
retirados e minúsculas, são `:recuperacao`. O resto é `:malformado`, que `Credentials` recusa com a
recusa única e o custo do hash.

## `gerar_codigos_de_recuperacao() :: [TheBand.Segredo.t()]`

## `resumo(codigo :: TheBand.Segredo.t()) :: binary()`

`sha256` do código **normalizado** (sem hífen, minúsculo). É o que vai para
`platform_operator_recovery_codes.code_hash`. SHA-256 e não Bcrypt pela razão de `sessions.ex:10-14`:
80 bits aleatórios não têm dicionário.

## O consumo do código de recuperação (em `Credentials`, e não aqui)

`UPDATE platform_operator_recovery_codes SET used_at = now() WHERE operator_id = $1 AND
code_hash = $2 AND used_at IS NULL RETURNING id`, conferindo **uma** linha. Dois envios paralelos
do mesmo código: exatamente um passa. O uso gera `AccessEvents.operador_recuperacao_usada/2`, com
quantos restam, em `:warning`.

## O que a API NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| leitura do segredo gravado | o segredo sai uma vez, no cadastro; depois, só `conferir/4` o usa |
| janela configurável | um parâmetro a mais é um lugar a mais para alargar a janela sem revisão |
| SMS, e-mail ou push como segundo fator | dependência de entrega, e a segurança da conta mais poderosa na caixa de outra pessoa |
| regenerar só os códigos de recuperação | regenerar é refazer o cadastro pelo comando de reinício, que é um caminho só |
| "lembrar este navegador" | FR-016: a cada entrada |
