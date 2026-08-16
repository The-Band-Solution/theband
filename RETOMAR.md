# Retomar — 2026-08-16

**Onde está**: branch `056-perfil-de-competencias`, **PR #330** com 4 commits, `MERGEABLE`,
gates com código de saída 0. Revisão pedida a `Adylla027` e `EduardoNFraiz`.

## O primeiro comando ao voltar

```bash
set -a && . ./.env && set +a      # a chave mestra e a API_KEY moram aqui
mix phx.server
```

Perfil real gravado no banco de desenvolvimento, gerado com a API de verdade:
<http://localhost:4000/people/fe70e4e6-b845-46e2-a18a-5394f15f9a6d>

---

# O propósito, reafirmado em 2026-08-16

**Entender as competências das pessoas: em que são fortes, e onde podem melhorar.**

Está escrito aqui porque governa as decisões abaixo, e porque a feature nasceu de um
enquadramento mais estreito — *"o que mudou ao longo do tempo"*. Evolução é **uma das
dimensões** da competência, e não o assunto.

O que isso decide, concretamente:

| decisão | direção |
|---|---|
| o papel no prompt | especialista em competências, não analista de série temporal |
| o que vem primeiro no texto | as habilidades e as forças; a trajetória as sustenta |
| o que é "melhorar" | onde a evidência é rala, envelheceu, ou o trabalho demora — **do registro**, nunca da pessoa |
| o que não entra | o que a tela já deriva sozinha, e o que o material não sustenta |

---

# O que fazer, na ordem

## 1. A página não recarrega quando a geração termina — **defeito entregue**

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

## 2. Feature 027 — geração automática e periódica

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

## 3. Tarefas que a pessoa abre **para outras** — sinal novo, medido em 2026-08-16

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

## 4. Tirar as tarefas abertas do prompt — **corta até 80% do material**

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

## 5. O papel no prompt — especialista em competências

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

## 6. Issue #320 — axiomas SRO carregados como `unknown`

`priv/knowledge_base/rules/sro_axioms.yaml` usa a chave de topo `rules:`, que **não é** um
dos nove tipos que o carregador reconhece. Nenhuma consulta por tipo os alcança.

**Mordeu de novo em 2026-08-15**: escrevi `profile_thresholds.yaml` nessa forma e ela era
ilegível por `KnowledgeBase.rule/1`. Contornei usando `derivation_rule:`, mas o `spo_axioms`
e o `sro_axioms` seguem inalcançáveis. Pequena, isolada, e evita a terceira mordida.

## 7. As outras issues abertas — triagem pela metade

| # | leitura |
|---|---|
| **181** | a feature 024 coleta iterações e campos. Conferir cobertura antes de fechar |
| **180** | mapear campo de quadro para atributo da ontologia — a 024 grava `field_name` cru. **Trabalho de verdade** |
| **107, 108, 81, 82** | telas — cada uma precisa ser comparada com o que existe. `82` (quem atravessa organizações) tem parte pronta na página da pessoa |
| **176, 317, 318** | features novas, não pendências |

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

## Feature 026 — perfil de competências (PR #330, esperando revisão)

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
- **024** sprints do Projects v2 — 220 sprints, 2225 vínculos
- **025** projeto, subprojetos e repositórios, com seletor de busca múltipla

## Os scripts do scratchpad

`gerar_perfis.exs` e `enviar_relatorios.exs` foram o protótipo do pipeline, e **estão
superados** pela feature na aplicação. Servem só para rodar em lote fora da app; se a 027
existir, podem sair.

---

# Duas coisas que valem lembrar ao mexer aqui

- **`mix gates` nunca com `| tail` nem `| grep`** — o veredito é o código de saída;
- **medir na origem antes de afirmar.** Três defeitos desta rodada apareceram assim: a spec
  dizia que `costabeber` ficava abaixo do piso e não fica; o `check` da tela carregava o
  material inteiro a cada render; e um `@type` declarava `String.t()` onde a função devolve
  `nil`. Nenhum apareceu na suíte verde.
