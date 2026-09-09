# A marca do conceito — a cor, e a família a que ela pertence

Decidido em 2026-09-08. Pedido textual da pessoa mantenedora: *"coloque uma cor no símbolo da
Task .. tá sem cor"*.

Vale para `defp marca/1` em `lib/the_band_web/live/teams_live/show.ex`, na seção *What each
person is on* da aba Dashboard de `/teams/:id`.

## 1. O veredito: as duas famílias não partilham paleta — e o protótipo aprovado já decidiu isso

O protótipo aprovado da 060 separa as duas famílias **pela forma, não pela cor**:

| família | classe do protótipo | forma | cor |
|---|---|---|---|
| origem e estado do vínculo | `.marca` | borda de 1.5px **e um quadrado de 0.6rem** cujo preenchimento é o canal — cheio (`.dec`, `.obs`), hachurado (`.der`, `.eqv`), tracejado (`.aus`), com linha (`.saiu`) | info, verdete, âmbar, clay, tinta-2 |
| taxonomia e rótulo | `.chip` | borda de 1.5px, **sem quadrado** | tinta-2 por padrão; cor **só** onde a cor é a identidade (`s1`/`s2`/`s3`, que são tokens próprios, fora dos quatro semânticos) |

A marca do conceito é um **chip**, não uma marca de evidência. E o chip é sem matiz por
definição.

**A causa da tensão é uma divergência da implementação, não uma questão de desenho.** Na coluna
*link* da aba Structure a implementação renderiza `declared`/`observed`/`left`/`mistake` como
badge nu — **o quadrado desapareceu**. Sem o quadrado, sobra a matiz como único canal, e as duas
famílias passam a disputar as mesmas seis cores. É por isso que hoje `BUG` e `mistake` são a
mesma classe (`badge-error badge-outline`) e `TASK` e `observed` são a mesma classe
(`badge-ghost`).

Regra que fica: **matiz pertence à origem e ao estado. A identidade do conceito é carregada pelo
texto** — e, na forma abreviada de três letras, por peso e fundo. A única matiz que a família do
conceito toma de empréstimo é o **clay**, e só para o defeito: o significado declarado do clay
nesta casa é "equívoco **e gravidade**", e um defeito é o caso da gravidade.

## 2. As classes

Duas camadas, e não cinco, porque o texto já distingue as cinco: a cor só precisa **acelerar o
achado do raro**. Ler `EPIC` como tarefa engana sobre escopo; não achar `BUG` engana sobre
gravidade. `US` e `TASK` são 1 048 dos 1 154 itens abertos — são o fundo da lista, e o fundo da
lista se lê, não se varre.

| marca | classe pronta para colar | razão em uma frase |
|---|---|---|
| `EPIC` | `badge-neutral font-semibold` | neutro cheio, sem matiz semântica: o mais raro (35) e o mais largo da escada, e um contêiner lido como folha engana sobre escopo |
| `US` | `badge-soft font-semibold` | o fundo da família com tinta plena e peso alto: um degrau abaixo do épico, um acima da tarefa |
| `TASK` | `badge-soft` | o fundo da família com tinta plena e peso normal — **um chip definido no lugar do buraco do `badge-ghost`**, e quieto porque são 760 itens |
| `BUG` | `badge-error badge-soft font-semibold` | a única matiz da família: clay é gravidade nesta casa, e `soft` a mantém fora dos preenchimentos da evidência (cheio, hachurado, tracejado) e fora da forma `outline` que **todo** badge de estado desta tela usa |
| conceito novo sem rótulo (cláusula `is_binary`) | `badge-dash text-base-content/80` | tracejado é o `absent` da casa: a base classificou, a tela não sabe nomear — lacuna do registro, e o identificador impresso já é o texto |
| `nil` (`—`) | `badge-dash text-base-content/60` | mesma forma de lacuna, mais apagada: não há o que ler, e a regra recusou chutar |

São **seis** cláusulas, não cinco: a captura `is_binary` e a `nil` dizem coisas diferentes e hoje
compartilham `badge-ghost`.

### Por que `TASK` estava "sem cor" — a razão é mecânica

`badge-ghost` é `background-color: var(--color-base-200)` com borda da mesma cor. No tema claro
`#eef0ee` sobre `#f7f8f7` é 3% de diferença: fundo que não existe. No tema escuro `#0f1513` é
**mais escuro** que a base `#151b19` — o chip lê como buraco.

`badge-soft` é tinta plena de `base-content` sobre 8% dela misturada à base. Claro ≈ `#e5e7e6`
(mais escuro que a base, visível); escuro ≈ `#212725` (mais claro que a base, visível). Nos dois
temas o fundo aparece, e no sentido certo.

### E `badge-soft` não estava em uso

`badge-soft` não aparece em nenhum arquivo de `lib/the_band_web/`. É uma forma **livre** neste
código — e é por isso que a família do conceito pode tomá-la inteira: passa a se distinguir de
todo badge de estado da tela pela forma, em cor, em monocromático e no papel impresso.

Feliz coincidência que não é coincidência: `badge-error badge-soft` calcula um fundo ≈ `#f3e6e3`
no claro e `#2b1a17` no escuro — praticamente os tokens `--clay-soft` (`#f3e3df` / `#2c1712`) do
próprio protótipo aprovado. A decisão é **derivada** do design system, não inventada.

## 3. Os conflitos, nomeados

1. **Verdete em `US` e `EPIC` colide com observado/declarado.** `badge-primary` e
   `badge-secondary` são a primária desta interface, cujo significado fixo é "a origem afirmou"
   (é o que o comentário dos dois temas em `app.css` diz). São 323 chips afirmando "observado"
   sobre uma taxonomia. **Resolvido:** o verdete sai da família do conceito. Depois disso, o
   verdete na aba Dashboard significa uma coisa só — evidência (os contadores de competência em
   `badge-primary badge-outline`).
2. **`badge-ghost` em `TASK` colide com sete coisas.** Nesta tela `badge-ghost` marca hoje:
   `TASK`, conceito sem rótulo, `—`, `start date unknown`, `observed`, nome de squad e papel
   oculto. Sete significados, um tratamento — e três deles são estados de ignorância, vizinhos da
   `TASK` na mesma função. **Resolvido** para a família do conceito; os outros quatro usos
   continuam e são defeito a registrar.
3. **Clay em `BUG` e em `mistake`:** a matiz é a mesma, e continua sendo. **Resolvido pela
   forma:** `mistake` fica no `outline` da família de estado, `BUG` toma o `soft`, que nenhum
   badge de estado usa.
4. **Âmbar não estava disponível** e nem foi considerado: na mesma linha, âmbar já é `stale` (o
   badge e os dias em negrito) e as habilidades demonstradas (pílulas tracejadas). **Azul `info`
   também não:** é `declared` no protótipo (`.dec`) e na implementação (`badge-info` em
   `teams_live/index.ex` e em `access_scopes_live`). **Não há matiz livre nesta paleta** — é o
   argumento central desta decisão.

## 4. CSS novo: nenhum

Nada a acrescentar em `assets/css/app.css` nem em `TheBandWeb.UI`. O design system já tinha a
forma que faltava (`soft`); o defeito era a família do conceito estar usando a paleta semântica.
Uma classe nova aqui esconderia isso.

O que precisa ser escrito é a **regra**, e o lugar dela é o comentário que já existe acima de
`marca_do_conceito/1` — a seção `## Cor não é a marca`, que hoje afirma "as quatro têm cores
diferentes". Passa a ser: *a matiz pertence à origem e ao estado; o conceito se distingue por
texto, peso e fundo; clay só para o defeito, porque clay é gravidade*. Sem isso, a próxima pessoa
alcança o verdete de novo.

## 5. O que fica pendente, e é maior que a cor

**Esta marca não está no protótipo aprovado.** A estrutura aprovada em 2026-09-07 diz, para a
seção People: "papel, todas as tarefas abertas com **idade e parada**, perfil demonstrado,
flags" (`PROMPT.md`, seção da aba Dashboard). A marca de três letras entrou hoje, depois da
aprovação. Pela regra da casa — *a tela implementada é exatamente a tela aprovada* — ela precisa
do protótipo republicado no mesmo endereço e do registro no item do backlog.

Três divergências para o Product Owner levar na mesma viagem:

| na tela | no protótipo aprovado |
|---|---|
| `declared` em `badge-success` (verdete) | `.dec` em **info azul** |
| `declared`/`observed`/`left`/`mistake` sem quadrado | `.marca` **sempre** com o quadrado de 0.6rem, cujo preenchimento é o canal |
| `stale` em âmbar | `.parada` em **clay tracejado** |

Restaurar o quadrado é o que faz a separação das duas famílias voltar a ser por forma, como
aprovado — e é a correção de raiz da tensão. Enquanto ela não vier, as classes da seção 2
resolvem a tensão por conta própria.

### Pergunta aberta para a republicação

**A marca deve ficar num vão de largura fixa?** Hoje `EPIC`, `US`, `TASK`, `BUG` e `—` têm
larguras diferentes, e cada título de tarefa começa num x diferente — quinze itens de uma pessoa
com quinze bordas esquerdas irregulares.

- **(a)** deixar como está: nada muda além da cor;
- **(b)** vão fixo (`w-14`, chip alinhado à direita): os títulos alinham numa borda só.

**Recomendo (b)**, e é mudança de estrutura, não de cor: entra na republicação do protótipo, não
neste commit.

## 6. Medidas novas que pedem YAML

**Nenhuma.** A marca não mostra medida: mostra a promoção que a regra
`github.issue_type_routing` já declara. Nada novo na tela sem declaração na base — princípio IV
satisfeito sem acréscimo.

## 7. O que não foi verificado

- **Não abri a tela.** Sem `mix`, nada foi renderizado: `badge-soft` a 0.65 rem nos dois temas,
  e o peso do mono em negrito nesse tamanho, não foram vistos — foram raciocinados a partir do
  CSS do daisyUI v5.5.20 e dos hexadecimais dos dois temas.
- **Os contrastes foram calculados, não medidos:** `badge-neutral` ≈ 10:1 / 9:1, `badge-soft` ≈
  15:1 / 13:1, `badge-error badge-soft` ≈ 7:1 / 6:1 (claro / escuro). Todos passariam AA; o
  cálculo é meu, e não de ferramenta.
- **Não confirmei no build** que `text-base-content/80` vence a declaração `color` do
  `badge-dash`. É a mesma aposta que o código já faz em produção (`badge badge-outline badge-xs
  text-warning`, na `stale` desta mesma linha), e a ordem de camadas do Tailwind 4 a sustenta —
  mas foi inferida, não observada.
- **Não confirmei que o Tailwind emite `badge-soft`.** A classe não existe hoje em nenhum
  arquivo; os `@source` de `app.css` cobrem `lib/the_band_web`, então ela deve ser gerada ao ser
  escrita — não pude rodar o build para ver.
- **Não olhei as outras telas que mostram conceito.** `<.evidence>` em `/work/issues`,
  `/work/items` e `/repositories` mostra o mesmo conceito **com** quadrado e rótulo por extenso.
  Pela regra desta decisão os dois são coerentes — lá o verdete é a origem, não o conceito —, mas
  não conferi as três telas.
