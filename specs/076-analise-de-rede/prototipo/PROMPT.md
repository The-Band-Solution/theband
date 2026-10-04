# PROMPT — protótipo da 076, Análise de rede

## 1. Os pedidos da pessoa mantenedora, textuais e em ordem

2026-10-03:

1. "eu quero ver os grafos da mesma forma que existe no codigo que foi passado e coloque a analise de rede em outro menu"
2. "quero a identificacao das comunidades, dos hubs ... a mesma analise quero todas"

Decisões transmitidas no mesmo dia (ver `README.md`, decisões 1 a 7): os dois grafos da
referência; as arestas *revisão* e *delegação*, escolhíveis, nunca "colaboração"; grafo
interativo com layout no servidor e lista no telefone; nomes só no alcance de quem consulta;
área própria no menu com a 073 como primeira página; todas as análises; o que não se repete.

## 2. O brief de design seguido

- **Referência lida**: `collaboration_report.md`, `collaboration_graph_weighted.png` e
  `collaboration_graph_communities.png` do relatório `leds-conectafapes-management-dashboard`
  (53 pessoas, 158 arestas). A codificação dos grafos é mantida; o novelo vinha dos 53 rótulos
  permanentes, não da codificação.
- **Herdado**: os tokens, os quadros com rota e estado, as marcas e a voz do protótipo aprovado da
  073 (`specs/073-rede-de-revisao/prototipo/review-network.html`) e `docs/design-system.md`.
  Tudo calculado aqui é **derivado** (hachurado); a origem é **observada** (sólido); a ausência é
  **tracejada** e escrita.
- **Dados**: fictícios, semente fixa, medidas calculadas pelo gerador; nenhum login real.
- **Tela em inglês**; este arquivo e o README em português.
- **Em repouso** tudo legível: o grafo inteiro sem esmaecer, o cartão de uma pessoa já aberto ao
  lado, os estados de ausência em quadros próprios.

## 3. A estrutura aprovada, seção por seção — a régua do QA

Cada item é conferido na tela entregue: existe, na ordem, com o texto, com a marca, com a ação,
com a recusa. Divergência é defeito.

### Em toda página da área

- 3.0.1 O menu principal tem **Network analysis** com as seis páginas abaixo, nesta ordem: Review network, Graph, Communities, Hubs, Distance and small world, Positions and profiles.
- 3.0.2 Seletor de aresta com duas opções, **review** ("reviewer → author of the change request") e **delegation** ("author of the issue → assignee"). A palavra "collaboration" não aparece.
- 3.0.3 A aresta escolhida acompanha a navegação entre as páginas.
- 3.0.4 Seletor de janela 30 / 90 / 180 dias; trocar lê outra leitura armazenada, não calcula.
- 3.0.5 Linha da leitura: data e hora, há quanto tempo, a janela, e as marcas *derived* e *observed*.
- 3.0.6 Nenhum número com mais de duas casas; nenhum zero ou travessão no lugar de ausência.

### Tela 1 — a área

- 3.1.1 Título "Network analysis", pergunta "Read the links between people as a network."
- 3.1.2 As duas arestas definidas em palavras, com a direção da seta.
- 3.1.3 Seis cartões: nome, pergunta que responde, medidas; Review network marcado como primeira página.
- 3.1.4 A frase de não-avaliação ("These pages describe how work flows… They do not assess anyone").

### Tela 2 — o grafo ponderado

- 3.2.1 Tamanho do nó = pessoas ligadas; cor = intermediação em cinco faixas nomeadas (none, <2%, 2–5%, 5–10%, ≥10%); espessura = contagem; seta = direção. Legenda com as três codificações e a marca *derived*.
- 3.2.2 Nomes escritos só para os sete mais ligados; os demais ao apontar ou tocar.
- 3.2.3 Zoom (roda e botões + − e "fit"), arrastar a vista, destaque dos vizinhos ao apontar, tocar ou focar pelo teclado.
- 3.2.4 Posições vindas do servidor: a mesma leitura desenha sempre a mesma figura.
- 3.2.5 Cartão da pessoa: revisou / foi revisada (ou atribuiu / recebeu), grau em pessoas, intermediação em % de caminhos, proximidade em passos, autovetor em 0–100, posição em frase.
- 3.2.6 Abaixo do grafo, contados e não desenhados: bot ou app, conta da organização, conta sem pessoa.
- 3.2.7 Pessoa observada sem ligação na janela: ausência escrita, não nó isolado.
- 3.2.8 Conectividade dita corretamente ("everyone drawn is linked…" ou "N groups not linked to each other").

### Tela 3 — comunidades

- 3.3.1 Três blocos: número de comunidades; modularidade com duas casas e a escala explicada; "Not the declared teams — a reading".
- 3.3.2 Grafo com cor, contorno tracejado e letra por comunidade; letras por tamanho, A a maior.
- 3.3.3 Método dito: Louvain, ponderado pela contagem.
- 3.3.4 Um cartão por comunidade: letra, pessoas, ligações dentro e para fora, os três mais ligados dentro (com o número), todos os membros por nome.

### Tela 4 — hubs

- 3.4.1 Quatro blocos — Degree, Betweenness, Closeness, Eigenvector —, cada um com a explicação em uma linha e a marca *derived*.
- 3.4.2 Os cinco mais altos de cada, empates por nome, valor em unidade.
- 3.4.3 A frase "A high value describes where someone sits in the links, not how good their work is."
- 3.4.4 Estado sem valor: "not computed: the calculation did not settle", com o número de rodadas e a razão; ninguém recebe valor, ninguém recebe zero.

### Tela 5 — distância e mundo pequeno

- 3.5.1 Distância média (passos), diâmetro (passos), eficiência global (%), com a nota de que só ali pares inalcançáveis contam como zero.
- 3.5.2 Distribuição dos caminhos mais curtos por comprimento, em barras hachuradas, com a contagem de pares.
- 3.5.3 Tabela: clustering e distância média, desta rede contra a média de 50 redes aleatórias com as mesmas pessoas e ligações, e a razão.
- 3.5.4 σ com uma casa e a leitura em palavras; quantas redes aleatórias não ficaram ligadas e como a distância foi medida nelas.
- 3.5.5 Estado da rede partida: "N groups not linked to each other", com os tamanhos; distância medida só entre os pares alcançáveis, dizendo quantos; σ "not tested".

### Tela 6 — posições e perfil

- 3.6.1 Tabela por nome, sem ordenação por coluna: pessoa, comunidade, ligada a, posição em frase.
- 3.6.2 A regra da posição a um clique.
- 3.6.3 A frase de que a posição descreve as ligações, não a pessoa.
- 3.6.4 Perfil: as duas comunidades, a posição nas duas redes, as medidas, e quatro listas por nome — atribui issues a, recebe issues de, revisou, foi revisada por — com totais; lista vazia escrita como ausência.

### Tela 7 — alcance parcial

- 3.7.1 Aviso *your reach* explicando o alcance, que as medidas são da rede inteira, e como aparecem os demais.
- 3.7.2 Nós nomeados só para quem está no alcance; um nó tracejado sem nome por comunidade para os demais, com "N outside your reach · letra"; ligações entre os de fora não desenhadas.
- 3.7.3 Apontar o nó sem nome diz só quantas pessoas ele contém.
- 3.7.4 Comunidades e hubs com o mesmo recorte: membros fora contados, mais ligados fora como "a person outside your reach". *(Sujeito à Q3.)*

### Tela 8 — telefone

- 3.8.1 Nenhum grafo no telefone; a frase dizendo que o grafo vira a lista.
- 3.8.2 Comunidades em cartões e pessoas em linhas empilhadas, por nome.
- 3.8.3 O perfil empilhado, com as mesmas seções da tela 6.

### Fim da página

- 3.9.1 "Decisions and open questions": decisões *Decided 2026-10-03*, propostas, e Q1–Q4 com opções e recomendação.

## 4. Como cada papel usa este arquivo

- **Product Owner**: registra no item do backlog (`docs/backlog/`) o endereço e este arquivo, cita os dois na spec 076, leva Q1–Q4 à pessoa mantenedora e traz as respostas.
- **Design**: marca as respostas como *Decided <data>* e republica **no mesmo endereço**; toda mudança de tela volta aqui primeiro.
- **Elixir/Phoenix Developer**: implementa exatamente a seção 3; o que não for possível ou honesto com o dado volta ao protótipo, não é improvisado no código. Antes do código: os YAML das medidas listadas no README, o mapeamento da aresta de delegação, e a avaliação do agente `security` sobre o alcance parcial.
- **QA**: confere a tela entregue item a item contra a seção 3, com captura da tela real ao lado.
