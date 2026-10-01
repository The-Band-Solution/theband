# PROMPT — o campo de rótulos no detalhe da issue

Protótipo: [`issue-detail-labels.html`](issue-detail-labels.html) ·
publicado em <https://claude.ai/artifact/EuS2pDSjnvpKuUiQJ4sKSj> · 2026-09-29 ·
**aprovado em 2026-09-29 pela pessoa mantenedora**.

## 1. Os pedidos, textuais e em ordem

**Da pessoa mantenedora** (os que regem este campo; nenhum pedido novo dela para este protótipo):

1. 2026-09-13, entrada da spec 065: *"as labels podem vir do campo label do github ou do titulo
   `[Devops]`, por exemplo"*.
2. 2026-09-13, decisões da listagem: coluna por último; três rótulos e um `+N` que **abre a
   issue**; a cor do GitHub não é usada (registradas no topo da `spec.md`).
3. 2026-09-07: *"quero exatamente a tela aprovada"*.
4. 2026-09-29, via Product Owner: Q1, Q2 e Q3 pela recomendação — origem **escrita** ao lado das marcas, uma linha por origem; o derivado no mesmo cartão *As the source describes it*; a frase do protótipo para a ausência. D1–D3 aprovadas. A normalização de caixa não entra na #904: virou a feature #1023.

**Do Product Owner, que encomendou este protótipo** (2026-09-29, textual):

> Tarefa: protótipo do campo de RÓTULOS no DETALHE da issue (`/work/issues/:id`), para corrigir
> o defeito D1 da feature 065 (issue #904, 065/US1). […]
> O defeito medido: issue `[Devops] …` com rótulo `backend` — `/work` mostra `backend`
> (observado, sólido) E `Devops` (derivado, hachura+contorno); o detalhe mostra só `backend`,
> `badge-ghost`, sem origem.
> Entregue: 1. Um protótipo navegável publicado como Artifact (HTML), com dado REAL de
> desenvolvimento quando possível (consulta SÓ DE LEITURA ao banco dev, se precisar — nunca
> escreva), mostrando o campo de rótulos do detalhe em três casos: (a) só do campo; (b) do campo
> + derivado do título; (c) sem rótulo nenhum (ausência escrita, nunca vazio). Mesma gramática da
> listagem: sólido = observado, hachura+contorno = derivado, texto sempre junto (title e texto
> visível/legível), distinguível em tons de cinza. Todos os rótulos (sem o corte 3+N da
> listagem, que é da linha). Interface em inglês.

## 2. O brief de design seguido

- **Herdar, não reinventar**: tokens, marcas e textos de `title` da coluna aprovada de `/work`
  (`https://claude.ai/code/artifact/cd7d0245-b8bf-459b-9e90-8089a2fc0339`) e do componente
  `TheBandWeb.UI.rotulos/1` (`lib/the_band_web/ui.ex`). Observado = verdete sólido; derivado =
  azul `info` hachurado com contorno, texto sobre fundo próprio; ausência = tracejado.
- **Uma mudança só**: a linha `labels` do cartão *As the source describes it*
  (`lib/the_band_web/live/work_item_live/show.ex`, hoje `badge-ghost` sobre `@issue.labels`).
  As demais linhas aparecem como *unchanged*.
- **Origem escrita**, além da forma e do `title`: uma linha por origem, não por chip.
- **Sem corte**: todos os rótulos (máximo medido: 6 do campo + 1 do título).
- **Ausência escrita e atribuída**: de quem é cada metade — do campo na origem, e do título para
  a plataforma.
- **Dado real** do `the_band_dev`, consulta só de leitura (ver `README.md`). Nenhum nome de pessoa.
- **Tons de cinza conferíveis** na própria página (botão *View in greyscale*).

## 3. A estrutura aprovada, seção por seção — a régua do QA

O QA confere na tela real (`/work/issues/:id`), com captura ao lado, **inclusive em tons de
cinza**:

| # | item | o que tem de existir |
|---|---|---|
| 3.1 | lugar | a linha `labels` continua no cartão **As the source describes it** (*Q2 Decided (a) em 2026-09-29, pela pessoa mantenedora*: o derivado fica neste cartão, no mesmo campo), entre `assignees` e `milestone`; nada mais no cartão ou na página muda |
| 3.2 | rótulos do campo | cada rótulo vigente do campo como marca **sólida** (verdete, texto em `paper`), `title="observed — set on the label field at the source"`, texto do rótulo **como escrito** |
| 3.3 | rótulo do título | quando o título começa com prefixo **declarado**, uma marca **hachurada com contorno** (azul `info`), texto sobre fundo próprio, `title="derived — read from the bracketed prefix in the title"`, grafia sem colchetes e sem normalização |
| 3.4 | ordem | primeiro todos os do campo (na ordem de `Rotulos.de/2`), depois o do título |
| 3.5 | origem escrita | ao lado de cada grupo, texto visível: **`observed — set on the label field at the source`** e **`derived — read from the bracketed prefix [<Prefixo>] in the title`** (este com o prefixo entre colchetes, em `code`). *Q1 Decided (a) em 2026-09-29, pela pessoa mantenedora* |
| 3.6 | sem corte | todos os rótulos; nenhum `+N`; quebram linha dentro do campo em telas estreitas |
| 3.7 | sem deduplicação | `backend` do campo e `Back-end` do título aparecem os dois (#2212) |
| 3.8 | ausência | sem rótulo de origem nenhuma: marca **tracejada** `no label` e o texto **`none on the label field at the source, and no declared prefix in the title`**; nunca vazio, nunca `—`. *Q3 Decided (a) em 2026-09-29, pela pessoa mantenedora* |
| 3.9 | prefixo não declarado | `[Portal ADM]` e outros fora da lista **não** viram rótulo (#956 cai em 3.8) |
| 3.10 | cor da origem | a cor do rótulo no GitHub **não** é usada |
| 3.11 | mesma leitura da listagem | para a mesma issue, o conjunto e a ordem dos rótulos no detalhe são **os mesmos** da linha em `/work` (teste independente da US1) |
| 3.12 | cinza | em tons de cinza, observado × derivado × ausente continuam distinguíveis pela forma **e** pelo texto (SC-003) |

Casos de conferência com dado real: `plataformas-project#461` (defeito), `autherix#13` (a),
`conectafapes-project#2212` (b), `conectafapes-project#956` (c).

## 4. Como cada papel usa este arquivo

- **Product Owner**: registra o link e este `PROMPT.md` no item do backlog da #904, leva as
  perguntas Q1–Q3 à pessoa mantenedora e aceita a entrega só conferida contra a seção 3.
- **Design**: marca *Decided <data>* nas respostas e republica **no mesmo endereço**.
- **Elixir/Phoenix Developer**: implementa exatamente a seção 3; o que não for possível ou
  honesto com o dado volta ao protótipo, não é improvisado no código.
- **QA**: confere item a item 3.1–3.12 na tela renderizada, com captura colorida e em cinza, por
  quem não implementou.

## Decisões

*Decided 2026-09-29*, pela pessoa mantenedora, todas pela recomendação do Design: D1–D3 aprovadas; Q1 (a) origem escrita, uma linha por origem; Q2 (a) o derivado no mesmo cartão; Q3 (a) a frase do protótipo para a ausência. Detalhe no `README.md` e na seção *Decisions and open questions* do HTML.

**Fora do escopo**: a normalização de caixa dos prefixos não entra na #904 — é a feature #1023.

---

# PROMPT — a linha divergente em `/work` (065/US2 emendada, #905)

Protótipo: [`divergences-row.html`](divergences-row.html) · publicado em
<https://claude.ai/artifact/Bkv3vSduKwE1y4sgBea8tW> · 2026-09-30 · **aprovado em 2026-09-30 pela pessoa mantenedora**.

## 1. Os pedidos, textuais e em ordem

**Da pessoa mantenedora**, 2026-09-30 (registrados na US2 emendada da `spec.md`):

1. A linha mostra **tipo declarado** (a alegação) e **conceito derivado** (o veredito) lado a
   lado, e diz que DIVERGEM. O rótulo NÃO é um dos lados.
2. Os rótulos aparecem na linha como CONTEXTO, com a origem de cada um; sem rótulo, `no label`
   basta.
3. CADA LINHA diz, em palavras, QUAL LADO a plataforma seguiu. Para `user_story_without_parts`,
   o lado seguido é o declarado ("concept kept").
4. 2026-09-07: *"quero exatamente a tela aprovada"*.
5. 2026-09-30, via Product Owner: Q1, Q2 e Q3 pela recomendação — a linha `why:` que nomeia a
   estrutura; o bloco dentro de `promoted to`; a alegação é o `issue_type` como escrito na origem,
   e o `declared_concept` vazio vira bug próprio. D4 aprovada.

**Do pedido que encomendou o protótipo** (2026-09-30, textual, trecho):

> Tarefa: protótipo da LINHA da tela de divergências para a 065/US2 emendada (issue #905). […]
> Use dado REAL do banco de desenvolvimento, SÓ DE LEITURA […] pelo menos uma
> `user_story_without_parts` com rótulo, uma sem rótulo, e, se existir, outro tipo de divergência.
> Mostre "hoje" e "proposto" lado a lado. Mobile-first (a tabela com mais de 3 colunas empilha).
> Distinguível em tons de cinza. Interface em inglês.

## 2. O brief de design seguido

- Herdar tokens, marcas de rótulo e textos de `title` de `issue-detail-labels.html` e da coluna
  aprovada de `/work`; a marca de evidência é a de `<.evidence>` (sólido = tipo declarado,
  hachurado = estrutura).
- Uma mudança na linha: um bloco dentro de `promoted to`, substituindo a linha âmbar de hoje.
  Nenhuma coluna nova; a coluna `labels` não muda.
- "Diverge" em três canais sem cor: borda dupla, glifo `≠` e a palavra. "Seguido" em palavras,
  e reforçado por sublinhado sólido (seguido) × pontilhado (não seguido).
- Dado real do `the_band_dev`, só leitura (ver `README.md`); a linha de outro tipo é `example`.

## 3. A estrutura aprovada, seção por seção — a régua do QA

Vale para a tabela *Issues* de `/work` e para a do detalhe do repositório.

| # | item | o que tem de existir |
|---|---|---|
| 3.1 | onde | só nas linhas com `divergence_kind`; o bloco fica na célula `promoted to` (*Q2 Decided (a) em 2026-09-30*), **abaixo** da marca de evidência, e substitui a linha âmbar de hoje |
| 3.2 | marca de divergência | cabeçalho **`≠ diverges · type and structure`**, borda dupla âmbar; legível em cinza pela borda, pelo glifo e pela palavra |
| 3.3 | os dois lados | lado a lado: **`declared type · claim`** com o `issue_type` como escrito (ex.: `Feature`; *Q3 Decided (a) em 2026-09-30*) e **`derived concept · verdict`** com `ConceptLabel.rotulo/1` (ex.: `atomic user story`) |
| 3.4 | o porquê | linha **`why: <frase do tipo>`** (*Q1 Decided (a) em 2026-09-30, pela pessoa mantenedora*): `no parts and no tasks are linked to it` · `task with collected parts` · `typed Epic, and it has no parts` · `composition makes it an epic` |
| 3.5 | lado seguido | linha **`followed: the declared type — concept kept, flagged as a signal`** quando `divergencia_mudou_conceito?/1` é falso; **`followed: the structure — concept decided by the axiom; …`** quando é verdadeiro; o lado seguido tem sublinhado sólido, o outro pontilhado |
| 3.6 | reason completo | `divergence_reason` no `title` do bloco |
| 3.7 | rótulos fora do bloco | nenhum rótulo dentro do bloco; a coluna `labels` continua como aprovada (última, 3 + `+N`, origem por marca e `title`, `no label`) |
| 3.8 | cartão | contagem e frases por tipo inalteradas; o vazio passa a **`None. Declared type and structure agree on every issue.`** |
| 3.9 | telefone | a tabela empilha; o bloco fica sob o rótulo `promoted to` da linha empilhada; nada rola na horizontal |
| 3.10 | cinza | em tons de cinza: diverge, lado seguido × não seguido, e as três origens de rótulo distinguíveis por forma **e** texto |

Casos de conferência: `edite-project#6`, `conectafapes-project#2280`, `agentes-project#13`.

## 4. Como cada papel usa este arquivo

- **Product Owner**: registra link e prompt na #905 e abre o bug do `declared_concept` vazio;
  aceita só conferido contra a seção 3. Q1–Q3 e D4: *Decided 2026-09-30*, pela pessoa mantenedora.
- **Design**: marca *Decided <data>* e republica no mesmo endereço.
- **Elixir/Phoenix Developer**: implementa exatamente a seção 3; o que não couber volta ao
  protótipo.
- **QA**: confere 3.1–3.10 na tela real, com captura colorida e em cinza, por quem não implementou.
