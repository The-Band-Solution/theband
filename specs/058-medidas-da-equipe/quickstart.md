# Quickstart — Feature 058

Como provar que a feature funciona. Cada cenário aponta o requisito que verifica.

## Pré-requisitos

```bash
mix deps.get
mix ecto.setup          # nenhuma migração nova
mix knowledge.validate
```

---

## Cenário 0 — Medir a cobertura antes de aceitar *(R6)*

**Vem primeiro, e é condição de aceitação.** A pesquisa não conseguiu medir o
banco — a aplicação não sobe neste ambiente (`:missing_master_key`) —, e uma taxa
sobre amostra desconhecida não sustenta decisão.

Com a chave disponível:

```elixir
# quantas execuções chegam a uma equipe pelo caminho escolhido
Repo.aggregate(from(v in "collected_verifications"), :count)
# quantos vínculos equipe ↔ projeto e projeto ↔ repositório existem
Repo.aggregate(from(x in "spo_project_teams"), :count)
Repo.aggregate(from(x in "spo_project_repositories"), :count)
```

**Esperado**: os três números escritos na review do sprint. Se o segundo ou o
terceiro for zero, a US3 entrega **apenas** o ramo `{:sem_projeto, _}` — e isso é
resultado, não falha.

---

## Cenário 1 — A interseção diz quando não sabe *(US2, FR-009, SC-005)*

```elixir
Periodos.interseccao([
  %{inicio: ~U[2026-01-01 00:00:00Z], fim: ~U[2026-06-01 00:00:00Z]},
  %{inicio: nil, fim: nil}
])
```

**Esperado**: `{:parcial, [:inicio_desconhecido, :fim_desconhecido]}` —
**nunca** `:intersecta`.

**A falha que este cenário pega** é silenciosa: tratar `nil` como aberto faz a
resposta parecer certa e afirmar o que ninguém disse. É o mesmo defeito que a
feature 057 corrigiu no vínculo.

---

## Cenário 2 — A borda do intervalo *(FR-012)*

Equipe ligada ao projeto de janeiro a **1º de junho**, pergunta sobre 1º de
junho.

**Esperado**: `:nao_intersecta`. A borda é `[início, fim)` — no instante do fim
já não está.

---

## Cenário 3 — Quem trabalhou no projeto em X *(US2, SC-004)*

1. equipe ligada ao projeto de **janeiro a junho**;
2. pessoa na equipe de **março a dezembro**.

| pergunta | esperado |
|---|---|
| fevereiro | a pessoa **não** aparece |
| abril | a pessoa aparece |
| agosto | **não** aparece — a equipe já saiu do projeto |

---

## Cenário 4 — Desligar não apaga *(FR-008)*

Equipe ligada e depois **desligada** do projeto.

**Esperado**: perguntando pelo intervalo em que esteve ligada, as pessoas
daquele intervalo aparecem.

---

## Cenário 5 — Uma pessoa, duas equipes, uma linha *(FR-010, SC-006)*

Mesma pessoa em duas equipes ligadas ao mesmo projeto.

**Esperado**: **uma** entrada, com `equipes` contendo as duas.

---

## Cenário 6 — A espera em curso não é zero *(US1, FR-004, SC-003)*

1. solicitação aberta há 40 dias, **revisada** em 2 horas;
2. solicitação aberta há 30 dias, **sem revisão**.

**Esperado**: as duas na lista — a primeira `{:revisada, 2.0}`, a segunda
`{:aguardando, 30}`.

**A falha que este cenário pega**: omitir a segunda faria a mediana melhorar
quanto **pior** a equipe estivesse.

---

## Cenário 7 — Robô não encerra a contagem *(US1, FR-003)*

Solicitação revisada primeiro por um robô, depois por uma pessoa.

**Esperado**: o tempo conta até a **humana**, e a tela declara que descarta a do
robô.

---

## Cenário 8 — O recorte é pela abertura *(US1, FR-002, SC-001)*

Pessoa com vínculo encerrado em 2026-03-15; solicitações abertas em 03-10 e
04-02.

**Esperado**: a de março conta para a equipe, a de abril não.

Repetir capturando a lista, registrando **outra** saída, e recapturando: os
valores do período encerrado são **idênticos** — SC-002.

---

## Cenário 9 — A taxa, e o que ela declara *(US3, FR-013, FR-016, SC-007)*

Equipe ligada a um projeto com repositórios que têm execuções coletadas.

**Esperado**: `{:ok, taxa}` com as cinco fases separadas, `em_andamento` **fora**
de `execucoes_consideradas`, e o caminho declarado.

**Na tela**: o número de execuções aparece junto da taxa. Uma taxa de 100% sobre
três execuções não é a mesma afirmação que sobre trezentas.

---

## Cenário 10 — Equipe sem projeto não tem taxa *(FR-013a)*

Equipe declarada, sem vínculo com projeto nenhum.

**Esperado**: `{:sem_projeto, %{equipe: nome}}` — **nunca** uma taxa de zero.
Zero diria que o pipeline falhou; a verdade é que a plataforma não sabe de quais
repositórios essa equipe cuida.

Na tela, o elo que falta é **nomeado**.

---

## Cenário 11 — O ator não entra *(FR-013, R1)*

Execução disparada por alguém **de fora** da equipe, num repositório do projeto
dela.

**Esperado**: ela **conta**. A medida é do pipeline dos repositórios, e não de
quem apertou o botão.

---

## Cenário 12 — Fases não somam a "falhou" *(FR-015)*

Execuções interrompida, não executada e expirada.

**Esperado**: cada uma no seu campo, nenhuma em `falha`. Cancelar é decisão
humana, e contá-la como quebra inflaria a taxa com o que ninguém quebrou.

---

## Cenário 13 — Isolamento entre tenants *(SC-010)*

Dois tenants povoados ao mesmo tempo, com equipes e projetos de mesmo nome.

**Esperado**: nenhuma consulta desta feature devolve linha do outro tenant.

---

## Cenário 14 — Ver não exige administrar *(SC-011)*

Pessoa sem escopo de administrar equipes abre a tela.

**Esperado**: lê as três medidas; não vê os controles de escrita.

---

## Os gates, antes do PR

```bash
mix gates
```

É a definição única — o veredito é **o código de saída dela**, e qualquer comando
depois o substitui.
