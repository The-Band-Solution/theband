# A versão em produção, e as novidades dela, na página

**Prioridade**: **alta** — decidida pelo papel de Product Owner em 2026-09-09, a confirmar
pela pessoa alocada.
**Origem**: decisão da pessoa mantenedora em 2026-09-09, acrescentada à definição do papel
pelo [#829](https://github.com/The-Band-Solution/theband/pull/829): *"a página do The Band
sempre carrega a versão da aplicação em produção e as funcionalidades novas daquela versão"*.

**A v0.6.0 subiu sem isto.** A regra nasceu junto com a release, não antes dela — o merge foi
às 13:39:49Z e o #829 entrou às 14:26:01Z. Então este item não é uma correção de algo que foi
feito errado: é a primeira vez que a regra existe.

## Por que o `docs/releases/` não basta

O arquivo serve a quem tem o repositório. A página serve a quem **usa** o produto, e é a
maioria. Uma release que só existe em Markdown é uma release que quem usa não sabe que
aconteceu: a tela muda debaixo da pessoa, e nada diz que mudou nem o que mudou.

## O bloqueio de primeira ordem: a plataforma não sabe qual versão está servindo

Conferido no código em 2026-09-09, e é o achado que ordena o resto deste item:

| O que se procurou | Resultado |
|---|---|
| leitura de `Application.spec(:the_band, :vsn)` em `lib/` | **nenhuma** |
| rota de versão ou de saúde em `router.ex` | **nenhuma** |
| a versão em qualquer tela | **em nenhuma** |

`mix.exs` tem `version: "0.6.0"`, mas a regra é explícita sobre não ser essa: *"não a do
`mix.exs` da árvore de trabalho: a que o Dokploy está servindo"*. São coisas diferentes — a
árvore de trabalho pode estar num commit qualquer, e no dia de um hotfix a diferença é
exactamente o que se precisa ver.

**Consequência para o registro da v0.6.0**: a afirmação *"a v0.6.0 está no ar"* apoia-se na
cadeia do CD — imagem publicada, webhook aceito, Dokploy puxa `:latest` —, e **não** numa
resposta da própria aplicação. O `HTTP 200` de `app.theband.dev/sign-in` prova que **responde**;
não prova **qual versão** responde.

E a regra já diz o que fazer quando não se sabe: **a página diz que não sabe.** Versão errada
em tela é pior que versão ausente.

## O conteúdo do primeiro corte — a decisão deste papel

O Design decide *como* aparece. **O que** aparece é decisão de valor, e é esta:

### 1. A versão

> **The Band 0.6.0** — no ar desde 9 de setembro de 2026.

Com uma regra de honestidade que não é negociável: se a aplicação não conseguir ler a própria
versão, a superfície diz **"versão não identificada"** e liga para o histórico de releases.
Nunca imprime a do `mix.exs` compilado na árvore de quem construiu a página.

### 2. As funcionalidades — cinco linhas, uma por user story aceita

Só entra o que está **aceito**. É o mesmo invariante da release: recusado não embarca, e
recusado não se anuncia. As cinco, escritas para quem usa — sem número de PR, sem nome de
tarefa, sem sigla de requisito:

| # | O que a página diz | User story |
|---|---|---|
| 1 | **Veja quem está na equipe, e de onde veio cada informação.** A página da equipe mostra cada pessoa uma vez, com o papel que ela desempenha e a origem de cada afirmação — o que a ferramenta mostrou e o que a sua organização declarou. Quem participa de uma subequipe aparece na equipe que a contém, numa linha só. | US1 |
| 2 | **Declare o papel de quem a ferramenta mostra — e mude quando mudar.** Onde antes havia apenas *não declarado*, agora se declara o papel na própria linha, sem sair da tela. Uma pessoa pode ter mais de um papel ao mesmo tempo, e trocar um deixa registrado o período em que o anterior vigeu. | US2 |
| 3 | **Corrija o vínculo que nunca existiu.** Quando a ferramenta atribuiu alguém a uma equipe por engano, o registro do equívoco tira a pessoa de **todas** as datas — com a razão e o autor guardados. E o texto na tela separa *nunca esteve nesta equipe* de *saiu da equipe*, que são coisas diferentes e antes se pareciam. | US4 |
| 4 | **Crie os papéis da sua organização.** Os papéis passam a ser da organização, não de uma equipe: crie um a partir da estrutura de qualquer equipe e ele fica disponível em todas. Renomear preserva os vínculos, e papel em uso não é removido — a recusa diz quantas pessoas o usam. | US5 |
| 5 | **Veja o fluxo da equipe inteira, em três granulações.** Quanto abriu e quanto fechou ao longo do tempo, o prometido ao lado do entregue, e uma previsão semanal de quando o trabalho aberto termina — por semana, mês ou ano. Cada subequipe ganha um cartão com o gráfico pequeno do próprio fluxo, e o cartão é a porta para o painel dela. | US9 |

### 3. O que fica de fora, e por quê

Isto **não** vai na página — vai neste registro, para que a ausência seja decisão e não
esquecimento:

| O que | Está em produção? | Por que não se anuncia |
|---|---|---|
| **a saída declarada** (US3) — registrar que a pessoa saiu, mantendo o que ela fez | **sim** | **não aceita**: o critério SC-013 (registrar em menos de um minuto) nunca foi cronometrado. É o item mais barato da fila: uma medida com um relógio, e ela entra |
| ***Problems now*** (US8 parcial) — os oito cartões de problema | **sim** | não avaliada, logo não aceita; e o próprio PR declara o que não fecha. Precisa de tarefas antes de veredito |
| **o cartão da subequipe como porta** (US7 parcial) | **sim** | o cartão existe; os outros critérios da US7 não foram avaliados |
| **a proveniência na página da equipe**, o gestor de cotas, o vínculo observado | **sim** | são melhorias de comportamento e de coleta, não user story aceita com valor novo para quem usa. Anunciá-las encheria a página de coisa que a pessoa não *passa a conseguir fazer* |

**A US3 é a que dói**, e por isso está nomeada primeiro: é uma funcionalidade pronta, em
produção, que a página não pode anunciar por falta de uma medida de um minuto. A regra é a
mesma que impede anunciar o que não funciona, e não se dobra por conveniência — mas o preço
dela fica escrito.

### 4. O caminho para o detalhe

Uma linha ao fim: *o registro completo desta versão, com o que foi aceito e o que não foi,
está no [histórico de releases](../releases/README.md)*. A página anuncia; o registro presta
contas. Quem quiser o desconforto inteiro tem onde achá-lo.

## O que fica fora deste item

- **como a superfície aparece** — é do Design, e vem depois: protótipo, aprovação da pessoa
  mantenedora, código, conferência do QA;
- **o mecanismo pelo qual a aplicação descobre a própria versão** — é decisão de arquitetura,
  não deste papel. O que este papel exige é o **comportamento**: a versão exibida é a que está
  servindo, e quando não se sabe, diz-se que não se sabe.

## Perguntas abertas, para a pessoa mantenedora

| # | Pergunta | Opções | Recomendação |
|---|---|---|---|
| 1 | **onde vive a superfície** | (a) na aplicação, para quem entra; (b) no site público `theband.dev`; (c) nos dois | **(c)**, com fontes diferentes: na aplicação a versão é lida em execução (é a que serve); no site é a última release publicada. A mesma frase nos dois lugares com origens diferentes é o tipo de coisa que divergindo ninguém percebe |
| 2 | **quem vê** | (a) todo mundo, inclusive antes de entrar; (b) só quem entrou | **(b)** para a versão em execução — antes de entrar não há sessão nem tenant, e expor a versão exata a quem não entrou dá a quem procura falha a informação mais útil de graça |
| 3 | **a pessoa é avisada de que mudou** | (a) só uma página consultável; (b) um aviso uma vez por versão, dispensável | **(a) no primeiro corte.** (b) exige lembrar por conta quem já viu o quê — estado novo por pessoa, e não há necessidade de informação declarada que o sustente |

## Critérios que a spec vai precisar carregar

- a versão exibida é a **em execução**, não a da árvore de trabalho;
- quando a versão não é identificável, a superfície **diz que não sabe** e não imprime número
  algum;
- **nenhuma** funcionalidade não aceita aparece anunciada — verificável contra o
  `docs/releases/vX.Y.Z.md` da versão;
- cada linha diz o que a pessoa **passa a conseguir fazer**, e nenhuma cita PR, tarefa ou
  requisito;
- a superfície está no protótipo aprovado antes de existir em código.
