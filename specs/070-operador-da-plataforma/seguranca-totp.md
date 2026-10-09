# Avaliação de segurança do segundo fator TOTP do operador — T010

Feita em 2026-10-01 pelo agente `security`, **que não escreveu o desenho** do TOTP (research R13,
`contracts/segundo-fator-do-operador.md`, `contracts/credenciais-do-operador.md`, `data-model.md`
§1 e §1a). FR-016, A16. Régua: OWASP Top 10 (A02, A04, A07, A09) e ASVS 4.0.3 V2.2 (anti-automação),
V2.5 (recuperação), V2.6 (segredo de consulta), V2.8 (OTP), V6 (cripto em repouso), V7 (log).

**Escopo**: leitura dos documentos da spec 070 e do código da NimbleTOTP 1.0.0, baixado com
`mix hex.package fetch nimble_totp 1.0.0 --unpack` (código de saída 0); leitura de
`lib/the_band/vault.ex`, `lib/the_band/encrypted/binary.ex`, `lib/the_band/segredo.ex`,
`lib/the_band/tenants/auth.ex:36-37,162-165`, `lib/the_band/tenants/sessions.ex:1-25`,
`lib/mix/tasks/the_band.rotate_key.ex` e `deps/phoenix` (1.8.11, `mix.exs:72` e
`lib/phoenix/logger.ex`). **Nada foi executado** além do download: nenhum teste, nenhum gate.

**Veredito**: o desenho é bom no que mais costuma falhar — segredo cifrado no `Ecto.Type`, entrada
num formulário só, reuso por marca d'água sob `FOR UPDATE`, consumo atômico, A6 apagando o cadastro.
Há **um achado alto** (T1, força bruta do segundo fator por quem já tem a senha) e **um médio que
muda parâmetro de contrato** (T2, entropia dos códigos de recuperação). Os dois foram **emendados nos
contratos nesta avaliação** (seção "Emendas feitas"). Com as emendas, T022/T023/T026/T028 podem
começar; T3 bloqueia a **release**, não o início do código.

> **Reconferido em 2026-10-01 por T011**, pelo agente `security`, depois de o protótipo T012 mudar o
> cadastro de **dois** para **três** passos (Q3 (b): `definir_senha/3`, `confirmar_segundo_fator/3`,
> `concluir_cadastro/2`, com o **código de guarda** entre os passos 2 e 3). A avaliação acima foi
> feita sobre dois passos; o texto abaixo foi corrigido onde dizia o contrário, e o terceiro passo
> ganhou o achado T12 e os cenários C14–C21. Emendas de T011 em §3.

---

## 1. A biblioteca — o que foi conferido no código da NimbleTOTP 1.0.0

| pergunta | resposta, e como foi verificada |
|---|---|
| `valid?/3` compara em tempo constante? | **Sim** para o código: `bxor` dígito a dígito, `|||` acumulado, `=== 0`, sobre exatamente 6 bytes (`nimble_totp.ex`, cláusula `valid?(secret, <<a1, …, a6>>, opts)`). O `and not reused?(…)` só roda quando o código casou: a diferença de tempo entre "errado" e "certo mas reusado" é uma consulta a `Keyword` — microssegundos, depois de um Bcrypt, e só alcançável por quem já tem a senha. Sem oráculo prático |
| entrada que não tem 6 bytes | cai na cláusula `valid?(_, _, _) -> false` sem calcular HMAC. Revela só o tamanho, que é público |
| truncamento | correto pelo RFC 4226 §5.3: `offset` nos 4 bits baixos do byte 19, 4 bytes a partir dele, bit alto descartado (`<<_::1, bits::31>>`), `rem(1_000_000)`, `pad_leading` com `"0"`. Os vetores do RFC 6238 apêndice B (8 dígitos) valem pelos 6 últimos, porque `x mod 10^8 mod 10^6 = x mod 10^6` — T022 já pede isso |
| como `since:` funciona | `reused? = floor_div(time, period) <= floor_div(to_unix(since), period)`, onde `time` é o `time:` **desta** chamada. Com `since: ultimo_passo * 30`, `floor_div(since, 30) == ultimo_passo` exatamente: a tradução do contrato está **certa**. `since: 0` é verdadeiro em Elixir (só `nil`/`false` desligam): passo 0 não escapa da regra |
| a janela ±1 com três chamadas reabre passo já usado? | **Não**, porque a regra é marca d'água (`<=`), e não igualdade. Depois de aceitar o passo `s`, os códigos de `s-1` e `s` são recusados mesmo dentro da janela; só `s+1` passa, e esse código ninguém viu ainda. **Desde que** se grave o passo **aceito** (que pode ser `s+1`, com relógio do celular adiantado), e não `div(agora, 30)` — cenário C3 |
| segredo | `:crypto.strong_rand_bytes(20)`; 160 bits (RFC 4226 §4) |
| URI | `Base.encode32(secret, padding: false)` e `URI.encode_query(…, :rfc3986)`; não gera QR |
| dependências | nenhuma (lido no `mix.exs` do pacote: só `{:ex_doc, ">= 0.19.0", only: :docs}`) |

**Distinguir `:reusado` de `:codigo_errado` refazendo as chamadas sem `since`**: é seguro e **não cria
oráculo externo**. Para fora, `Credentials` devolve a mesma recusa única, e o custo extra são três
HMAC depois de um Bcrypt. A distinção serve ao evento, e é útil: `:segundo_fator_reusado` com senha
certa é o sinal de código observado por terceiro. Recomendação de simplificação (T7, informativo):
uma passada **sem** `since`, que devolve o passo que casou, e a regra `passo > ultimo_passo` em
inteiro, numa linha — mesma semântica, metade dos caminhos, e a regra de reuso fica num lugar só e
testável sem a biblioteca.

---

## 2. Achados

| id | severidade | OWASP · ASVS | onde | o quê | bloqueia código? |
|---|---|---|---|---|---|
| **T1** | **alta** | A07 · V2.2.1; NIST 800-63B §5.2.2 | `contracts/credenciais-do-operador.md`, "segundo fator errado conta falha no mesmo `failed_attempts`" e "não há bloqueio de conta"; research R13 (linha "falha de segundo fator conta na mesma espera"); `auth.ex:36-37,162-165` | **Quem já tem a senha força o segundo fator sem limite.** A espera satura em 60 s (`@teto_segundos 60`): ~1 440 tentativas por dia, para sempre. A janela ±1 aceita 3 códigos por tentativa: 3×10⁻⁶ por tentativa, **≈0,43 % por dia, ≈12 % em 30 dias, ≈50 % em ~160 dias**, e o único rastro é uma linha de log. O atacante é exatamente o que o TOTP existe para parar (senha reutilizada ou capturada, A16), e ele obtém a conta que suspende todas as organizações. NIST limita falhas consecutivas a 100; aqui não há limite | **sim** — emendado: contador próprio, trava em 10, saída pelo reinício (T023, T028, T028a) |
| **T2** | média | A02 · **V2.6.2** | `contracts/segundo-fator-do-operador.md`, "códigos de recuperação" e `resumo/1`; research R13 | **80 bits com `sha256` sem sal não cumpre V2.6.2**, que pede ≥112 bits **ou** sal aleatório de 32 bits por código. A analogia com `sessions.ex:10-14` não se aplica: lá são **256** bits. Caminho: quem lê o banco ou um backup (a US1 da 064 existe por isso) sem a chave mestra encontra o `totp_secret` cifrado, mas os resumos dos códigos de recuperação **em claro** — é o único material de segundo fator no dump fora do Cloak. Quebrar 2⁸⁰/10 hoje é impraticável para esse atacante; a régua é explícita e a correção é grátis antes de emitir o primeiro código | **sim, por ser parâmetro de contrato** — emendado: 16 bytes (128 bits), 26 caracteres |
| **T3** | média | A02 · V6.4.2 | `lib/mix/tasks/the_band.rotate_key.ex:37` e `:70` (só `tool_credentials`); `data-model.md` §1 (`totp_secret`) | **A rotação da chave mestra não alcança `platform_operators.totp_secret`.** Depois de rotacionar e remover `THE_BAND_PREVIOUS_MASTER_KEY`, o Cloak não decifra o segredo, e todo operador fica sem entrada; a saída "fácil" seria manter a chave antiga publicada, que é o que a rotação existe para impedir. **O mesmo defeito já existe hoje** para `ai_provider_credentials.secret` (`lib/the_band/ai/provider_credential.ex:27`), fora da 070 | **não o início**; bloqueia a **release** da 070 (T021, emenda) |
| T4 | baixa | A02 · V6.1.1, V8.3.4 | `data-model.md` §1; `contracts/rotas-da-plataforma.md` (`OperatorScope` atribui `:current_operator` a cada requisição) | o tipo Cloak **decifra no carregamento**: todo `%Operator{}` carregado por `OperatorScope`, por `Sessions.conferir` ou por `Grants` traz o segredo TOTP em claro na memória do processo da requisição. `redact: true` protege `inspect/1`, não o binário nu que sai do struct | não — T011/T021: `load_in_query: false` no campo; só `Credentials` o seleciona, e embrulha em `Segredo.novo/1` na mesma expressão |
| T5 | média | A04 · V8.2.1, V3.1.1 | `contracts/rotas-da-plataforma.md`, `POST /platform/setup` e `/setup/second-factor` | **nada proíbe o segredo e os códigos de recuperação de passarem por `put_flash` + redirect** (o hábito PRG do Phoenix). O flash mora no cookie `_the_band_key`, que é **só assinado** (research R3.2, `sessao.ex:16-17`) e vai em toda requisição do domínio: o segredo TOTP ficaria legível em base64 no navegador. Defesa que depende de quem implementa lembrar | não — T011: o contrato diz "renderizados na resposta do `POST`, nunca por flash, sessão, redirect ou `GET`"; cenário C8 |
| T6 | baixa | A07 · V2.2.1 | `segundo-fator-do-operador.md`, `classificar/1` | um `\d` com a flag `u` aceita dígitos não ASCII; `valid?/3` recusa (falha fechada), mas o caso vira `:segundo_fator_errado` e conta no contador de T1 em vez de `:malformado` | não — `[0-9]` literal; cenário C11 |
| T7 | informativo | — | `segundo-fator-do-operador.md`, `conferir/4` | a dupla passada (com e sem `since`) é segura (§1); recomenda-se a passada única com `passo > ultimo_passo` | não |
| T8 | baixa | A09 · V7.1.3 | `data-model.md` §1a (`used_at` "preenchido no uso, ou no reinício e na nova concessão") | `used_at` confunde **uso** com **invalidação**. Depois de um incidente, "algum código de recuperação foi usado por alguém?" só se responde pelo log, que tem retenção de log | não — T011: coluna `invalidated_at`; o consumo exige `used_at IS NULL AND invalidated_at IS NULL`. Retenção aceita: apagar linhas com `coalesce(used_at, invalidated_at) < now() - 90 days`, **nunca** as vigentes (T058) |
| T9 | informativo | A07 · V2.5.5, V2.8.5, V2.8.6 | roteiro (T059); `eventos-de-acesso.md` | (a) código de recuperação **dá entrada, mas não revoga o aparelho perdido**: o segredo antigo continua valendo nele. Aparelho perdido é **reinício pelo comando**, mesmo havendo códigos; (b) V2.5.5 e V2.8.5 pedem **notificar** o titular na troca de fator e no reuso; não há canal de notificação ao operador, e o que existe é o evento em `:warning` | não — texto do roteiro; a falta de notificação vai como risco residual na nota da release |
| T10 | informativo | A07 · V2.8 (L3) | FR-016 | TOTP não resiste a phishing em tempo real (proxy reverso que repassa senha e código em menos de 90 s). Aceitável em L2; WebAuthn seria o passo seguinte | não — risco residual |
| T11 | informativo | A07 · V2.8.1 | research R13 (janela ±1) | o relógio do **servidor** decide a janela. Deriva acima de 30 s recusa todo código, e com T1 trava o segundo fator em 10 tentativas. O NTP do VPS **não foi verificado** | não — roteiro: conferir `timedatectl` antes da primeira concessão |
| T12 | informativo | A07 · V2.2.1 | `credenciais-do-operador.md`, `confirmar_segundo_fator/3` e `concluir_cadastro/2` (reconferência de T011) | **o TOTP errado do passo 2 e o código de guarda errado do passo 3 contam só em `failed_attempts`, e não em `second_factor_failures`**, decisão que outro agente tomou sem o contrato a fixar. Avaliado: **não abre força bruta útil**. Quem tem o `enrollment_token` recebeu o segredo na mesma resposta; só quem lê o corpo de um `POST` do passo 2 sem ter visto o passo 1 teria o código sem o segredo, e esse tem 10 min sem renovação, ~16 tentativas pela espera (`auth.ex:36-37,162-165`), ≈5×10⁻⁵ de acerto, e ganharia códigos de recuperação **sem a senha**. O código de guarda tem 160 bits. Contar em `second_factor_failures` seria pior: erros de digitação no cadastro gastariam o limite de T1 da primeira entrada | não — **mantida, com a razão escrita no contrato**; cenário C20 |

### O que foi verificado e está correto (com a fonte)

| ponto | onde, e como |
|---|---|
| segredo em repouso | `TheBand.Encrypted.Binary` = `Cloak.Ecto.Binary` com `TheBand.Vault` (AES-GCM 256, IV de 12 bytes, rótulo derivado da chave); mesmo tipo de `tool_credential.ex:31` e `provider_credential.ex:27`. ASVS V2.8.2 pede chave "altamente protegida": chave de ambiente é o nível da casa, não HSM — registrado, não achado |
| segredo exibido uma vez | nenhuma função devolve o segredo depois de `definir_senha/3` (`credenciais-do-operador.md`, "NÃO expõe"); `no_store` na pipeline (`rotas-da-plataforma.md`); recarregar o `POST` reenvia um código de definição já consumido (A5) e é recusado |
| campos do formulário fora do log | Phoenix 1.8.11 tem `filter_parameters: ["password", "token"]` como padrão de aplicação (`deps/phoenix/mix.exs:72`, casamento por substring em `logger.ex`), e os campos são `password`, `setup_token`, `enrollment_token`, `second_factor_token`; o contrato acrescenta `code`, `secret`, `totp` |
| reuso sob concorrência | marca d'água lida da linha travada por `FOR UPDATE`; no `READ COMMITTED` do PostgreSQL, o segundo `FOR UPDATE` espera e relê a versão confirmada. Vale **se** a decisão usar a linha travada, e não um struct carregado antes (cenário C5) |
| consumo do código de recuperação | `UPDATE … WHERE used_at IS NULL AND invalidated_at IS NULL RETURNING` (T8, emenda T011), conferindo uma linha: atômico |
| abandono entre os passos (três, desde T012) | `totp_confirmed_at` nulo — gravado **só** no passo 3 — faz `autenticar/3` recusar **antes** de olhar código de recuperação; o código de cadastro e o de guarda vencem em 10 min; a saída é o reinício. Não há conta habilitada sem segundo fator, nem código de recuperação que vale sem ter sido declarado guardado |
| revogação no meio do cadastro | `revogar/3` anula os códigos de definição, de cadastro e de guarda (A14, `concessao-do-operador.md`); `confirmar_segundo_fator/3` e `concluir_cadastro/2` exigem concessão vigente; nova concessão apaga segredo, passo e códigos (A6). Coberto no contrato; os testes são C6 e C18 |
| o terceiro passo contra A1, A3 e A5 (reconferência de T011) | `concluir_cadastro/2` (`credenciais-do-operador.md`): transação com `FOR UPDATE` na linha (A1); `sha256` com `secure_compare` e validade, anulados na mesma transação (A5); recusa única com o custo do hash para e-mail inexistente, código errado, vencido e ausente (A3); a caixa `codes_stored` conferida pelo controller **antes** de chamar, sem consumir nem contar falha (`rotas-da-plataforma.md`). No banco, `data-model.md` §1: o par `(ack_code_hash, ack_code_expires_at)` e o `CHECK` que só admite o código de guarda com `totp_confirmed_at` nulo, `totp_secret` e `totp_last_used_step` preenchidos e o código de cadastro anulado — o código de guarda não sobrevive ao sucesso nem convive com o passo 2 aberto. `definir_senha/3`, `revogar/3`, `reiniciar_credencial/2` e `conceder/3` o anulam. Um ponto foi emendado: o custo do hash nas recusas do passo 2 não estava escrito, e agora está |
| perda do aparelho | o caminho é `Release.reiniciar_credencial_do_operador/2`, com o mesmo nível de prova da concessão inicial (acesso ao Dokploy): V2.5.7 coerente |

---

## 3. Emendas feitas nesta avaliação (só documentos da spec 070)

| achado | arquivo | o que mudou |
|---|---|---|
| T1 | `contracts/credenciais-do-operador.md` | regra nova "limite próprio do segundo fator": `second_factor_failures` sobe **só** quando a senha conferiu e o segundo fator falhou (errado, reusado, recuperação errada ou já usada); zera **só** no sucesso completo; em **10**, o segundo fator trava — `autenticar/3` recusa com a recusa única e o custo do hash **mesmo com tudo certo**, até o reinício pelo comando; o motivo interno é `:segundo_fator_travado`. A linha "não há bloqueio de conta" ganhou a distinção: quem só sabe o e-mail não alcança esse contador |
| T1 | `data-model.md` §1 | coluna `second_factor_failures integer not null default 0`, `CHECK (>= 0)`; zerada também por `conceder/3` e `reiniciar_credencial/2` |
| T1 | `contracts/concessao-do-operador.md` | A6 zera `second_factor_failures` |
| T1 | `contracts/eventos-de-acesso.md` | `operador_segundo_fator_travado(operator_id)` e o motivo `:segundo_fator_travado` |
| T2 | `contracts/segundo-fator-do-operador.md` | códigos de recuperação com **16 bytes (128 bits)**, 26 caracteres base32 (hífen a cada 4 para leitura); `classificar/1` reconhece 26; `resumo/1` justificado por V2.6.2 (≥112 bits dispensa o sal) e não por analogia com a sessão |
| T1, T3 | `tasks.md` | T028a nova, bloqueante de T036 e T039; T021 ganha a rotação (T3); T023 e T028 citam T1; T010 marcada feita |

Os demais (T4, T5, T6, T8, T9, T11) ficam para **T011**, que os aplica e aponta o trecho.

### Emendas de T011 (2026-10-01, agente `security`)

| achado | trecho que o cobre |
|---|---|
| T4 | `data-model.md` §1, linha `totp_secret` (`load_in_query: false`, leitura por `select` explícito); `contracts/credenciais-do-operador.md`, regra "O segredo TOTP só é lido aqui" e `confirmar_segundo_fator/3` ("o segredo pendente é lido da linha travada"); `tasks.md` T021 (C13) |
| T5 | `contracts/rotas-da-plataforma.md`, seção "A exibição única do segredo e dos códigos" e as linhas de `POST /platform/setup` e `/setup/second-factor` ("renderizada na resposta deste `POST`"); cenário C8 ampliado |
| T6 | `contracts/segundo-fator-do-operador.md`, `classificar/1`, "Só ASCII, e conferido antes de normalizar" (`[0-9]`, `[A-Za-z2-7]`, sem `u`, `\z`, `String.downcase(_, :ascii)` depois da conferência); C11 ampliado; `tasks.md` T022 |
| T8 | `data-model.md` §1a (`invalidated_at`, `CHECK (used_at IS NULL OR invalidated_at IS NULL)`, índice e retenção); `contracts/segundo-fator-do-operador.md` (o `UPDATE` do consumo); `contracts/credenciais-do-operador.md` (`definir_senha/3`); `contracts/concessao-do-operador.md` (A6); `tasks.md` T058 |
| T9, T10, T11 | `plan.md`, "Riscos" (três linhas, riscos residuais declarados); `tasks.md` T059 (roteiro: aparelho perdido é reinício; `timedatectl`) e T062 (nota da release) |
| T12 | `contracts/credenciais-do-operador.md`, `confirmar_segundo_fator/3` (a razão de contar só em `failed_attempts`, e o custo do hash nas recusas) e `concluir_cadastro/2`; `contracts/eventos-de-acesso.md` (`:identificador_nao_resolveu`, e `:totp_errado` como rastro); C20 |
| texto | research R13 e `plan.md` (item 14): "dois passos" corrigido para três; `tasks.md` T063 |

---

## 4. Cenários de ataque para o QA

Cada um com o defeito a injetar. Relógio sempre fixado por `agora` (L46); dois operadores
povoados quando o cenário toca concorrência.

| # | achado | cenário: quem, com o quê, esperando o quê | asserção (metade `refute`) | defeito a injetar |
|---|---|---|---|---|
| C1 | T1 | atacante com a senha certa envia 10 TOTP errados, avançando `agora` além da espera a cada vez; depois envia o **TOTP certo** | antes da 10ª, um código certo **é** aceito (a guarda de que mediu); depois da 10ª, o certo é recusado com `:invalid_credentials` e evento `:segundo_fator_travado`; `refute` sessão aberta | contar só em `failed_attempts`: o 11º passa e o teste reprova |
| C1b | T1 | quem só sabe o e-mail envia 10 senhas **erradas** com qualquer código | `second_factor_failures` continua 0; depois da espera, senha e TOTP certos entram | incrementar `second_factor_failures` antes de conferir a senha: a entrada legítima é recusada e o teste reprova |
| C2 | T2 | `gerar_codigos_de_recuperacao/0` | 10 códigos distintos; cada um decodifica para **16** bytes; `classificar/1` dá `:recuperacao` para 26 caracteres com e sem hífen, e `:malformado` para 16 | voltar a 10 bytes |
| C3 | marca d'água | celular adiantado: no passo `s`, o código de `s+1` é aceito; no passo `s+1`, o mesmo código de novo | o primeiro `{:ok, s+1}`; o segundo `{:error, :reusado}`; `totp_last_used_step == s+1` | gravar `div(agora, 30)` em vez do passo aceito: o segundo passa |
| C4 | janela | aceito o passo `s`, tenta-se o código de `s-1` ainda dentro da janela | `{:error, :reusado}` | trocar `<=` por `==` na regra de reuso |
| C5 | reuso concorrente | duas `Task` com senha e TOTP certos e iguais, sandbox compartilhado | exatamente uma `{:ok, _}` (as duas contadas, L90) | decidir pelo `ultimo_passo` de um struct lido **antes** do `FOR UPDATE` |
| C6 | revogação no meio | `definir_senha/3` ok → `revogar/3` → `confirmar_segundo_fator/3` com código de cadastro e TOTP certos; depois `conceder/3` e o mesmo par antigo | os dois recusados; `refute` `totp_confirmed_at`; depois da nova concessão `totp_secret` é nulo | `revogar/3` sem anular `enrollment_code_hash` **e** `confirmar` sem exigir concessão (um por vez) |
| C7 | reinício no meio | o mesmo de C6 com `reiniciar_credencial/2` no lugar de `revogar/3` | o código de cadastro antigo é recusado | `reiniciar_credencial/2` sem anular o código de cadastro |
| C8 | exibição única, T5 | percorrer os três passos pelo `ConnCase`, e as recusas: TOTP errado no passo 2, passo 3 sem a caixa e com código de guarda errado | as respostas de sucesso dos passos 1 e 2 são `200` (não `302`) e trazem `cache-control: no-store`; `refute` o segredo base32, a URI e os códigos em `get_session(conn)`, no flash, em `Location` e no corpo de qualquer `GET` seguinte; `refute` o segredo no corpo da recusa do passo 2 e os códigos no corpo das recusas do passo 3; `assert` que a recusa do passo 2 traz o `enrollment_token` de volta (a guarda) | `put_flash(:info, codigos)` + `redirect`; e, separado, re-renderizar a recusa do passo 3 com os códigos |
| C9 | log | `capture_log` em toda a definição, confirmação, entrada aceita, recusada e com recuperação | `refute log =~` para o segredo base32, a URI, o código TOTP, cada código de recuperação, o código de definição e o de cadastro; e `assert log =~` o evento (a guarda) | `Logger.warning(inspect(Segredo.expor(...)))` no cadastro |
| C10 | T3 | cifrar com a chave A, rotacionar para B, remover A, e entrar | o operador entra com o TOTP; a tarefa reporta a contagem de `platform_operators` | tirar `platform_operators` da tarefa: a entrada falha |
| C11 | T6 | `classificar/1` com `"١٢٣٤٥٦"` (dígitos arábico-índicos), `"12345６"`, `"123456\n"`, e um código de recuperação válido com uma letra trocada pelo sinal de Kelvin (`U+212A`); e um válido com hífens e maiúsculas (a guarda) | os quatro primeiros `:malformado`; o último `:recuperacao` | `\d` com a flag `u`; `$` no lugar de `\z`; `String.downcase/1` Unicode antes da conferência (um por vez) |
| C12 | consumo | senha **errada** + código de recuperação válido; depois, sem concessão vigente + senha certa + código válido | nos dois, `refute` `used_at` preenchido; o código ainda entra depois, com tudo certo | consumir o código antes de conferir a senha (ou a concessão) |
| C13 | T4 | `OperatorScope` atribui `:current_operator` | `current_operator.totp_secret` é `nil` (não carregado), e a entrada com o TOTP certo continua aceita (a guarda: `Credentials` o lê por `select`) | retirar `load_in_query: false` |
| C14 | código de guarda, colunas separadas | com o passo 1 feito, `concluir_cadastro/2` com o `enrollment_token` válido; depois do passo 2, `concluir_cadastro/2` com o `enrollment_token` já usado | as duas recusas únicas; `refute` `totp_confirmed_at`; `ack_code_hash` intacto na segunda; `autenticar/3` continua recusando | conferir o código de guarda contra `enrollment_code_hash` (reaproveitar a coluna) |
| C15 | A5 no passo 3 | duas `Task` com o mesmo `acknowledgement_token`, sandbox compartilhado | exatamente uma `{:ok, _}` e uma `{:error, :invalid_credentials}` (as duas contadas, L90); `ack_code_hash` nulo; `password_epoch` subiu **uma** vez | conferir o resumo em memória e anular depois, sem `FOR UPDATE` (já em T027) |
| C16 | validade do código de guarda | passo 2 em `agora`; passo 3 em `agora + 10 min + 1 s` com o código certo; depois `reiniciar_credencial/2` e os três passos de novo (a guarda) | a primeira recusa única e `refute` `totp_confirmed_at`; o refeito entra | retirar a conferência de `ack_code_expires_at` |
| C17 | a caixa | `POST /platform/setup/recovery-codes` sem `codes_stored`, e com `codes_stored=false`; depois com `"true"` | nos dois primeiros: `ack_code_hash` igual ao de antes, `failed_attempts` igual, nenhum evento de recusa, nenhum código de recuperação no corpo; o terceiro conclui (a guarda) | o controller chamar `concluir_cadastro/2` sem conferir a caixa, ou conferir só a presença do campo |
| C18 | revogação e reinício entre 2 e 3 | passo 2 ok → `revogar/3` (e, em outro caso, `reiniciar_credencial/2`) → `concluir_cadastro/2` com o código de guarda certo | recusa única; `refute` `totp_confirmed_at`; `ack_code_hash` nulo depois do ato; nenhum código de recuperação vale em `autenticar/3` | `revogar/3` (ou `reiniciar_credencial/2`) sem anular `ack_code_hash` |
| C19 | passo 3 repetido | `concluir_cadastro/2` duas vezes, em sequência, com o mesmo código | a segunda recusa única; `password_epoch` e as sessões não mudam na segunda | não anular o código de guarda no sucesso: a transação precisa **levantar** pelo `CHECK` do código de guarda (`data-model.md` §1), e o teste afirma isso — é a prova de que o `CHECK` existe |
| C20 | T12 | com o passo 1 feito, 10 TOTP errados no passo 2, avançando `agora` além da espera; depois o TOTP certo **antes** dos 10 min; e, noutro caso, depois deles | `second_factor_failures` continua 0 e `failed_attempts` subiu; o certo antes do vencimento **passa** (a guarda); depois do vencimento, recusa única, e `enrollment_code_expires_at` não foi prorrogado | prorrogar a validade a cada falha; e, separado, consumir o código de cadastro no TOTP errado (o certo dentro do prazo reprova) |
| C21 | A3 nos passos 2 e 3 | e-mail inexistente; operador com código de cadastro errado; operador com código de guarda errado; operador em espera | cada recusa passou por `Bcrypt.no_user_verify/0` uma vez (contagem por `:telemetry`, não cronômetro, como T025) | retirar o hash do ramo "código errado" de um dos dois passos |

---

## 5. Perguntas para a pessoa mantenedora

1. **T1 — o limite próprio do segundo fator trava até o reinício, ou só alonga a espera?**
   (a) trava em 10 falhas consecutivas com senha certa, e a saída é `reiniciar_credencial_do_operador`
   pelo Dokploy; (b) a espera do segundo fator sobe para 1 h em vez de 60 s (~2,6 % por ano para o
   atacante). **Recomendação: (a)**, que é a emenda aplicada. Não reabre o DoS que motivou "sem
   bloqueio de conta", porque só quem tem a senha alcança esse contador — e quem tem a senha **é** o
   incidente, cuja resposta já é o reinício. Se escolher (b), a emenda volta a T011.
2. **T2 — códigos de recuperação com 128 bits (26 caracteres), ou 80 bits com sal por código?**
   **Recomendação: 128 bits**, aplicada: a consulta continua por índice e o código ganha 10
   caracteres, digitados em emergência. O sal obrigaria a buscar e comparar as 10 linhas do operador.
3. **T3 — abrir já a issue `bug`+`security` para `mix the_band.rotate_key` recifrar também
   `ai_provider_credentials.secret`?** É defeito de hoje, fora da 070. **Recomendação: sim, separada**,
   e pela regra de "corrigir antes de implementar" ela vem antes da 070 na mesma superfície (Cloak).
   Fica também a pergunta de como a tarefa roda em produção, sendo `Mix.Task` numa release.

### Decisões da pessoa mantenedora, 2026-10-01

| pergunta | decisão | onde está aplicada |
|---|---|---|
| **T1** | **(a) travar até o reinício pelo comando**: 10 falhas consecutivas do segundo fator com a senha certa travam a entrada até `Release.reiniciar_credencial_do_operador/2` | já emendada (§3): `contracts/credenciais-do-operador.md` ("limite próprio do segundo fator"), `data-model.md` §1 (`second_factor_failures`), `contracts/concessao-do-operador.md` (A6 zera), `contracts/eventos-de-acesso.md` (`operador_segundo_fator_travado`); prova em T028a, bloqueante de T036 e T039 |
| **T2** | **128 bits, 26 caracteres** (16 bytes em base32 sem padding, hífen a cada 4) | já aplicada (§3): `contracts/segundo-fator-do-operador.md` (parâmetros, `classificar/1`, `resumo/1`) |
| **T3** | **issue separada da 070**: [#1052](https://github.com/The-Band-Solution/theband/issues/1052) aberta (`bug` + `security`), para `mix the_band.rotate_key` recifrar **todos** os campos cifrados, inclusive `ai_provider_credentials.secret`, que é o defeito de hoje. O `platform_operators.totp_secret` entra **na mesma lista** pela T021 da 070 | `tasks.md` T021 (com o cenário C10); pela regra de corrigir antes de implementar, a #1052 vem antes da 070 na mesma superfície (Cloak), e T3 continua bloqueando a **release** da 070 |

---

## 6. O que NÃO foi verificado

**Na reconferência de T011 (2026-10-01)**: nada foi executado — os cenários C14–C21 são de leitura
dos contratos; o protótipo foi lido só nas frases de recusa (`prototipo/PROMPT.md` 3.8 e 3.14), e
não o HTML; a contagem de ~16 tentativas em C20/T12 é aritmética sobre `auth.ex:36-37,162-165`
de hoje, e a cópia em `Credentials` nasce da versão corrigida pela #1046, que pode mudar as
constantes; não foi verificado se `Plug.Conn` guarda os `assigns` de uma resposta renderizada em
algum lugar além do processo (T5 supõe que não); e não foi verificado que `load_in_query: false`
funciona com `Cloak.Ecto` 1.x no `select` explícito (T4 supõe que sim; C13 tem a guarda).

Da avaliação original (T010):

- **Nada foi executado**: nem os vetores do RFC 6238 contra a NimbleTOTP (só li o truncamento),
  nem os cenários acima, nem `mix gates`. Toda afirmação de "correto" acima é de leitura;
- o **checksum** do pacote baixado contra o `mix.lock` que T022 vai gravar (T009 mediu o `hex.audit`;
  a integridade do tarball ficou com o `hex`);
- os commits **não publicados** do repositório da NimbleTOTP (2025-11 e 2026-04): li só o 1.0.0;
- o comportamento do Cloak ao **falhar a decifragem** no carregamento (exceção, e o que ela imprime)
  — relevante para T3 e para o evento "falha de decifragem" que A09 pede;
- se `put_flash` no `/platform` cai mesmo no cookie `_the_band_key` (deduzido de research R3.2 e
  `fetch_session` na pipeline; não li `endpoint.ex`);
- o NTP do VPS de produção (T11), e se a tarefa de rotação roda numa release (T3);
- a forma final de `Tenants.Auth` depois dos PRs #1048 e #1049, que `Credentials` copia;
- as telas: `prototipo/` não foi lida (T012, outro agente); campo com `autocomplete="one-time-code"`,
  ausência de JS de terceiros e de QR por serviço externo ficam para a conferência do protótipo;
- `lib/the_band/tenants/access_events.ex:43-48`, citado pelo contrato de eventos como a regra de não
  logar segredo, não foi relido.
