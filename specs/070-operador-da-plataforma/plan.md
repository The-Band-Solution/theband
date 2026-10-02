# Implementation Plan: o operador da plataforma — suspender e reativar uma organização

**Branch**: `070-operador-da-plataforma` · **Spec**: [spec.md](spec.md) · **Data**: 2026-10-01

**Segurança**: [seguranca.md](seguranca.md) · **Research**: [research.md](research.md) ·
**Modelo**: [data-model.md](data-model.md) · **Contratos**: [contracts/](contracts/) ·
**Validação**: [quickstart.md](quickstart.md)

---

## Gate de segurança, antes de qualquer código

**A segunda autenticação precisa de avaliação própria do agente `security`, feita por quem não
escreveu este desenho, antes de qualquer linha em `lib/` ou `test/`.**

A pessoa mantenedora escolheu a entidade separada (b) **contra** a recomendação (a) da avaliação, e
a própria avaliação registrou o preço: *"nasce uma segunda autenticação, que precisa de avaliação
própria no plano"* (seguranca.md, "Decisões"). Este plano desenhou essa autenticação. Ele **não** a
avaliou, e o autor do desenho não pode ser quem a avalia (CLAUDE.md, AGENTS.md §14.0).

O que a avaliação precisa cobrir, no mínimo:

| item | onde está o desenho |
|---|---|
| o código de definição impresso pelo comando, e onde ele fica depois | research R1; `contracts/concessao-do-operador.md` |
| armazenamento da senha e a espera crescente, duplicadas de `Tenants.Auth` | research R2; `contracts/credenciais-do-operador.md` |
| a sessão de 8 h, a concessão lida na conferência, a retenção | research R3.1; `contracts/sessao-do-operador.md` |
| o cookie próprio: cifrado, `Path=/platform`, `SameSite=Strict` | research R3.2 |
| o `404` sem redirecionamento, e a página de entrada pública | research R4; `contracts/rotas-da-plataforma.md` |
| a ausência de segundo fator (O16) | **decidida**: TOTP nesta feature (FR-016, pergunta 2); avaliação própria em T010 |
| a lacuna do LiveView aberto depois do `ended_at` | **resolvida pelo #1044**, já em `development` (A2, research R9; pergunta 3) |

**Como o gate se fecha**: um arquivo `seguranca-autenticacao.md` nesta pasta, com achados e
veredito. Achado alto ou crítico vira tarefa bloqueante do que depende dele.

**Estado do gate em 2026-10-01: fechado para o desenho, com emendas.**
[seguranca-autenticacao.md](seguranca-autenticacao.md) deu o veredito "pode seguir para
`tasks.md`, com as emendas da §4", e as emendas entraram nos contratos, no `data-model.md` e no
`research.md` no mesmo dia:

| achado | sev. | emenda | onde |
|---|---|---|---|
| A1 | alta | tentativa serializada por `FOR UPDATE`, na forma da #1046 | `contracts/credenciais-do-operador.md`; research R2 |
| A2 | alta | `Sessions.avisar_encerramento({:sessao, id})` depois do `commit`, em `suspender/3` e `reativar/3`; `live_socket_id` retirado de R9; a pergunta 3 sai | `contracts/suspensao.md`, `contracts/sessoes-e-tokens-da-organizacao.md`; research R9 |
| A3 | média | o custo do hash também na espera, na forma da #1047 | `contracts/credenciais-do-operador.md` |
| A5 | média | consumo atômico do código de definição e do de cadastro | `contracts/credenciais-do-operador.md` |
| A6 | média | conceder de novo apaga senha, segundo fator, sobe a época e encerra as sessões | `contracts/concessao-do-operador.md` |
| A9 | média | lista permitida por rota, e asserção sobre `"users"` no SQL | research R10 |
| A7, A10–A15 | média e baixa | eventos da definição; nomes de campo; `last_seen_at`; curinga do `404`; triggers; definição exige concessão; `FOR SHARE` na sessão | contratos e `data-model.md` |

**O código ficou bloqueado** pelo que a avaliação não podia fechar sozinha: a avaliação
**própria do TOTP** (FR-016 nasceu depois dela; **feita** em 2026-10-01, `seguranca-totp.md`, T010 e
T011), as correções em `Tenants.Auth` que a cópia espera (#1048 e #1049, **os dois mergeados** em
2026-10-01), e o protótipo da tela (**aprovado** em 2026-10-01, T012). Continua aberto, na mesma
superfície do segredo em repouso, a #1052 (PR #1053): a rotação da chave mestra recifra todos os
campos cifrados, e o `totp_secret` do operador entra nessa lista (seguranca-totp.md, T3). O
`tasks.md` tem cada um como tarefa bloqueante, com `Pronta quando` citando o achado.

Pré-requisitos de código, pela regra "corrigir antes de implementar":

| pré-requisito | estado em 2026-10-01 (`gh pr view`) |
|---|---|
| #1033, `Tenants.ensure_active/1` (FR-012), **PR #1038** | **mergeado** |
| #1034, `Access.operacional?/2` compara o tenant (O5, I5), **PR #1039** | **mergeado** |
| #1035, `ApiTokens.criar/4` confere o dono (O15), **PR #1040** | **mergeado** |
| #1042, a tela aberta cai quando a sessão é encerrada (A2), **PR #1044** | **mergeado**; `avisar_encerramento/1` em `lib/the_band/tenants/sessions.ex:146-149` de `development` |
| #1046, a espera crescente sob concorrência (A1), **PR #1048** | **mergeado** (2026-10-01) |
| #1047, a espera paga o custo do hash (A3), **PR #1049** (branch `fix/1047-espera-paga-o-hash`) | **mergeado** (2026-10-01, `gh pr view 1049`) |
| #1050, o giro operacional com a aplicação no ar roda pelo nó que serve, e derruba as telas abertas, **PR #1051** | **mergeado** (2026-10-01); criou `Release.girar_sessoes/0`, por `rpc` (`release.ex:139-145` de `development`), que a T032 estende |
| #1052, a rotação da chave mestra recifra **todos** os campos cifrados (T3 de seguranca-totp.md), **PR #1053** | **aberto** (2026-10-01). Bloqueia T021, que acrescenta `platform_operators.totp_secret` à lista da rotação, e a release da 070 (T064, C10 verde) |
| forma da área do operador (pergunta 1, T005) | **decidida** em 2026-10-01: controllers + cookie próprio; FR-011 emendada (commit `61d6098`) |
| medir se o Traefik do Dokploy sobrescreve `x-forwarded-for` (A4, decisão 2) | **não medido**; dono: pessoa mantenedora, com acesso ao servidor. Bloqueia só o limite por IP |

## A tela, antes do código

A tela do operador **precisa de protótipo do agente Design**, publicado e guardado na spec com o
prompt e as decisões, **antes** de qualquer controller ou template. Este plano não desenha pixel.
O que ele fixa para o protótipo (aprovado em 2026-10-01, T012): cinco telas (entrada com segundo fator, definição de senha,
cadastro do segundo fator com os códigos de recuperação, lista, histórico com o ato), as colunas
da FR-007, a ausência de episódio escrita com `<.absent>`, as razões vindas da
base, e a interface em inglês.

---

## Summary

A spec pede que uma pessoa **acima das organizações** suspenda e reative uma organização, com razão
registrada, e que suspender derrube de verdade as sessões e os tokens. A decisão de 2026-10-01 fez
dessa pessoa uma **entidade separada de `users`**, e é ela que dá a forma do plano:

- `TheBand.Platform`, um contexto novo, com operador, concessão, sessão e episódio de suspensão;
- uma **segunda autenticação**, que reaproveita as decisões da primeira e não o código, e que entra
  por um código de definição de uso único, nunca por senha em comando;
- uma área `/platform` com pipeline, plug e cookie próprios, que responde `404` a quem não é
  operador e nunca passa pelo leitor de sessão das organizações;
- a suspensão como **uma transação** que muda o estado, abre o episódio, encerra as sessões e
  revoga os tokens da organização, e a reativação que fecha o episódio e encerra as sessões de novo.

`users`, `user_sessions` e o caminho de domínio **não mudam** (FR-011).

## Technical Context

| | |
|---|---|
| **Linguagem** | Elixir, Phoenix 1.8.11, LiveView 1.2.9, Plug 1.20.3 (`mix.lock:47`, `:52`, `:55`) |
| **Persistência** | PostgreSQL; **quatro** tabelas novas sem `tenant_id` (`platform_operators`, `platform_operator_grants`, `platform_operator_sessions` e `platform_operator_recovery_codes`; a exceção da FR-011), uma com (`tenant_suspensions`) |
| **Hash de senha** | `bcrypt_elixir 3.3.2` (`mix.lock:3`), já na base |
| **Resumo de token e de código** | `:crypto.hash(:sha256, …)` com `Plug.Crypto.secure_compare/2`, como `sessions.ex:233-237` e `:250` de `development` (`a16a750`) |
| **Executor** | Oban; nenhum worker novo. A retenção entra no `ApagaSessoesAntigas` |
| **Dependência nova** | **`{:nimble_totp, "== 1.0.0"}`** (decidida por T009, 2026-10-01; research R13). Dashbit, publicada por José Valim, Apache-2.0, **zero dependências transitivas** (o `mix.lock` ganha uma linha só), 4,1 milhões de downloads; 1.0.0 é de 2023-03-21 e o repositório segue ativo (último commit 2026-04-07). `mix hex.audit` → código 0, saída **idêntica** à da `development` sem ela (só as duas advisories de `cowlib` já ignoradas); `mix deps.audit` → código 0, "No vulnerabilities found". Fixada com `==`, e não `~>`, pela mesma razão de `ex_mcp`: versão nova só entra com a auditoria refeita. *Problema*: FR-016 exige o código RFC 6238 (HMAC-SHA1, truncamento dinâmico, comparação em tempo constante) e a URI `otpauth://`; errar o truncamento ou comparar com `==` é defeito de segurança silencioso, que os vetores do apêndice B pegam só em parte. *Agora ou previsão*: agora — FR-016 decidida em 2026-10-01, e T022 precisa dela. *O que piora*: uma dependência a mais na cadeia de suprimento, sem release desde 2023 (advisory nova dependeria do mantenedor ou de fork); a janela ±1 continua **nossa** (`valid?/3` confere um instante só: são três chamadas, `agora - 30`, `agora`, `agora + 30`); e `:since` é um **instante**, não um passo, então `totp_last_used_step` é traduzido como `since: ultimo_passo * 30`. **Sem QR code** na primeira forma: recomendação de T009, decisão da pessoa mantenedora (research R13) |
| **Segredo em repouso** | o segredo TOTP, cifrado por `TheBand.Encrypted.Binary` (Cloak, já na base: `mix.lock:7-8`) |
| **Escala** | uma ou duas pessoas operadoras por instalação; sem paginação (spec, Assumptions) |
| **O que verifica** | `mix gates`, pelo código de saída |

**Nenhum NEEDS CLARIFICATION técnico**: a implementação do TOTP foi decidida por T009 (NimbleTOTP
1.0.0, acima). As perguntas de decisão estão todas decididas ou respondidas (a 1, controller, em
2026-10-01); estão no fim.

## Constitution Check

| princípio | como este plano o satisfaz |
|---|---|
| **I, II, IV** | nenhuma ontologia muda. As razões de suspensão são **vocabulário declarado** na base, `platform.tenant_suspension`, e não constante de módulo |
| **III — proveniência** | o episódio guarda autor, instante e razão; a concessão guarda o autor **declarado**, com o nome dizendo isso |
| **V — multitenant** | o operador não tem tenant e **não alcança** caminho de domínio: tipo próprio, cookie com `Path=/platform`, leitor próprio. A guarda de telemetria (R10) prova que nenhuma consulta de domínio roda nas rotas dele. `encerrar_da_organizacao/1` recebe `%Tenant{}` |
| **X, letra D — depender da fronteira, nunca da tabela** | `Platform.Suspensions` **não lê nem escreve `tenants`**: a troca de estado é `Tenants.trocar_estado_no_multi/5`, um passo que entra no `Multi` da suspensão, e a lista lê `Tenants.resumos_para_a_plataforma/0`, com `select` das quatro colunas permitidas (`contracts/sessoes-e-tokens-da-organizacao.md`). Sem exceção (achado D1 do `/speckit-analyze`, 2026-10-01) |
| **VI — contrato antes** | oito contratos em `contracts/`, cada um com o que **não** expõe; emendados em 2026-10-01 pela avaliação da segunda autenticação e pelo TOTP, antes de qualquer código |
| **VII — revisão independente** | o gate de segurança acima; nenhuma tarefa da segunda autenticação antes dele |
| **VIII — desenho justificado** | o registro abaixo |
| **X — responsabilidade única** | credencial, sessão, concessão e suspensão em módulos separados; cookie separado da linha; cinco telas de uma pergunta cada |
| **XI — sinal nunca silenciado** | a migração do `CHECK` **levanta** com valor desconhecido em vez de mapear; base ausente faz o ato recusar |

**Desvios declarados de `AGENTS.md` §7.3**: as tabelas `platform_*` e `tenant_suspensions` não têm
`internal_id` nem `record_version`, como `user_sessions` e `api_access_tokens` também não, porque
não são registro de domínio. E as **quatro** `platform_*` não têm `tenant_id`, que é a FR-011:
`platform_operators`, `platform_operator_grants`, `platform_operator_sessions` e
`platform_operator_recovery_codes` (a quarta é do segundo fator, FR-016, e pertence ao operador,
que não tem organização).

**Desvio declarado de `AGENTS.md` §8**: a regra nova não tem schema em `schemas/`, como nenhuma
`derivation_rule` hoje tem; o validador confere id e proveniência (`yaml_validator.ex:476-481`).
Criar o schema das regras é trabalho de outra feature.

### Registro das decisões de desenho (princípio VIII)

**1. Contexto `TheBand.Platform`, fora de `TheBand.Tenants`**

- *Problema*: a FR-011 exige que o operador não alcance nenhum caminho de domínio. Em `Tenants`, as
  funções do operador morariam ao lado das que recebem `%User{}` e `%Tenant{}`, e a fronteira
  seria convenção.
- *Existe agora?* Sim: é a decisão de 2026-10-01.
- *O que piora*: um contexto a mais, e `Platform.Suspensions` precisa de funções públicas novas
  de `Tenants` em vez de chamar o `Repo` dele (`contracts/sessoes-e-tokens-da-organizacao.md`):
  `Tenants.trocar_estado_no_multi/5` e as leituras `resumos_para_a_plataforma/0` e
  `resumo_para_a_plataforma/1` em `TheBand.Tenants`, `encerrar_da_organizacao/1` em
  `Tenants.Sessions`, `revogar_por_suspensao/2` e `clausulas_registradas/0` em `Tenants.ApiTokens`.
  É o que a constituição exige (princípio X, letra D), e a lista **não tem exceção**: a versão
  anterior do contrato deixava a escrita de `tenants.status` e um `LEFT JOIN LATERAL` sobre
  `tenants` dentro de `Platform.Suspensions`, e o `/speckit-analyze` o apontou (D1). A lista
  ganha duas consultas em vez de uma, compostas em memória pelo `id`.

**2. Fachada com `defdelegate` em `TheBand.Platform`**: padrão da tabela de `AGENTS.md` §7.7, usado
para o problema dele: a fronteira verificável em revisão.

**3. Segunda autenticação duplicada, e não extraída** (research R2)

- *Problema*: o operador precisa de senha, tempo constante e espera crescente.
- *Existe agora?* Sim, e é a **segunda** ocorrência.
- *O que piora*: cerca de trinta linhas em dois lugares, que podem divergir. O teste de paridade
  segura as constantes.

**4. Código de definição impresso pelo comando** (research R1)

- *Problema*: O4 e O11; a senha não pode passar por argumento nem por ambiente.
- *Existe agora?* Sim.
- *O que piora*: o código aparece uma vez no terminal do Dokploy, que pode guardá-lo (**não
  verificado**). Vale 30 minutos e uma vez.

**5. Cookie próprio e telas por controller** (research R3.2) — **decidido** (pergunta 1, T005)

- *Problema*: o socket do LiveView só lê o `Plug.Session`
  (`deps/phoenix/lib/phoenix/socket/transport.ex:278-286`), e a saída de domínio apaga o cookie
  inteiro (`session_controller.ex:47` de `development`).
- *Existe agora?* Sim, os dois fatos estão no código.
- *O que piora*: recarga por ação. A FR-011 dizia `live_session`, e foi emendada para "pipeline,
  plug e cookie próprios" (commit `61d6098`).

**6. Relator para a concessão, e não coluna**: padrão "Relator" de §7.7, usado para o problema dele:
papel com período e autor. Uma coluna perderia quem concedeu, quando, e a revogação.

**7. Episódio de suspensão com índice único parcial**: a forma de `account_disablements`
(`20260910050000_episodio_de_desativacao.exs:93-96`), pelo mesmo problema: um aberto, histórico
livre.

**8. Triggers que impedem apagar e reescrever** (research R7)

- *Problema*: FR-002 e O11 pedem garantia além da ausência de função.
- *Existe agora?* Sim: as tabelas nascem aqui, com o requisito escrito.
- *O que piora*: **é o primeiro trigger da base**; invisível a quem lê Elixir; não protege de quem
  tem o banco. Medido: nenhuma migração usa trigger hoje.

**9. `CHECK` em `tenants.status`, e `:status` fora do `cast`** (research R6): é a regra de §7.3
("constraint de verdade no banco e validação no changeset") aplicada onde faltava. Piora: dois
testes que suspendem pelo changeset precisam mudar.

**10. `Ecto.Multi` com passos nomeados** (research R8)

- *Problema*: seis escritas que só valem juntas, e o teste precisa afirmar **qual** recusou. É
  também o que permite a escrita do estado ficar em `Tenants` (D1): `trocar_estado_no_multi/5`
  devolve o `Multi` com o passo, e não abre transação própria.
- *Existe agora?* Sim.
- *O que piora*: nada que `Repo.transaction/1` não tenha; a casa usa os dois.

**11. `FOR SHARE` na concessão dentro da suspensão** (research R8)

- *Problema*: O6, a revogação concorrente com um ato em voo.
- *Existe agora?* Sim, é a FR-014.
- *O que piora*: um lock de linha a mais, numa tabela de uma ou duas linhas.

**12. Coluna `revoked_by_suspension_id` e cláusula só registrada**

- *Problema*: `revoked_by_user_id` é FK para `users`, e o operador não está lá.
- *Existe agora?* Sim (`20260918140000_tokens_de_api.exs:72`).
- *O que piora*: uma coluna e dois `CHECK` em `api_access_tokens`, e a tela de tokens aprende a
  escrever um autor que não é conta.

**14. Segundo fator TOTP no próprio contexto** (research R13; `contracts/segundo-fator-do-operador.md`)

- *Problema*: FR-016, decisão de 2026-10-01; a conta mais poderosa protegida só por senha (O16, A16).
- *Existe agora?* Sim.
- *O que piora*: um segredo a mais em repouso, a dependência `nimble_totp 1.0.0` (Technical Context), **três** passos de definição
  (emenda T012, Q3 (b)) que podem ser abandonados no meio, e as telas de cadastro do segundo fator (protótipo T012). `SegundoFator` é de funções puras, e quem
  grava é `Credentials`, na transação com `FOR UPDATE`.

**15. O aviso às telas abertas é o do #1044, por id** (research R9, A2)

- *Problema*: `ended_at` sozinho não derruba a aba já conectada.
- *Existe agora?* Sim; o #1044 já tem o mecanismo.
- *O que piora*: uma publicação por sessão encerrada depois do `commit`. Um tópico por organização
  seria uma publicação só, e alargaria o que cada socket escuta.

**13. Guarda de telemetria com lista permitida** (research R10)

- *Problema*: SC-003 pede provar que o operador não lê domínio, e uma lista proibida não pega a
  tabela de domínio que nascer depois.
- *Existe agora?* Sim.
- *O que piora*: o teste precisa filtrar pelo processo, e a lista permitida muda quando a área do
  operador ganhar uma leitura nova, o que é o objetivo.

## Project Structure

### Documentação

```text
specs/070-operador-da-plataforma/
├── spec.md
├── seguranca.md                 # avaliação antes do plano
├── seguranca-autenticacao.md    # o gate da segunda autenticação, escrito; A1–A17
├── seguranca-totp.md            # [gate TOTP] escrito em 2026-10-01 pelo agente security (T010, T011)
├── tasks.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── prototipo/                   # do agente Design; aprovado em 2026-10-01 (T012)
└── contracts/
    ├── credenciais-do-operador.md
    ├── sessao-do-operador.md
    ├── concessao-do-operador.md
    ├── suspensao.md
    ├── sessoes-e-tokens-da-organizacao.md
    ├── rotas-da-plataforma.md
    ├── segundo-fator-do-operador.md
    └── eventos-de-acesso.md
```

### Código

```text
lib/the_band/platform.ex                         # fachada, defdelegate
lib/the_band/platform/operator.ex                # schema platform_operators
lib/the_band/platform/grant.ex                   # schema platform_operator_grants
lib/the_band/platform/operator_session.ex        # schema platform_operator_sessions
lib/the_band/platform/suspension.ex              # schema tenant_suspensions
lib/the_band/platform/recovery_code.ex           # schema platform_operator_recovery_codes
lib/the_band/platform/credentials.ex             # a segunda autenticação          [gate]
lib/the_band/platform/segundo_fator.ex           # TOTP, funções puras             [gate TOTP]
lib/the_band/platform/sessions.ex                # a linha da sessão                [gate]
lib/the_band/platform/grants.ex                  # conceder, reiniciar, revogar     [gate]
lib/the_band/platform/suspensions.ex             # listar, suspender, reativar
lib/the_band/platform/suspension_reasons.ex      # leitor da base
lib/the_band/tenants.ex                          # + trocar_estado_no_multi/5, resumos_para_a_plataforma/0, resumo_para_a_plataforma/1 (D1)
lib/the_band/tenants/tenant.ex                   # :status fora do cast, CHECK
lib/the_band/tenants/sessions.ex                 # + encerrar_da_organizacao/1
lib/the_band/tenants/api_tokens.ex               # + revogar_por_suspensao/2, clausulas_registradas/0
lib/the_band/tenants/access_events.ex            # + eventos de plataforma
lib/the_band/jobs/apaga_sessoes_antigas.ex       # + sessões do operador
lib/the_band/release.ex                          # + três comandos; encerrar_todas_as_sessoes/0 e girar_sessoes/0 encerram também as do operador  [gate]
lib/mix/tasks/the_band.rotate_key.ex             # + platform_operators.totp_secret na lista da #1052 (T3)
lib/the_band_web/router.ex                       # :plataforma, scope /platform, CSP num atributo
lib/the_band_web/plataforma/sessao_do_operador.ex                                   [gate]
lib/the_band_web/plataforma/operator_scope.ex    # plug + require_operator          [gate]
lib/the_band_web/controllers/plataforma/*        # cinco telas                      [protótipo]
config/config.exs                                # :operator_id no formatador; filter_parameters (A10)
priv/repo/migrations/<ts>_operador_da_plataforma.exs
priv/repo/migrations/<ts>_segundo_fator_do_operador.exs
priv/repo/migrations/<ts>_episodio_de_suspensao.exs
priv/repo/migrations/<ts>_estado_da_organizacao_valido.exs
priv/knowledge_base/rules/platform_tenant_suspension.yaml
priv/knowledge_base/rules/api_access_thresholds.yaml   # + clausulas_so_registradas
test/the_band/platform/…
test/the_band_web/plataforma/…
test/the_band_web/plataforma/operador_nao_le_dominio_test.exs   # SC-003, telemetria
```

**Structure Decision**: o monólito de sempre. Um contexto novo em `lib/the_band/platform/`, a web
em `lib/the_band_web/plataforma/` e `controllers/plataforma/`, e nada em `ontology/`.

## Riscos

| risco | mitigação |
|---|---|
| ordem das migrações com a #879, que altera `users` | esta feature não toca `users`; gerar as migrações depois de rebasear sobre `development` (research R11) |
| organização em produção com `status` fora da lista | a migração levanta com a contagem; a skill `release` mede antes |
| organização já `suspended` em produção sem episódio | a migração cria episódio `not_recorded`, sem autor |
| o LiveView aberto de domínio continua depois do `ended_at` | **fechado pelo desenho**: o aviso do #1044 depois do `commit` (A2, research R9) |
| o código de definição no histórico do terminal do Dokploy | 30 min, uso único e consumo atômico (A5); não verificado se o Dokploy guarda. **A17**: o runbook diz que a pessoa operadora roda o comando ela mesma, ou recebe o código por voz, nunca por chat |
| conta do operador tomada derruba a disponibilidade de todas as organizações | O16 e A16: **reduzido** pelo TOTP (FR-016); o resto é o aparelho do segundo fator, e entra na nota da release |
| **A8**, XSS de domínio usa o cookie do operador pela mesma origem | **risco residual declarado** (decisão 3 da pessoa mantenedora): a CSP é a defesa; host próprio quando `theband.dev` entrar em produção |
| **A4**, sem limite por IP, e negação de serviço do operador pela espera | depende da medição do Traefik (decisão 2); sem ela, fica a espera por conta, e o risco vai para a nota da release |
| **T9** (seguranca-totp.md): (a) código de recuperação dá entrada mas não revoga o aparelho perdido, cujo segredo continua valendo; (b) não há notificação ao operador na troca de fator nem no reuso (ASVS V2.5.5, V2.8.5) | (a) o roteiro (T059) diz que aparelho perdido é **reinício pelo comando**, mesmo havendo códigos; (b) **risco residual declarado**: o sinal é o evento em `:warning` (`operador_recuperacao_usada`, `operador_entrada_recusada` com `:segundo_fator_reusado`), e entra na nota da release (T062) |
| **T10**: TOTP não resiste a phishing em tempo real (proxy reverso que repassa senha e código em menos de 90 s) | **risco residual declarado**: aceitável em ASVS L2; WebAuthn seria a feature seguinte, com spec própria. Entra na nota da release (T062) |
| **T11**: o relógio do servidor decide a janela ±1; deriva acima de 30 s recusa todo código e, com T1, trava o segundo fator em 10 tentativas | o NTP do VPS **não foi verificado**; o roteiro (T059) manda conferir `timedatectl` antes da primeira concessão, e a nota da release (T062) registra a medição |
| A1 e A3 existiam em `Tenants.Auth` | issues #1046 (PR #1048) e #1047 (PR #1049), **as duas mergeadas** em 2026-10-01, **antes** desta feature; a cópia nasce da versão corrigida |
| **T3** (seguranca-totp.md): a rotação da chave mestra não alcança `totp_secret`, e o mesmo defeito existe hoje em `ai_provider_credentials.secret` | issue #1052, PR #1053 (**aberto**), corrigida antes desta feature na mesma superfície; T021 acrescenta `totp_secret` à lista, e a release só sai com C10 verde (T023a, T064) |
| a cópia diverge da correção do original | o teste de paridade compara as constantes e a forma da serialização |

## Perguntas para a pessoa mantenedora

**1. A área do operador é por controller, com cookie próprio, em vez de `live_session`?** —
**decidida em 2026-10-01: controllers + cookie próprio** (T005; FR-011 emendada no commit
`61d6098`). O socket do LiveView só lê o cookie de sessão das organizações. Para ter
`live_session`, a sessão do operador teria de morar dentro desse cookie, chegando a toda rota de
domínio e caindo quando alguém sai da conta de organização no mesmo navegador. **A recomendação
era controller com cookie próprio** (research R3.2), e a palavra `live_session` da FR-011 virou
"pipeline, plug e cookie próprios". A avaliação da segunda autenticação concordou.

**2. Segundo fator** — **decidida em 2026-10-01: TOTP nesta feature** (FR-016). Desenho em research
R13 e `contracts/segundo-fator-do-operador.md`; a biblioteca, decidida por T009: NimbleTOTP 1.0.0
(Technical Context). QR code: recomendado não ter; decisão da pessoa mantenedora.

**3. A suspensão fecha os LiveViews abertos?** — **respondida pelo #1044** (A2). Sai das perguntas.

**4. IP do cliente** (A4, seguranca-autenticacao.md P2) — **decidida**: medir o Traefik, depois
`Plug.RewriteOn`. A medição é da pessoa mantenedora.

**5. Origem** (A8, P3) — **decidida**: mesma origem com CSP; host próprio depois.

## Complexity Tracking

| desvio | por que é necessário | alternativa mais simples recusada porque |
|---|---|---|
| segunda autenticação | decisão da pessoa mantenedora (FR-011) | reaproveitar `users` foi a opção (a), recusada em 2026-10-01 |
| primeiro trigger da base | FR-002 pede que o registro não se apague | só ausência de função não protege de `Repo.delete_all` em código novo |
| tabelas sem `tenant_id` | o operador não pertence a organização (FR-011) | tenant de plataforma (opção c) feria a US2, cenário 4 |

## Pós-desenho

O Constitution Check foi refeito depois de `data-model.md` e dos contratos, e nada mudou. Os dois
gates que este plano **não** fecha estão no topo: a avaliação de segurança da segunda autenticação e
o protótipo da tela.
