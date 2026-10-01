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
| a ausência de segundo fator (O16) | pergunta 2 |
| a lacuna do LiveView aberto depois do `ended_at` | research R9; pergunta 3 |

**Como o gate se fecha**: um arquivo `seguranca-autenticacao.md` nesta pasta, com achados e
veredito. Achado alto ou crítico vira tarefa bloqueante do que depende dele. Até lá, as tarefas
que tocam `Platform.Credentials`, `Platform.Sessions`, `Platform.Grants`, o cookie e as rotas ficam
**bloqueadas** no `tasks.md`.

E três pré-requisitos de código, pela regra "corrigir antes de implementar":

| pré-requisito | estado em 2026-10-01 |
|---|---|
| #1033, `Tenants.ensure_active/1` (FR-012), no **PR #1038** | **aberto**, não mergeado; `ensure_active/1` está em `lib/the_band/tenants.ex:88-90` só no commit `103d59e` |
| #1034, `Access.operacional?/2` compara o tenant (O5, I5) | aberta |
| #1035, `ApiTokens.criar/4` confere o dono (O15) | aberta |

## A tela, antes do código

A tela do operador **precisa de protótipo do agente Design**, publicado e guardado na spec com o
prompt e as decisões, **antes** de qualquer controller ou template. Este plano não desenha pixel.
O que ele fixa para o protótipo: quatro telas (entrada, definição de senha, lista, histórico com o
ato), as colunas da FR-007, a ausência de episódio escrita com `<.absent>`, as razões vindas da
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
| **Persistência** | PostgreSQL; três tabelas novas sem `tenant_id` (a exceção da FR-011), uma com |
| **Hash de senha** | `bcrypt_elixir 3.3.2` (`mix.lock:3`), já na base |
| **Resumo de token e de código** | `:crypto.hash(:sha256, …)` com `Plug.Crypto.secure_compare/2`, como `sessions.ex:201-218` |
| **Executor** | Oban; nenhum worker novo. A retenção entra no `ApagaSessoesAntigas` |
| **Dependência nova** | **nenhuma** |
| **Escala** | uma ou duas pessoas operadoras por instalação; sem paginação (spec, Assumptions) |
| **O que verifica** | `mix gates`, pelo código de saída |

**Nenhum NEEDS CLARIFICATION técnico**. Três perguntas de decisão ficam para a pessoa mantenedora,
no fim.

## Constitution Check

| princípio | como este plano o satisfaz |
|---|---|
| **I, II, IV** | nenhuma ontologia muda. As razões de suspensão são **vocabulário declarado** na base, `platform.tenant_suspension`, e não constante de módulo |
| **III — proveniência** | o episódio guarda autor, instante e razão; a concessão guarda o autor **declarado**, com o nome dizendo isso |
| **V — multitenant** | o operador não tem tenant e **não alcança** caminho de domínio: tipo próprio, cookie com `Path=/platform`, leitor próprio. A guarda de telemetria (R10) prova que nenhuma consulta de domínio roda nas rotas dele. `encerrar_da_organizacao/1` recebe `%Tenant{}` |
| **VI — contrato antes** | seis contratos em `contracts/`, cada um com o que **não** expõe |
| **VII — revisão independente** | o gate de segurança acima; nenhuma tarefa da segunda autenticação antes dele |
| **VIII — desenho justificado** | o registro abaixo |
| **X — responsabilidade única** | credencial, sessão, concessão e suspensão em módulos separados; cookie separado da linha; quatro telas de uma pergunta cada |
| **XI — sinal nunca silenciado** | a migração do `CHECK` **levanta** com valor desconhecido em vez de mapear; base ausente faz o ato recusar |

**Desvios declarados de `AGENTS.md` §7.3**: as tabelas `platform_*` e `tenant_suspensions` não têm
`internal_id` nem `record_version`, como `user_sessions` e `api_access_tokens` também não, porque
não são registro de domínio. E as três `platform_*` não têm `tenant_id`, que é a FR-011.

**Desvio declarado de `AGENTS.md` §8**: a regra nova não tem schema em `schemas/`, como nenhuma
`derivation_rule` hoje tem; o validador confere id e proveniência (`yaml_validator.ex:476-481`).
Criar o schema das regras é trabalho de outra feature.

### Registro das decisões de desenho (princípio VIII)

**1. Contexto `TheBand.Platform`, fora de `TheBand.Tenants`**

- *Problema*: a FR-011 exige que o operador não alcance nenhum caminho de domínio. Em `Tenants`, as
  funções do operador morariam ao lado das que recebem `%User{}` e `%Tenant{}`, e a fronteira
  seria convenção.
- *Existe agora?* Sim: é a decisão de 2026-10-01.
- *O que piora*: um contexto a mais, e `Platform.Suspensions` precisa de duas funções públicas
  novas de `Tenants` (`contracts/sessoes-e-tokens-da-organizacao.md`) em vez de chamar o `Repo`
  dele.

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

**5. Cookie próprio e telas por controller** (research R3.2) — **condicionado à pergunta 1**

- *Problema*: o socket do LiveView só lê o `Plug.Session`
  (`deps/phoenix/lib/phoenix/socket/transport.ex:278-286`), e a saída de domínio apaga o cookie
  inteiro (`session_controller.ex:46`).
- *Existe agora?* Sim, os dois fatos estão no código.
- *O que piora*: recarga por ação, e a FR-011 diz `live_session`.

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

- *Problema*: seis escritas que só valem juntas, e o teste precisa afirmar **qual** recusou.
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
├── seguranca-autenticacao.md    # [gate] a escrever pelo agente security — o gate
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── prototipo/                   # a escrever pelo agente Design — antes da tela
└── contracts/
    ├── credenciais-do-operador.md
    ├── sessao-do-operador.md
    ├── concessao-do-operador.md
    ├── suspensao.md
    ├── sessoes-e-tokens-da-organizacao.md
    ├── rotas-da-plataforma.md
    └── eventos-de-acesso.md
```

### Código

```text
lib/the_band/platform.ex                         # fachada, defdelegate
lib/the_band/platform/operator.ex                # schema platform_operators
lib/the_band/platform/grant.ex                   # schema platform_operator_grants
lib/the_band/platform/operator_session.ex        # schema platform_operator_sessions
lib/the_band/platform/suspension.ex              # schema tenant_suspensions
lib/the_band/platform/credentials.ex             # a segunda autenticação          [gate]
lib/the_band/platform/sessions.ex                # a linha da sessão                [gate]
lib/the_band/platform/grants.ex                  # conceder, reiniciar, revogar     [gate]
lib/the_band/platform/suspensions.ex             # listar, suspender, reativar
lib/the_band/platform/suspension_reasons.ex      # leitor da base
lib/the_band/tenants/tenant.ex                   # :status fora do cast, CHECK
lib/the_band/tenants/sessions.ex                 # + encerrar_da_organizacao/1
lib/the_band/tenants/api_tokens.ex               # + revogar_por_suspensao/2, clausulas_registradas/0
lib/the_band/tenants/access_events.ex            # + eventos de plataforma
lib/the_band/jobs/apaga_sessoes_antigas.ex       # + sessões do operador
lib/the_band/release.ex                          # + três comandos                  [gate]
lib/the_band_web/router.ex                       # :plataforma, scope /platform, CSP num atributo
lib/the_band_web/plataforma/sessao_do_operador.ex                                   [gate]
lib/the_band_web/plataforma/operator_scope.ex    # plug + require_operator          [gate]
lib/the_band_web/controllers/plataforma/*        # quatro telas                     [protótipo]
config/config.exs                                # :operator_id no formatador
priv/repo/migrations/<ts>_operador_da_plataforma.exs
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
| o LiveView aberto de domínio continua depois do `ended_at` | research R9; pergunta 3 |
| o código de definição no histórico do terminal do Dokploy | 30 min, uso único; não verificado se o Dokploy guarda |
| conta do operador tomada derruba a disponibilidade de todas as organizações | O16, risco residual; pergunta 2 |
| #1038 não mergeado | pré-requisito do gate; a FR-012 não se cumpre sem ele |

## Perguntas para a pessoa mantenedora

**1. A área do operador é por controller, com cookie próprio, em vez de `live_session`?**
O socket do LiveView só lê o cookie de sessão das organizações. Para ter `live_session`, a sessão do
operador teria de morar dentro desse cookie, chegando a toda rota de domínio e caindo quando alguém
sai da conta de organização no mesmo navegador. **Recomendação: controller com cookie próprio**
(research R3.2), e emendar a palavra `live_session` da FR-011 para "pipeline, plug e cookie
próprios".

**2. O operador entra só com senha, sem segundo fator?**
É o risco O16: a conta mais poderosa protegida por senha e espera de até 60 s. TOTP exigiria
dependência nova e avaliação de segurança própria. **Recomendação: aceitar como risco residual
nesta feature, registrado na release, e abrir a spec do segundo fator logo depois.**

**3. A suspensão também fecha os LiveViews abertos das pessoas da organização?**
Por leitura, a sessão cai no banco e a tela aberta continua até reconectar, e o mesmo vale hoje
para desativar conta e trocar senha. A correção é gravar `live_socket_id` na sessão de domínio e
enviar `disconnect`, o que toca `TheBandWeb.Sessao`. **Recomendação: medir primeiro; se confirmar,
abrir um defeito próprio, corrigido antes desta feature, porque a lacuna já existe na desativação
de conta**, e esta feature só passa a usá-lo.

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
