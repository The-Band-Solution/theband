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
