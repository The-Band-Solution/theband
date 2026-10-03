# Contrato: o passo de jornada, da emissão ao span

Feature 074 · [spec](../spec.md) · [plan](../plan.md) · [research](../research.md) ·
[seguranca](../seguranca.md)

Este contrato existe **antes** de qualquer função pública (AGENTS §12). Quando a implementação
mostrar que ele errou, ele é corrigido no mesmo commit, com a razão.

## 1. O evento `:telemetry`

```
nome        [:the_band, :jornada, :passo]
medidas     %{}                                 nesta fatia, nenhuma (research R2, R9)
metadados   %{
              jornada:  :entrar_e_sair,          átomo da lista declarada
              passo:    passo(),
              desfecho: :concluiu | :falhou,     :abandonou nunca é emitido (R6)
              motivo:   motivo() | nil,          nil se e só se desfecho == :concluiu
              tenant_id: Ecto.UUID.t() | nil,
              user_id:   Ecto.UUID.t() | nil,
              jornada_id: String.t() | nil       só em abrir_a_entrada e entrar_com_senha
            }
```

`passo()` e `motivo()` são **exatamente** os da tabela *A régua* da spec e de
`priv/knowledge_base/rules/journey_entrar_e_sair.yaml`.

**O que o evento NÃO carrega, e por quê**: o identificador digitado, a senha, o cookie, o
token, o e-mail e a struct `%User{}`. As funções emissoras recebem só ids e átomos — é a
assinatura, e não a disciplina, que impede (`access_events.ex:44-50`).

## 2. Quem emite — `TheBand.Tenants.AccessEvents.passo/1`, e de onde é chamado

```elixir
@spec passo(%{
        required(:passo) => passo(),
        required(:desfecho) => :concluiu | :falhou,
        required(:motivo) => motivo() | nil,
        required(:tenant_id) => Ecto.UUID.t() | nil,
        required(:user_id) => Ecto.UUID.t() | nil,
        optional(:jornada_id) => String.t()
      }) :: :ok
```

Uma função **nova**, só de emissão. Guardas na cabeça: `passo` e `desfecho` são átomos da lista;
`motivo` é átomo ou `nil`; ids são binários. **Nada mais passa** — nem struct, nem `conn`, nem
changeset, nem texto livre (seguranca.md, S1, terceira camada). As funções de log que já existem
(`entrada_aceita/3`, `entrada_recusada/3`, `espera_acionada/3`, `sessao_derrubada/3`) **não
mudam**.

| quem chama | quando | passo |
|---|---|---|
| `Auth.authenticate/3` | **depois** da transação, uma vez, em todo ramo, a partir do relator interno `{decisão, motivo, conta}` (S4) | `entrar_com_senha` |
| `SessionLive.New.mount/3` | só com `connected?(socket)`, lendo `:jornada_id` da sessão | `abrir_a_entrada` |
| `SessionController.delete/2` | depois de decidir por `conn.assigns[:current_session]` | `sair` |
| `CurrentScope.sem_sessao/3` | ao lado de `AccessEvents.sessao_derrubada/3` | `sessao_derrubada` |
| `SessionController.set_password/2` e `update_password/2` | depois da decisão | `definir_a_senha`, `trocar_a_senha` |

**`Auth.authenticate/3`**: `authenticate(identificador, senha, opts \\ [])`, com
`opts[:jornada_id]`. `authenticate/2` continua existindo e delega com `[]`. O **retorno não muda**:
`{:ok, user}`, `{:error, :invalid_credentials}` ou `{:error, {:throttled, s}}` — o controller nunca
vê o motivo. O correlator vai por argumento, e **não** por `Logger.metadata` nem pelo dicionário
do processo: estado implícito é o que §7.4 proíbe para o tenant, e vale igual aqui.

**Identidade (FR-004, D1)**: `user_id` vai no passo só quando o desfecho pede ação, e
no `concluiu` da entrada só com `falhas_apagadas > 0`. O mesmo trabalho é feito em todo ramo: a
decisão de incluir ou não é uma comparação, sem consulta.

**Erros**: `passo/1` não devolve erro nem levanta com entrada válida; com entrada inválida
**levanta** (`FunctionClauseError`), porque é bug de quem chama — e o teste da régua o pega.

## 3. O span

```
nome        "the_band.acesso." <> passo            ex.: the_band.acesso.entrar_com_senha
kind        :internal
atributos   journey.name     "entrar_e_sair"
            journey.step     passo
            journey.id       correlator (22 chars base64url) — só quando houver
            outcome          "concluiu" | "falhou"
            failure.reason   motivo — só quando outcome == "falhou"
            tenant.id        UUID — quando conhecido
            user.ref         ver §5 — quando conhecido
status      :ok se concluiu; :error se falhou — SEM descrição (o filtro a apaga)
eventos     nenhum — e nenhum record_exception, nunca (FR-017)
links       nenhum
recurso     service.name=the_band, service.version, deployment.environment — e nada mais
```

**Nome é o que foi tentado; atributo é como terminou** (ADR 0005, decisão 4).

## 4. `TheBand.Telemetria.Jornada` — o handler

```elixir
@spec anexar() :: :ok | {:error, :already_exists}
@spec id() :: String.t()
@spec handle_event(list(atom()), map(), map(), term()) :: :ok
```

- anexado em `TheBand.Application.start/2`, **antes** dos filhos, como `LogDaConsulta` (#1222);
- `handle_event/4` tem `catch kind, reason` — e não só `rescue`, que não pega `exit` nem `throw`
  (seguranca.md, S11): um handler que falha seria **desanexado** pelo `:telemetry` (ADR S5). O
  `catch` incrementa o contador `handler_falhou` e loga **só o `kind` e o módulo da exceção** —
  nunca a mensagem, a pilha nem os metadados;
- um teste confere, depois de forçar a exceção, que o handler **continua anexado**
  (`:telemetry.list_handlers/1`).

## 5. `user.ref` — D1, decidida em 2026-10-03

Decidido: o `user_id` (UUID), com a minimização da FR-004. Quando outra pessoa ganhar acesso ao
SigNoz, passa a
ser `HMAC-SHA256(chave, user_id)` truncado, com a chave em variável de ambiente, e o contrato
muda **só** aqui — o nome do atributo fica. Opções e recomendação em [seguranca.md](../seguranca.md).

## 6. `TheBand.Telemetria.Exportador` — o filtro

Implementa o behaviour `:otel_exporter` (`init/1`, `export/4`, `shutdown/1`).

```elixir
@spec init(%{destino: {module(), term()}}) :: {:ok, estado}
@spec export(:traces, :ets.tab(), :otel_resource.t(), estado) :: :ok | :failed_not_retryable | :failed_retryable
@spec shutdown(estado) :: :ok
```

- para cada span da tabela, monta um span **novo**: nome conferido contra a enumeração dos
  passos (span de nome desconhecido é descartado inteiro); só os atributos da **lista permitida**
  de §3, com o **valor** conferido (UUID, enumeração declarada **para aquele passo**, correlator);
  eventos e links vazios; status sem descrição;
- cada descarte incrementa `the_band.telemetria.atributo_descartado` com o **nome** do atributo
  (nunca o valor);
- o recurso é reescrito com os três atributos de §3;
- delega ao `destino` (`:opentelemetry_exporter` em produção; `:otel_exporter_pid` no teste).

**O que NÃO expõe**: nenhuma função para "liberar" um atributo em tempo de execução. A lista é
constante do módulo e só muda por commit com teste.

## 7. Contadores

| nome | quando | rótulos |
|---|---|---|
| `the_band.telemetria.handler_falhou` | `rescue` do handler | `tipo` do erro |
| `the_band.telemetria.atributo_descartado` | o filtro descartou | `atributo` (nome) |
| `the_band.telemetria.span_descartado` | o `BatchProcessor` descartou por fila cheia | — |

Vivem em `:counters`, **fora** do OpenTelemetry, e o `telemetry_poller` existente os loga em
`warning` quando não são zero, junto com a conferência de que o handler segue anexado (research
R13). Contá-los como span seria contar a perda pelo cano que perdeu.

## 8. Mudança de comportamento observável

**Nenhuma** para quem usa: a resposta HTTP, o redirect, a frase e o tempo de cada caminho de
`session_controller.ex` continuam iguais. A 045 (`login_test.exs`, `Enum.uniq`) continua passando.
`Sessions.encerrar/1` **não muda** (tem oito chamadores, cinco em teste, que casam `:ok`).
`delete/2` decide o passo por `conn.assigns[:current_session]`, que `CurrentScope` só preenche
depois de conferir que a sessão está aberta (`current_scope.ex:30-60`): com ela, `concluiu`; sem
ela, `falhou` / `sessao_ja_nao_existia`. Quando o cookie trazia uma sessão já encerrada, a mesma
requisição produz **dois** passos — `sessao_derrubada` (emitido por `CurrentScope`, com o motivo)
e `sair` com `falhou` —, e isso é correto: são dois fatos.
