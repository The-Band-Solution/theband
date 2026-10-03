# O protótipo da tela da rede de revisão (073)

[`review-network.html`](review-network.html) — abrir no navegador. Sete telas, separadas pelas
faixas `screen N · nome`, antecedidas pela leitura do repositório de referência e seguidas da seção
`Decisions and open questions` e dos nomes de medida que a tela pede. Tudo visível ao carregar; os
controles são *View in greyscale*, as abas de janela da tela 1 (30/90/180, funcionais) e o `+`/`–`
de cada pessoa.

Desenhado em **2026-10-03** pelo agente Design, a pedido da pessoa mantenedora (*"olhe os dados que
ele gera e me faça uma proposta de tela"*). Publicado em
**<https://claude.ai/artifact/Ni1tRcrWPWXALXpvUxb9Uq>** (versão 2, republicada no mesmo endereço);
**a cópia aqui é a que vale** — o endereço pode mudar, a spec não pode depender dele.

**Estado: APROVADO em 2026-10-03 pela pessoa mantenedora, na versão 2.** D1–D10 aprovadas como
propostas; Q1–Q5 decididas (abaixo). As tarefas de tela deixam de estar bloqueadas pelo protótipo
(FR-017, plano R15).

## O que mudou da versão 1 para a 2

| tela | mudança | decisão |
|---|---|---|
| leitura da referência | a linha do grafo diz *"no drawing in this slice, a matrix ordered by group sketched for slice 2"* | Q1 |
| 3 | grupos contados **só entre as pessoas alcançadas**: *"Everyone you reach with a review between them is linked, directly or through others: 5 people."*; some o *"small group"* e a nota de grupos sobre a organização inteira | Q4 |
| 1, 3 | *"not linked to a person"* passa a dizer *"…matches no observed person, or was deleted at the source"* | base |
| 4b | sai a variante *"mostra com aviso"*; fica só a fração ausente, *"too few reviews to speak of concentration: 4 of the 10 needed"*, com as contagens ao lado | Q2 |
| 4d | sai a variante só-data; fica a linha *"A review collection ended on …, after this reading…"*, com a condição escrita | Q3 |
| 6 | a matriz sai da régua: vira esboço da fatia 2, *"not part of this delivery"* | Q1 |
| 7 | marcado *"not part of this delivery"* | Q1 |
| seção final | D1–D10, Q1–Q5 e as decisões da base marcadas *Decided 2026-10-03* | — |

A estrutura seção a seção — **a régua do QA** — está na seção 3 do [`PROMPT.md`](PROMPT.md).

## O dado que a tela mostra

**Todo de exemplo**, marcado `example` na página. Pessoas fictícias com o sobrenome `Example`
(Ana, Bia, Ciro, Rui…), organizações `example-org` e `example-labs`, equipe `Payments`.
**Nenhum login do relatório de referência aparece**: são pessoas reais e o artifact é publicado. O
cenário da spec usa "Caio"; aqui é **Ciro**, porque `CaioLessaSimao` é um login real da
organização de referência.

A **forma e a escala** seguem a saída da referência (53 nós, 158 arestas, 6 comunidades de 14, 14,
10, 8, 4 e 3): 48 pessoas na lista, 120 arestas em 90 dias (180 em 180 dias), 3 grupos de 40, 5 e
2. Os números **não são plausíveis soltos**: saem de **um** conjunto de revisões de exemplo,
gerado com semente fixa, e cada contagem da página é calculada dele pela mesma regra do plano
(research R2: a unidade é o par pessoa × solicitação). Por isso batem entre si: 236 revisões em 90
dias, 31 revisores, 43 pessoas revisadas, concentração 92/131/161 de 236; Bia com 12 de 4 pessoas e
5 solicitações revisadas por 2 (6 revisões). O banco de desenvolvimento não foi consultado (a
instrução vedou `mix`), e a tela não existe ainda.

## O que a tela faz com a saída da referência

Lidos `collaboration_report.md` (1 900 linhas), `teams.md`, `developer_stats.md` e as duas imagens
do grafo, em `leds-conectafapes/leds-conectafapes-management-dashboard/report/`.

| a referência produz | a tela | por quê |
|---|---|---|
| aresta autor da issue → responsável, chamada "colaboração" | **adapta**: aresta revisor → autor da solicitação de mudança, chamada "review" | atribuir issue é coordenação, não colaboração; a revisão é avaliação de artefato (QAPO) sobre solicitação de mudança (CMPO). PR não é merge |
| por pessoa, "atribui issues para N / recebe de N" | **adota**: "reviewed N, of M people" / "was reviewed on N, by M people" | os dois sentidos são a parte útil do relatório, ditos em palavras em vez de grau |
| por pessoa, tabelas "recebidas de", ordenadas por contagem | **adapta**: os pares, abertos no lugar, ordenados por nome | ordenada por contagem, cada tabela é um ranking pequeno |
| "Hubs": centralidade de grau, cinco primeiros por nome | **adapta**: a fração das 1, 2 e 3 pessoas que mais revisaram, sem nome | responde "depende de poucos?" sem ranquear ninguém (R1) |
| "desconexo, contendo 1 componentes" | **adota** a contagem de grupos, dita certo: "3 groups" ou "everyone is linked" | a frase se contradiz |
| comunidades por modularidade (6, 0,4981) | **depois**: fatia 2, contra as equipes declaradas (esboço, tela 7) | comunidade serve à decisão quando posta ao lado da equipe declarada |
| grafo de 53 nós desenhado de uma vez | **recusa** o novelo; nenhum desenho nesta fatia (Q1); a matriz ordenada por grupo fica no esboço da fatia 2 (tela 6) | os rótulos se sobrepõem e ninguém lê quem revisa quem |
| a conta da organização (`LEDS`) e `dependabot[bot]` como nós | **recusa** como nó; conta como "left out" | nó é pessoa observada com `account_type = 'person'` (FR-001, R9); o resto é contado, nunca listado |
| "Papel na rede" por percentil (hub, ponte, coordenador central…) | **recusa** | rótulo em pessoa é julgamento, não medida (FR-018) |
| intermediação, proximidade, autovetor, com quatro casas | **recusa** | "0,1266" não apoia decisão e ninguém confere à mão (SC-001) |
| índice σ de mundo pequeno, distância média, diâmetro, eficiência | **recusa** | fora da spec (FR-019); o σ da referência só usa os aleatórios conexos |
| equipes cujos membros somam 77 para 53 pessoas | **recusa** total sobre equipes (esboço 7) | quem está em duas equipes contaria duas vezes |
| issues fechadas e abertas por autor, em % | **recusa** aqui | outra necessidade de informação |

## As premissas que o protótipo herda (já decididas)

| de onde | o que fixa na tela |
|---|---|
| decisão de 2026-10-03, R1 | concentração sem nome para todos; para alcance parcial, só sobre revisões entre pessoas alcançadas |
| decisão de 2026-10-03, R2 | a tela não conta o que ficou fora do alcance; diz que há recorte e a regra |
| decisão de 2026-10-03, R4 | uma rede por organização observada; seletor de organização quando há mais de uma |
| decisão de 2026-10-03, R6/R7 | as três janelas já calculadas; trocar não calcula; uma leitura vigente, com o instante dela |
| FR-018, FR-018a, FR-018b | sem rótulo, lista por nome, nenhuma coluna ordena, sem exportação, a frase de não-avaliação ao lado da lista |
| FR-004, R9 | exclusões só em contagem, nunca login; auto-revisão só no agregado |
| plano research R6 | o alcance é `pessoas_alcancadas/2`, sem liderança declarada |
| plano research R12 | exclusões só para quem alcança todos |
| plano research R14 | falha de cálculo não é registrada; a leitura vigente aparece com o instante dela |
| plano research R15 | rota `/organizations/:id/review-network?window=` |
| contrato `review-network.md`, `view()` | os campos que a tela usa, e o que ela não recebe |
| `docs/design-system.md` | sólido observado, hachurado derivado, tracejado ausente, sempre com texto; ausência diz de quem é; empilha abaixo de 40 rem; inglês na tela |

## As decisões de desenho — *Decided 2026-10-03*, aprovadas como propostas

| # | decisão | a razão |
|---|---|---|
| **D1** | Concentração em três barras na mesma escala (0–100%, tracejado em 50%), cada uma com a contagem: *"39% · 92 of 236 reviews"*. Porcentagem inteira; nenhum limiar, cor de faixa ou veredito | a contagem ao lado deixa conferir à mão (SC-001); limiar seria faixa numérica sem razão (o defeito da referência) |
| **D2** | A unidade dita na tela: *"one person reviewing one change request"*; quando a linha (solicitações) e a soma dos pares (revisões) diferem, a linha aberta diz por quê | confirma research R2 no protótipo, como o plano pediu |
| **D3** | Três colunas em palavras; duas ausências tracejadas, ambas da origem: *"no review by them in this window"*, *"no review on their change requests in this window"*. Quem não abriu nada e quem abriu sem revisão leem igual | distinguir exigiria contar solicitações abertas por pessoa, outra medida sobre pessoa |
| **D4** | Pares abertos no lugar, sob a linha, sem rota nova; ordenados por nome, *"on N"*; link para o painel da pessoa. Alcance parcial: *"some pairs are outside your reach"*, sem número | contrato `reviews_of`/`reviewed_by`/`pairs_outside_reach?`; R2 item 1 |
| **D5** | O aviso de recorte descreve o que `pessoas_alcancadas/2` faz, **sem** a cláusula de liderança declarada que a tela de quem integrou vermelho usa | research R6: aquela tela promete mais alcance do que aplica; vai como issue própria |
| **D6** | Exclusões só para quem alcança todos; alcance parcial lê a regra em palavras | confirma research R12 |
| **D7** | Instante e idade da leitura sempre visíveis; *"Switching the window reads another stored reading. It computes nothing."* | R6/R7; sem o instante, uma leitura velha passa por nova |
| **D8** | A frase *"These counts do not assess a person"* vem **antes** da tabela | quem lê a tabela primeiro já julgou (precedente de `verification_live/people.ex`) |
| **D9** | Rota `/organizations/:id/review-network?window=30\|90\|180`, qualquer conta do tenant; links de organização quando há mais de uma | confirma research R15 |
| **D10** | *"people reviewed"* (autores com ao menos uma solicitação revisada), sobre o mesmo recorte das outras duas contagens | precisa de um campo no `view()` do contrato (`authors`); deriva das arestas, sem dado novo |

## As perguntas — *Decided 2026-10-03*, pela pessoa mantenedora

| # | pergunta | opções | recomendação | decisão |
|---|---|---|---|---|
| **Q1** | Desenhar a rede? | (a) não nesta fatia; (b) matriz em SVG no servidor; (c) grafo do grupo escolhido | (a) agora, (b) na fatia 2 | **(a)**: nenhum desenho nesta fatia. A matriz vai para o esboço da fatia 2, fora desta entrega |
| **Q2** | Abaixo da amostra mínima? | (a) frações com aviso; (b) fração ausente com motivo | (b), unidade em revisões | **(b)**, decidida pelas respostas da base: a fração fica **ausente** com o motivo e *N de 10*; a unidade é **revisões** (uma pessoa revisando uma solicitação; uma solicitação com dois revisores conta duas) |
| **Q3** | Coleta terminou depois da leitura? | (a) só data e idade; (b) mais uma linha | (b), se o fim da coleta for registrado por organização | **(b)**: além do instante e da idade, a linha aparece quando o fim da coleta de revisões estiver registrado por organização e for posterior à leitura |
| **Q4** | Grupos para alcance parcial? | (a) organização inteira, pequeno sem tamanho; (b) só entre alcançados | (b) | **(b)**: contados **só entre as pessoas alcançadas**. Muda `review.network.unconnected_groups.count` (filtro do alcance antes de contar) |
| **Q5** | Bot/app para alcance parcial? | (a) não; (b) sim | (a) | **(a)**, como desenhado |

**Também decidido para a base (2026-10-03)**: conta apagada no GitHub entra em *"sem pessoa
ligada"* (`not_linked`), e não em bot; grupo mínimo = **3** (fica declarado em
`review.network.parameters`; com a Q4 em (b), não aparece nesta tela).

## Medidas e nomes que a tela pede antes do código

Mantidos de `proposta-base/`: `review.concentration` (necessidade de informação),
`review.network.concentration.top_k_share`, `review.network.reviews_given.count`,
`review.network.reviews_received.count`, `review.network.unconnected_groups.count`,
`review.network.parameters` (k, amostra mínima, grupo mínimo, janelas).

**Novos**, um por número da tela que ainda não tem declaração:

- `review.network.reviews.count` — revisões (pares) do recorte;
- `review.network.reviewers.count` — pessoas que revisaram, no recorte;
- `review.network.authors_reviewed.count` — pessoas revisadas, no recorte (D10);
- `review.network.people_without_activity.count` — pessoas observadas (ou alcançadas) sem revisão
  nem solicitação na janela;
- `review.network.excluded.count` — por motivo: `self_review`, `bot_or_app`, `not_linked`.

## O que o protótipo descobriu e a implementação precisa saber

- **A amostra pequena estava em três versões** (spec, contrato, proposta da base): a Q2 decidiu ausente, em revisões. O edge case da spec e o `sample: {:pequena, minimo}` do contrato precisam acompanhar.
- **O contrato não traz `authors`** (D10, aprovada) nem distingue *"abriu nenhuma"* de *"abriu e ninguém
  revisou"* (D3, decidido não distinguir).
- **A linha da pessoa mostra o total verdadeiro, e a concentração conta só o recorte**: na tela 3,
  Bia aparece com *"reviewed 12"* e a concentração diz *10 of 14*. A tela escreve, acima da lista,
  *"Each row shows the person's whole count in the window; the pairs show only people you reach"*.
  É a FR-015, e o QA deve conferir que a frase está lá.
- **k maior que o número de revisores** (`fewer_reviewers_than_k` da proposta) não está no
  contrato. A régua o mantém (item 4.3); no dado de exemplo da versão 2 ele não aparece desenhado,
  porque o único recorte com dois revisores ficou abaixo da amostra mínima.
- **Q4 em (b) muda o contrato**: `groups` passa a ser calculado sobre o subgrafo das pessoas
  alcançadas, e `small_without_size` deixa de ter uso nesta tela.
- **Colegas de equipe se veem** (risco residual da segurança): a tela 3 é exatamente isso, Lia lê
  quanto Bia revisou. É a regra decidida, e a pessoa mantenedora a vê desenhada antes de aprovar.
- **Achado lateral (D5)**: o aviso de `verification_live/people.ex:157-161` promete a liderança
  declarada, e a função não a aplica. Issue própria, fora da 073.
