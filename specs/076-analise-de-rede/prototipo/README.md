# Protótipo — 076 Análise de rede

| | |
|---|---|
| Endereço | https://claude.ai/artifact/PeL32PvxhaXAkqNZa93sAY (privado, não compartilhado) |
| Cópia que vale | [`network-analysis.html`](network-analysis.html) — o endereço pode mudar, a spec não depende dele |
| Versão | 1, publicada em 2026-10-03 |
| Estado | **aguardando aprovação** da pessoa mantenedora |
| Régua do QA | [`PROMPT.md`](PROMPT.md), seção 3 |

Republicar é sempre no mesmo endereço. Endereço novo é protótipo novo e pede aprovação nova.

## O que o exemplo mostra

Oito telas numa página, cada uma num quadro com a rota e o estado de quem consulta:

1. a área **Network analysis** no menu principal, com a rede de revisão da 073 como primeira página e as cinco análises abaixo dela, cada uma com a pergunta que responde;
2. o **grafo ponderado**, interativo: tamanho = pessoas ligadas, cor = intermediação em cinco faixas nomeadas, espessura = contagem, seta = direção; zoom, arrastar a vista, destaque ao apontar ou tocar; o cartão da pessoa ao lado;
3. o **grafo de comunidades**: cor, contorno tracejado e **letra** por comunidade; modularidade com a escala explicada; os cartões das comunidades com membros e os mais ligados de cada uma;
4. **hubs**: as quatro centralidades, cada uma com a explicação em uma linha e o valor em unidade (pessoas, % de caminhos, passos, escala 0–100); e o estado em que o autovetor **não assenta**, escrito como ausência;
5. **distância e mundo pequeno**: distância média, diâmetro, eficiência global, a distribuição dos caminhos mais curtos, a tabela contra 50 redes aleatórias e o σ; e o estado da rede **partida** em grupos;
6. **posição na rede** de cada pessoa, por nome, com a regra a um clique; e o **perfil** de uma pessoa: para quem atribui, de quem recebe, quem revisou e por quem foi revisada;
7. o **alcance parcial**: nomes só de quem está no alcance; os demais como um nó sem nome por comunidade; o mesmo nas comunidades e nos hubs;
8. o **telefone**: o grafo vira lista; o perfil empilhado.

O seletor **review / delegation** funciona em todas as telas de análise. O seletor de janela é ilustrativo.

## Dados

Fictícios, com nomes `… Example`. Nenhum login do relatório de referência aparece. Gerados por um
script com semente fixa (76), que também **calcula** as medidas — os números batem entre si:

| | revisão | delegação |
|---|---|---|
| pessoas | 49 (1 sem revisão na janela, escrita como ausência) | 50 |
| arestas dirigidas | 168 | 169 |
| ligações não dirigidas | 145 | 153 |
| comunidades (Louvain) | 6, modularidade 0,61 | 5, modularidade 0,61 |
| distância média · diâmetro | 2,9 · 7 | 2,6 · 5 |
| eficiência global | 43% | 46% |
| clustering · aleatória | 0,46 · 0,12 | 0,52 · 0,13 |
| σ | 3,0 | 3,7 |

O estado de ausência é real, não encenado: a delegação num recorte de 30 dias (44 arestas, 38
pessoas) fica partida em 3 grupos (26, 9 e 3 pessoas), e o autovetor não assenta em 1 000
iterações. As contagens de bots, conta da organização e contas sem pessoa são `example`.

## Decisões da pessoa mantenedora — *Decided 2026-10-03*

1. **Os dois grafos da referência.** Ponderado: tamanho = grau, cor = intermediação, espessura = peso. Comunidades: cor por comunidade.
2. **Duas arestas, escolhíveis na tela:** *revisão* (revisor → autor da solicitação de mudança) e *delegação* (autor da issue → responsável). Nunca "colaboração".
3. **Interativo, com layout no servidor.** A página só faz zoom, arrasto e destaque. No telefone, o grafo vira lista.
4. **Nomes só no alcance de quem consulta.** Quem administra vê todos; quem está fora aparece como nó sem nome, agrupado.
5. **Área própria "Network analysis" no menu principal**, com a rede de revisão da 073 como primeira página.
6. **Todas as análises da referência:** comunidades, as quatro centralidades, distância, diâmetro, eficiência, mundo pequeno, papel na rede, perfil individual.
7. **O que não se repete:** quatro casas sem significado, "desconexo, contendo 1 componentes", zero no lugar de ausência, bots e conta da organização como nós, o grafo-novelo.

## Decisões de desenho propostas — para aprovar junto

8. Nomes escritos só para os **sete mais ligados**; os demais ao apontar ou tocar, e sempre nas listas.
9. Intermediação em **cinco faixas** nomeadas (nenhuma, <2%, 2–5%, 5–10%, ≥10%), não gradiente contínuo.
10. **Letra e contorno tracejado** por comunidade, para ler em escala de cinza (WCAG 1.4.1).
11. Toda medida **em unidade**; duas casas só para modularidade e clustering, com a escala ao lado.
12. A aresta escolhida **acompanha** a navegação entre as páginas da área.
13. Listas de pessoas **por nome**; as listas de hubs são o único ranking, por terem sido pedidas.

## Perguntas abertas — para o Product Owner levar à pessoa mantenedora

**Q1 · Como mostrar o papel na rede sem virar julgamento de pessoa.**
- a. Uma frase sobre as ligações ("on many paths between communities"), a regra a um clique, e a frase de não-avaliação acima da lista. *Mostrado.*
- b. Os rótulos da referência: hub, ponte, coordenador central, papel misto.
- c. Nenhuma posição; só as quatro medidas por pessoa.

Recomendação: **a**. Mantém a informação da referência e a diz sobre a rede. Um substantivo como
"hub" gruda na pessoa e viaja para conversa de desempenho; uma frase sobre ligações, não.

**Q2 · As arestas de delegação e de revisão aparecem juntas ou alternadas.**
- a. Alternadas pelo seletor, uma rede por vez. *Mostrado.*
- b. Juntas num só desenho, com dois estilos de linha.
- c. Dois desenhos lado a lado, mesmas posições.

Recomendação: **a**. Comunidades, centralidades e σ são calculados por rede; um desenho com as
duas não tem um conjunto único de medidas para colori-lo. Se comparar as duas virar necessidade,
**c** é uma página própria, depois.

**Q3 · O que o alcance parcial pode saber de quem está fora dele.**
- a. Medidas sobre a rede inteira; um nó sem nome por comunidade; listas de hubs com linhas sem nome e o valor. *Mostrado.*
- b. Medidas recalculadas só sobre o recorte, como faz a página da 073.
- c. Como a, mas as listas de hubs mostram só quem está no alcance, sem linhas sem nome.

Recomendação: **a**, condicionada à avaliação do agente `security` **antes do código** (dado de
pessoa, §14.0): os nós agrupados revelam quantas pessoas estão fora e como se ligam à equipe de
quem consulta — o que a 073 deliberadamente não diz ("the page does not say how much is outside
it"). Se a avaliação objetar, **c**.

**Q4 · As recusas da 073 e esta área.** A 073 recusou rótulo de papel, as centralidades e o σ
(FR-018, FR-019). A decisão 6 os adota aqui.
- a. A página da 073 fica como aprovada; a spec 076 registra que as páginas dela adotam o que a 073 recusou, por decisão da pessoa mantenedora de 2026-10-03.
- b. A página da 073 também ganha as centralidades.

Recomendação: **a**. A 073 responde uma pergunta e foi aprovada para ela; a reversão pertence às
páginas novas e precisa estar escrita na 076, não implícita.

## Medidas novas que precisam de YAML antes do código

Princípio IV: nada na tela sem declaração na base. Cada uma com a aresta (`review`, `delegation`)
como parâmetro e a necessidade de informação declarada:

- `network_analysis.degree` — pessoas distintas ligadas, em qualquer direção
- `network_analysis.betweenness` — fração dos caminhos mais curtos entre outros que passa pela pessoa
- `network_analysis.closeness_steps` — média de passos até os alcançáveis
- `network_analysis.eigenvector` — escala 0–100 relativa ao máximo; **ausente** quando não assenta
- `network_analysis.community` e `network_analysis.modularity` — Louvain, ponderado pela contagem
- `network_analysis.average_distance`, `network_analysis.diameter`, `network_analysis.global_efficiency`
- `network_analysis.shortest_path_length_distribution`
- `network_analysis.clustering`, `network_analysis.small_world_sigma` — com o número de redes aleatórias e quantas não ficaram conexas
- `network_analysis.position` — a regra de posição (quinto superior em grau e/ou intermediação; senão, para onde vão as ligações)
- a **aresta de delegação** em si (autor da issue → responsável): precisa de mapeamento declarado e justificativa semântica; não existe na 073

## Premissas que a spec carrega até serem contestadas

- uma pessoa é nó só se observada com tipo de conta *person*; bots, apps, conta da organização e contas sem pessoa são contados abaixo do grafo, nunca desenhados;
- distâncias ignoram direção e peso; as medidas são da rede não dirigida, como na referência;
- o autovetor é calculado sem deslocamento; se não assentar em 1 000 iterações, ninguém recebe valor;
- σ só é testado em rede ligada; em rede partida, a tela diz "not tested";
- a eficiência global é a única medida em que pares inalcançáveis contam como zero, e a tela diz isso.
