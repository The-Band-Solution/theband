# Tarefas — Feature 014: clicar leva à página

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md)
Cinco tarefas em três fases. Nenhuma consulta nova.

## F1 — o detalhe da issue

### T001 Ligar autor e designados quando há pessoa
- **Pronta quando**: nada além do repositório.
- **Descrição**: em `lib/the_band_web/live/work_item_live/show.ex`, o nome do autor vira
  `<.link navigate={~p"/people/#{@issue.author_person_id}"}>` **quando** `author_person_id` existe;
  cada designado idem, por `a.person_id`. Sem `person_id`, o texto fica como está — e a frase
  *"person not collected"* permanece. FR-001, FR-002, FR-004.
- **Feita quando**: autor e designados com pessoa levam à página dela; sem pessoa, não há `<a>`; e
  a frase que explica continua na tela.
- **Teste**: `test/the_band_web/live/clicar_leva_a_pagina_test.exs` — o `assert` do caminho com
  pessoa, e o **`refute`** do caminho sem, que é o que impede a feature de virar defeito.

## F2 — o detalhe da equipe

### T002 Ligar os membros
- **Pronta quando**: T001 feita.
- **Descrição**: em `teams_live/show.ex`, o nome e o login do membro viram ligação para
  `~p"/people/#{member.person.id}"`. Membro cuja participação **não é mais observada** continua
  clicável e continua marcado: a pessoa existe, a participação é que acabou. FR-001.
- **Feita quando**: clicar no nome ou no login chega à mesma página; a marca de não observado
  permanece.
- **Teste**: o mesmo arquivo — inclusive o caso do membro ausente.

## F3 — provar o que não mudou

### T003 [P] Nome sem destino continua texto
- **Pronta quando**: T001 e T002 feitas.
- **Descrição**: teste que monta issue com autor **sem** pessoa e exige zero ligações para
  `/people`; e confere que nenhum nome de **organização** virou ligação, na lista de pessoas e nas
  sincronizações. FR-002, FR-003.
- **Feita quando**: os dois casos passam, e a frase explicativa continua no HTML.
- **Teste**: `refute html =~ ~r{<a[^>]*href="/people/}` na região do autor não coletado.

### T004 [P] Nenhuma consulta nova
- **Pronta quando**: T001 e T002 feitas.
- **Descrição**: contar consultas por render, antes e depois, nas duas telas. FR-010, SC-006.
  **O contador exclui as tabelas do Oban** — é a L42, e foi o que reprovou o CI da feature 013.
- **Feita quando**: o número é idêntico ao de antes nas duas telas.
- **Teste**: o mesmo `contar_consultas/1` já usado em `person_detail_test.exs`.

### T005 [P] Ligação alcançável por teclado e sem depender de cor
- **Pronta quando**: T001 e T002 feitas.
- **Descrição**: as ligações usam `<.link>`, que renderiza `<a href>` — alcançável por tabulação e
  acionável por `Enter` sem código. A distinção visual não pode ser só cor: o estilo de ligação do
  design system já traz sublinhado no foco. FR-005, FR-006.
- **Feita quando**: cada ligação é `<a href>` real, e o estilo aplicado não é só `text-primary`.
- **Teste**: asserção sobre o markup — `href` presente, e a classe de ligação do design system.

## Cobertura

| Requisito | Tarefa |
|---|---|
| FR-001, FR-004 | T001, T002 |
| FR-002, FR-003 | T003 |
| FR-005, FR-006 | T005 |
| FR-007 | T001, T002 — as rotas existem e o teste segue |
| FR-008 | T001 — o botão do GitHub continua separado |
| FR-009, FR-010 | T004 |
| SC-001, SC-002 | T001, T002 |
| SC-003, SC-004, SC-005 | T003 |
| SC-006 | T004 |
| SC-007 | T004 |
