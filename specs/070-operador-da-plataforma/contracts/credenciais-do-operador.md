# Contrato — `TheBand.Platform.Credentials`

FR-011, FR-016, O4, O11, O16. Desenho em [research.md](../research.md) R1, R2 e R13; tabela em
[data-model.md](../data-model.md) §1 e §1a. Segundo fator em
[segundo-fator-do-operador.md](segundo-fator-do-operador.md).

> **Emendado em 2026-10-01** pela avaliação da segunda autenticação
> ([seguranca-autenticacao.md](../seguranca-autenticacao.md)), achados **A1, A3, A5, A10 e A14**, e
> pela decisão da pessoa mantenedora de ter **TOTP nesta feature** (FR-016). O gate de desenho está
> fechado; o código deste módulo continua **bloqueado** até a avaliação própria do TOTP
> (`tasks.md`) e até os PRs #1048 (#1046, a forma da A1) e o da #1047 (a forma da A3) estarem em
> `development`, porque esta cópia nasce da versão corrigida de `Tenants.Auth`, e não da de hoje.

Depende de: nenhuma ontologia. É infraestrutura de acesso, como `TheBand.Tenants.Auth`.

## As regras que valem para toda função que confere credencial

- **Tentativa serializada (A1).** Toda função que confere senha, código de definição, código de
  cadastro ou segundo fator abre uma transação e lê a linha do operador com `SELECT … FOR UPDATE`
  **antes** de decidir a espera e **antes** do hash. A verificação e o registro da falha ou do
  sucesso acontecem dentro da mesma transação. Dez tentativas paralelas sobem `failed_attempts` em
  no máximo um, e as outras recebem `{:throttled, _}`. A forma segue a correção da #1046 em
  `Tenants.Auth` (PR #1048); se a #1048 escolher o incremento atômico com `RETURNING`, esta cópia
  segue a mesma escolha, e o teste de paridade afirma isso.
- **O custo do hash roda também na espera (A3).** A recusa por espera chama
  `Bcrypt.no_user_verify/0` **antes** de devolver `{:throttled, _}`. Quem não existe, quem está em
  espera, quem não tem concessão e quem não tem senha pagam o mesmo custo de quem errou a senha.
  A forma segue a correção da #1047.
- **Recusa única.** Para quem chama, todo caso de falha é `{:error, :invalid_credentials}` ou
  `{:error, {:throttled, s}}`. O motivo interno vai só para `AccessEvents`.
- **O segredo chega como `TheBand.Segredo.t()`** (FR-006 da 064): senha, código de definição,
  código de cadastro e segundo fator. Um `FunctionClauseError` não os imprime.
- **Os campos do formulário contêm `token` ou `password` no nome (A10)**: `password`,
  `setup_token`, `enrollment_token`, `second_factor_token`. O filtro padrão do Phoenix
  (`["password", "token"]`, por substring) os redige na linha `Parameters:`. Mesmo assim,
  `config/config.exs` ganha `filter_parameters` com `"code"`, `"secret"` e `"totp"`, para que um
  nome renomeado não vaze.

## `autenticar(email :: String.t(), senha :: TheBand.Segredo.t(), segundo_fator :: TheBand.Segredo.t()) :: {:ok, Operator.t()} | {:error, :invalid_credentials} | {:error, {:throttled, pos_integer()}}`

Um formulário só, com os três campos. Não existe estado "meio autenticado" entre a senha e o
segundo fator.

- resolve o operador por `lower(email)`, com `FOR UPDATE` (A1);
- **recusa única** para: e-mail inexistente, senha errada, senha não definida, **segundo fator não
  cadastrado** (`totp_confirmed_at IS NULL`), segundo fator errado, segundo fator reusado, código
  de recuperação já usado e **sem concessão vigente**;
- o custo do Bcrypt roda **sempre**, inclusive na espera (A3);
- o segundo fator é conferido **só depois** de a senha conferir, mas a conferência dele é barata
  (HMAC), e o tempo da recusa é dominado pelo Bcrypt nos dois casos;
- o segundo fator é um código TOTP de 6 dígitos **ou** um código de recuperação; a forma do texto
  decide qual se tenta (`SegundoFator.classificar/1`), e o código de recuperação é consumido de
  forma atômica (`segundo-fator-do-operador.md`);
- segundo fator errado **conta falha** no mesmo `failed_attempts` da senha: são a mesma porta;
- espera crescente com as mesmas constantes de `Tenants.Auth`, depois da correção da #1046;
- **sem concessão vigente não registra falha**: a credencial pode estar certa, e é o papel que caiu;
- o sucesso grava o passo TOTP aceito em `totp_last_used_step` (contra reuso), zera as falhas
  **depois** de registrar quantas apagou, e grava `logged_in_at`.

Cada recusa gera `AccessEvents.operador_entrada_recusada/2` com o motivo interno
(`:identificador_nao_resolveu`, `:senha_errada`, `:sem_senha`, `:sem_segundo_fator`,
`:segundo_fator_errado`, `:segundo_fator_reusado`, `:recuperacao_usada`, `:sem_concessao`).

## `definir_senha(email, setup_token :: TheBand.Segredo.t(), senha :: TheBand.Segredo.t()) :: {:ok, {Operator.t(), cadastro}} | {:error, :invalid_credentials} | {:error, {:throttled, pos_integer()}} | {:error, Ecto.Changeset.t()}`

`cadastro :: %{segredo: TheBand.Segredo.t(), uri: TheBand.Segredo.t(), enrollment_token: TheBand.Segredo.t()}`

O primeiro dos dois passos da definição. **Não habilita a entrada**: depois dele, `autenticar/3`
continua recusando, porque o segundo fator não foi confirmado.

- **exige concessão vigente (A14)**; sem ela, a recusa única, com o custo do hash;
- **consumo atômico do código (A5)**: dentro da transação com `FOR UPDATE` na linha do operador,
  confere `sha256(setup_token)` com `Plug.Crypto.secure_compare/2` e `setup_code_expires_at` no
  futuro, e anula `setup_code_hash` e `setup_code_expires_at` **na mesma transação**. Dois `POST`
  paralelos com o mesmo código: exatamente um passa;
- código errado, vencido, ausente ou e-mail inexistente: **a mesma** recusa única, e conta falha;
- `{:error, changeset}` só depois de o código conferir, e só pela política de senha (12 a 128). O
  código já foi consumido nesse caso? **Não**: a validação da senha roda antes do consumo, dentro
  da mesma transação, e o `ROLLBACK` devolve o código;
- no sucesso, na mesma transação: grava `password_hash`, sobe `password_epoch` de forma atômica,
  gera o segredo TOTP pendente (`SegundoFator.gerar_segredo/0`), grava-o cifrado em
  `totp_secret`, anula `totp_confirmed_at`, `totp_last_used_step` e os códigos de recuperação
  anteriores, emite o **código de cadastro** (20 bytes, `sha256` no banco, 10 minutos, uso único)
  e encerra toda sessão aberta do operador;
- devolve o segredo e a URI `otpauth://` **uma vez**, para a tela de cadastro, e o código de
  cadastro, que vai num campo oculto do formulário seguinte, no corpo do `POST`, nunca na URL.

## `confirmar_segundo_fator(email, enrollment_token :: TheBand.Segredo.t(), codigo :: TheBand.Segredo.t()) :: {:ok, {Operator.t(), [TheBand.Segredo.t()]}} | {:error, :invalid_credentials} | {:error, {:throttled, pos_integer()}}`

O segundo passo. Devolve os **códigos de recuperação**, uma vez.

- exige concessão vigente (A14);
- consome o código de cadastro de forma atômica, como `definir_senha/3` consome o de definição (A5);
- confere o código TOTP contra o segredo pendente, com a janela de ±1 passo
  (`segundo-fator-do-operador.md`);
- código de cadastro errado, vencido ou ausente, ou TOTP errado: recusa única, e conta falha. O
  TOTP errado **não** consome o código de cadastro: a pessoa pode ter digitado errado, e o código
  vale até vencer;
- no sucesso, na mesma transação: grava `totp_confirmed_at` e `totp_last_used_step`, gera **10
  códigos de recuperação** (`SegundoFator.gerar_codigos_de_recuperacao/0`), grava só o `sha256` de
  cada um, anula o código de cadastro, sobe `password_epoch` e encerra as sessões do operador.

Abandonar o cadastro entre os dois passos deixa o operador sem entrada até
`Release.reiniciar_credencial_do_operador/2`. É o preço de não existir conta habilitada sem segundo
fator.

## `emitir_codigo(Operator.t()) :: {:ok, TheBand.Segredo.t()}` — interna ao contexto

Chamada só por `TheBand.Platform.Grants` (contrato em `concessao-do-operador.md`). 20 bytes
aleatórios, base32 minúscula; grava `sha256` e a validade de 30 minutos, **substituindo** o código
anterior. Devolve o bruto **uma vez**, como `Segredo.t()`.

## O que a API NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| nenhuma função recebe senha que não venha do navegador do operador | O11: senha não passa por comando, ambiente nem log |
| nenhuma função devolve o hash, o código gravado, o segredo TOTP gravado nem a época | quem precisa decidir chama `autenticar/3`; o segredo sai **uma vez**, no cadastro |
| não há `change_password(atual, nova)` nem "trocar o segundo fator" | trocar é pedir um código novo pelo comando, que refaz os dois passos. Para uma ou duas pessoas, um caminho só é menos superfície que dois |
| não há entrada sem segundo fator, nem "lembrar este navegador" | FR-016: o segundo fator vale a cada entrada |
| não há bloqueio de conta | bloqueio é negação de serviço para quem souber o e-mail (forma de `auth.ex:20-23`); A4 fica com a espera por conta até o limite por IP (que depende da medição do Traefik) |
| nenhuma função aceita `%User{}`, e nenhuma função de `TheBand.Tenants` aceita `%Operator{}` | é o que mantém as duas autenticações sem ponto de contato (FR-011) |
| não há leitura do código de definição por GET, nem código na URL | o código ficaria no log de acesso, no histórico e no `Referer` (research R1) |
