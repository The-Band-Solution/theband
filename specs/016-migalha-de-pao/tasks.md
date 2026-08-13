# Tarefas — Feature 016: a migalha de pão

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md)
Cinco tarefas em três fases.

## F1 — o componente

### T001 O componente `<.breadcrumb>`
- **Pronta quando**: nada além do repositório.
- **Descrição**: em `core_components.ex`, ao lado do `<.header>`. Recebe uma lista de níveis, cada
  um com rótulo e destino; **destino `nil` é o nível atual**, e não vira ligação. Marca semântica:
  `<nav aria-label>` e `aria-current="page"` no último. Separador por CSS, nunca por texto no
  rótulo. FR-002, FR-003, FR-005, FR-006, FR-009.
- **Feita quando**: nível com destino é `<a href>`; o último não é; e o separador não entra na
  leitura do leitor de tela.
- **Teste**: `test/the_band_web/live/migalha_test.exs` — o `refute` do `<a>` no último nível.

## F2 — as telas

### T002 As cinco telas de detalhe declaram o caminho
- **Pronta quando**: T001 feita.
- **Descrição**: `people_live/show`, `teams_live/show`, `work_item_live/show`,
  `repository_live/show` e `sync_live/mapping_rules`. Cada uma declara a própria lista. FR-001.
- **Feita quando**: as cinco exibem migalha, e as seis telas raiz não exibem.
- **Teste**: o teste percorre as **onze** rotas e assere presença ou ausência — não uma amostra.

### T003 Remover os dois jeitos antigos de voltar
- **Pronta quando**: T002 feita.
- **Descrição**: sai o botão `voltar` de `teams_live/show` — **em português, numa interface em
  inglês** — e o `back to people` de `people_live/show`. Os botões da issue **ficam**: `Repository
  issues` e `View at source` não são "voltar", são ações. FR-007.
- **Feita quando**: a palavra `voltar` não existe mais em `lib/the_band_web/`; e `back to people`
  também não.
- **Teste**: asserção sobre o HTML das duas telas, mais `grep` no diretório como parte do teste.

### T004 O caminho da issue diz de onde vim
- **Pronta quando**: T002 feita.
- **Descrição**: chegando pela lista do repositório, o caminho inclui o repositório; chegando pela
  lista de trabalho, não. Sem percurso — endereço colado —, vale o **estrutural**, pelo repositório
  que é dono da issue. FR-004.
- **Feita quando**: os três casos produzem os três caminhos.
- **Teste**: três casos no mesmo arquivo, e o do endereço colado é o que mais importa.

## F3 — a prova

### T005 [P] Nenhuma consulta nova, e 360 px
- **Pronta quando**: T002 feita.
- **Descrição**: contar consultas por render nas cinco telas, antes e depois — **excluindo as
  tabelas do Oban**, que é a L42. E conferir que em 360 px o **primeiro** nível continua visível.
  FR-008, FR-010, SC-004, SC-005.
- **Feita quando**: o número é idêntico; e a asserção de 360 px existe, **declarada como asserção
  em HTML** — olho humano continua sendo de quem tem a tela.
- **Teste**: o mesmo `contar_consultas/1`, mais a asserção da classe que encurta o último nível.
