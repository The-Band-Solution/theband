# Modelo de dados do The Band

Como o banco e os schemas Ecto estão organizados, e **por que têm essa forma**.

Companheiro de [overview.md](overview.md), que trata da arquitetura. Este trata
das tabelas e das classes.

**Estado do documento**: escrito em 2026-08-11, a partir das 16 migrações e dos 13
schemas Ecto que existem no repositório. O que não foi conferido está declarado na
[última seção](#o-que-este-documento-não-cobre).

---

## 1. A coisa que mais confunde quem chega

**A maior parte deste esquema não foi escrita à mão. Foi derivada.**

Existe um script — `scripts/derive_information_model.py` — que lê a base de
conhecimento em `priv/knowledge_base/` e produz o modelo de informação: quais
conceitos viram tabela, quais viram coluna discriminadora, quais viram chave
estrangeira, e quais não viram nada.

```bash
python3 scripts/derive_information_model.py --ontology eo
```

A migração é escrita **a partir dessa saída**. Isso inverte o instinto normal:
você não decide que `eo_teams` precisa de uma coluna de organização e a
acrescenta. Você declara a relação na ontologia, roda o derivador, e a coluna
aparece — ou não aparece, e aí a resposta é que ela não devia existir.

A regra tem nome: **ADR 0004, decisão D4** — o modelo de informação é derivado,
nunca escrito à mão.

### O que acontece quando alguém ignora isso

Aconteceu, e está registrado numa migração que existe só para desfazer:

```
priv/repo/migrations/20260810140000_drop_hand_written_organization_columns.exs
```

Na feature 001, `eo_people.organization_id` e `eo_teams.organization_id` foram
acrescentadas à mão porque a relação não estava declarada em EO — e declarar não
bastaria, porque o derivador ainda não gerava chave estrangeira a partir de
associação. Escrever a coluna foi o atalho.

O resultado, medido antes de remover:

```
tabela    | total | com organization_id
----------+-------+--------------------
eo_people |    72 |                   0
eo_teams  |    10 |                   0
```

**Zero em 100% dos registros.** Nenhum código preenchia as colunas, porque nenhum
comando derivado da ontologia sabia que elas existiam. Uma coluna fora do modelo
derivado não é apenas irregular: ela não tem quem a escreva.

E `eo_people.organization_id` não voltou, por um motivo mais forte que
procedimento: **ela é semanticamente errada**. A mesma conta do GitHub aparece em
mais de uma organização, e a pessoa é uma linha só, porque a identidade dela é a
Application Reference. Uma coluna simples alternaria de valor a cada coleta, e a
última organização sincronizada apagaria a anterior. O caminho correto é pessoa →
equipe → organização.

`eo_teams.organization_id` voltou na migração seguinte — **derivada**, anulável, e
com a restrição que o derivador pediu.

---

## 2. Duas metades que não se misturam

O banco tem duas naturezas, e a fronteira entre elas é o **princípio II da
constituição**: *fonte externa não é domínio*.

```
┌─────────────────────────────────────────────────────────────────┐
│  INFRAESTRUTURA DA PLATAFORMA                                   │
│  o que a plataforma precisa para funcionar                      │
│                                                                  │
│  tenants ─── users                                               │
│     │                                                            │
│     ├── connected_tools ─── tool_credentials                     │
│     │         │                                                  │
│     │         ├── tool_observation_events   (append-only)        │
│     │         └── syncs ─── sync_checkpoints                     │
│     │                  └── raw_payloads     (payload preservado) │
│     │                                                            │
└─────┼────────────────────────────────────────────────────────────┘
      │  a travessia acontece aqui: semantic_integration/
      │  lê raw_payloads e chama a API pública do módulo ontológico
┌─────┼────────────────────────────────────────────────────────────┐
│     ▼   DOMÍNIO — derivado das ontologias                        │
│                                                                  │
│  eo_organizations ──┬── eo_teams ──┐                             │
│                     │              ├── eo_team_memberships       │
│                     └── eo_people ─┤        (relator)            │
│                                    └── eo_team_membership_       │
│  eo_organizational_roles ───────────────────  evidence           │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Por que a separação importa.** Um `raw_payload` é o que o GitHub respondeu — com
o vocabulário do GitHub, os campos do GitHub e os erros do GitHub. Uma linha de
`eo_people` é uma pessoa no sentido da Enterprise Ontology. Misturar as duas faria
o domínio herdar o modelo de dados de cada fonte, que é exatamente o problema que
a plataforma existe para resolver.

Consequência prática: **nenhuma tabela `eo_*` tem coluna que só faça sentido para
o GitHub.** Se você precisar de uma, o lugar dela é o payload preservado.

### Inventário das tabelas

Verificado nas 16 migrações. Oban tem tabela própria, criada pela biblioteca.

| Tabela | Natureza | O que guarda |
|---|---|---|
| `tenants` | plataforma | o tenant; toda tabela de domínio aponta para cá |
| `users` | plataforma | pessoa que usa a plataforma — **não** é `eo_people` |
| `connected_tools` | plataforma | uma organização observada numa instância de ferramenta |
| `tool_credentials` | plataforma | credencial cifrada em repouso |
| `tool_observation_events` | plataforma | transições `ended` / `resumed`, append-only |
| `syncs` | plataforma | uma execução de coleta, com o relatório |
| `sync_checkpoints` | plataforma | cursor por tipo de entidade, para retomar |
| `raw_payloads` | plataforma | o que a origem respondeu, preservado |
| `eo_organizations` | domínio (EO) | `eo.organization` |
| `eo_people` | domínio (EO) | `eo.person` |
| `eo_teams` | domínio (EO) | `eo.team`, com discriminador de subtipo |
| `eo_organizational_units` | domínio (EO) | `eo.organizational_unit` — antes `eo_sectors` |
| `eo_organizational_roles` | domínio (EO) | `eo.organizational_role` |
| `eo_team_memberships` | domínio (EO) | o **relator** da alocação |
| `eo_team_membership_evidence` | domínio (EO) | o que foi observado e ainda não virou alocação |

**`users` contra `eo_people` é a confusão mais comum.** `users` é quem faz login.
`eo_people` é quem aparece nos dados coletados. A mesma pessoa física pode estar
nas duas, e as duas linhas não se ligam: ligá-las exigiria decidir que a conta do
GitHub e o e-mail de login são a mesma identidade, e isso é uma afirmação sobre o
mundo que ninguém declarou.

---

## 3. Application Reference: a identidade que sustenta a idempotência

Toda tabela de domínio que vem de fonte externa tem estas três colunas:

```elixir
add :source_system,   :string, null: false   # "github"
add :source_instance, :string, null: false   # "https://github.com"
add :external_id,     :string, null: false   # o id global na origem
```

E um índice único sobre elas, com o tenant:

```elixir
create unique_index(
  :eo_people,
  [:tenant_id, :source_system, :source_instance, :external_id],
  name: :eo_people_application_reference_index
)
```

**Por que três colunas e não uma.** O mesmo identificador pode existir em duas
instâncias diferentes da mesma ferramenta — `github.com` e um GitHub Enterprise
Server interno. Sem `source_instance`, as duas colidiriam; e a colisão apareceria
como uma pessoa com dois nomes, não como um erro.

**O que isso compra: idempotência.** Coletar duas vezes não duplica nada, porque
o upsert reconhece a linha pela Application Reference. A constituição trata isso
como não negociável (princípio III), e o teste que o prova compara as contagens
antes e depois de uma segunda coleta idêntica.

**Por que não usar o número que a origem mostra.** O número de uma issue é único
dentro do repositório, e mover a issue entre repositórios cria outro. O
identificador global não muda. A regra vale para toda entidade: a identidade é o
identificador global, nunca o número apresentado na interface.

### `internal_id` e `record_version`

Duas colunas em toda tabela de domínio que vêm da tese, não do GitHub:

| Coluna | Para que serve |
|---|---|
| `internal_id` | identidade estável do dado **entre módulos ontológicos** — um módulo referencia o dado de outro por aqui, nunca pela chave primária |
| `record_version` | versão do registro, para reprocessamento e retrofito |

---

## 4. Papel nunca é coluna: o relator

Esta é a decisão que mais surpreende, e é a que mais economiza refatoração
depois.

**A pergunta errada**: "qual o papel desta pessoa?" — que sugere uma coluna
`eo_people.role`.

**Por que ela é errada**: a resposta é sempre *depende*. Depende do time, do
período, e pode haver mais de uma. Uma coluna guarda um valor e perde as três
coisas:

| A coluna perde | Exemplo concreto |
|---|---|
| **o contexto** | a mesma pessoa é Product Owner num time e desenvolvedora em outro |
| **o período** | "quem era o PO no sprint 3" é pergunta legítima, e a coluna só sabe o hoje |
| **a multiplicidade** | duas alocações simultâneas são normais |

A forma correta é uma tabela própria — o **relator**, que reifica a relação:

```elixir
create table(:eo_team_memberships, primary_key: false) do
  add :person_id,              references(:eo_people), null: false
  add :team_id,                references(:eo_teams),  null: false
  add :organizational_role_id, references(:eo_organizational_roles)
  add :started_at, :utc_datetime
  add :ended_at,   :utc_datetime
end
```

`started_at` e `ended_at` são o que uma coluna nunca teria. É a **ADR 0004, D5**.

O derivador aplica essa regra sozinho. Rodando a derivação da SRO, ele imprime
uma linha por papel:

```
sro.product_owner: role elevado a eo.person [outra ontologia];
                   materializa pelo relator, não por discriminador
```

E ela quase não foi aplicada. Até 2026-08-10 a guarda só valia quando o alvo
estava na mesma ontologia, e CMPO e SPO já produziam `eo.person.type +=
{project_person_stakeholder}` com o CI verde. Nenhuma dessas colunas chegou ao
banco, e a correção está registrada na [L22](../sprints/licoes-aprendidas.md).

### Por que existe uma tabela de *evidência* separada

`eo_team_membership_evidence` existe porque **o GitHub não fornece papel
organizacional**. Ele fornece nível de acesso na plataforma — `MEMBER`,
`MAINTAINER` — que é outra coisa: diz o que a pessoa pode fazer na ferramenta, não
o papel dela na organização.

Sem papel, não é possível criar a alocação: `organizational_role_id` faria parte
de uma afirmação que ninguém tem como sustentar. Então o que foi observado é
guardado como **evidência**, com o nível de acesso da plataforma nomeado como
tal:

```elixir
add :platform_access_level,  :string        # MEMBER, MAINTAINER — o que o GitHub dá
add :promoted_membership_id, references(:eo_team_memberships)   # nulo até haver papel
```

`promoted_membership_id` fica nulo enquanto a evidência não virar alocação. A
coluna existe para que a promoção, quando acontecer, seja rastreável — e para que
`count_evidence_pending_role/2` possa dizer quantas estão esperando.

**A tabela `eo_team_memberships` existe no banco e ainda não tem schema Ecto.**
Isso é intencional e não é omissão: o relator só se materializa quando houver
papel declarado, e é justamente o que as issues
[#99 e #100](https://github.com/The-Band-Solution/theband/issues/99) vão fazer.

---

## 5. Evento é append-only; situação é derivada

**ADR 0004, D7.** Eventos são registrados e nunca alterados. Situações não são
materializadas — saem de consulta sobre os eventos.

O caso concreto é o ciclo de observação de uma ferramenta. Encerrar e retomar
**ocorreram**, num instante, por alguém: são eventos.

```elixir
create table(:tool_observation_events, primary_key: false) do
  add :connected_tool_id, references(:connected_tools), null: false
  add :event,       :string,        null: false     # "ended" | "resumed"
  add :occurred_at, :utc_datetime,  null: false
  add :actor_user_id, references(:users)            # anulável de propósito
  add :reason,  :text
  add :impact,  :map

  timestamps(type: :utc_datetime_usec, updated_at: false)
end
```

Três decisões dentro dessas linhas:

**Sem `updated_at`.** Não existe caminho para alterar um evento, e o schema Ecto
também não tem `update_changeset`. Se um encerramento foi registrado errado, a
correção é um evento novo — atualizar reescreveria o passado. Ter a coluna
convidaria a isso.

**`impact` guarda o que foi contado no instante.** Não o que uma consulta de hoje
devolveria. As duas coisas divergem: uma coleta posterior muda os números, e o que
interessa no registro é o que a pessoa viu antes de confirmar.

**`actor_user_id` é anulável.** Uma retomada pode vir de processo, e inventar um
autor seria pior que declarar que não há.

O estado sai de uma função, não de uma coluna:

```elixir
def observation_ended?(%ConnectedTool{id: tool_id}) do
  Repo.one(
    from e in ObservationEvent,
      where: e.connected_tool_id == ^tool_id,
      order_by: [desc: e.occurred_at, desc: e.inserted_at],
      limit: 1, select: e.event
  ) == "ended"
end
```

**Um caminho só.** A tela e o filtro de coleta usam a mesma função. Dois caminhos
discordariam, e a tela mostraria como encerrado o que a plataforma continua
coletando.

### O microssegundo, e por que ele está ali

`timestamps(type: :utc_datetime_usec)` não é preciosismo. Com precisão de segundo,
um `ended` e um `resumed` no mesmo segundo **empatavam**, e o "último evento"
passava a depender do plano de execução do Postgres. O efeito observado: retomar
com sucesso e a tela continuar dizendo "encerrada".

`occurred_at` continua em segundos — é quando a coisa *ocorreu*, e segundo basta.
`inserted_at` é a **ordem de gravação**, e é ela que desempata. Separar os dois
papéis é o que torna a ordem definida sem fingir precisão que o evento não tem.

Foi a segunda ocorrência do mesmo defeito no projeto — a primeira foi na escolha
de credencial — e reincidiu porque a primeira lição foi registrada sobre
*credenciais* em vez de sobre *derivar estado de conjunto ordenado*. Está na
[L20](../sprints/licoes-aprendidas.md).

### A dívida que contradiz esta seção

`connected_tools.status` **materializa uma situação**, contra a D7. É dívida da
feature 001, está declarada, e a feature 003 não a ampliou — ela apenas parou de
exibi-la quando contradiz o estado derivado.

---

## 6. Ausência marca, nunca apaga

Três tabelas de domínio têm este par:

```elixir
add :last_observed_at,      :utc_datetime
add :no_longer_observed_at, :utc_datetime
```

**Por que não `DELETE`.** O GitHub não emite evento quando alguém sai de um time.
A plataforma percebe a ausência **por comparação entre coletas**: quem estava lá
antes e não apareceu agora. E "não apareceu" não é o mesmo que "não existe" —
pode ser permissão, pode ser falha parcial, pode ser mudança de escopo.

Apagar transformaria uma inferência em fato irreversível. Marcar preserva a
resposta a "quem estava neste time em março".

### O escopo, que é a parte fácil de errar

A marca precisa ser escopada pelo **que foi realmente observado naquela coleta**.
Esta versão está errada:

```elixir
# ERRADO — foi a L19
where: e.tenant_id == ^tenant_id and
       e.last_observed_at < ^collection_started_at
```

Coletar *uma* organização marcava os vínculos de *todas*: as outras não haviam
aparecido naquela coleta, e nunca apareceriam. O efeito real, no banco de
desenvolvimento: os 7 vínculos de uma organização e 55 dos 70 de outra marcados
no mesmo instante, `00:44:30`, enquanto a coleta em execução era de uma terceira.

A forma correta restringe ao escopo observado:

```elixir
equipes_da_org =
  from t in Team,
    where: t.tenant_id == ^tenant_id and t.organization_id == ^organization_id,
    select: t.id

from e in TeamMembershipEvidence,
  where: e.tenant_id == ^tenant_id and
         e.team_id in subquery(equipes_da_org) and
         e.last_observed_at < ^collection_started_at and
         is_nil(e.no_longer_observed_at)
```

**A regra geral, para quem for escrever a próxima coleta**: o filtro de ausência
tem que ter o mesmo recorte da coleta. Se a coleta olhou uma organização, o filtro
é por organização. Se olhar um repositório, será por repositório — e é por isso
que a feature 004 traz isso como requisito e não como lembrete.

### A ordem dentro do encerramento também é regra

Em `end_observation/3`, a marcação é: **equipes, depois vínculos, depois
pessoas**. As pessoas por último porque a decisão sobre a pessoa depende dos
vínculos já marcados — ela só perde vigência se *nenhum* vínculo dela sobrou.
Inverter marcaria quem ainda tinha vínculo em outra organização.

---

## 7. Credencial cifrada pelo tipo, não pelo código

```elixir
defmodule TheBand.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: TheBand.Vault
end
```

E no schema:

```elixir
@derive {Inspect, except: [:secret]}

schema "tool_credentials" do
  field :secret, TheBand.Encrypted.Binary, redact: true
  field :last_four, :string
  ...
end
```

**Por que no tipo Ecto e não no changeset.** Um campo declarado com este tipo não
tem como ser gravado em claro por esquecimento de quem escreve o comando. Se a
cifragem morasse no changeset, cada caminho de escrita novo precisaria lembrar —
e um deles não vai lembrar.

Três camadas, cada uma cobrindo o vazamento de um lugar diferente:

| Mecanismo | O que impede |
|---|---|
| `TheBand.Encrypted.Binary` | gravar em claro no banco |
| `@derive {Inspect, except: [:secret]}` | vazar em log, em `IO.inspect`, em stacktrace |
| `last_four` | exibir algo útil na tela sem exibir o segredo |

**Como se verifica**: lendo a tabela direto. O teste não afirma que a cifragem
funciona — ele procura o texto claro no valor gravado e exige não encontrar. Para
qualquer invariante de segurança, o teste é a violação.

A chave mestra vem do ambiente (`THE_BAND_MASTER_KEY`) e a aplicação **recusa
subir sem ela**. Consequência que vale saber antes de tropeçar: uma credencial
cifrada com uma chave não é decifrável com outra — trocar a chave exige
`mix the_band.rotate_key`, e uma chave descartável não abre dado real.

---

## 8. `tenant_id` explícito em toda tabela de domínio

Não há schema por tenant, não há `WHERE` implícito, não há middleware que injeta o
filtro. **A coluna está lá e cada consulta a usa.**

```elixir
add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
```

`on_delete: :restrict` de propósito: apagar um tenant com dado dentro é recusado
pelo banco.

**Por que explícito.** É o princípio V da constituição. Um filtro implícito
funciona até a primeira consulta que o contorna — um `join`, um `subquery`, uma
função nova — e o vazamento que resulta é silencioso: os dados aparecem, ninguém
percebe que são de outro tenant.

Com a coluna explícita, a violação é **textual**, e por isso pega em revisão: uma
consulta sobre tabela de domínio sem `tenant_id` no `where` está errada, e dá para
ver lendo.

**Como o erro se apresenta ao usuário**: recurso de outro tenant devolve **"não
encontrado"**, nunca "sem permissão". Dizer "sem permissão" já entrega que o
recurso existe.

---

## 9. Schemas privados, e por que a fronteira é o módulo raiz

```
lib/the_band/ontology/seon/eo.ex          ← a fronteira
lib/the_band/ontology/seon/eo/
    commands.ex                            ← escritas
    queries.ex                             ← leituras
    constraints.ex                         ← verificações
    schemas/
        organization.ex                    ← privados
        person.ex
        team.ex
        organizational_role.ex
        team_membership_evidence.ex
```

O módulo raiz contém **apenas `defdelegate`** (ADR 0003):

```elixir
defdelegate upsert_person_from_source(tenant, attrs), to: Commands
```

**A regra**: nenhum módulo fora de `eo/` alcança `EO.Schemas.*`, e nenhum módulo
fora de `eo/` chama `Repo` sobre as tabelas `eo_*`.

### Por que o módulo raiz e não o schema

O instinto é fazer do schema a unidade pública — é o que ele parece ser. Mas o
schema é a **forma da tabela**, e a tabela é derivada: ela muda quando a ontologia
muda. Se outros módulos dependessem do schema, cada mudança de derivação
quebraria consumidores em toda a aplicação, e a pressão para não mexer na
derivação venceria a semântica.

Um segundo motivo, mais imediato: **uma função que devolve `Ecto.Query` vaza a
fronteira**. Quem recebe a query pode compor sobre ela e, ao compor, contornar o
filtro de tenant. Por isso nenhuma função pública devolve query — devolvem dados.

### O que a API deliberadamente não expõe

Documentado no próprio módulo, e vale ler antes de acrescentar função:

| Ausente | Por quê |
|---|---|
| `create_person/2`, `create_team/2` | não há cadastro manual nesta feature, e expor convidaria a criar registro sem proveniência |
| `delete_*` | ausência marca `no_longer_observed_at`; a plataforma existe para preservar rastreabilidade |
| `create_team_membership/2` | exige papel organizacional, que nenhuma fonte atual fornece |
| qualquer função que devolva `Ecto.Query` | vaza o schema interno e permite contornar o filtro de tenant |

**Ausência documentada com motivo é decisão. Ausência silenciosa é esquecimento.**
As duas parecem iguais no código, e é por isso que o motivo está escrito.

---

## 10. Discriminador de subtipo, e a restrição que o acompanha

`eo_teams` tem uma coluna que parece um enum banal:

```elixir
add :type, :string, null: false, default: "organizational_team"
```

Ela é a materialização de `subkind` — um subtipo rígido não ganha tabela própria,
ganha um valor de discriminador na tabela do kind. `eo.organizational_team` e
`eo.project_team` são as duas linhas possíveis.

E a restrição que veio com ela mostra por que o discriminador não é decorativo:

```sql
check: organization_id IS NOT NULL OR type <> 'organizational_team'
```

Equipe **organizacional** precisa de organização. Equipe **de projeto** não — ela
pode atravessar organizações, e obrigar a coluna para todo subtipo afirmaria o
contrário. É o que separa isso de um `NOT NULL`: a obrigatoriedade é do subtipo, e
o discriminador é quem diz qual subtipo a linha é.

**Detalhe operacional que custou uma migração**: criar coluna e restrição juntas
não funciona em banco povoado. As equipes já coletadas eram todas
`organizational_team` sem organização, e o Postgres recusou com
`ERROR 23514 (check_violation)`. A separação virou vantagem — a migração da
restrição passou a ser **a verificação do retrofito**: se qualquer equipe
organizacional ficar sem organização, ela se recusa a aplicar.

---

## 11. Coleta: o que cada tabela responde

```
connected_tools ──┬── syncs ──┬── sync_checkpoints   (onde parei, por entidade)
                  │           └── raw_payloads       (o que a origem respondeu)
                  └── tool_observation_events        (encerrei / retomei)
```

| Tabela | Pergunta que responde |
|---|---|
| `syncs` | esta execução coletou quanto, criou quanto, atualizou quanto, e por que pulou o que pulou |
| `sync_checkpoints` | onde parei em cada tipo de entidade, para retomar sem recoletar |
| `raw_payloads` | o que exatamente a origem respondeu, para reprocessar quando a regra mudar |

**`raw_payloads` é o que torna o erro recuperável.** As regras de classificação
vão estar erradas na primeira tentativa. Se corrigir exigisse nova coleta completa
da origem, ninguém corrigiria — e a plataforma acumularia dado classificado errado
que ninguém tem coragem de reprocessar.

Ele guarda também `mapping_id` e `mapping_version`: qual mapeamento processou
aquele payload e em que versão. Payload gravado antes de o campo existir aparece
no reprocessamento como registro ignorado com motivo nomeado, e não como falha
silenciosa.

**`syncs` tem índice único parcial sobre `connected_tool_id`** para as execuções
em andamento — duas coletas simultâneas da mesma ferramenta produziriam contagens
que nenhuma das duas explicaria.

---

## 12. Como acrescentar algo ao modelo

A ordem importa, e ela é o inverso do instinto.

1. **Declare na ontologia**, em `priv/knowledge_base/ontology/<rede>/<ont>/modules/`.
   Conceito precisa de `ufo_category` **e** `ontouml_stereotype` — sem os dois, o
   derivador recusa derivar em vez de adivinhar.
2. **Rode o derivador** e leia a saída:
   ```bash
   python3 scripts/derive_information_model.py --ontology eo
   ```
   Ela diz a tabela, as colunas, os discriminadores e o que foi absorvido para
   onde. Se a coluna que você esperava não apareceu, a resposta é que ela não
   devia existir — não que o derivador está incompleto.
3. **Escreva a migração a partir dessa saída**, e explique no `@moduledoc` por que
   a forma é essa. As migrações deste projeto são longas de propósito: o motivo é
   a parte que ninguém recupera depois.
4. **Schemas em `schemas/`**, privados. A API pública é `defdelegate` no módulo
   raiz.
5. **Nove quality gates**, incluindo `mix knowledge.validate`, o validador Python
   e a reprodutibilidade da derivação.

### O que faz o derivador recusar

```
não é possível derivar sro: 43 conceito(s) sem ontouml_stereotype
```

Isso é comportamento correto, não bug. `ufo_category` é a categoria de topo e
**não expressa sortalidade nem rigidez** — as duas meta-propriedades que decidem
se o conceito vira tabela, discriminador ou relator. Sem elas, adivinhar produz
esquema plausível e errado, que é pior que esquema ausente.

Como cada estereótipo se materializa:

| Estereótipo | Vira |
|---|---|
| `kind` | tabela |
| `subkind` | valor de discriminador `type` na tabela do kind |
| `phase` | valor de discriminador `status` na tabela do kind |
| `role` | **nada** — materializa pelo relator |
| `relator` | tabela |
| `category`, `role_mixin`, `mixin` | achatado |

---

## O que este documento não cobre

Declarado em vez de omitido.

| Não coberto | Onde procurar |
|---|---|
| As 11 ontologias sem tabela | só 4 têm `ontouml_stereotype` — EO, SPO, CMPO e SRO. RSRO e SYS_SWO têm 16 conceitos sem estereótipo |
| Tabelas da SRO | a derivação passou a existir no sprint 003; **nenhuma migração SRO foi escrita ainda** |
| Oban | tabela criada pela biblioteca; não a inspecionei |
| Índices completos | listei os únicos que sustentam a Application Reference; não auditei todos |
| Colunas de `eo_organizational_units` | tabela renomeada de `eo_sectors`; não reli a migração original |
| Regras de derivação em detalhe | `scripts/derive_information_model.py` e a [ADR 0004](../adr/) |

## Manutenção deste documento

Reescrever quando: uma migração nova mudar a forma de uma tabela de domínio; o
derivador passar a produzir outra forma; uma ontologia nova ganhar estereótipos e
virar tabela.

O critério é: **se alguém que lesse este documento e depois o banco encontrasse
divergência, ele está desatualizado.** As contagens citadas são de 2026-08-11.
