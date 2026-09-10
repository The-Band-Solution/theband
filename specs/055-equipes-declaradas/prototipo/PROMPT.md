# Protótipo do vínculo declarado — 055, FR-003

Arquivo de três partes: (1) o que a pessoa mantenedora pediu, textual e em ordem; (2) o brief
de design que eu segui; (3) **a estrutura aprovada, seção por seção** — a régua do QA; (4) como
cada papel usa este arquivo.

- Protótipo: [`team-declared-link.html`](team-declared-link.html) — a cópia que vale.
- Endereço publicado, decisões e razões: [`README.md`](README.md).

---

## 1. Os pedidos da pessoa mantenedora, textuais e em ordem

### 2026-09-06 — a emenda que definiu o que sobra para este protótipo

> as pessoas que a origem mostra no time já estão vinculadas quando a tela abre — com papel
> não declarado. O que quem administra faz por elas é declarar o papel, não criar o vínculo
> (FR-013, FR-014). **Vincular do zero continua existindo para quem a origem não mostra.**

### 2026-09-07 — decisões que este protótipo obedece sem rediscutir

> a data da saída é obrigatória; o campo não vem preenchido com hoje — a premissa da 055
> ("hoje, marcada como presumida") fica substituída, porque presunção sem marca no registro
> vira fato.

> equívoco em vínculo observado: permitido. A coleta não recria.

### 2026-09-07 — a regra que dá nome ao papel Design

> quero exatamente a tela aprovada

### 2026-09-10 — o pedido que originou este protótipo

> Desenhe o protótipo do **ato de vincular uma pessoa a uma equipe** — o requisito FR-003 da
> spec 055, que é cláusula **MUST** e **nunca ganhou tela**.
>
> **`EO.declare_team_membership/5` existe, tem `@spec`, tem `@doc`, tem onze testes — e zero
> chamadas em `lib/`.** Nenhuma tela do produto a alcança.
>
> **A saída é declarável e a entrada não.** Essa assimetria é o que o protótipo existe para
> fechar, e ela merece estar escrita na própria tela.
>
> O que decidir, com a razão escrita:
>
> 1. **Onde o ato mora.** A aba *Estrutura* de `/teams/:id` já lista os vínculos com ações por
>    linha. O ato de vincular alguém que **não está na lista** não tem linha onde morar.
>    Decida: formulário acima da tabela, ação no cabeçalho da seção, ou outro lugar — e diga
>    por quê.
> 2. **A busca.** Vincular exige achar a pessoa entre as coletadas. `/accounts` já resolve isso
>    para o elo conta↔pessoa, com nome, login, organização observada e a marca *no longer
>    observed*. Reusar aquele padrão ou desenhar outro? O edge case dos homônimos já matou uma
>    US antes.
> 3. **O papel e a data de início.** FR-003 pede os dois; a FR-016 da 060 diz que a data
>    **MAY** ser declarada no mesmo ato e, em branco, a tela MUST dizer o que assume. Papel
>    também é opcional? Decida e escreva a razão.
> 4. **A pessoa que a origem JÁ mostra.** Se quem administra buscar alguém que já tem vínculo
>    observado nesta equipe, o ato tem de **recusar nomeando** — a emenda diz que ali o que se
>    faz é declarar o papel, não criar um segundo vínculo. Como a recusa aparece, e como ela
>    leva à ação certa?
> 5. **A pessoa vinculada a OUTRA equipe, ou a uma subequipe desta.** Vincular direto nesta
>    também é legítimo (a 060 fala de vínculo direto × via subequipe). A tela precisa dizer o
>    que a pessoa já tem antes de o ato acontecer?
> 6. **A assimetria escrita na tela.** Hoje a saída se declara e a entrada não; depois deste
>    protótipo, as duas se declaram. Onde isso aparece — e o que a tela diz sobre o vínculo
>    **observado**, que continua nascendo sem autor de declaração?
>
> Regras da casa que valem, e duas mudaram HOJE: The One-Ramp Rule (dez passos, nenhum tamanho
> fora deles) e The No-Accent-Edge Rule (nenhuma borda colorida acima de 1px num lado só). (…)
> **O detector é gate**: `node .claude/skills/impeccable/scripts/detect.mjs <seu arquivo>` tem
> de devolver **0**.
>
> Dado real: o banco de desenvolvimento tem 3 contas e 80 pessoas coletadas. E-mail de conta é
> dado pessoal — linhas de exemplo vão marcadas `example`, como os outros protótipos fazem.

---

## 2. O brief de design que eu segui

**Nada de identidade nova.** Tokens, marcas, vozes tipográficas e vocabulário de seção são
herdados de `DESIGN.md`, de `.impeccable/design.json` e dos protótipos aprovados de 057, 060 e
045. O que este protótipo acrescenta é **um dispositivo de composição**, não um estilo: a
**linha de veredito** da busca (`.vd`), três colunas — quem é, o que ela já tem, o ato —, com
borda uniforme de 1.5px na cor semântica e o **quadrado de 0.6rem** carregando o veredito.

**As duas regras de 2026-09-10, cumpridas e auditadas:**

- **The One-Ramp Rule** — o arquivo usa oito dos dez passos: `micro` 0.6875, `label` 0.75,
  `meta` 0.8125, `body` 0.875, `prose` 1, `lead` 1.125, `section` 1.5, `hero` 1.875. **Não usa
  `tick` 0.625** — não há gráfico SVG nesta tela, e `tick` só vale para rótulo de eixo dentro
  de gráfico. Aqui há uma divergência deliberada dos protótipos anteriores: eles põem `th` em
  0.625rem, que a regra de hoje exclui; **este põe `th` em 0.6875rem**, e quem normalizar
  `team-people.html` e `team-dashboard-structure.html` tem aqui o valor certo.
- **The No-Accent-Edge Rule** — nenhuma borda colorida acima de 1px num lado só, e nenhum
  `box-shadow`. Onde a cor carrega sentido ela está na **borda inteira** de 1.5px
  (`.vd.recusa` em barro, `.vd.limite` em âmbar, `.form-inline.novo` em azul) mais camada
  tonal, ou no **quadrado de 0.6rem**. Fios de 1px aparecem só como régua (linha de tabela,
  indentação de `dd`, separador de fase). A única borda colorida acima de 1px é o indicador de
  **aba** (2.5px), herdado literalmente da tela aprovada: aba não é cartão, item de lista,
  aviso nem chamada, e mudá-la faria a aba desta tela divergir da aba da tela aprovada.

**Raios:** três dos quatro passos — `mark` 0.125, `field` 0.25, `box` 0.5. Nenhum outro valor.

**Regras de conteúdo que o desenho obedece:** ausência sempre escrita com dono, nunca zero nem
célula vazia; recusa como estado de primeira classe **com a razão ao lado do botão inerte**;
todo ato dizendo o que faz **e o que não faz**; as duas afirmações lado a lado quando coleta e
declaração discordam; nenhum total somado entre equipe e subequipe; copy em inglês; mostrado em
repouso, sem depender de clique; dado real marcado `real`, inventado marcado `example`; nenhum
e-mail de conta em lugar nenhum da página.

**Dado real, medido no banco de desenvolvimento em 2026-09-10** (é o que os números da tela
dizem, e o que a última seção do protótipo declara):

| medida | valor |
|---|---:|
| pessoas coletadas | 80 |
| contas | 3 |
| equipes | 10 — 9 observadas em github.com, 1 declarada |
| vínculos vigentes | 90 |
| … sem papel declarado | 56 |
| … com papel declarado | 34 |
| … encerrados / equívocos | 0 / 0 |
| … com início desconhecido | 87 |
| evidências de vínculo | 90, em 80 pessoas, nenhuma vencida |
| **vínculos declarados do zero** | **0** — nenhum carrega o identificador `declared_` que o comando escreve |
| **pessoas fora de toda equipe** | **0** de 80 |
| composições declaradas | 4 |
| papéis criados pela organização | 2 |
| Conecta Fapes (`LEDS - ConectaFapes`) | 48 membros — 31 diretos, 17 pelas 3 squads — e 32 pessoas vinculáveis |

---

## 3. A estrutura aprovada, seção por seção — **a régua do QA**

Para cada item: **existe**, **na ordem**, **com o texto**, **com a marca**, **com a ação** e
**com a recusa**. Divergência é defeito, não melhoria de implementação.

### 3.0 O que desta página vira tela do produto

A página tem três faixas `screen N`. **Só a seção nova da tela 1 é código novo**; a tela 2 é o
comportamento da busca dentro dessa seção, e a tela 3 é **razão de desenho**, não uma quarta
tela do produto — os quadros dela existem para que a decisão fique registrada.

| na página | no produto |
|---|---|
| tela 1, seção *Link a person to this team* | **nova seção** de `/teams/:id?tab=structure`, entre *Roles* e *Members* |
| tela 1, seção *Members* | a lista **já aprovada** em 060; muda **uma coluna** (item 3.4) |
| tela 2, resultados e vereditos | o corpo da busca da seção nova, aberto pelo botão |
| tela 3, *the four acts* / *what each kind keeps* / *what the act refuses* | não é tela — é a razão. O produto herda dela só os **textos de recusa** (3.7) |

### 3.1 Cabeçalho da seção nova

1. Título **`Link a person to this team`**, entre a seção *Roles* e a seção *Members* — nesta
   ordem, e nenhuma seção existente movida.
2. Rótulo do cabeçalho: `for someone the source does not show · N of M collected people are
   linkable here`, com **N e M vindos da consulta**, nunca fixos.
3. Botão primário **`＋ Link a person…`** no cabeçalho da seção.
4. **Em repouso a seção aparece com o título, os dois números e o texto — e a busca fechada.**
   Fechada não é ausente: a seção precisa dizer que o ato existe mesmo sem ninguém clicar.
5. Parágrafo: o ato não tem linha onde morar, e é por isso que tem seção.

### 3.2 A busca — passo 1

6. Campo de busca com `placeholder` **`name or GitHub login…`**, `aria-label` próprio, e botão
   `Cancel` ao lado.
7. Escopo escrito abaixo do campo: **pessoas coletadas desta organização**, por **nome ou login
   do GitHub**, **nunca por e-mail**; **no máximo 8 resultados**; consulta **no evento da
   digitação**, nada consultado antes de digitar.
8. Frase: a tela **não cria pessoa** — pessoa existe porque uma coleta a viu; **não achar
   ninguém é resposta**.
9. Frase: **nome, login e organização observada juntos** no resultado, pelo caso dos homônimos.

### 3.3 O formulário — passo 2

10. Rótulo `step 2 · declare the link · opens with the person picked from the search`.
11. Campo **person**: a pessoa escolhida, com nome, login e botão `change`. Não é campo de
    texto livre — não se digita uma pessoa aqui.
12. Campo **role in \<team\>**: seletor com os papéis **da organização** e `＋ new role…` como
    última opção. **`choose a role…` é a opção inicial**, e o ato não acontece com ela.
13. Campo **member since**: data, **vazia**, com a nota `· empty = start unknown`. **O campo
    MUST NOT vir preenchido com hoje.**
14. Botão primário **`Declare the link`**.
15. **O mesmo botão inerte**, precedido do rótulo `the same button, before a role is chosen`,
    com **a razão ao lado**: vínculo vigente sem papel e sem origem é a única forma que a
    plataforma não distingue de um vínculo materializado pela coleta, e ocuparia a vaga que a
    coleta precisa depois.
16. Nota **what this creates**: um vínculo vigente, com **o seu nome** e **a data de hoje** na
    declaração, e o início digitado — ou **início desconhecido, escrito**, se a data ficou
    vazia. Diz que o campo nunca vem com hoje, e que 87 dos 90 vínculos já têm início
    desconhecido.
17. Nota **what it does not do**: não muda nada na origem, não confirma evidência, não vira
    vínculo observado; **a próxima coleta não toca nele**; se a origem passar a mostrar a
    pessoa, a tela mostra **as duas afirmações** e não escolhe.

### 3.4 A lista de membros, com a coluna corrigida

18. Cabeçalho: `48 current · 17 without a declared role · 1 left · 1 mistake · sorted by
    squad`, com os números vindos da consulta; `real` e `example` ditos no parágrafo, não
    dentro do rótulo.
19. Parágrafo: **a coluna `link` passa a nomear como o vínculo veio a existir**; papel e autor
    do papel ficam na coluna `role`. A razão escrita: na tela aprovada, `declared` na coluna
    `link` podia significar duas coisas diferentes, e depois deste ato são dois fatos.
20. Ordem das colunas: `person · role · link · since · squads · (ações)`.
21. Cinco linhas, nesta ordem e com estas marcas:
    - **declarada do zero** (fundo tonal azul): marca `declared`, `by <autor> · <data> · no
      source shows this link`; papel `<papel>` + `declared in the same act`; `since` =
      `unknown`; chip `direct`; ações `Change role · Left the team… · Mistake…`.
    - **observada sem papel**: marca `observed`, `at github.com · last seen <data>`; papel
      *not declared* em itálico âmbar; `since` = `unknown`; ação primária `Declare role`.
    - **observada com papel declarado**: marca `observed` + `the role was declared on the same
      link`; papel com autor e data na coluna `role`; `since` com data real.
    - **saída** (`apagada`): marca `left`, data + quem registrou; `since` = período; ação
      substituída por `history · counted until <data>`.
    - **equívoco** (`apagada`): marca `mistake`, razão entre aspas + data + autor; papel =
      *never had one here*; `since` = `never`; ação substituída por `excluded from every
      measure, on every date · record kept`.
22. Parágrafo final: a linha nova é a única cuja **existência** ninguém observou; **não é
    marcada derivada** — nenhuma regra concluiu, uma pessoa afirmou; e falta a origem
    registrada no vínculo para a marca ser honesta (pergunta aberta 1).

### 3.5 Os seis vereditos da busca

23. Cabeçalho `Results for “<consulta>”` com `N matches of M collected people · at most 8
    shown`.
24. **Cada resultado é uma linha de três colunas**: `quem` (nome, login, organização observada
    ou a marca *no longer observed*) · `what she already has` · o **veredito** com o quadrado
    de 0.6rem, o botão, e a consequência escrita.
25. Os seis vereditos, cada um com o seu texto e a sua ação:

    | # | situação | veredito | ação | o que a tela diz |
    |---|---|---|---|---|
    | 1 | vínculo só em equipe que **não** faz parte desta | `link allowed` (verdete) | `Link to this team` | pessoa pode estar em mais de uma equipe; contagens não somam |
    | 2 | **vínculo observado nesta equipe** | `link refused` (barro, fundo tonal) | botão **inerte** + razão ao lado, **e** `Declare her role ↓` | já é membro; o que falta é o **papel**; declarar completa **aquele** vínculo, não cria um segundo |
    | 3 | vínculo em **subequipe desta** | `allowed — a different fact` (âmbar, quadrado hachurado) | `Link directly anyway` | direto e via squad são afirmações diferentes; a linha mostra `direct` ao lado do chip da squad; **a contagem de membros não muda** |
    | 4 | vínculo **encerrado** aqui | `link allowed — a new link` | `Link to this team` | nasce vínculo **novo**; os dois períodos coexistem; nada já contado muda |
    | 5 | **equívoco** aqui | `link allowed — the mistake stays` | `Link to this team` | o equívoco não é apagado nem contradito; *equívoco* e *saída* nunca colapsam num só |
    | 6 | pessoa que a origem **deixou de mostrar** | `allowed — read the mark first` (âmbar) | `Link to this team` | nada vai confirmar nem encerrar este vínculo; é legítimo, e é o caso para o qual FR-003 existe |

26. Cada linha de veredito que o banco de desenvolvimento **não pode produzir hoje** diz isso
    onde está: 0 vínculos encerrados, 0 equívocos, 0 pessoas que a origem deixou de mostrar.
27. **A busca vazia**: `No collected person matches “<consulta>”`, com o que faria a busca achar
    alguém (uma coleta que alcance a ferramenta, ou o elo da conta em `/accounts`), e a frase de
    que o vazio **não é erro** e não leva vermelho.

### 3.6 A assimetria — os quatro atos de um vínculo

28. Cinco fases, na ordem: **begins — declared** (fundo tonal, `before this prototype: no
    screen`), **begins — observed**, **role declared**, **ends**, **never was**. Cada uma com o
    que o registro guarda e o que havia antes deste protótipo.
29. Quadro **what each kind of link keeps — and what it cannot**: duas afirmações lado a lado,
    cada uma com quadrado de 0.6rem, seis linhas casadas (`who says so`, `keeps`, autor ou
    proveniência **ausente e nomeada**, `role`, `start`, `ends when`).
30. Frase: o autor de um vínculo observado lê **`observed at the source`**, nunca o nome de uma
    pessoa — preencher com a conta que rodou a coleta transformaria observação em afirmação de
    alguém.

### 3.7 As recusas, e como elas falam

31. Seis recusas escritas, cada uma com a razão: já é membro desta equipe; nenhum papel
    escolhido; data de início no futuro; não é administradora e não tem o papel com a concessão
    *gerir estrutura da equipe*; pessoa de outra organização → **`not found`**, nunca "no
    permission"; a mesma pessoa duas vezes → cai na primeira recusa.
32. Frase final: o ato **continua visível**, a razão fica **ao lado**, e onde outro ato é o
    certo a tela oferece **aquele ato** em vez de um beco sem saída.

### 3.8 Decisões e perguntas abertas

33. Seis itens numerados: três propostas com a razão escrita (onde o ato mora; a busca; papel
    obrigatório e data opcional) e três perguntas abertas com opções e recomendação (origem
    registrada × derivada; saída declarável nas duas pontas; evidência que chega depois de um
    vínculo declarado).
34. Seção final **what was measured, and what was not**: o que é `real`, o que é `example`, e
    o que **não foi decidido aqui**.

---

## 4. Como cada papel usa este arquivo

- **Product Owner** — registra no item do backlog o endereço do artifact e este `PROMPT.md`,
  cita os dois na spec, e **leva as três perguntas abertas** da seção 3.8 à pessoa mantenedora.
  Duas delas mudam o que a tela desenha, e o `README.md` diz exatamente o quê. Só aceita a
  entrega conferida item a item contra a seção 3, com captura da tela real ao lado.
- **Elixir/Phoenix Developer** — implementa a seção 3 como está. O `README.md` lista **quatro
  mudanças no domínio** que a tela aprovada exige, e uma delas é um defeito que derruba a
  recusa em 87 dos 90 vínculos do banco. Descobrir que algo aqui não é possível **volta ao
  protótipo**, republicado no mesmo endereço — não se improvisa no código.
- **QA** — confere a seção 3, item por item: existe, na ordem, com o texto, com a marca, com a
  ação, com a recusa. Item ambíguo é para perguntar ao Design; ambiguidade do protótipo é
  defeito do protótipo e se corrige aqui.
- **Design** — republica no **mesmo endereço** a cada mudança, marcando *Decided \<data\>* nas
  decisões que a pessoa mantenedora fechar.
