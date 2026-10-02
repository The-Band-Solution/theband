# Contrato — `TheBand.Platform.Credentials`

FR-011, FR-016, O4, O11, O16. Desenho em [research.md](../research.md) R1, R2 e R13; tabela em
[data-model.md](../data-model.md) §1 e §1a. Segundo fator em
[segundo-fator-do-operador.md](segundo-fator-do-operador.md).

> **Emendado em 2026-10-01** pela avaliação da segunda autenticação
> ([seguranca-autenticacao.md](../seguranca-autenticacao.md)), achados **A1, A3, A5, A10 e A14**, e
> pela decisão da pessoa mantenedora de ter **TOTP nesta feature** (FR-016). O gate de desenho está
> fechado. O código deste módulo esperava a avaliação própria do TOTP (**feita**, T010 e T011,
> `seguranca-totp.md`) e os PRs #1048 (#1046, a forma da A1) e #1049 (#1047, a forma da A3) em
> `development` (**os dois mergeados** em 2026-10-01), porque esta cópia nasce da versão corrigida
> de `Tenants.Auth`. O que ainda falta está no `Pronta quando` de T023, em `tasks.md`.
>
> **Emendado em 2026-10-01 pelo protótipo T012** (Q3 (b), decisão da pessoa mantenedora; o fluxo
> em [segundo-fator-do-operador.md](segundo-fator-do-operador.md), "O fluxo de cadastro (emenda
> T012)", e a rota `POST /platform/setup/recovery-codes` em
> [rotas-da-plataforma.md](rotas-da-plataforma.md)): o cadastro tem **três** passos.
> `confirmar_segundo_fator/3` deixa de habilitar a entrada e emite o **código de guarda**;
> `concluir_cadastro/2` é nova e é a única que grava `totp_confirmed_at`.
>
> **Emendado em 2026-10-01 por T011** (seguranca-totp.md §3, "Emendas de T011"): T4 (o segredo TOTP
> só é lido por `select` explícito), T8 (`invalidated_at`), e a decisão sobre o TOTP errado do
> passo 2 contar só em `failed_attempts` (seguranca-totp.md, T12).

Depende de: nenhuma ontologia. É infraestrutura de acesso, como `TheBand.Tenants.Auth`.

## As regras que valem para toda função que confere credencial

- **Tentativa serializada (A1).** Toda função que confere senha, código de definição, código de
  cadastro, código de guarda ou segundo fator abre uma transação e lê a linha do operador com `SELECT … FOR UPDATE`
  **antes** de decidir a espera e **antes** do hash. A verificação e o registro da falha ou do
  sucesso acontecem dentro da mesma transação. Dez tentativas paralelas sobem `failed_attempts` em
  no máximo um, e as outras recebem `{:throttled, _}`. A forma segue a correção da #1046 em
  `Tenants.Auth` (PR #1048); se a #1048 escolher o incremento atômico com `RETURNING`, esta cópia
  segue a mesma escolha, e o teste de paridade afirma isso. (Conferido em 2026-10-01, T008: o
  diff do #1048 escolheu `FOR UPDATE`, com `Repo.transaction/1` devolvendo o resultado da
  verificação.)
- **A recusa confirma o registro da falha (A1, T008).** A transação de uma recusa termina em
  `COMMIT`, e não em `Repo.rollback/1`: a função devolve `{:error, …}` **de dentro** da transação
  bem-sucedida, como `verificar_com_trava/2` do #1048. Uma recusa por `rollback` desfaria o
  `failed_attempts + 1` junto, e a espera deixaria de contar as falhas: o A1 voltaria pela porta da
  transação. O único `ROLLBACK` previsto é o do `{:error, changeset}` de `definir_senha/3`, que
  acontece **depois** de o código conferir, e por isso não apaga falha nenhuma.
- **O custo do hash roda também na espera (A3).** A recusa por espera chama
  `Bcrypt.no_user_verify/0` **antes** de devolver `{:throttled, _}`. Quem não existe, quem está em
  espera, quem não tem concessão e quem não tem senha pagam o mesmo custo de quem errou a senha.
  A forma segue a correção da #1047.
- **Recusa única.** Para quem chama, todo caso de falha é `{:error, :invalid_credentials}` ou
  `{:error, {:throttled, s}}`. O motivo interno vai só para `AccessEvents`.
- **`{:throttled, s}` não chega à tela como resposta distinta (A3, T008).** Só uma conta que
  existe entra em espera; uma frase ou um status diferente para a espera entregaria pela mensagem
  o mesmo oráculo de existência que o custo do hash fecha pelo relógio. Os controllers de
  `/platform` respondem a espera com **a mesma frase, o mesmo status e o mesmo destino** de
  `:invalid_credentials`, e não mostram os segundos, como `session_controller.ex:10-11` e `:36-37`
  de `development` fazem na entrada das organizações. O `s` serve ao evento
  `operador_espera_acionada/2`, e a nenhuma outra coisa.
- **O segredo chega como `TheBand.Segredo.t()`** (FR-006 da 064): senha, código de definição,
  código de cadastro, código de guarda e segundo fator. Um `FunctionClauseError` não os imprime.
- **O segredo TOTP só é lido aqui, e só por `select` explícito (seguranca-totp.md, T4).** O campo
  tem `load_in_query: false` (`data-model.md` §1): nenhum `%Operator{}` carregado fora deste módulo
  traz o segredo decifrado. `autenticar/3` e `confirmar_segundo_fator/3` o selecionam **dentro** da
  transação, da linha travada pelo `FOR UPDATE`, e o embrulham em `Segredo.novo/1` na mesma
  expressão; ele nunca é atribuído a struct, `assign`, `Logger.metadata` nem estado de processo.
- **Os campos do formulário contêm `token` ou `password` no nome (A10)**: `password`,
  `setup_token`, `enrollment_token`, `acknowledgement_token`, `second_factor_token`. O filtro padrão do Phoenix
  (`["password", "token"]`, por substring) os redige na linha `Parameters:`. Mesmo assim,
  `config/config.exs` ganha `filter_parameters` com `"code"`, `"secret"` e `"totp"`, para que um
  nome renomeado não vaze.

## `autenticar(email :: String.t(), senha :: TheBand.Segredo.t(), segundo_fator :: TheBand.Segredo.t()) :: {:ok, Operator.t()} | {:error, :invalid_credentials} | {:error, {:throttled, pos_integer()}}`

Um formulário só, com os três campos. Não existe estado "meio autenticado" entre a senha e o
segundo fator.

- resolve o operador por `lower(email)`, com `FOR UPDATE` (A1);
- **enquanto `totp_confirmed_at` é nulo, recusa sempre** (recusa única, com o custo do hash,
  motivo interno `:sem_segundo_fator`), qualquer que seja o segundo fator enviado: **inclusive um
  código de recuperação**, que já tem o `sha256` gravado desde o passo 2 do cadastro, e inclusive
  um TOTP certo. A conferência de `totp_confirmed_at` vem **antes** de `classificar/1` e antes de
  qualquer consumo em `platform_operator_recovery_codes`: código de recuperação mostrado e não
  confirmado (passo 3) não é credencial, e não é gasto. Esta recusa não sobe
  `second_factor_failures` (não há segundo fator cadastrado a forçar);
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
- **limite próprio do segundo fator (seguranca-totp.md, T1)**: com a senha **certa** e o segundo
  fator errado, reusado, ou com código de recuperação errado ou já usado, sobe também
  `second_factor_failures`, na mesma transação. Ele **zera só no sucesso completo**, e a senha
  errada **não** o toca. Ao chegar a **10** (`@limite_do_segundo_fator`, com este motivo escrito), o
  segundo fator fica **travado**: `autenticar/3` devolve a recusa única, com o custo do hash, **mesmo
  com senha e código certos**, e o motivo interno `:segundo_fator_travado`, até
  `Release.reiniciar_credencial_do_operador/2`. A espera de 60 s sozinha deixava ~1 440 tentativas
  por dia, para sempre (≈12 % de acerto em 30 dias); NIST 800-63B §5.2.2 limita a 100. Não reabre o
  DoS de "sem bloqueio de conta": só quem **já tem a senha** alcança este contador, e quem tem a
  senha é o incidente, cuja resposta já é o reinício. O evento
  `AccessEvents.operador_segundo_fator_travado/1` sai uma vez, na transição para travado;
- espera crescente com as mesmas constantes de `Tenants.Auth`, depois da correção da #1046;
- **sem concessão vigente não registra falha**: a credencial pode estar certa, e é o papel que caiu;
- o sucesso grava o passo TOTP aceito em `totp_last_used_step` (contra reuso), zera as falhas
  **depois** de registrar quantas apagou, e grava `logged_in_at`.

Cada recusa gera `AccessEvents.operador_entrada_recusada/2` com o motivo interno
(`:identificador_nao_resolveu`, `:senha_errada`, `:sem_senha`, `:sem_segundo_fator`,
`:segundo_fator_errado`, `:segundo_fator_reusado`, `:recuperacao_usada`, `:segundo_fator_travado`,
`:sem_concessao`).

## `definir_senha(email, setup_token :: TheBand.Segredo.t(), senha :: TheBand.Segredo.t()) :: {:ok, {Operator.t(), cadastro}} | {:error, :invalid_credentials} | {:error, {:throttled, pos_integer()}} | {:error, Ecto.Changeset.t()}`

`cadastro :: %{segredo: TheBand.Segredo.t(), uri: TheBand.Segredo.t(), enrollment_token: TheBand.Segredo.t()}`

O primeiro dos **três** passos da definição (`segundo-fator-do-operador.md`, "O fluxo de cadastro"). **Não habilita a entrada**: depois dele, `autenticar/3`
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
  zera `second_factor_failures` (T1),
  gera o segredo TOTP pendente (`SegundoFator.gerar_segredo/0`), grava-o cifrado em
  `totp_secret`, anula `totp_confirmed_at`, `totp_last_used_step` e o código de guarda
  (`ack_code_hash`, `ack_code_expires_at`), marca `invalidated_at` nos códigos de recuperação
  anteriores ainda vigentes (T8; os já usados guardam o `used_at`), emite o
  **código de cadastro** (20 bytes, `sha256` no banco, 10 minutos, uso único) e encerra toda sessão aberta do operador;
- devolve o segredo e a URI `otpauth://` **uma vez**, para a tela de cadastro, e o código de
  cadastro, que vai num campo oculto do formulário seguinte, no corpo do `POST`, nunca na URL.

## `confirmar_segundo_fator(email, enrollment_token :: TheBand.Segredo.t(), codigo :: TheBand.Segredo.t()) :: {:ok, {Operator.t(), [TheBand.Segredo.t()], TheBand.Segredo.t()}} | {:error, :invalid_credentials} | {:error, {:throttled, pos_integer()}}`

O segundo passo. Devolve os **códigos de recuperação**, uma vez, e o **código de guarda**. **Não
habilita a entrada** (Q3 (b) do protótipo T012): depois dele, `autenticar/3` continua recusando,
porque `totp_confirmed_at` continua nulo.

`{:ok, {Operator.t(), [TheBand.Segredo.t()], acknowledgement_token :: TheBand.Segredo.t()}}` é o
sucesso: os dez códigos e o código de guarda, que vai num campo oculto do formulário do passo 3, no
corpo do `POST`, nunca na URL.

- exige concessão vigente (A14);
- consome o código de cadastro de forma atômica, como `definir_senha/3` consome o de definição (A5);
- confere o código TOTP contra o segredo pendente, com a janela de ±1 passo
  (`segundo-fator-do-operador.md`);
- o segredo pendente é lido da linha travada, por `select` explícito (T4);
- código de cadastro errado, vencido ou ausente, e-mail inexistente, ou TOTP errado: recusa única,
  **com o custo do hash** (`Bcrypt.no_user_verify/0` uma vez em toda recusa, inclusive na espera e
  sem concessão; A3: e-mail inexistente e código errado custam o mesmo), e conta falha em
  `failed_attempts`. O TOTP errado **não** consome o código de cadastro: a pessoa pode ter digitado
  errado, e o código vale até vencer. A falha **não** prorroga `enrollment_code_expires_at`;
- **o TOTP errado deste passo conta só em `failed_attempts`, e não em `second_factor_failures`
  (seguranca-totp.md, T12, decidido por T011).** A razão: quem tem um `enrollment_token` válido
  recebeu o segredo TOTP na mesma resposta de `definir_senha/3`, e não precisa adivinhar código
  nenhum; força bruta aqui só interessa a quem obteve o código de cadastro **sem** o segredo, o que
  exige ler o corpo de um `POST` (TLS, e `enrollment_token` redigido no log por A10). Mesmo esse
  atacante tem o código por 10 minutos, sem renovação pela falha, e a espera de `failed_attempts`
  limita a ~16 tentativas nessa janela (3 livres, depois esperas de 2, 4, 8, 16 e 32 s e então
  60 s, `auth.ex:36-37,162-165`): 16 × 3 / 10⁶ ≈ 5×10⁻⁵ de acerto, e o que ganharia são códigos de recuperação **sem a senha**, definida no passo 1. Um código
  de cadastro novo só sai de um código de definição novo, que só sai do comando no Dokploy. Contar
  em `second_factor_failures` seria pior: o contador é zerado por `definir_senha/3` e só tem efeito
  sobre segundo fator confirmado, e erros de digitação no cadastro consumiriam o limite de T1 da
  primeira entrada;
- no sucesso, na mesma transação: grava `totp_last_used_step` (o passo aceito), gera **10 códigos
  de recuperação** (`SegundoFator.gerar_codigos_de_recuperacao/0`), grava só o `sha256` de cada um,
  anula o código de cadastro e emite o **código de guarda**: 20 bytes de
  `:crypto.strong_rand_bytes/1`, `sha256` em `ack_code_hash`, validade de **10 minutos** em
  `ack_code_expires_at`, uso único;
- **não** grava `totp_confirmed_at`, **não** sobe `password_epoch` e **não** encerra sessões: as três
  coisas são de `concluir_cadastro/2`. Os códigos de recuperação gravados aqui não valem até lá,
  porque `autenticar/3` recusa antes de olhá-los.

## `concluir_cadastro(email, acknowledgement_token :: TheBand.Segredo.t()) :: {:ok, Operator.t()} | {:error, :invalid_credentials} | {:error, {:throttled, pos_integer()}}`

**Este é o contrato único de `concluir_cadastro/2`** (achado A1 do `/speckit-analyze`): o fluxo de
cadastro em `segundo-fator-do-operador.md` aponta para cá, e não repete a assinatura.

O terceiro passo: o operador declarou que guardou os códigos de recuperação. **É a única função que
grava `totp_confirmed_at`**, e por isso a única que habilita a entrada.

- **a caixa `codes_stored` não é argumento**: quem a confere é o controller, antes de chamar
  (`rotas-da-plataforma.md`). Sem a caixa, esta função não é chamada, o código de guarda não é
  consumido e nenhuma falha conta;
- exige concessão vigente (A14); sem ela, a recusa única, com o custo do hash, e não conta falha;
- **consumo atômico do código de guarda (A5)**: dentro da transação com `FOR UPDATE` na linha do
  operador (A1), confere `sha256(acknowledgement_token)` com `Plug.Crypto.secure_compare/2` e
  `ack_code_expires_at` no futuro, e anula `ack_code_hash` e `ack_code_expires_at` **na mesma
  transação**. Dois `POST` paralelos com o mesmo código: exatamente um passa;
- código de guarda errado, vencido, ausente ou e-mail inexistente: **a mesma** recusa única, com o
  custo do hash (A3), e conta falha em `failed_attempts`. Não sobe `second_factor_failures`, pela
  razão do passo 2 (T12) e por mais uma: o código de guarda tem 160 bits, e não há o que forçar;
- o código de **cadastro** não abre este passo: são colunas diferentes, e o de cadastro já foi
  anulado no passo 2;
- no sucesso, na mesma transação: grava `totp_confirmed_at`, sobe `password_epoch` de forma
  atômica e encerra toda sessão aberta do operador (`Platform.Sessions.encerrar_do_operador/1`).
  Gera `AccessEvents.operador_segundo_fator_cadastrado/1`;
- **nunca devolve os códigos de recuperação**: eles só existem em claro na resposta de
  `confirmar_segundo_fator/3`, e a recusa deste passo não os mostra de novo.

Abandonar o cadastro entre quaisquer dois passos — inclusive fechar a aba com os códigos de
recuperação na tela, sem marcar a caixa — deixa o operador sem entrada até
`Release.reiniciar_credencial_do_operador/2`, que gera segredo e códigos novos e invalida os
anteriores. É o preço de não existir conta habilitada sem segundo fator, nem código de recuperação
que vale sem ter sido declarado guardado.

## `emitir_codigo(Operator.t()) :: {:ok, TheBand.Segredo.t()}` — interna ao contexto

Chamada só por `TheBand.Platform.Grants` (contrato em `concessao-do-operador.md`). 20 bytes
aleatórios, base32 minúscula; grava `sha256` e a validade de 30 minutos, **substituindo** o código
anterior. Devolve o bruto **uma vez**, como `Segredo.t()`.

## O que a API NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| nenhuma função recebe senha que não venha do navegador do operador | O11: senha não passa por comando, ambiente nem log |
| nenhuma função devolve o hash, o código gravado (de definição, de cadastro ou de guarda), o segredo TOTP gravado nem a época | quem precisa decidir chama `autenticar/3`; o segredo sai **uma vez**, no cadastro |
| não há `change_password(atual, nova)` nem "trocar o segundo fator" | trocar é pedir um código novo pelo comando, que refaz os três passos. Para uma ou duas pessoas, um caminho só é menos superfície que dois |
| não há entrada sem segundo fator, nem "lembrar este navegador" | FR-016: o segundo fator vale a cada entrada |
| não há bloqueio de conta **pela senha** | bloqueio pela senha é negação de serviço para quem souber o e-mail (forma de `auth.ex:20-23`); A4 fica com a espera por conta até o limite por IP (que depende da medição do Traefik). A trava do **segundo fator** (T1, acima) é outra coisa: só quem tem a senha a alcança |
| nenhuma função aceita `%User{}`, e nenhuma função de `TheBand.Tenants` aceita `%Operator{}` | é o que mantém as duas autenticações sem ponto de contato (FR-011) |
| não há leitura do código de definição por GET, nem código na URL | o código ficaria no log de acesso, no histórico e no `Referer` (research R1) |
