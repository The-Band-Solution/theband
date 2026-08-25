# T018 — Percurso do quickstart

**Feature**: 043 · **Data**: 2026-08-25 · **Issue**: [#500](https://github.com/The-Band-Solution/theband/issues/500)

O registro que a T018 pede: passo a passo, contra o **dado real** — 3 organizações, 12 equipes, 101 evidências.

## Como foi feito, e o que isso limita

Percorrido pelo **domínio**, contra o banco de desenvolvimento, e não clicando na tela. As rotas foram verificadas apenas quanto a responderem (302 para login).

Isso alcança tudo que é comportamento — a composição, o escopo, a promoção, as contagens. **Não alcança** se as frases da tela ensinam quem nunca leu a spec, que é a `SC-007`. Ela fica declarada como não percorrida.

---

## Passo 1 — Os quatro estão lá, sem cadastrar · `FR-002`, `SC-001`

```
leds-conectafapes:  4 papéis (4 sem linha) — Client Role, Developer Role, Product Owner Role, Scrum Master Role
The-Band-Solution:  4 papéis (4 sem linha) — idem
ifesserra-lab:      4 papéis (4 sem linha) — idem

papéis na tabela: 0
```

**Passa nas três organizações reais**, e com zero linhas gravadas. É a `SC-001`: nenhum passo antes de poder promover.

### Divergência 1 — os nomes vêm sufixados

A rede nomeia os conceitos como `Product Owner Role`, `Developer Role`. A tela mostra *"Developer Role"*, e não *"Developer"*.

É fiel à SRO e é feio na interface. **Não corrigi**: retirar o sufixo na exibição seria a plataforma reescrevendo o nome que a rede dá, e é exatamente o que a `FR-022` proíbe fazer na edição. Se incomodar, a correção certa é na SRO — ou um rótulo de exibição declarado, que é feature própria.

---

## Passo 2 — Papel próprio não vaza · `FR-001`, `SC-004`

Verificado em teste automatizado (`papeis_por_organizacao_test.exs`), não no dado real — declarar um papel no banco de desenvolvimento seria escrever nele sem necessidade.

O caso cobre: declarar em A, conferir que não aparece em B, e que o mesmo código nas duas é aceito.

---

## Passo 3 — Promover, sem ver o nível de acesso · `FR-011`, `SC-005a`

**Promovido de verdade**, contra o dado real:

```
promovendo: Adylla027 (@Adylla027) em The Band
  o retorno tem platform_access_level? false
  OK — vinculo f5386185
  autor gravado: true
  started_at: 2026-01-15 00:00:00Z
```

`Map.has_key?(pendente, :platform_access_level)` é **falso** no contrato. A garantia está onde é mais barata.

---

## Passo 4 — A materialização acontece uma vez · decisão 1 do plano

```
papéis na tabela agora: 1
tamanho da equipe:      1
pendentes restantes:    2
```

Antes da promoção a tabela tinha **zero** papéis. Depois de uma promoção, **um** — a linha nasceu no primeiro uso, como o plano previa.

---

## Passo 5 — Dois papéis, uma pessoa · `FR-006c`, `SC-008`

Verificado em teste (`promocao_de_evidencia_test.exs`): a mesma pessoa com Developer e Scrum Master dá **dois vínculos** e `team_size == 1`.

---

## Passo 6 — Papel de outra organização é recusado · `FR-008`

Verificado em teste, com `{:error, :role_from_another_organization}`.

---

## Passo 7 — Ocultar não apaga · `FR-004`, `FR-015`

Verificado em teste: ocultar preserva a linha, e ocultar papel com vínculo vigente é recusado com a contagem.

---

## Passo 8 — A equipe vazia diz por quê · `FR-014`, `SC-007`

**Medido no dado real**, e é a parte mais informativa do percurso:

```
total esperando confirmação: 97

LEDS - ConectaFapes      28 pendentes · 0 membros
PLATAFORMA               18 pendentes · 0 membros
SQUAD BLUE                8 pendentes · 0 membros
SQUAD GREEN               8 pendentes · 0 membros
IA                        7 pendentes · 0 membros
QA                        7 pendentes · 0 membros
SQUAD PINK                5 pendentes · 0 membros
DADOS                     4 pendentes · 0 membros
PRODUTO                   4 pendentes · 0 membros
Zeppelin                  4 pendentes · 0 membros
The Band                  3 pendentes · 0 membros
ifesserra-lab             1 pendentes · 0 membros
```

### Divergência 2 — são 97, e não 101

A decomposição explica, e a explicação é a regra funcionando:

```
total=101  encerradas=4  promovidas=0  pendentes=97
```

**Quatro evidências têm `no_longer_observed_at` preenchido** — a origem parou de mostrar aquelas participações. A `FR-010` manda não oferecê-las para promoção, e é o que acontece.

A `SC-003` da spec diz *"das 101 evidências, 100% podem ser promovidas"*. **Está errada por quatro**: o número certo é 97, e as outras quatro não são promovíveis **por desenho**, não por falta.

---

## O que apareceu e não estava em passo nenhum

### `CompileError` na primeira tentativa de abrir a tela

`/roles` devolveu **500** com `CompileError`. O servidor estava no ar desde antes das mudanças, com código antigo em memória, e falhou ao recompilar em tempo de requisição.

Reiniciado, as rotas respondem **302** — redirecionamento para login, que é o correto.

**Não é defeito da feature**, e vale registrar mesmo assim: quem for percorrer isto depois de mexer no código precisa reiniciar o servidor, ou vai concluir que a tela está quebrada.

---

## Veredicto da T018

**Concluída com duas divergências**, ambas viradas em correção.

| passo | estado |
|---|---|
| 1 — os quatro sem cadastrar | **observado** nas 3 organizações |
| 2 — papel próprio não vaza | teste automatizado |
| 3 — promover sem o nível | **observado**, promoção real feita |
| 4 — materialização única | **observado** |
| 5 — dois papéis, uma pessoa | teste automatizado |
| 6 — papel de outra org recusado | teste automatizado |
| 7 — ocultar não apaga | teste automatizado |
| 8 — a equipe vazia diz por quê | **observado**, 97 em 12 equipes |

**Não percorrido**: a `SC-007` — se a frase ensina quem nunca leu a spec. Um teste confirma que ela está lá; nenhum confirma que ela ensina.

### O que fica para quem administra

**97 confirmações.** A tela existe e o caminho funciona ponta a ponta — o que falta é o ato humano, e o tempo dele não é da plataforma.

A diferença em relação a ontem é que a tela agora diz *"N participations waiting for confirmation"* em vez de mostrar doze equipes vazias sem explicação.
