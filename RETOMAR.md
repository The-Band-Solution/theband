# Retomar — 2026-08-16, ao fim da rodada de fechamento

**Onde está**: dois PRs abertos, os dois com revisor pedido à equipe `the-band` e o pedido
**conferido** — `reviewRequests` devolveu a equipe, e não lista vazia.

| PR | O que é | Estado |
|---|---|---|
| [#360](https://github.com/The-Band-Solution/theband/pull/360) | feature 027 — a rodada mensal de perfis, 23 issues | 13 gates verdes, 917 testes |
| [#361](https://github.com/The-Band-Solution/theband/pull/361) | o guarda de `:unknown` que faltava ao #359 | 13 gates verdes |

Mergeados nesta rodada: [#330](https://github.com/The-Band-Solution/theband/pull/330) —
perfil de competências — e [#359](https://github.com/The-Band-Solution/theband/pull/359) —
os axiomas ganham tipo próprio, que fecha a issue #320.

**A revisão independente continua sem acontecer.** O pedido existe e está conferido nos
dois PRs; `pulls/<n>/reviews` está vazio nos dois. Pedido é condição necessária, e não
suficiente — está declarado assim no review do sprint 016, e não marcado como cumprido.

## O primeiro comando ao voltar

```bash
docker compose up -d              # o Postgres mora aqui, e sem ele os gates reprovam
set -a && . ./.env && set +a      # a chave mestra e a API_KEY moram aqui
mix phx.server
```

E, para os gates, **nunca com pipe** — é a L60, aprendida nesta rodada:

```bash
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"
```

Perfil real gravado no banco de desenvolvimento, gerado com a API de verdade:
<http://localhost:4000/people/fe70e4e6-b845-46e2-a18a-5394f15f9a6d>

---

# O propósito, reafirmado em 2026-08-16

> **Entender a pessoa pelas habilidades dela, que são materializadas pelas tarefas
> executadas.** Um resumo das competências, **por meio das tarefas**.

O verbo é da SRO, e não é enfeite: a tarefa executada produz o entregável, e o entregável
materializa alguma coisa. **A tarefa é evidência; a competência é o que ela materializa.**

Está no topo porque governa as decisões abaixo, e porque a feature nasceu de um enquadramento
mais estreito — *"o que mudou ao longo do tempo"*. Evolução é **uma das dimensões** da
competência, e não o assunto.

## O formato-alvo, dado em 2026-08-16

Sete seções, na ordem: **Visão Geral · Competências Técnicas · Soft Skills · Constância de
Entrega · Confiabilidade · Áreas de Alocação Futura · Observações.**

As competências técnicas vêm **agrupadas por área** — Back-end, Front-end, DevOps,
Ferramentas — com o específico dentro de cada uma:

> **Back-end:** experiência com .NET, incluindo criação de APIs, integração com sistemas de
> autenticação (OpenFGA, Auth) e manipulação de dados.

### Duas regras minhas que o formato contradiz, e como reconciliar

**1. Eu proibi categoria ampla, e o exemplo usa exatamente elas.** Escrevi *"nunca backend,
nunca DevOps"*. Estava certo sobre o **problema** — "backend" sozinho não diz nada — e errado
sobre a **solução**: proibi o cabeçalho junto com o vazio.

O exemplo resolve melhor: a área é **agrupamento**, e o específico mora dentro. Um leitor
acha "DevOps" na varredura e lê ".NET, OpenFGA, Docker, AWS" logo abaixo. Cinco strings
hiperespecíficas soltas não se varrem.

**Reconciliação**: `area` como agrupamento, `competencias` dentro dela, e a proibição passa a
valer só para o nível de baixo — nenhuma competência pode ser *"boas práticas"* ou
*"resolução de problemas"*.

**2. Eu recusei Soft Skills, e o exemplo mostra como fazê-lo honesto.** Meu argumento era que
44% das descrições foram escritas por terceiros, então o texto não prova como a pessoa
comunica. Continua verdade — mas o exemplo não afirma traço, **nomeia o tipo de tarefa**:

> **Resolução de Problemas:** identificação e correção de erros, tanto no front-end (erros de
> login, CORS) quanto no back-end (erros de compilação, problemas de URL).

Isso é observável: são as tarefas de correção que ela executou. O que continua proibido é
*"é proativo"*, *"é comprometido"* — traço sem tarefa que o mostre.

**Reconciliação**: soft skill entra **com as tarefas que a evidenciam**, e a distinção de
autoria continua valendo — colaboração sai de tarefas compartilhadas (contável), comunicação
só do que a pessoa escreveu.

**3. Liderança técnica agora tem lastro.** O exemplo pede em Áreas de Alocação, e eu não
tinha como sustentar. Com o sinal do item 3 — tarefas abertas para outras pessoas, contável —
passa a ter. Continua sendo "a evidência existe", e não um rótulo na pessoa.

### O que o formato pede e a plataforma ainda não tem

- **"O gráfico de Throughput indica cadência regular"** — a série mensal está no material, mas
  a tela não tem o gráfico. Existe no protótipo de gestão, não na página da pessoa;
- **"Prometido vs Realizado"** — precisa de compromisso registrado. A associação issue↔sprint
  serve, e foi **removida do material** por cobrir de 6% a 95% conforme a pessoa. Reintroduzir
  exige declarar a cobertura por pessoa, senão compara gente medida com gente não medida.

## A consequência estrutural, e é a maior mudança pendente

Hoje o JSON tem `habilidades` como **lista de rótulos soltos**, e as tarefas que as sustentam
vivem numa seção **separada**, `destaques`. Quem lê a linha de habilidades não vê o que a
materializa; quem lê os destaques vê evidência sem saber que competência ela sustenta.

Se a competência é a unidade, **ela carrega as tarefas junto**. As duas seções viram uma:

```jsonc
competencias: [
  {
    nome: "observabilidade com OpenTelemetry e SigNoz",
    o_que_faz_nela: "instrumentou aplicações, montou coletores e painéis",
    tarefas: 14,
    periodos: [1, 2, 3],
    mais_recente: "2026-08",
    // o que MATERIALIZA a competência — com título, não só número:
    // um número não mostra o que foi feito, e quem lê não vai abrir a issue
    evidencia: [
      { numero: 199, titulo: "Spike: Autenticação Keycloak ↔ GitHub ↔ Signoz" },
      { numero: 449, titulo: "Transferir Signoz para VPS" }
    ]
  }
]
```

Aplicado ao formato-alvo, o schema fica:

```jsonc
{
  visao_geral: "string",              // versátil em quê, taxa de conclusão, cadência
  competencias: [{
    area: "Back-end" | "Front-end" | "DevOps" | "Dados" | "Ferramentas" | …,
    itens: [{
      nome: "…",                      // específico: ".NET com APIs e OpenFGA"
      o_que_faz_nela: "…",
      tarefas: 14, periodos: [1,2,3], mais_recente: "2026-08",
      evidencia: [{ numero: 199, titulo: "…" }]
    }]
  }],
  soft_skills: [{
    nome: "Resolução de problemas",   // nunca traço: nada de "é proativo"
    como_aparece: "…",
    evidencia: [{ numero: 412, titulo: "Corrigir erro de CORS no login" }]
  }],
  constancia: "…",                    // usa a série pessoa/projeto do material
  confiabilidade: "…",                // taxa, e o que ela esconde
  alocacao: [{ area: "…", porque: "…", evidencia: [ … ] }],
  observacoes: [ "…" ],               // no máximo três, cada uma nascida do material
  do_time_nao_da_pessoa: "…",         // o contrapeso, obrigatório
  nao_alcanca: "…"                    // obrigatório
}
```

`melhorar` deixa de ser seção própria e vira **`observacoes`**, como no exemplo — mas mantendo
o enquadramento: lacuna do registro, nunca da pessoa.

**A mudança que mais importa está no `evidencia`**: hoje é `[199, 449]`, só números. Com
título, a tarefa aparece como o que ela é — a materialização da competência. Sem título,
a evidência é uma promessa de que existe.

E `melhorar` fica a mesma estrutura com evidência mais fraca: o mesmo objeto, com o que
falta nomeado — rala, envelhecida, ou trabalho que demora.

## O que isso decide, concretamente

| decisão | direção |
|---|---|
| a unidade do relatório | a **competência**, com as tarefas que a materializam dentro |
| o papel no prompt | especialista em competências, não analista de série temporal |
| a evidência | número **e título** — o título é o que mostra a materialização |
| o que vem primeiro | as competências; a trajetória mostra como elas se formaram |
| o que é "melhorar" | a mesma estrutura com evidência rala, envelhecida ou lenta — **do registro**, nunca da pessoa |
| o que não entra | o que a tela já deriva sozinha, e o que o material não sustenta |

---

# O que fazer, na ordem

> **Estado dos nove, conferido em 2026-08-16 contra o código e o banco.** Quatro saíram da
> lista; dois são funcionalidade nova; três são decisão sua.
>
> | # | assunto | estado |
> |---|---|---|
> | 1 | página não recarrega | **entregue** — `Profiles.broadcast/3`, os dois desfechos |
> | 2 | geração automática | **entregue**, no PR #360 |
> | 3 | tarefas abertas para outros | funcionalidade nova, não iniciada |
> | 4 | tirar as abertas do prompt | **entregue**, incluindo o lugar na tela |
> | 5 | competência como unidade | funcionalidade nova, não iniciada — **a maior** |
> | 6 | axiomas `unknown` | **entregue** no #359; o guarda contra a repetição, no #361 |
> | 7 | triagem das issues | **feita** — cada issue recebeu comentário com a medição |
> | 8 | Conecta Fapes | **decisão sua**, e uma parte nem é respondível hoje |
> | 9 | decisões antigas | **decisão sua** |

## As sete decisões que esperam por você

Nenhuma delas é trabalho parado por falta de tempo: são escolhas que a plataforma não pode
fazer sozinha, e três delas estão escritas nas próprias specs como recusa deliberada.

| # | decisão | o que trava enquanto não vier |
|---|---|---|
| 1 | **medir o custo real de uma rodada** ([#356](https://github.com/The-Band-Solution/theband/issues/356)) | a `FR-021` exige a medição antes de N e M valerem. Exige chave real e de 15 a 35 minutos |
| 2 | **percorrer o quickstart a mão** ([#358](https://github.com/The-Band-Solution/theband/issues/358)) | a suíte verde não substitui — três defeitos da rodada anterior só apareceram com a aplicação no ar |
| 3 | **criar ou não as iterações que faltam** ([#176](https://github.com/The-Band-Solution/theband/issues/176)) | `flow.throughput` não separa os sprints 003, 004 e 005 |
| 4 | **qual é o quadro do projeto no Conecta Fapes** | lida só pelo quadro corrente, a entrega parece começar em abril de 2026 com 4 issues |
| 5 | **qual campo de data é o prazo**, por quadro | sem isso, "tarefas em atraso" não existe |
| 6 | **`FR-012` da 023** — quem vê o painel de trabalho de quem | aberta desde 2026-08-14 |
| 7 | **`FR-007` da 022** — qual movimentação marca o início | sem ela não há throughput, WIP verdadeiro nem cycle time pessoal |

**Uma delas nem é respondível hoje.** A pergunta do Conecta Fapes *"done é fechar a issue ou
a coluna do quadro?"* depende do campo `Status`, e a plataforma **não coleta campo de
quadro** — é a issue [#181](https://github.com/The-Band-Solution/theband/issues/181), com a
medição feita em 2026-08-16. Responder por fora, com consulta manual à API, é possível; a
plataforma responder, não.

## 1. A página não recarrega quando a geração termina — **ENTREGUE**

`Profiles.subscribe/2` e `broadcast/3` por tenant e pessoa; `GenerateWorker` anuncia
`:pronto` **e** `{:falhou, motivo}`; `people_live/show.ex:69` assina no `mount` e trata os
dois. A frase da tela virou *"this page updates on its own"*.

O cuidado que este item pedia foi respeitado: anunciar só o sucesso deixaria a tela
esperando um evento que não vem, e espera infinita é indistinguível de "ainda rodando".

<details>
<summary>O texto original do item, preservado</summary>

### A página não recarrega quando a geração termina — defeito entregue

A tela diz *"Requested. The model takes about a minute — reload to see it"*: a plataforma
pedindo à pessoa que faça o trabalho dela. A geração leva de 25 a 60 segundos.

O projeto já tem o padrão: `TheBand.Ingestion` faz `Phoenix.PubSub.subscribe/broadcast` num
tópico por tenant, e `RecomputePromotions` também.

- `GenerateWorker` publica ao gravar — **e também ao falhar**;
- a aba assina no `mount` e recarrega o perfil ao receber;
- o teste é o estado intermediário: pedir, mandar o evento, e afirmar que o perfil aparece
  **sem** um novo `live/2`.

**O cuidado**: um `subscribe` que só recebe sucesso transforma erro em espera infinita, e
espera infinita é indistinguível de "ainda rodando". Mesma família da lição que já reincidiu
sete vezes aqui.

</details>

## 2. Feature 027 — geração automática e periódica — **ENTREGUE, no PR #360**

As 23 issues #331 a #353, com as quatro decisões escritas no corpo do PR. Fica de fora, e
com destino registrado: a **medição do custo real** ([#356](https://github.com/The-Band-Solution/theband/issues/356)),
que a `FR-021` exige antes de N e M valerem, e o **quickstart percorrido a mão**
([#358](https://github.com/The-Band-Solution/theband/issues/358)). Os dois dependem de
chave real, e por isso são seus.

<details>
<summary>A medição que motivou a feature, preservada</summary>

### Feature 027 — a medição de 2026-08-16

Medida em 2026-08-16, **não escrita como spec**. Recomendação: **cron próprio, não no sync.**

| medição | valor |
|---|---|
| pessoas que passam nos pisos | **34** de 41 |
| material mediano por pessoa | 191k chars ≈ **48k tokens** |
| rodada completa | **1,63M tokens** de entrada |
| fecharam 10+ tarefas nos últimos 30 dias | **6** |
| fecharam 1 a 9 | 14 |
| **fecharam nenhuma** | **14** |

Catorze das 34 não fecharam uma tarefa em 30 dias: material idêntico, texto novo diria o
mesmo. O sync roda muito mais que uma vez por mês. E a razão de conceito: **sync é coleta,
perfil é interpretação** — acoplar faz toda observação custar dinheiro.

```
regenera se  (tarefas_fechadas_hoje − tasks_closed_do_perfil) ≥ N
         ou  generated_at mais velho que M meses
```

O recorte já está em coluna para isso — `FR-016`. Com N=10 rodariam **6 de 34**: ~290k
tokens em vez de 1,63M. N e M em `profile.thresholds`.

**De graça**: a tabela é somente-acréscimo, e sem regra de mudança a geração automática a
encheria de textos quase idênticos — o histórico viraria ruído.

> **Decisão pendente antes da spec.** Hoje a geração é ato de alguém. Automática, mais
> leitura aberta ao tenant (`FR-023`), mais sem contestação (`FR-024`), significa que
> **ninguém decide** — o texto passa a existir sobre todo mundo por padrão. Não é
> impeditivo; é decisão, e merece estar escrita como o resíduo das outras duas está.

</details>

## 3. Tarefas que a pessoa abre **para outras** — sinal novo, medido em 2026-08-16

> **Não iniciada.** Conferido em 2026-08-16: nenhuma ocorrência de contagem de autoria para
> outros em `lib/the_band/profiles/`. O material só tem `autoria_propria`, que é outra
> coisa — diz quem escreveu a tarefa **da própria pessoa**, e não para quem ela escreveu.
>
> É funcionalidade nova, e serve à número 5. As duas andam juntas.

Pedido teu: quem abre tarefa para outra pessoa está fazendo algo que a contagem de tarefas
designadas não mostra. **É contável, e não inferido**: `author_login` da pessoa com
designado diferente dela.

Medido no banco real:

| login | abriu | para outros | % | pessoas distintas |
|---|---|---|---|---|
| paulossjunior | 1255 | 1191 | 95% | **28** |
| vinicius-je | 715 | 375 | 52% | 15 |
| marcelasfl | 409 | 283 | 69% | 9 |
| fatasy | 264 | 252 | 95% | **21** |
| joaomrpimentel | 347 | 146 | 42% | 17 |
| sofialctv | 65 | 64 | 98% | 13 |

**Pessoas distintas discrimina melhor que a contagem bruta.** Escrever 200 tarefas para uma
pessoa e 60 para treze são coisas diferentes: a segunda atravessa o time.

### O que falta, e é o ponto que você levantou depois

**Hoje o modelo não vê essas tarefas.** O material é só o que foi *designado à pessoa* —
concluídas e abertas. As que ela **abriu para outros** não entram: nem título, nem corpo. Ele
não pode analisar o que não recebe.

E a contagem sozinha não basta: quem escreve *"corrigir typo"* para outros e quem escreve
*"Inception do SOT DevEx"* com contexto e critério aparecem **idênticos** numa contagem.
Título e corpo é que separam distribuir trabalho de **decompor** trabalho.

### Como eu faria

1. **A contagem vai calculada**, como o veredito da linha de base — o modelo erra conta, já
   provou. Por período: quantas abriu para outros, e para quantas pessoas distintas;
2. **Uma amostra do texto** dessas tarefas entra no material, com teto — as mais recentes,
   digamos vinte, com título e corpo truncado. O material mediano já é de 48k tokens, então
   o teto não é economia, é necessidade;
3. **Campo próprio no schema**, com a interpretação limitada ao que se sustenta.

### O que **não** escrever

`liderança` é conclusão, e a evidência não a sustenta sozinha. Abrir tarefa para outros
também é papel de quem faz triagem, quem escreve requisito, quem coordena entrega, ou quem
simplesmente é o único com permissão no repositório. O que é afirmável:

> *"Escreveu N tarefas executadas por M pessoas diferentes entre <mês> e <mês>, e o texto
> delas traz contexto e critério"* — ou não traz, que também é achado.

Quem lê tira a conclusão. A plataforma não deve rotular pessoa.

## 4. Tirar as tarefas abertas do prompt — **ENTREGUE, inteiro**

As três partes: a seção saiu do material e a contagem ficou em `COBERTURA`
(`prompt.ex:70`); a forma `trava` das lacunas foi reescrita e agora compara as concluídas
contra a **mediana da própria pessoa** — *"40 dias é muito para quem fecha em 3 e normal
para quem fecha em 30"*; e a lista da tela saiu do cartão do perfil e foi para **depois da
tabela de issues** (`people_live/show.ex:632`), com o comentário explicando a proveniência
misturada.

<details>
<summary>A medição que motivou, preservada</summary>

### O corte de até 80% do material

Pedido teu em 2026-08-16, e a razão é dupla.

**É duplicação.** A tela já lista as abertas há mais de 90 dias, a partir de dado observado e
**recalculado a cada leitura** — `Profiles.stale_open/2`. O texto do modelo sobre elas
envelhece; a lista não. Uma tarefa que fechou depois da geração some da lista e continua no
texto.

**E é caro.** Medido:

| login | abertas | material | sem abertas | economia |
|---|---|---|---|---|
| ManoelRL | 103 | 134k | **27k** | **80%** |
| lukevds | 66 | 96k | 32k | 66% |
| vinicius-je | 152 | 320k | 129k | 60% |
| marcelasfl | 103 | 193k | 79k | 59% |
| GustavoACaetano | 60 | 141k | 60k | 57% |
| tadeuaugustovs | 57 | 270k | 223k | 17% |

**Isso refaz a conta da 027.** A rodada completa de 1,63M tokens cai muito, e o teto por
período — o outro achado — pode nem ser necessário depois disto. Medir de novo antes de
decidir o teto.

### O que muda

- sai a seção `TAREFAS EM ABERTO` do material;
- fica **a contagem** em `COBERTURA`, que é uma linha e serve ao parágrafo de atenção;
- a forma `trava` das lacunas **sobrevive, e melhora**: passa a olhar as concluídas que
  demoraram muito acima da mediana da própria pessoa — o `Nd aberta` já está em cada tarefa
  concluída. Deixa de ser "há coisa parada" (que a tela mostra) e vira "neste domínio o
  trabalho demora", que a tela não mostra.

### Onde a lista fica na tela

Complemento teu: **derivada da listagem de tarefas, e posicionada depois dela.** Hoje o bloco
`Open longer than 90 days` mora dentro do cartão do perfil, no meio do texto derivado — e é
fato observado, não conclusão de modelo. Lugar errado por dois motivos:

- **mistura proveniência**: está cercado de blocos hachurados, quando é sólido;
- **repete a consulta**: a página já lista as issues da pessoa logo abaixo.

Tirar do cartão do perfil e pôr **depois da tabela de issues**, derivado dela. A tabela é
paginada, então conferir se dá para derivar do conjunto que a página já carrega ou se a
consulta continua necessária — se continuar, ela é observada e barata, e o guard de consultas
da página precisa ganhar a linha correspondente.

</details>

## 5. O papel e a estrutura — a competência como unidade

> **Não iniciada, e é a maior.** Conferido em 2026-08-16 contra
> `priv/profiles/perfil_schema.json` e `priv/profiles/perfil.md`:
>
> - `habilidades` continua array de string solta, e `destaques` continua seção separada —
>   não viraram `competencias`;
> - `evidencia` é `{"items": {"type": "integer"}}` — **só número, sem título**, que o
>   próprio texto abaixo chama de *"a mudança que mais importa"*;
> - não existem `soft_skills`, `constancia`, `confiabilidade`; `recomendacoes` não virou
>   `observacoes`;
> - o papel ainda abre com *"o que mudou?"*, que é o enquadramento que este item manda
>   trocar.

**Esta é a maior das nove, e as outras oito servem a ela.** A reestruturação do JSON está
descrita no propósito, lá em cima: `habilidades` e `destaques` viram `competencias`, e a
evidência passa a carregar título além do número.

Reflexo na tela: as marcas de habilidade deixam de ser rótulos e passam a abrir para as
tarefas que as materializam. O critério de destaque continua visível — é ele que impede
"competência" de virar opinião.

### O papel no prompt

Pedido teu em 2026-08-16. Hoje o prompt abre com *"Você compara uma pessoa com ela mesma ao
longo do tempo (…) e responde uma pergunta: o que mudou?"* — enquadramento de comparação
temporal, não de competência.

A feature virou sobre **habilidades**: a linha de habilidades é a primeira coisa da tela, os
destaques têm critério próprio, e as lacunas são de evidência de competência. O papel tem de
dizer isso.

**O que trocar**: o enquadramento de abertura, e o peso relativo — **competência primeiro,
evolução como uma das dimensões dela**. A pergunta que o papel responde deixa de ser *"o que
mudou?"* e passa a ser *"em que esta pessoa é forte, e onde a evidência ainda não sustenta?"*.

Reflexo no que a tela mostra primeiro: hoje o resumo abre por forças, o que já está certo —
o que muda é o peso das seções seguintes e o critério de corte do que entra.

**O que não perder** ao reescrever, porque cada um custou um defeito observado:

- **não é avaliação de desempenho** — desempenho é a distância entre combinado e entregue, e
  o combinado não está no material;
- **não compara pessoas** — recebe uma por vez, sem a distribuição;
- **a armadilha da linha de base** — o corpo mediano do projeto foi de 216 para 1310 chars, e
  sem o contrapeso todo perfil conclui que a pessoa aprendeu a documentar;
- **lacuna é do registro, não da pessoa** — não observar não é não saber;
- **sem gênero, sem nível** — o escopo atribuído reflete o nível que o time já presumia.

## 6. Issue #320 — axiomas SRO carregados como `unknown` — **ENTREGUE**

Corrigida no [#359](https://github.com/The-Band-Solution/theband/pull/359), já na `main`:
os axiomas ganharam o tipo `:axiom`, e `KnowledgeBase.axioms/0` e `axiom/1` os devolvem um
a um — nove, sete da SRO e dois da SPO.

**A terceira mordida ficou sem guarda**, e o [#361](https://github.com/The-Band-Solution/theband/pull/361)
é esse guarda: fixa a lista dos **quinze** arquivos que ainda carregam como `:unknown` e
reprova quando ela cresce. A lista separa os dez JSON Schemas — que são `:unknown`
legítimo, porque `SchemaCheck` os alcança pelo caminho — dos **cinco de `sources/`,
`glossary/` e `examples/`, que são conhecimento invisível**, e ficam declarados como
dívida.

## 7. As outras issues abertas — **triagem feita em 2026-08-16**

Cada issue recebeu comentário com a medição, e não com leitura de código.

| # | veredito | evidência |
|---|---|---|
| **82** | **fechada** | `EO.organizations_by_person/2` existe e a tela marca `in N organisations`. Medido: **2 de 88 pessoas** em mais de uma das 3 organizações |
| **81** | aberta, **nada feito** | o único filtro de `/people` é `show_automation`. Não há seletor de organização em tela alguma |
| **181** | aberta, **um terço feito** | 220 iterações gravadas; **11 quadros e 2 nomes de campo**. A própria consulta diz *"só o campo de iteração interessa aqui"*. Não há entidade de quadro: `board_number` é coluna de `sro_sprints`. Os outros **15 dos 26 quadros não existem** para a plataforma |
| **180** | aberta, **bloqueada pela 181** | não há o que mapear: os 17 campos do quadro não são coletados |
| **107** | aberta, **bloqueada pela 181** | idem |
| **108** | aberta, e o achado é preciso | `CMPO.exclude_from_observation/3` existe e funciona; **os únicos chamadores são dois arquivos de teste**. Medido: **0 de 160 repositórios excluídos** — não por falta de vontade, por falta de caminho. É a fatia vertical cortada ao contrário |
| **176** | **decisão sua**, não trabalho | criar as iterações **recria as existentes** (L11, custou reatribuir 96 itens); não criar deixa `flow.throughput` sem separar os sprints 003, 004 e 005 |
| **317, 318** | funcionalidade nova | a **#179 fechou**, então o único bloqueio restante da 317 é a 181; a 318 está sem bloqueio |

## 8. A análise do Conecta Fapes — adiada por você em 2026-08-15

Está inteira na memória, em `conecta-fapes-tem-dois-quadros.md`. O resumo do que espera
decisão:

- **qual quadro é o quadro do projeto** — hoje há dois. O `Conecta Fapes - Delivery` entregou
  980 issues entre jun/2025 e abr/2026; o `Conecta Fapes` assume em junho de 2026. A troca
  não está declarada em lugar nenhum, e lida só pelo quadro corrente a entrega do projeto
  parece começar em abril de 2026 com 4 issues;
- **o que fazer com 275 issues abertas fora do quadro** — 233 num quadro antigo, 42 sem
  quadro algum;
- **coletar timeline do `conectafapes-project`** — tem **zero** eventos de status, e é o que
  destrava homologação e cycle time;
- **se "done" é fechar a issue ou a coluna do quadro** — discordam em 11% onde dá para
  comparar: 13 marcadas `Done` seguem abertas, 12 fechadas nunca saíram do `Backlog`.

Painel com tudo: <https://claude.ai/code/artifact/170d05f0-c706-4232-ba47-9cad7bfae29b>

## 9. Decisões antigas ainda abertas

- **qual campo de data é o prazo**, por quadro. A sondagem achou 33 campos de data em 24
  quadros, com **três significados em duas línguas** — `End date` é fim planejado ou fim
  real? Sem essa declaração, "tarefas em atraso" não existe;
- **`FR-012` da feature 023** — quem vê o painel de trabalho de quem. A 026 não herdou a
  lacuna, decidiu a dela; a 023 segue aberta desde 2026-08-14;
- **`FR-007` da feature 022** — qual movimentação marca o início. Sem ela não há throughput,
  WIP verdadeiro nem cycle time pessoal.

---

# O que já está entregue

## Feature 026 — perfil de competências (PR #330, **mergeado** em 2026-08-16)

Aba na página da pessoa: habilidades como marcas, resumo em três parágrafos, trajetória em
três períodos, destaques com o critério visível, lacunas classificadas por forma, tarefas
paradas, e o contrapeso da linha de base.

**A decisão de modelagem** está em `research.md` R1: nenhum conceito de competência entra na
rede. Criar `eo.competence` faria a plataforma afirmar que a pessoa *tem* a habilidade — o
que a spec recusa — e licenciaria "quem sabe X", pergunta que a evidência não sustenta.

**Quatro recusas com quatro frases**, porque são quatro fatos: `:no_assignment`,
`:below_floor`, `:period_too_thin`, `:no_text_to_compare`.

**O modelo responde em JSON Schema com `strict: true`.** Consertou três coisas que não eram
o objetivo: o modelo largara os subtítulos numa geração e a limpeza apagara dezenove citações
em silêncio; a regra de não citar no resumo fora pedida quatro vezes e ignorada; e a regra de
devolver lacunas vazias passou a ser obedecida ao virar campo de array.

Protótipo da tela: <https://claude.ai/code/artifact/5240baae-c064-4d44-b3ee-aa2cb7e62a14>

## Features anteriores, mergeadas

- **022** timeline das issues e os quatro antipadrões, tela `/process`
- **024** sprints do Projects v2 — 220 sprints, 2225 vínculos. **Só as iterações**: quadros
  e campos não são coletados, e é a issue #181
- **025** projeto, subprojetos e repositórios, com seletor de busca múltipla

## Os scripts do scratchpad

`gerar_perfis.exs` e `enviar_relatorios.exs` foram o protótipo do pipeline, e **estão
superados** pela feature na aplicação. Servem só para rodar em lote fora da app.

**A condição para tirá-los foi cumprida**: a 027 existe, no PR #360. Podem sair assim que
ele for incorporado — e vale conferir antes se o `enviar_relatorios.exs` faz alguma coisa
que a aplicação ainda não faz, porque o envio não entrou na 027.

---

# Duas coisas que valem lembrar ao mexer aqui

- **`mix gates` nunca com `| tail` nem `| grep`** — o veredito é o código de saída;
- **medir na origem antes de afirmar.** Três defeitos desta rodada apareceram assim: a spec
  dizia que `costabeber` ficava abaixo do piso e não fica; o `check` da tela carregava o
  material inteiro a cada render; e um `@type` declarava `String.t()` onde a função devolve
  `nil`. Nenhum apareceu na suíte verde.
