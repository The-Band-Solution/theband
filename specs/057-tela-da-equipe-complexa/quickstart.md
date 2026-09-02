# Quickstart — Feature 057

Como provar que a feature funciona, do zero. Cada cenário aponta o requisito e o
critério que ele verifica.

## Pré-requisitos

```bash
mix deps.get
mix ecto.setup          # nenhuma migração nova nesta feature
mix knowledge.validate
```

Precisa existir, no tenant de teste: uma organização, pessoas, uma equipe
declarada, e issues coletadas com `external_created_at` e `external_closed_at`
preenchidos. As fixtures da feature 055 já produzem equipe declarada com
composição.

---

## Cenário 1 — O passado não se reescreve *(US1, SC-002)*

**É o cenário mais importante da feature.** Se ele falhar, nada mais importa.

```bash
mix test test/the_band/profiles/team_skills_test.exs
```

1. declarar equipe com três pessoas, com trabalho fechado em janeiro, março e
   junho;
2. abrir `/teams/:id`, anotar a série de evolução mês a mês;
3. registrar a saída de uma pessoa com data em **julho**;
4. reabrir a tela.

**Esperado**: os pontos de janeiro a junho têm **exatamente** os mesmos valores.
Só julho em diante muda.

**Falha típica que este cenário pega**: o conjunto de membros ser lido uma vez e
aplicado a todos os meses — o defeito de origem (R9).

---

## Cenário 2 — Quem saiu para de contar na saída *(US1, SC-001)*

1. pessoa com vínculo encerrado em 2026-03-15;
2. ela fecha uma issue em 2026-03-10 e outra em 2026-04-02.

**Esperado**: a de março conta para a equipe; a de abril **não**.

Repetir com vínculo **invalidado** (equívoco da 055): **nenhuma das duas** conta,
em período nenhum.

---

## Cenário 2b — Vínculo sem data de início continua contando *(FR-006a, SC-011a)*

Pessoa com `started_at` nulo — o que `Commands.allocate/2` grava quando a data é
desconhecida.

**Esperado**: aparece nas medidas em **qualquer** data, e a tela declara que a
data de início é desconhecida.

**A falha que este cenário pega** é silenciosa: escrita como `started_at <= data`,
a comparação avalia para desconhecido contra nulo e o Postgres descarta a linha —
a pessoa deixa de ser membro em data alguma, sem erro e sem aviso.

---

## Cenário 3 — Nada é somado *(US2, SC-003)*

1. equipe A composta por B e C;
2. a mesma pessoa em B **e** em C;
3. a mesma issue atribuída a ela.

```bash
mix test test/the_band_web/live/teams_live/show_test.exs
```

**Esperado na tela de A**: uma linha para B, uma para C, uma para membros
diretos, e **nenhuma célula de total**. O texto explica que a pessoa conta nas
duas e por isso não se soma.

**Verificação direta**: a tela renderizada não contém as palavras `total`,
`sum` ou `combined` em cabeçalho de coluna.

---

## Cenário 4 — Uma issue de duas pessoas conta uma vez para a equipe *(R4)*

Mesma issue atribuída a duas pessoas **da mesma** equipe.

**Esperado**: a série da equipe conta **1**. As linhas por pessoa mostram **2** —
uma para cada — e a tela declara por que os dois números diferem.

Este é o cenário que o `DISTINCT` de `team_state_changes_by_period/4` protege.

---

## Cenário 5 — A distância entre as curvas é o trabalho aberto *(US5, SC-004)*

1. 12 issues abertas antes da janela e ainda abertas;
2. na janela: 6 criadas, 4 fechadas.

**Esperado**: `escopo` da primeira semana parte de **12**, não de zero.
Na última semana, `aberto == 12 + 6 - 4 == 14`, e bate com a contagem direta de
issues em aberto naquela data.

**Sem a linha de base o teste devolve 2, e o gráfico mentiria por 12** — R2.

---

## Cenário 6 — A previsão recusa quando não tem histórico *(US6, SC-010)*

Equipe com 3 semanas e 4 issues fechadas.

**Esperado**: `{:sem_historico, %{semanas: 3, semanas_exigidas: 6, fechadas: 4,
fechadas_exigidas: 10}}`. A tela mostra o que falta, e **nenhuma faixa**.

---

## Cenário 7 — A previsão é a mesma duas vezes *(US6, SC-009)*

```elixir
{:ok, a} = TheBand.Forecast.monte_carlo(serie, aberto: 19)
{:ok, b} = TheBand.Forecast.monte_carlo(serie, aberto: 19)
assert a == b
```

Igualdade estrita, não tolerância. Se falhar, a semente está vindo do relógio.

---

## Cenário 8 — Quando quase nada termina, a tela diz isso *(US6, FR-035)*

Série em que a abertura supera o fechamento — por exemplo `criadas` somando 76 e
`fechadas` somando 57 em 8 semanas.

**Esperado**: `congelado` traz percentis; `vivo` traz `nao_concluiram` perto do
total de rodadas e os três percentis em `nil`.

**A tela apresenta a proporção.** Omitir transformaria "quase nunca termina" em
"termina em poucas semanas".

---

## Cenário 9 — Todas as tarefas, e a ausência dita *(US4, SC-006)*

1. pessoa com **duas** issues abertas;
2. outra pessoa da equipe **sem nenhuma**.

**Esperado**: duas linhas para a primeira, com tempos distintos e **sem** nenhuma
marcada como atual; a segunda aparece com `No open task assigned` em texto.

Issue aberta há mais de 90 dias traz a marca de parada, e o texto diz que é
convite a perguntar. **O tempo é contado da abertura**, e a tela declara isso —
R1.

---

## Cenário 10 — Habilidade abaixo do piso *(US4, FR-023)*

Pessoa com material insuficiente para perfil.

**Esperado**: nenhuma pílula, e o motivo escrito. **Não** uma seção vazia, e
**não** zero habilidades — a distinção entre "nenhuma" e "não foi possível ler" é
o ponto.

---

## Cenário 11 — Ver não exige administrar *(SC-012)*

Pessoa **sem** escopo de administrar equipes abre `/teams/:id`.

**Esperado**: abre e lê tudo. Não vê os controles de declarar, compor ou registrar
saída.

---

## Cenário 12 — Isolamento entre tenants *(SC-011)*

Dois tenants povoados ao mesmo tempo, cada um com equipe de mesmo nome.

**Esperado**: nenhuma consulta desta feature devolve linha do outro tenant.
Obrigatório pelo princípio V, e coberto por teste com dois tenants.

---

## Os gates, antes do PR

```bash
mix gates
```

É a definição única — o veredito é o código de saída dela, e qualquer comando
depois substitui esse código. Não rodar os gates um a um e concluir pelo texto.
