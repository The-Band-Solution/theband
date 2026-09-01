# Research — A primeira conta nasce do ambiente

Cinco decisões. Nenhuma dependência nova, nenhuma migração.

## R1 — A corrida (FR-005) já está resolvida pelo esquema

**Decisão**: não acrescentar nada. Confiar em `unique_index(:tenants, [:slug])` e
`unique_index(:users, [:email])`, ambos criados na migração
`20260809120000_create_tenants_and_users.exs`.

**Razão**: o FR-005 exige que duas subidas simultâneas não produzam dois
administradores, e que a garantia venha do armazenamento. As duas subidas leem
**as mesmas variáveis** — mesmo slug, mesmo e-mail. Uma vence; a outra recebe a
violação de unicidade e a trata como "já existe". O caso que o requisito teme não
é "dois valores diferentes ao mesmo tempo", porque não há de onde eles viriam.

**Alternativas consideradas**:

- *`pg_advisory_xact_lock` na transação*: correto, e desnecessário. Acrescenta um
  mecanismo que quem lê precisa entender, para proteger contra uma corrida que os
  índices já barram.
- *Índice único parcial "um admin por organização"*: **errado**, e vale dizer por
  quê para ninguém propor de novo. A plataforma permite vários administradores
  por organização — é o que `/accounts` faz. Esse índice quebraria a feature 045.
- *Tabela de controle de instalação*: cria estado novo para responder uma
  pergunta que a tabela `users` já responde.

## R2 — Onde a criação roda

**Decisão**: `TheBand.Release.semear_primeira_conta/0`, chamada pelo
`rel/entrypoint.sh` na linha seguinte a `TheBand.Release.migrate()`.

**Razão**: é o único ponto que satisfaz o FR-003 — depois do esquema aplicado,
antes de o endpoint atender. O `Release` já usa `Ecto.Migrator.with_repo/2`, que
sobe o repositório sem a árvore de supervisão; o mesmo mecanismo serve aqui, e
pela mesma razão que o `@moduledoc` do `Release` já registra: subir a aplicação
inteira faria os coletores começarem a puxar trabalho.

**Alternativas consideradas**:

- *Dentro da árvore de supervisão, no boot da aplicação*: roda em `mix test` e em
  `mix phx.server` também, e passaria a criar contas em desenvolvimento. Além
  disso, competiria com os coletores do Oban pelo mesmo esquema.
- *Tarefa `mix` executada à mão*: é exatamente o passo manual que a feature
  existe para eliminar. Num release não há `mix`, e voltaríamos ao console.
- *Comando pós-deploy configurado no painel*: funciona, mas põe o procedimento
  fora do repositório — quem recriar a produção não o encontra.

## R3 — Relator em vez de log (FR-006, FR-007, FR-009)

**Decisão**: `TheBand.Tenants.Bootstrap.criar_primeira_conta/1` devolve um
relator; `Release.semear_primeira_conta/0` traduz em frase e imprime.

**Razão**: a L69 registra que defeito dentro de `Logger.info` é invisível a teste
por configuração. Os cenários que a spec exige provar — a variável ausente
**nomeada** (US3-1), a regra recusada **nomeada** (US3-3), o "já existe"
**dito** (US2-1) — viram asserção sobre um valor de retorno, e não captura de
log.

Também é o que a constituição VIII pede em outra frase: erro previsto de negócio
é retorno, exceção é bug.

**Alternativas consideradas**:

- *Imprimir direto e testar por `capture_log`*: possível, e frágil pela razão
  acima. O projeto já pagou por isso.
- *Levantar exceção quando falta variável*: viola o FR-007. A ausência é caso
  previsto, não bug.

## R4 — A senha fora de log e de argumento (FR-006)

**Decisão**: a senha entra por variável de ambiente lida dentro do processo, vai
direto para `User.senha_changeset/3` — que já hasheia — e **não aparece no
relator**. O relator carrega e-mail e slug; nunca a senha.

**Razão**: argumento de linha de comando é visível a qualquer processo da máquina
por `/proc`. Variável de ambiente do contêiner, não. E manter a senha fora do
relator elimina a chance de o chamador imprimi-la por descuido — a proteção fica
no formato do dado, não na disciplina de quem escreve o `IO.puts`.

O hash já acontece dentro do changeset, e o `@moduledoc` do `User` diz por quê:
"nenhum caminho grava senha em claro por esquecimento".

**Alternativas consideradas**:

- *Ler de arquivo montado como segredo*: mais seguro num orquestrador que
  suporte, e o painel usado hoje trabalha com variáveis. Fica registrado como
  caminho futuro, não como escopo.

## R5 — Validação: reaproveitar, não reescrever

**Decisão**: nenhuma validação nova. `Tenant.changeset/2` já exige nome e slug e
valida o formato do slug; `User.changeset/2` já exige e-mail e valida o papel;
`User.senha_changeset/3` já exige mínimo de 12 caracteres.

**Razão**: o FR-008 pede que valor recusado pelas regras que já valem produza a
mesma recusa. Reescrever a validação aqui criaria duas fontes que podem divergir
— e a divergência apareceria como "a instalação aceitou uma senha que a
plataforma depois recusa".

**Consequência que precisa estar no `tasks.md`**: o teste tem que provar que a
recusa vem do changeset existente, e não de uma cópia. A prova é usar um valor
que só aquele changeset recusa — uma senha de 11 caracteres, por exemplo.

## O que ficou de fora, e por quê

**Tela de instalação pela interface.** Considerada na conversa que originou a
spec e descartada por simplicidade. O custo dessa escolha está registrado na
spec: enquanto a variável de senha existir no painel, a senha do primeiro
administrador é legível por quem tem acesso a ele. Uma tela levaria a senha do
teclado ao hash sem parada intermediária.

**Rotação automática da variável.** A recomendação de remover o valor depois do
primeiro acesso entra no runbook (FR-012), como procedimento — não como código.
Código que apaga a própria configuração é surpresa para quem opera.
