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
        | {:parcial, [:inicio_desconhecido | :fim_desconhecido]}

@spec interseccao([periodo()]) :: veredito()
```

Borda `[início, fim)` — fechada no início, aberta no fim, a mesma da feature 057.

**`nil` é desconhecido, e nunca "aberto".** Um período com `inicio: nil` que se
sobrepõe aos demais devolve `{:parcial, [:inicio_desconhecido]}`, e **não**
`:intersecta`.

Essa é a razão de o módulo existir. Tratar `nil` como aberto é o fallback
silencioso que a feature 057 corrigiu no vínculo, e a regra precisa viver num
lugar só — escrita três vezes, divergiria na primeira correção.

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

### `team_time_to_first_review_by_person/3`

Mesma assinatura, agrupada por autor.

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
        caminho: String.t()
      }
```

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
| período "aberto" como padrão para `nil` | `nil` é desconhecido |
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
