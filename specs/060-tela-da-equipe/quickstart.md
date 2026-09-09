# Quickstart — a tela da equipe (feature 060)

Como conferir, à mão, o que esta feature entregou. Cada cenário corresponde a uma user story,
e cada um diz **o que olhar** — não só onde clicar.

Os testes provam que o comportamento existe; este documento serve a quem precisa **ver**: a
pessoa mantenedora aceitando o entregável, e quem chega depois e precisa entender a tela sem
ler o código.

## Antes

```bash
export THE_BAND_MASTER_KEY=...      # do .env; nunca no chat, nunca em log
mix ecto.migrate
mix phx.server
```

A tela é `/teams/:id`. Sem `?tab=`, abre o **Dashboard**; com `?tab=structure`, a
**Estrutura**. Trocar de aba não recarrega a página, e a aba escolhida vai ao endereço — um
link cai onde aponta.

## US1 — quem está na equipe, uma linha por pessoa

Abra `/teams/<id>?tab=structure` de uma equipe com gente.

**O que olhar:**

- **cada pessoa aparece UMA vez**, mesmo quem tem vínculo direto *e* numa subequipe. Os dois
  vínculos ficam dentro da linha, e os chips à direita dizem `direct` e o nome da subequipe;
- a coluna de papel diz o papel declarado ou **`not declared`** em destaque — nunca em branco,
  porque célula vazia se lê como "não carregou";
- **a palavra `MAINTAINER` não aparece em lugar nenhum.** Ela é permissão de administração no
  GitHub, não papel na organização, e a versão anterior a mostrava numa coluna chamada "access
  at the platform". O nível continua gravado no banco; saiu desta tela;
- a legenda das quatro marcas — `declared`, `observed`, `left`, `mistake` — vem **antes** da
  tabela e em texto. Cor sozinha não é marca;
- o cabeçalho conta **pessoas**: *N people here · N left · N recorded by mistake*. Os três
  números saem da mesma agregação da lista, e é por isso que não se contradizem.

**Para conferir a diferença que mais importa:** procure alguém com dois papéis vigentes. O
cabeçalho conta **1** pessoa, e a linha traz os dois papéis. Antes desta feature o mesmo caso
contava 2 — a consulta contava vínculos onde prometia pessoas.

## US1 — quem não gere lê tudo e não vê ação

Entre com uma conta `member` sem pessoa declarada e abra a mesma URL.

**O que olhar:** a lista inteira, os papéis, as subequipes — tudo legível. E **nenhum botão**.
Abaixo do cartão *Where this team sits*, a recusa nomeada diz o que fazer para conseguir.

**A proteção não é esconder o botão.** Para provar, os testes disparam o evento por websocket
sem passar pelo formulário: o veredito é re-perguntado no `handle_event`, e a recusa vem do
servidor.

## US3 — a pessoa saiu

Na linha de alguém, clique **Left the team…**.

**O que olhar:**

- **a data vem VAZIA.** O protótipo aprovado mostrava a data de hoje, e a FR-023 substituiu
  aquela premissa: um campo já preenchido é enviado como está, e a data de hoje passa a ser a
  data de saída de quem saiu no mês passado;
- enviar sem data é recusado, com a frase *"A departure needs a date — the platform does not
  assume today."*;
- data no futuro é recusada;
- depois de registrar, a mensagem diz **quantos vínculos** foram alcançados. Numa pessoa com
  dois papéis, diz 2 — omitir o número esconderia que a ação alcançou mais do que a linha
  clicada.

**A conferência que prova o SC-001:** antes de registrar, anote o número de membros que o
cabeçalho mostra. Registre uma saída com data retroativa. O número **de hoje** muda; qualquer
medida de período anterior à data informada **não**.

## US4 — o vínculo que nunca foi

Na mesma linha, **Mistake…**.

**O que olhar:** a razão é obrigatória, e o texto na tela diz a diferença — *"This is not
'left the team'. A mistake is a link that never was: it leaves every measure, for every
date."*

**A conferência:** depois de um equívoco, uma medida de período **anterior** também zera. É
essa a diferença com a saída, que fecha um período que existiu.

E: depois do equívoco, a próxima coleta **não** recria o vínculo enquanto a origem continuar
mostrando a pessoa. A evidência fica viva, e a tela mostra as duas afirmações.

## US2 — declarar e alterar o papel

Na linha, **Declare role** (onde não há papel) ou **Change role** (onde há).

**O que olhar:**

- o botão diz **qual** das duas ações é. Um rótulo só para as duas esconderia que a segunda
  **encerra** o papel atual;
- a data *since* vem vazia, com o texto *"empty date = unknown, never today"*;
- **`＋ new role…`** abre o campo do nome **sem sair da linha**, cria o papel na organização
  da equipe e declara na mesma submissão. O código sai do nome: *Tech Lead* vira `tech_lead`;
- declarar sobre um vínculo **observado** completa o mesmo vínculo — o `id` não muda;
- um **segundo** papel é aceito: Developer e Scrum Master ao mesmo tempo é comum;
- trocar para o papel que a pessoa já tem é recusado, e **nada** muda — a transação desfaz o
  encerramento.

**Depois de alterar**, a linha traz **dois** vínculos: o antigo com o período fechado e o
novo. Não há tabela de histórico de papel, e não é lacuna — o histórico *é* a linha encerrada.

## US5 — os papéis da organização, a partir da Estrutura

A seção **Roles**, na mesma aba.

**O que olhar:**

- os quatro do catálogo SRO e os criados pela organização, com origem e código;
- **quantas pessoas** desempenham cada papel **aqui** e **na organização**. A mesma pessoa com
  o papel em duas equipes conta **uma** vez na coluna da organização;
- criar com o código **sugerido** do nome, e editável. A partir do momento em que você digita
  no código, a sugestão para de sobrescrever;
- papel do catálogo **não** tem *Rename* nem *Hide*: o nome vem da rede de conceitos, e
  mudá-lo aqui faria a plataforma discordar da ontologia que ela publica;
- ocultar papel com gente é recusado dizendo **quantos** vínculos impedem.

**A conferência do SC-005:** crie um papel aqui e abra `/roles`. É o **mesmo** papel — uma
porta, um escopo. Se aparecesse só num dos dois lugares, seriam dois catálogos divergindo em
silêncio.

## US9 — o fluxo, em três granulações

O **Dashboard** da mesma equipe.

**O que olhar:**

- **Burn-up and burn-down**, com o **valor em cada ponto**, o teto do eixo escrito, e o eixo X
  como **linha do tempo com datas** — `2026-W36` é rótulo interno, e ninguém lê número de
  semana ISO sem consultar um calendário;
- **a diferença e o horizonte pela velocidade de entrega**: *"the gap is N items still open. At
  the closing pace observed in this window — X closed per week — half of the simulated runs
  reach zero within N weeks"*. É **faixa com confiança, nunca uma data**, e sempre com as duas
  ressalvas: assume que nada novo entra, e não há escopo comprometido;
- **Promised × Delivered**, com a definição **junto do título** — *promised = opened in the
  period, delivered = closed in the period* — e a declaração de que não há escopo comprometido;
- **Delivery forecast**, que é o Monte Carlo, desenhado como **histograma** da distribuição das
  rodadas. As duas hipóteses empilhadas com o **mesmo** eixo X, os percentis marcados sobre a
  forma, e a coluna hachurada das rodadas que **nunca** zeraram;
- o **seletor semana/mês/ano** no cabeçalho de cada gráfico de fluxo. Dois lugares, **um** só
  estado: os dois mudam o mesmo parâmetro do endereço.

**A conferência que prova a FR-061:** cada granulação tem a **sua** janela padrão — 8 semanas,
12 meses, todos os anos coletados —, e a janela aparece sempre no título. Trocar a granulação
**mantendo a janela** reagrupa os mesmos itens sem mudar a medida; isso está provado em
`test/the_band/work_items/fluxo_da_equipe_test.exs`, porque a igualdade das somas é
propriedade da agregação, e não da tela.

**Numa equipe composta:** os gráficos cobrem a **equipe inteira** — os membros próprios mais
todos das subequipes com composição vigente — e a tela diz que a curva **não é a soma** das
curvas das subequipes. A pessoa em duas subequipes, e o item com dois responsáveis, contam uma
vez ali e uma vez em cada subequipe. A **tabela** por subequipe continua sem gráfico: ela é
para comparar, e comparação se faz em números alinhados.

## O que medir depois de subir

1. **contas não-admin com escopo `organization` vigente.** A T006 trocou a regra de escrita: o
   escopo de conta deixou de decidir escrita na estrutura, e passou a decidir a **concessão de
   papel**. Foi medido antes de mudar — **zero** contas perderam acesso de escrita —, e é a
   medida a repetir em produção antes de aceitar. Conte quantas contas têm escopo
   `organization` vigente e **nenhum** papel com a concessão: são as que perderiam escrita;
2. **o custo das duas abas.** Painel 21 consultas por render, estrutura 7, os dois constantes
   com o tamanho da equipe. O teste está em
   `test/the_band_web/live/teto_de_consultas_da_equipe_test.exs`, e subir qualquer um dos dois
   é decisão que aparece naquele arquivo;
3. **quantas pessoas por equipe têm papel `not declared`.** É o número que a US2 existe para
   baixar, e ele não cai por si: alguém precisa declarar.

## O que esta feature NÃO entregou

- **T029 — o gráfico pequeno no cartão da subequipe** (FR-084). Depende do **cartão**, que é a
  US7 e não tem tarefa planejada. Construir o gráfico antes do cartão seria infraestrutura sem
  consumidor visível;
- **US6, US7, US8** — o perfil de cada membro, o cartão da subequipe como porta, e as tarefas
  e problemas por pessoa. Especificadas, sem tarefa;
- **os quatro gráficos por membro** (WIP, prometido × realizado, throughput, Monte Carlo).
  Especificados em `spec-graficos-por-membro.md` como US10 a US12, **sem protótipo aprovado** —
  e a casa não implementa tela sem ele.
