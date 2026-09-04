# Contrato — As medidas e a interseção de períodos

Escrito **antes** da primeira função pública, como exige o princípio VI. Quando a
implementação mostrar que ele está errado, corrigir aqui **no mesmo commit**.

Quatro módulos ganham API pública, e **um é novo**. Nenhuma migração.

---

## 1. `TheBand.Periodos` — novo, e puro

A única coisa que atravessa três ontologias. Não consulta nada.

### `interseccao/1`

```elixir
@type periodo :: %{inicio: DateTime.t() | nil, fim: DateTime.t() | nil}
@type veredito ::
        :intersecta
        | :nao_intersecta
        | {:parcial, [:inicio_desconhecido]}

@spec interseccao([periodo()]) :: veredito()
```

Borda `[início, fim)` — fechada no início, aberta no fim, a mesma da feature 057.

**As duas pontas nulas significam coisas diferentes.** `inicio: nil` é *não se
sabe desde quando* e devolve `{:parcial, [:inicio_desconhecido]}`; `fim: nil` é
*ainda vigente* e **não** produz dúvida.

A assimetria é do domínio: `eo_team_memberships.started_at` é anulável de
propósito, e `linked_at` é `NOT NULL` nas duas tabelas de projeto (R2a).

Essa é a razão de o módulo existir. Tratar o início nulo como aberto é o fallback
silencioso que a feature 057 corrigiu no vínculo; tratar o fim nulo como
desconhecido é o erro oposto, e pior na prática — a maioria dos vínculos está em
curso.

A regra precisa viver num lugar só: escrita três vezes, divergiria na primeira
correção.

**Por que na raiz de `lib/the_band/`, e não dentro de uma ontologia**: intersectar
datas não pertence a EO, SPO nem CIRO. Pô-la em qualquer uma obrigaria as outras
duas a alcançá-la, contra o princípio V.

---

## 2. `TheBand.Quality` — o tempo de revisão, recortado

### `team_time_to_first_review/3`

```elixir
@spec team_time_to_first_review(Tenant.t(), Ecto.UUID.t(), keyword()) :: [espera()]
@type espera :: %{
        change_request_id: Ecto.UUID.t(),
        numero: integer(),
        titulo: String.t(),
        aberta_em: DateTime.t(),
        autor_person_id: Ecto.UUID.t() | nil,
        estado: {:revisada, float()} | {:aguardando, non_neg_integer()}
      }
```

`opts`: `:desde`, `:ate`.

**O recorte é pela ABERTURA, não pela revisão.** A solicitação conta para a
equipe quando quem a abriu pertencia a ela **na data de abertura**. Recortar pela
data da revisão mediria a equipe de quem revisa — e a medida se chama *tempo até
a primeira revisão*, que é uma espera de quem abriu.

**Só revisão humana encerra a contagem.** `TheBand.Quality` já filtra
`author_type == @humano`; esta função consome e não redefine.

**`{:aguardando, dias}` nunca é omitido nem vira zero.** Ver o data-model: sem as
em espera, a mediana melhora quanto pior a equipe estiver.

`espera` carrega também `autor_login`, para a tela nomear quem abriu sem uma
segunda consulta às pessoas.

### `team_time_to_first_review_by_person/3`

Mesma assinatura, agrupada por autor.

### `agrupar_por_pessoa/1` e `mediana_em_horas/1` — acrescentadas na implementação

**Correção do contrato, escrita quando a tela mostrou o erro** (2026-09-03). A
seção mostra as duas leituras juntas, e chamar `team_time_to_first_review/3` e
depois `..._by_person/3` faria **duas consultas com o mesmo filtro** por render.

`agrupar_por_pessoa/1` é pura e recebe a lista já carregada;
`team_time_to_first_review_by_person/3` passou a ser a composição das duas.

`mediana_em_horas/1` é pura e ignora as em curso: a espera delas não terminou.
Devolve `nil` quando nenhuma foi revisada — zero afirmaria revisão instantânea.

**As duas contagens não somam**, e quem chama precisa dizer isso na tela: a
mesma solicitação tem **um** autor, então aqui não há dupla contagem — mas a
mediana por pessoa e a da equipe respondem perguntas diferentes, e ninguém deve
tentar reconciliá-las.

---

## 3. `TheBand.Ontology.SEON.SPO` — quem trabalhou, e quando

### `who_worked_on/3`

```elixir
@spec who_worked_on(Tenant.t(), Ecto.UUID.t(), periodo()) :: [pessoa_no_projeto()]
@type pessoa_no_projeto :: %{
        person_id: Ecto.UUID.t(),
        name: String.t(),
        login: String.t() | nil,
        equipes: [%{team_id: Ecto.UUID.t(), name: String.t()}],
        periodo: TheBand.Periodos.veredito()
      }
```

A interseção de **três** períodos: pessoa ↔ equipe, equipe ↔ projeto, e a janela
perguntada.

**Vínculo encerrado continua contando** no intervalo em que vigeu. Desligar não
apaga o que houve — é a mesma regra que a feature 055 estabeleceu para a saída de
uma pessoa.

**Pessoa que alcança o projeto por duas equipes aparece uma vez**, com as duas em
`equipes`. Duas linhas somariam a mesma pessoa.

Ordenada por `name`. Sem interseção devolve `[]`, e quem chama diz a ausência em
texto — lista vazia sem explicação é o que FR-011 proíbe.

### `project_repositories_in/3`

```elixir
@spec project_repositories_in(Tenant.t(), Ecto.UUID.t(), periodo()) :: [Ecto.UUID.t()]
```

Os repositórios ligados ao projeto **no período**. Existe para a US3, e usa
`spo_project_repositories.linked_at` / `unlinked_at` — colunas que **nenhuma
consulta usava**.

### As variantes em lote — acrescentadas na implementação

**Correção do contrato, escrita quando o teto de consultas reprovou**
(2026-09-03). A tela da equipe pergunta por **todos** os projetos dela de uma vez,
e as funções por projeto, chamadas num laço, fariam a página consultar por linha —
o defeito que o teto da feature 057 existe para impedir.

```elixir
@spec who_worked_on_many(Tenant.t(), [Ecto.UUID.t()], periodo()) ::
        %{Ecto.UUID.t() => [pessoa_no_projeto()]}
@spec project_teams_with_period_many(Tenant.t(), [Ecto.UUID.t()]) :: [map()]
@spec project_repositories_with_period_many(Tenant.t(), [Ecto.UUID.t()]) :: [map()]
```

`who_worked_on_many/3` custa **duas** consultas para qualquer número de projetos, e
`who_worked_on/3` passou a ser ela com um id — uma implementação só, e por isso
uma regra só.

### `team_projects_ever/2` e `team_project_links_with_period/2`

**Correção do contrato, escrita quando um teste mostrou o erro** (2026-09-03). A
seção usava `list_team_projects/2`, que filtra `is_nil(unlinked_at)` porque serve
à associação. Com ele, **o projeto de que a equipe saiu sumia da tela inteira**,
levando junto todo mundo que trabalhou nele — contra a FR-008.

`team_projects_ever/2` devolve os projetos por que a equipe passou, um por
projeto. `team_project_links_with_period/2` devolve **cada vínculo** com seu
período: ligada, desligada e religada são dois intervalos, e colapsá-los antes de
intersectar contaria o intervalo do meio, em que a equipe não estava lá.

---

## 4. `TheBand.Verification` — a taxa da equipe

### `team_pipeline_rate/3`

```elixir
@spec team_pipeline_rate(Tenant.t(), Ecto.UUID.t(), keyword()) ::
        {:ok, taxa()} | {:sem_projeto, %{equipe: String.t()}}

@type taxa :: %{
        sucesso: non_neg_integer(),
        falha: non_neg_integer(),
        interrompida: non_neg_integer(),
        nao_executada: non_neg_integer(),
        expirada: non_neg_integer(),
        em_andamento: non_neg_integer(),
        execucoes_consideradas: non_neg_integer(),
        percentual: float() | nil,
        denominador_do_percentual: non_neg_integer(),
        repositorios: non_neg_integer(),
        caminho: String.t()
      }
```

`opts` aceita `:desde`, `:ate`, e mais dois que **existem para não repetir
trabalho de quem chama**: `:nome`, o nome da equipe — a tela já o tem, e sem ele a
recusa custaria uma consulta para escrever uma palavra que já está na página; e
`:vinculos`, a lista de vínculos equipe ↔ projeto já carregada, que a seção de
quem trabalhou nos projetos carrega de qualquer jeito.

### Os DOIS denominadores — acrescentados na implementação

**Correção do contrato, escrita ao implementar** (2026-09-03). O tipo original não
tinha percentual nenhum, e a tela teria de inventar um denominador — que é
exatamente o que a FR-013b proíbe.

`execucoes_consideradas` são as que **terminaram**, nas cinco fases.
`percentual` é `sucesso / (sucesso + falha)`, e `denominador_do_percentual` diz
sobre quantas. São dois números diferentes de propósito: dividir o sucesso pelas
cinco fases faria a taxa cair a cada cancelamento, e chamar isso de *taxa de
sucesso do pipeline* culparia o pipeline por decisão humana.

`percentual` é **nil** quando nada produziu resultado. Zero diria que tudo falhou;
nil diz que não há o que dividir.

`repositorios` é quantos repositórios entraram na conta — parte do tamanho da
amostra que a FR-016 exige junto do número.

**O caminho é `repositório → projeto → equipe`**, e não o ator da execução.

O ator é quem **disparou**, não quem cuida do código: execução agendada tem por
ator quem configurou o agendamento; de `push`, quem empurrou. Uma equipe cujo CI
roda por agendamento apareceria quase vazia (R1).

**`actor_person_id` não é usado por esta função.** Existe na tabela, e usá-lo
produziria uma segunda taxa com o mesmo rótulo e denominador diferente — a L67.

**As cinco fases são campos próprios**, e nenhuma soma a `falha`.
`em_andamento` fica **fora** de `execucoes_consideradas`.

**`execucoes_consideradas` é obrigatório.** A cobertura do dado é desconhecida
(R6), e uma taxa de 100% sobre três execuções não é a mesma afirmação que sobre
trezentas.

**`{:sem_projeto, _}` é o relator**, e não uma taxa de zero. Zero diria que o
pipeline falhou; a verdade é que a plataforma não sabe de quais repositórios
aquela equipe cuida.

---

## O que este contrato **não** oferece

| Ausente | Motivo |
|---|---|
| taxa por ator da execução | R1 — outra pergunta, e o nome enganaria |
| início "aberto" como padrão para `nil` | é desconhecido, e afirmar seria inventar |
| tempo médio de revisão sem as em espera | a mediana andaria para o lado errado |
| soma entre nível pessoa e nível equipe | respondem perguntas diferentes |

---

## Regras que valem em todas as funções acima

1. **Tenant explícito, sempre** — princípio V, FR-022.
2. **Ausência é relator, nunca zero** — `{:aguardando, _}`, `{:sem_projeto, _}`,
   `{:parcial, _}`.
3. **A vigência é avaliada contra a data do evento**, e não contra hoje — é o que
   faz SC-002 valer.
4. **Erro previsto é retorno**, e exceção fica para bug.
