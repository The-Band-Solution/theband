# Research — Feature 057

O que foi conferido no código antes de planejar, e as decisões que saíram disso.
Três achados mudaram a spec; estão marcados.

---

## R1 — A origem não registra quando a atribuição aconteceu *(mudou a spec)*

**Conferido em**: `lib/the_band/work_items/person_work.ex:96-120`, documentação de
`state_changes_by_period/3`.

> `issue_assignees` **não guarda quando a designação aconteceu** — a origem não
> fornece. Decisão da pessoa mantenedora em 2026-08-27: **sem essa data, a issue é
> da pessoa**, e o período dela é o da própria issue.

**Decisão**: o tempo em tarefa é contado da **abertura do item**, nunca da
atribuição, e a tela declara isso.

**Razão**: a spec pedia "tempo desde a atribuição" (FR-019 na primeira redação). O
dado não existe. Derivá-lo de qualquer outra coluna — primeira movimentação,
primeiro comentário, data de criação — seria inventar uma data e apresentá-la como
observada. A decisão de 2026-08-27 já resolveu a mesma questão para a série da
pessoa, e mantê-la aqui evita duas definições do mesmo tempo na mesma plataforma.

**O que piora**: uma tarefa assumida tarde lê como mais lenta do que foi, e o
limiar de parada de 90 dias dispara para casos em que a pessoa está há uma semana
nela. A tela diz isso em texto — é limitação declarada, não erro escondido.

**Alternativas descartadas**:

- *Usar a primeira movimentação de quadro como proxy da atribuição* — só existe
  para issues com timeline coletada, e criaria duas populações com definições
  diferentes de tempo na mesma tabela;
- *Adiar a medida até a origem fornecer a data* — a pergunta "há quanto tempo isto
  está parado" é respondível com o que existe, e adiá-la entregaria a tela sem o
  que ela existe para mostrar.

**Efeito na spec**: FR-019 reescrito, FR-019a acrescentado, cenário novo em US4,
suposição do limiar reescrita.

---

## R2 — O acumulado de janela não mede trabalho em aberto *(mudou a spec)*

**Conferido em**: `person_work.ex:255-285`, documentação de `burn/1`.

> O acumulado começa no primeiro período da série, e não em zero absoluto.

**O problema**: com o acumulado partindo de zero na primeira semana da janela, a
distância entre as curvas mede **os itens nascidos dentro da janela e ainda
abertos** — não o trabalho em aberto. Uma equipe com 40 itens abertos há seis
meses e nenhuma abertura nas últimas oito semanas apareceria com distância zero.

**Decisão**: o acumulado de abertos parte da **contagem de itens já em aberto no
início da janela** — uma linha de base.

**Por que fecha a conta**: `aberto(t) = aberto(t₀) + criadas(t₀..t) − fechadas(t₀..t)`.
Com a linha de base, fechar um item nascido antes da janela reduz a distância
corretamente, e a identidade de FR-028 passa a valer em qualquer ponto.

**Custo**: uma consulta a mais por equipe. Aceito — sem ela o gráfico afirma menos
trabalho aberto do que existe, que é o pior tipo de erro numa tela de gestão.

**Efeito na spec**: FR-026a acrescentado, caso de borda novo.

**Achado colateral, fora de escopo**: a página da pessoa tem a mesma limitação,
com o mesmo `burn/1`. Não é corrigido aqui — mudar a página da pessoa exigiria
critério de revisão próprio e teto de consultas próprio. **Registrado como item de
backlog** ao final desta feature.

---

## R3 — `burn/1` já calcula o burn-up/burn-down pedido

**Conferido em**: `person_work.ex:279-285`.

```elixir
def burn(serie) do
  serie
  |> Enum.scan(%{escopo: 0, feito: 0}, fn d, acc ->
    %{periodo: d.periodo, escopo: acc.escopo + d.criadas, feito: acc.feito + d.fechadas}
  end)
  |> Enum.map(&Map.put(&1, :aberto, &1.escopo - &1.feito))
end
```

`escopo` é o burn-up (acumulado de abertas), `feito` é o burn-down (acumulado de
fechadas), `aberto` é a diferença. **É exatamente FR-026 a FR-028.**

**Decisão**: reusar a função, estendida com a linha de base de R2 —
`burn(serie, aberto_inicial \\ 0)`. Nada de burn novo para equipe.

**Razão**: é função pura sobre uma série. O que muda entre pessoa e equipe é
**quem produz a série**, não como ela acumula. Escrever um segundo acumulador
criaria duas definições de burn que divergiriam na primeira correção.

**O que piora**: `burn/2` ganha um parâmetro que a página da pessoa sempre passa
como zero, e alguém lendo a assinatura pode achar que a pessoa também tem linha de
base. Mitigado no `@doc` e no item de backlog de R2.

**Sobre o campo `aberto`**: FR-027 proíbe apresentar o que resta como **terceira
série**. Não proíbe calculá-lo — é o mesmo número que a altura da faixa
representa. A restrição é de apresentação, e vive na tela.

---

## R4 — A série por equipe, e por que não é uma consulta por pessoa

**Conferido em**: `state_changes_by_period/3` faz `join` em `issue_assignees` com
`a.person_id == ^person_id`.

**Decisão**: uma consulta por equipe, com `a.person_id in ^ids_dos_membros` e
`DISTINCT` na issue.

**O `DISTINCT` é obrigatório e não é detalhe**: uma issue atribuída a duas pessoas
da mesma equipe apareceria duas vezes no `count`. Para a **equipe** ela é um item
só. Isto é o oposto da regra por pessoa (FR-025), onde a mesma issue aparece para
cada pessoa de propósito — e a diferença entre as duas contagens é o motivo de
FR-008 proibir somar as linhas.

**Alternativa descartada**: chamar `state_changes_by_period/3` uma vez por membro
e somar. Somaria a issue compartilhada duas vezes, produzindo exatamente o número
que a feature existe para recusar.

---

## R5 — Como restringir a série ao período do vínculo

**O ponto difícil**: o conjunto de membros muda ao longo da janela. Uma consulta
com `person_id in ^ids` usa **um** conjunto para todas as semanas — que é o defeito
de origem desta feature.

**Decisão**: a condição de pertencimento entra na consulta como **junção com o
vínculo**, e não como lista de ids:

```text
issue ⋈ assignee ⋈ membership
  onde membership.team_id = ?
    e membership.invalidated_at é nulo
    e membership.started_at <= <a data do evento da issue>
    e (membership.ended_at é nulo ou membership.ended_at > <a data do evento>)
```

A data comparada é **a do evento que a série conta** — `external_created_at` na
série de abertas, `external_closed_at` na de fechadas. Assim cada semana é
avaliada contra quem pertencia **naquela semana**, e não contra quem pertence hoje.

**Isto é o que faz SC-002 passar.** Registrar uma saída amanhã não muda nenhuma
linha cuja data do evento seja anterior à saída.

**A borda é `[started_at, ended_at)`** — fechada no início, aberta no fim, a mesma
convenção de `count_team_members_at/3`. Divergir dela faria quem troca de equipe
num mesmo dia contar nas duas.

**Alternativa descartada**: calcular a série em Elixir filtrando por período. Traz
todas as issues da equipe para a memória, e o filtro por data de vínculo é
exatamente o que o banco faz bem.

---

## R6 — Monte Carlo determinístico

**Exigência**: FR-036 e SC-009 pedem que a mesma consulta produza a mesma
previsão. Simulação com semente de relógio viola isso.

**Decisão**: semente derivada de valores estáveis — `tenant_id`, `team_id` e as
bordas da janela — via `:rand.seed(:exsss, {a, b, c})` num processo isolado por
chamada.

**Razão**: a previsão é lida numa reunião e conferida depois. Duas leituras
diferentes do mesmo dado destroem a confiança mais rápido do que uma previsão
larga. E a semente estável não é enfeite: é o que torna o resultado testável com
igualdade em vez de tolerância.

**O que piora**: dois períodos adjacentes com histórico parecido produzem
trajetórias correlacionadas, o que não afeta os percentis mas pode surpreender
quem compara duas equipes. Aceito.

**Número de rodadas: 10 000.** Suficiente para o percentil 95 ser estável na
segunda casa, e barato — a simulação é aritmética sobre uma lista de 8 números.

**Alternativas descartadas**:

- *Fórmula analítica* — exige distribuição assumida; a amostragem do histórico
  real não assume nenhuma, e é o argumento central da técnica;
- *Reusar `projecao/1`* — devolve ponto e recusa quando não converge. Recusar é
  correto para um ponto, mas a pergunta "qual a chance de terminar" tem resposta
  mesmo quando a maioria das rodadas não termina; é FR-035.

---

## R7 — O piso da previsão

**Decisão**: 6 semanas completas dentro do período coletado **e** ao menos 10
itens fechados na janela. Abaixo disso, `{:sem_historico, o_que_falta}`.

**Razão**: com 3 semanas e 4 fechamentos, a reamostragem devolve faixa que cobre
quase todo o horizonte. Uma faixa de 2 a 11 semanas não informa, e apresentá-la
com rótulo de 85% empresta autoridade a ruído.

**O que piora**: equipe nova não vê previsão nas primeiras semanas. É o
comportamento correto — e a tela diz o que falta e quando aparecerá.

---

## R8 — O piso de perfil já existe; não se inventa outro

**Conferido em**: `lib/the_band/profiles/team_skills.ex:24` — "Quem não tem perfil
vem **nomeado**, nunca somado como zero (FR-004)".

**Decisão**: FR-023 consome o piso já em vigor na geração de perfis. Esta feature
**não** define piso próprio para habilidades.

**Razão**: dois pisos para a mesma pergunta divergiriam, e a tela da pessoa e a da
equipe passariam a discordar sobre quem tem perfil.

---

## R9 — O defeito de `evolution/2`, e por que ele é o mesmo de R5

**Conferido em**: `team_skills.ex:70-95` e `:210-215`.

`membros/2` chama `list_team_members(team_id, include_no_longer_observed: false)` —
lê a **evidência de hoje**. `evolution/2` chama `membros/2` **uma vez** e usa o
resultado para recontar todos os meses.

**Duas consequências**, e a segunda é a que SC-002 proíbe:

1. quem saiu continua contando depois da saída, se a origem ainda o lista;
2. quando a origem para de listar alguém, a pessoa some **de janeiro também** — o
   número de um mês fechado muda hoje.

**Decisão**: `membros/2` passa a receber a data — `membros(tenant, team_id, quando)`
—, e `evolution/2` chama uma vez **por mês da série**, com o corte daquele mês.

**Custo**: uma consulta por mês em vez de uma. Aceito, e limitado: a série tem um
ponto por mês **que teve geração de perfil**, não um por mês do calendário.

**Alternativa descartada**: carregar todos os vínculos com seus períodos e filtrar
em memória. É viável e seria mais rápido; foi descartado porque a condição de
vigência tem três partes e já está escrita e testada em SQL — reescrevê-la em
Elixir criaria a segunda definição de "vigente", que é o defeito que a 055 gastou
um sprint para eliminar.

---

## R10 — Onde a tela se divide

**Conferido em**: `router.ex:70-71` — existem `/teams` e `/teams/:id`.
`teams_live/show.ex` tem hoje: estrutura, membros, projetos, avisos de processo e
competências.

**Decisão**: **uma rota só**, `/teams/:id`, com a tela escolhendo o que mostrar
conforme a equipe tenha ou não subequipes.

**Razão**: é a mesma pergunta — "como está esta equipe". O princípio X pede uma
razão para mudar por tela; aqui a razão é uma só, e a composição é um atributo da
equipe, não outra pergunta. Duas rotas exigiriam decidir qual abrir antes de saber
se a equipe é composta.

**O que piora**: `show.ex` já é grande e ganha mais. Mitigado extraindo os blocos
como componentes de função no mesmo módulo web, e mantendo **toda** a lógica de
medida fora da LiveView.

**Alternativa descartada**: rota `/teams/:id/sub/:sub_id`. Uma subequipe é uma
equipe; dar a ela URL diferente da própria tela faria a mesma equipe ter dois
endereços conforme o caminho de chegada.
