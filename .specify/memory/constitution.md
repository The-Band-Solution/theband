<!--
Sync Impact Report
==================
Versão: template não preenchido → 1.0.0
Motivo do bump: ratificação inicial. O arquivo continha apenas os placeholders do
template; nenhum princípio havia sido definido. Primeira versão concreta = MAJOR 1.

Princípios definidos (todos novos):
  [PRINCIPLE_1_NAME] → I. Domínio organizado pelas ontologias
  [PRINCIPLE_2_NAME] → II. Fonte externa não é domínio
  [PRINCIPLE_3_NAME] → III. Proveniência e idempotência (NÃO NEGOCIÁVEL)
  [PRINCIPLE_4_NAME] → IV. Semântica declarada em YAML versionado
  [PRINCIPLE_5_NAME] → V. Monólito modular multitenant
  (adicionados)      → VI. Spec Kit e sprint backlog antes do código
  (adicionados)      → VII. Quality gates e revisão independente

Seções definidas:
  [SECTION_2_NAME] → Restrições tecnológicas
  [SECTION_3_NAME] → Fluxo de desenvolvimento

Princípios acrescentados por emenda posterior:
  1.2.0 → VIII. Desenho que o problema justifica
  1.3.0 → IX. Ontologias modulares e autônomas
  1.4.0 → X. Responsabilidade única, em módulo e em tela
  1.5.0 → XI. Estado conferido antes, sinal nunca silenciado

Fonte dos princípios: AGENTS.md na raiz do repositório, documento normativo de fato
desde antes desta ratificação. Esta constituição não inventa regra nova — codifica o
que o AGENTS.md já exigia, e passa a prevalecer sobre ele em caso de conflito.

Itens diferidos: nenhum. RATIFICATION_DATE assumida como a data desta ratificação,
por não haver adoção anterior registrada — o arquivo era template.

Emenda 1.1.0 — 2026-08-09
=========================
Versão: 1.0.0 → 1.1.0 (MINOR: orientação materialmente ampliada, nenhum princípio
removido ou redefinido).

Princípio VI ganha a exigência de **contrato da API antes da implementação**.

Motivo: o /speckit-analyze da feature 001 encontrou duas divergências entre
contrato e código — assinatura de `mark_evidence_no_longer_observed/2` e as
`opts` das funções de leitura — em que o código estava certo e o documento,
desatualizado. Ambas nasceram de contrato escrito junto com o código em vez de
antes dele.

O que passa a ser exigido de quem já seguia a versão anterior: escrever o
contrato em `specs/<feature>/contracts/` antes da primeira função pública, e
corrigi-lo no mesmo commit quando a implementação mostrar que ele estava errado.

Emenda 1.2.0 — 2026-08-09
=========================
Versão: 1.1.0 → 1.2.0 (MINOR: princípio adicionado, nenhum removido ou redefinido).

Acrescentado o princípio **VIII. Desenho que o problema justifica**.

Motivo: instrução da pessoa mantenedora para que boas práticas, padrões de
desenho e a recusa a antipadrões passem a ser norma. A formulação escolhida
**não** é "aplique padrões": é "o padrão precisa do problema". A diferença
importa — "aplique design patterns" é justamente o que produz fábrica com um
produto, interface com uma implementação e camada de abstração sobre a única
fonte que existe.

Os antipadrões nomeados não vieram de livro: cada um já apareceu neste
repositório ou está a um descuido de aparecer. O `.credo.exs` que substituía o
conjunto de checks em vez de complementá-lo, criado e removido no sprint 001, é o
exemplo de configuração que mantém o gate verde e o faz parar de proteger.

O que passa a ser exigido de quem já seguia a versão anterior: registrar no
`plan.md` as três respostas antes de introduzir qualquer padrão — qual problema
concreto, se ele existe agora, e o que fica pior.

Emenda 1.5.0 — 2026-08-26
=========================
Versão: 1.4.0 → 1.5.0 (MINOR: princípio acrescentado, nenhum removido ou redefinido).

Acrescenta o **princípio XI — Estado conferido antes, sinal nunca silenciado**.

Motivo: numa sessão de 2026-08-26, quatro operações destrutivas de git escreveram no
lugar errado, e as quatro têm a mesma forma — o sinal que revelaria o erro foi
suprimido ou substituído. `git stash` sem ler a lista, `git checkout` sem verificar
worktree, `git reset --hard` em branch não confirmada, e `git checkout <ref> --
<caminhos>` com `2>/dev/null` sobrescrevendo trabalho não commitado.

No mesmo dia, e pela mesma causa, um commit afirmou "13 gates verdes" com o credo
reprovando: o `tail` depois do `mix gates` devolveu o próprio código de saída. Na
direção oposta, um `grep -c` no fim da linha fez gates verdes serem lidos como falha.

O que passa a ser exigido de quem já seguia a versão anterior: commitar antes de trocar
de contexto; ler o estado antes de comando que sobrescreve; não suprimir `stderr` de
comando que escreve; e ler o código de saída de dentro do log, nunca da notificação do
comando composto.

Emenda 1.6.0 — 2026-08-28
=========================
Versão: 1.5.0 → 1.6.0 (MINOR: orientação materialmente ampliada na seção Fluxo de
desenvolvimento; nenhum princípio removido ou redefinido).

A seção de issues do PR ganha formato obrigatório: um bloco por user story (título,
número, prioridade) e tabela por tarefa — issue, ID e o resumo do que entregou, na
frente. Padrão adotado no PR #543 e tornado norma por instrução da pessoa mantenedora.

Motivo: a lista `US1 #529 (T001 #532, ...)` informa rastreabilidade e nada mais — quem
revisa precisa abrir cada issue para saber o que o PR contém. O resumo na frente põe a
decisão de revisão no próprio PR.

O que passa a ser exigido de quem já seguia a versão anterior: escrever a seção de
issues nesse formato em todo PR de feature, a partir desta data.

-->

# Constituição do The Band

## Princípios fundamentais

### I. Domínio organizado pelas ontologias

O núcleo do domínio MUST ser organizado pelas ontologias da rede SEON/Continuum, nunca
pelas ferramentas externas. Não existe módulo de domínio nomeado por ferramenta: GitHub
é fonte, não conceito.

- Conceito que já existe em ontologia mais geral MUST ser reutilizado por referência,
  nunca duplicado. `Person` mora em EO; SRO, CIRO e CDRO apenas a referenciam em papéis
  contextuais.
- A dependência entre ontologias MUST ir do específico para o geral. `EO → SRO`,
  `SPO → CIRO` e `SysSwO → CDRO` são proibidas e verificadas por `mix knowledge.graph` e
  por teste automatizado.
- As distinções semânticas do modelo MUST ser preservadas no código e no esquema: Pull
  Request ≠ Merge, Pessoa ≠ Membro de equipe, processo planejado ≠ executado, Código ≠
  Programa, documento de requisito ≠ requisito, caso de teste ≠ execução, code smell ≠
  defeito, defect ≠ fault ≠ failure.
- Mapeamento por semelhança de nome MUST NOT ser aceito. Todo mapeamento exige
  justificativa semântica escrita, com grau de equivalência e limitações declaradas.

**Razão**: um mapeamento errado contamina em silêncio toda medida derivada dele, e o erro
só aparece depois que a decisão já foi tomada sobre o dado errado. A organização por
ontologia é o que torna o erro revisável antes de virar número.

### II. Fonte externa não é domínio

O caminho do dado externo até o domínio MUST seguir, sem atalho:

```text
fonte externa → integração → payload bruto → proveniência
→ mapeamento YAML → validação semântica → comando da ontologia → persistência
```

- Conector MUST NOT escrever em schema Ecto de módulo ontológico. Ele grava payload bruto
  com proveniência e chama a API pública do módulo.
- O modelo de dados da ferramenta externa MUST NOT ser usado como modelo de domínio.
- O payload original MUST ser preservado sem alteração antes de qualquer transformação, de
  modo que uma correção de mapeamento possa ser reaplicada sem consultar a fonte de novo.
- Uma entidade externa pode alimentar várias ontologias; a transformação MUST tratar isso
  explicitamente, e não escolher uma ontologia por conveniência.

**Razão**: a fronteira é o que permite trocar a fonte, corrigir o mapeamento e auditar a
derivação sem reescrever o domínio.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL)

Todo registro conhecido pela plataforma MUST carregar sua origem, e toda ingestão MUST ser
idempotente.

- Toda tabela de domínio MUST ter `tenant_id`, `internal_id`, `record_version`,
  `inserted_at` e `updated_at`.
- Toda tabela alimentada por fonte externa MUST ter `source_system`, `source_instance`,
  `external_id` e `collected_at`, com `unique_index` sobre
  `[:tenant_id, :source_system, :source_instance, :external_id]`.
- Registro sem Application Reference — `source_system` + `source_instance` + `external_id`
  — é inválido, não incompleto.
- Executar a mesma coleta duas vezes MUST levar ao mesmo estado final: sem duplicar
  registro e sem alterar registro cuja origem não mudou.
- Cursor e checkpoint MUST ser persistidos, nunca mantidos apenas em memória.
- Ausência na origem MUST ser registrada como não mais observada, nunca como remoção
  silenciosa do registro.

**Razão**: a plataforma existe para responder de qual fonte um indicador veio e como foi
calculado. Sem proveniência ela vira um dashboard sem lastro; sem idempotência, os números
mudam a cada execução sem que nada tenha mudado na realidade.

### IV. Semântica declarada em YAML versionado

A semântica MUST viver na base de conhecimento YAML versionada em `priv/knowledge_base/`,
não em regra embutida no código de coleta ou de transformação.

- Conceitos, relações, cardinalidades, constraints, perguntas de competência, mapeamentos,
  necessidades de informação e medidas MUST ser declarados em YAML validado contra os
  schemas do repositório.
- YAML inválido MUST NOT entrar no repositório. `mix knowledge.validate`,
  `mix knowledge.graph` e `mix knowledge.test` são gate, não sugestão.
- Falha ao carregar a base MUST ser falha de inicialização. Uma aplicação que sobe com o
  modelo pela metade é pior que uma que não sobe.
- Medida declarada MUST trazer limitações e interpretações incorretas possíveis. Número sem
  contexto engana, e o schema exige esses campos por isso.
- Toda medida MUST responder a uma necessidade de informação declarada. Dashboard sem
  necessidade de informação MUST NOT ser criado.

**Razão**: quem revisa a semântica não é necessariamente quem compila o projeto. Declarar em
YAML mantém a revisão possível e o diff semântico legível.

### V. Monólito modular multitenant

A plataforma MUST ser um monólito modular multitenant em Elixir/Phoenix, com as camadas da
tese realizadas como fronteiras internas e não como serviços separados.

- Multitenancy MUST ser uma base PostgreSQL com tabelas compartilhadas e `tenant_id`. Banco
  ou schema por tenant MUST NOT ser criado.
- Toda query de domínio MUST receber o tenant explicitamente. Query sem filtro de tenant é
  bug de segurança, não de correção.
- Todo job Oban MUST carregar `tenant_id` nos argumentos e validá-lo antes de executar.
- Os testes MUST cobrir vazamento entre tenants com dois tenants povoados simultaneamente.
- A API pública de um módulo ontológico MUST ser o único ponto de entrada; outro módulo
  MUST NOT alcançar schema interno nem `Repo` alheio.
- Broker externo, microserviço, banco de grafos, backend adicional ou frontend separado
  MUST NOT ser introduzidos enquanto a stack atual atender, e nunca sem ADR aprovada.

**Razão**: a complexidade distribuída cobra caro antes de entregar valor. A fronteira de
módulo dá a separação que importa sem o custo operacional que ainda não se justifica.

### VI. Spec Kit e sprint backlog antes do código

Nenhuma linha de código de feature MUST ser escrita sem o ciclo Spec Kit percorrido e o
sprint backlog aberto.

- O ciclo é: `/speckit-specify` → `/speckit-clarify` → `/speckit-checklist` → aprovação →
  `/speckit-plan` → revisão arquitetural e semântica → `/speckit-tasks` →
  `/speckit-taskstoissues` → `/speckit-analyze` → `sprint-backlog` → implementação.
- Implementar sem sprint backlog aberto pela skill `sprint-backlog` MUST NOT acontecer.
- Abrir sprint sem ler o registro de lições aprendidas MUST NOT acontecer; fechar sprint sem
  separar o que foi entregue do que não foi, tampouco.
- Toda entrega MUST ser uma fatia vertical: tela e backend na mesma proposta de mudança.
  Infraestrutura sem consumidor visível MUST NOT ser entregue como feature. Ao propor uma
  feature, o primeiro enunciado MUST ser o que a pessoa verá ao final; se a resposta for
  "nada ainda", a fatia está mal cortada.
- **O contrato da API MUST existir antes da implementação.** Nenhuma função pública é escrita
  antes de sua assinatura, seus retornos de sucesso e de erro, e o que a API deliberadamente
  não expõe estarem declarados em `specs/<feature>/contracts/`. Quando a implementação
  revelar que o contrato estava errado, ele MUST ser corrigido no mesmo commit, com a razão
  registrada — código correto com contrato desatualizado é falha de rastreabilidade, não
  detalhe de documentação.
- Requisito novo MUST NOT ser implementado sem atualizar os artefatos do Spec Kit. Ampliar
  escopo em silêncio MUST NOT acontecer.
- Inconsistência reportada pelo `/speckit-analyze` MUST ser resolvida ou registrada, nunca
  ignorada.

**Razão**: o ciclo é o que mantém a rastreabilidade entre necessidade, decisão e código. A
fatia vertical é o que impede meses de infraestrutura sem nada que se possa olhar.

### VII. Quality gates e revisão independente

Quem implementa MUST NOT ser quem valida sozinho.

- Antes de abrir PR, todos os gates MUST estar verdes: `mix format --check-formatted`,
  `mix compile --warnings-as-errors`, `mix credo --strict`, `mix dialyzer`, `mix test`,
  `mix knowledge.validate`, `mix knowledge.graph`, `mix knowledge.test`.
- Desabilitar check, silenciar Dialyzer com anotação, remover ou enfraquecer teste para o
  pipeline passar MUST NOT acontecer.
- Aprovar o próprio PR, ou fazer merge sem revisão independente, MUST NOT acontecer. Quando
  a revisão independente não puder ser obtida, a lacuna MUST ser declarada — nunca marcada
  como cumprida.
- Sucesso MUST ser declarado com evidência: saída de teste, log ou captura de tela. Tarefa
  marcada como concluída sem evidência MUST NOT ser aceita.
- Push direto na branch principal MUST NOT acontecer.
- Erro MUST NOT ser escondido com mock excessivo ou valor fixo. Mock somente na borda HTTP;
  módulo de domínio próprio MUST NOT ser mockado.

**Razão**: o custo de um gate vermelho é minutos; o de um dado errado em produção é a
confiança na plataforma inteira.

### VIII. Desenho que o problema justifica

Boas práticas e padrões de desenho MUST ser aplicados **quando existe o problema que
eles resolvem**, e MUST NOT ser aplicados por serem reconhecíveis. Padrão sem problema é
antipadrão: paga complexidade hoje por flexibilidade hipotética, e atrapalha quem lê.

- Todo padrão introduzido MUST trazer, no `plan.md` da feature, as três respostas: qual
  problema concreto ele resolve, se esse problema **existe agora** ou é previsão, e o que
  fica pior por adotá-lo. Quem não sabe dizer o que piorou não entendeu o padrão.
- Abstração criada para um caso hipotético MUST NOT ser introduzida. Duplicar duas vezes é
  barato; abstrair cedo e errado é caro. Na terceira ocorrência já se sabe o que varia.
- Os antipadrões declarados em `AGENTS.md` §7.7 MUST ser tratados como defeito em revisão,
  não como preferência de estilo. Entre eles, os que a arquitetura deste projeto atrai:
  booleano no lugar do relator, mapeamento por semelhança de nome, consulta sem tenant,
  fallback silencioso, mock de módulo de domínio próprio, configuração que enfraquece um
  quality gate, e acoplamento temporal em checkpoint.
- **Ausência MUST ser representada como nula, nunca como zero.** Preencher com zero o que
  não se sabe transforma lacuna em decisão, e a medida derivada mente sem avisar.
- Erro previsto de negócio MUST ser retorno — `{:error, motivo}` —, e exceção MUST ficar
  reservada ao que é bug. Exceção como fluxo de controle esconde o caso previsto entre os
  imprevistos.
- Refatoração MUST entrar na feature apenas quando o código tocado torna a mudança mais
  difícil. Refatoração oportunista MUST NOT ser misturada ao mesmo diff: ela precisa de
  critério de revisão diferente do da feature.

**Razão**: este projeto já tem complexidade essencial — uma rede de doze ontologias, um
modelo de informação derivado e proveniência em cada registro. Complexidade acidental
somada a essa não é neutra: ela consome a atenção que a semântica exige. A regra existe
para que a estrutura que houver seja a que o problema pediu, e para que a lista de
antipadrões seja verificável em revisão em vez de opinião de quem revisa.

### IX. Ontologias modulares e autônomas

Cada ontologia da rede MUST ser **autônoma**: validável e derivável sem que outra esteja
completa. SWO e SRO MUST ser independentes entre si, e o mesmo vale para qualquer par.

Autonomia MUST NOT ser confundida com isolamento. Referência entre ontologias é o padrão,
exigido pelo princípio I e detalhado no ADR 0004 D9 — a ontologia nova aponta para os
kinds que já existem e acrescenta os seus, sem alterar nada do que está lá.

> **A regra da fronteira.** Dentro de uma ontologia, aplicam-se as técnicas de
> transformação. Ao atravessar a fronteira, aplica-se **referência** — e qual das duas
> vale é decidido pelo **estereótipo declarado**, nunca pela ferramenta. `subkind` afirma
> identidade herdada e materializa na tabela do kind referenciado; `kind` afirma
> identidade própria e materializa na ontologia que o declara.

- **A derivação de uma ontologia MUST NOT falhar por causa do estado de outra.** O que
  bloqueia é a falta de estereótipo nos conceitos **da própria** ontologia. Derivar não
  depende de a rede estar completa.
- **As técnicas de transformação — lifting, flattening, discriminador, relator — MUST ser
  aplicadas dentro da fronteira de uma ontologia.** Elas resolvem a hierarquia interna do
  módulo: um `subkind` sobe ao kind da própria ontologia, um não-sortal é achatado nos
  sortais dela, uma `phase` vira discriminador na tabela dela.
- **Atravessar a fronteira é decisão de identidade, e MUST estar declarada no
  estereótipo** — nunca resolvida pela ferramenta:

  | Declaração | O que afirma | Como materializa |
  |---|---|---|
  | `subkind` com pai em outra ontologia | tem a **mesma** identidade daquele kind | por referência: valor de discriminador na tabela do pai, e tabela de extensão para os atributos próprios |
  | `kind` | tem identidade **própria** | tabela na própria ontologia; o `parent` permanece como referência semântica e deixa de decidir a transformação |

- A ferramenta MUST NOT materializar localmente um kind de outra ontologia por conta
  própria. Fazê-lo escolheria identidade no lugar de quem modela, e fragmentaria em duas
  tabelas o que a referência mantém em uma — quebrando a promessa de que instalar uma
  ontologia nova só acrescenta.
- Quando um conceito referencia kind de ontologia **ainda não materializada**, a derivação
  MUST declarar a exigência, nomeando o conceito que falta. Atender a exigência MUST ser
  **incremental**: anota-se o conceito referenciado, não a ontologia inteira.
- Nenhuma feature MUST ser bloqueada por anotação em massa de ontologia alheia. Anotar
  onze conceitos para registrar um repositório é acoplamento disfarçado de pré-requisito;
  anotar o único conceito referenciado é a referência funcionando.
- A fronteira MUST valer também no código: um módulo ontológico fala com outro pela API
  pública do módulo raiz, nunca por schema Ecto nem por consulta direta às tabelas dele.

**Razão**: a rede tem doze ontologias e quatro anotadas, e vai crescer por instalação
incremental. Duas falhas simétricas ameaçam isso, e o princípio existe para barrar as
duas.

**Fragmentar** — cada ontologia materializando localmente o que referencia — faz "todas as
atividades de configuração" virar uma união entre tabelas, e faz a ontologia seguinte
encontrar dois lugares para apontar em vez de um.

**Bloquear** — exigir a ontologia alheia inteira antes de começar — faz cada feature nova
carregar a anotação de todo caminho que atravessa, até que ninguém comece.

A saída não é escolher entre as duas: é que **o estereótipo já responde**. Identidade
própria é `kind` e materializa aqui; identidade herdada é `subkind` e materializa por
referência. Foi assim que a SRO ficou independente da RSRO e da SysSwO — `user_story` e
`deliverable` são `kind` porque têm identidade própria, não para contornar anotação
pendente.

### X. Responsabilidade única, em módulo e em tela

Cada módulo e cada tela MUST ter **uma razão para mudar**. Quando duas mudanças de origens
diferentes tocam o mesmo arquivo, ele tinha duas responsabilidades — e a segunda estava
escondida.

> **A regra.** Um módulo faz uma coisa. Uma tela mostra uma coisa. Se descrever o que ele
> faz exige a palavra "e", ele provavelmente são dois.

- **Módulo com duas razões para mudar MUST ser dividido**, e o critério é a origem da
  mudança, não a contagem de linhas. Um módulo de 400 linhas que muda só quando a
  ontologia muda está correto; um de 80 que muda quando a regra de negócio muda **e**
  quando o formato de exibição muda, não.
- **Tela MUST mostrar uma coisa.** Duas perguntas diferentes na mesma tela são duas telas,
  ou uma tela e um componente. O sinal é o cabeçalho: se ele precisa de duas frases para
  dizer o que a tela responde, a tela responde duas coisas.
- **Ação MUST existir num lugar só.** Dois botões que disparam a mesma operação produzem
  duas leituras de "quando isto foi atualizado", e a resposta certa é uma.
- **Módulo `utils`, `helpers` ou `common` MUST NOT ser criado.** Ele é o lugar onde
  responsabilidade sem dono vai morar, e cresce até ninguém saber o que há dentro. Função
  sem casa clara indica conceito ainda não nomeado.
- **A extração acontece quando a segunda razão aparece**, nunca antes. Dividir por previsão
  é o que o princípio VIII proíbe: os dois módulos nascem acoplados por uma interface que
  ninguém precisou.

**As cinco letras, traduzidas para o que significam aqui.** SOLID nasceu em orientação a
objetos, e aplicá-lo ao pé da letra em Elixir produz `behaviour` sem implementação
alternativa e protocolo sem segundo tipo — abstração sem problema, que o princípio VIII
recusa. O que cada letra exige neste projeto:

| Letra | O que MUST valer aqui |
|---|---|
| **S** — responsabilidade única | uma razão para mudar, por módulo e por tela |
| **O** — aberto/fechado | estender por **cláusula ou módulo novo**, não editando um `case` que cresce. Um `case` com sete ramos sobre o mesmo eixo é a semântica pedindo para virar dado — e neste projeto, dado é YAML versionado |
| **L** — substituição | quem implementa um `behaviour` MUST honrar o contrato dele, incluindo o que ele devolve em falha. Implementação que levanta onde o contrato prevê `{:error, motivo}` quebra quem a chama |
| **I** — segregação de interface | a API pública MUST ser o menor conjunto que serve ao caso de uso. Função que devolve `Ecto.Query` viola por obrigar quem chama a conhecer o schema interno |
| **D** — inversão de dependência | um módulo MUST depender da **fronteira pública** de outro, nunca dos schemas nem das tabelas dele. É a ADR 0003, e é o que a constituição IX já exige entre ontologias |

**Razão**: esta plataforma tem doze ontologias, um modelo derivado e proveniência em cada
registro. A complexidade essencial é alta, e é justamente aí que responsabilidade misturada
custa mais: um módulo que faz duas coisas força quem lê a carregar as duas para entender
uma.

E há o custo específico das telas. Uma tela que responde duas perguntas obriga quem olha a
decidir qual delas está vendo — e a decisão errada é silenciosa. O caso concreto deste
projeto: um resumo de trabalho **do tenant** exibido dentro do cartão de **cada**
sincronização fazia uma coleta de 14 repositórios aparecer com 135 ao lado. Nada falhou;
o número simplesmente respondia outra pergunta.

**Relação com o princípio VIII**: os dois não se sobrepõem. **VIII decide se estrutura
nova deve existir**; **X decide como dividir a que existe.** Usar X para justificar
abstração antecipada inverte os dois: a segunda razão para mudar tem de ter **aparecido**,
não de ser prevista.

### XI. Estado conferido antes, sinal nunca silenciado

Comando que **escreve em estado compartilhado** — árvore de trabalho, branch, remoto, banco
— MUST ser precedido da leitura do estado em que vai escrever, e MUST NOT ter a saída de
erro suprimida.

- Trabalho não commitado **não tem cópia em lugar nenhum**. Antes de trocar de branch, de
  aplicar `stash`, ou de rodar qualquer comando que sobrescreva a árvore, o que está feito
  MUST estar commitado.
- `git reset --hard`, `git checkout <ref> -- <caminhos>`, `git stash pop` e `git push -f`
  MUST ser precedidos da leitura explícita do que será perdido — a branch corrente, a
  lista de stashes, os worktrees, o que diverge do remoto. Encadear com `&&` ou `||` sem
  conferir entre um e outro MUST NOT acontecer.
- `2>/dev/null` em comando que escreve MUST NOT acontecer. O erro suprimido é exatamente o
  que diria que a escrita foi para o lugar errado.
- **O veredito de uma verificação é o código de saída, e o código de saída que chega a quem
  lê é o do último comando da linha.** `mix gates > log; tail log` reporta o `tail`. Em
  execução de fundo, o código MUST ser escrito **dentro** do próprio log, onde nada o
  substitui; em primeiro plano, a linha MUST terminar em `exit $ec`.
- Afirmar "gates verdes", "teste passou" ou "mergeado" sem ter lido o número MUST NOT
  acontecer. Vale o princípio VII: sucesso se declara com evidência.

**Razão**: em 2026-08-26 esta regra foi violada quatro vezes numa sessão, e as quatro têm a
mesma forma — o sinal que revelaria o erro foi suprimido ou substituído.

`git stash` sem ler a lista aplicou o stash de outra branch dentro da `main`, com conflito.
`git checkout gh-pages` falhou porque a branch estava presa num worktree órfão, e o commit
do site foi parar na branch de uma feature aberta. `git reset --hard` rodou numa branch que
não havia sido confirmada, e a `main` local passou a apontar para o commit do site. E
`git checkout <branch> -- <caminhos>` com `2>/dev/null` sobrescreveu uma revisão de
literatura que ainda não estava commitada.

Nada se perdeu **por sorte**: o texto sobrevivera num arquivo não rastreado, gerado a
partir da fonte que ele documenta. Sorte não é procedimento.

No mesmo dia, um commit afirmou "13 gates verdes" com o credo reprovando — porque o
`tail` depois do `mix gates` devolveu o próprio código de saída, e a notificação do
processo reportou o do comando composto. Na direção oposta, um `grep -c` no fim da linha
fez gates verdes serem lidos como falha, por sair 1 ao não achar nada.

**Relação com o princípio VII**: VII exige que o gate esteja verde antes do PR; **XI exige
que o verde tenha sido lido, e não presumido**. Um gate que reprova e é reportado como
verde é pior que um gate que não roda, porque quem lê para de conferir.

## Restrições tecnológicas

Stack fixada: Elixir/Erlang OTP, Phoenix e LiveView, Ecto e PostgreSQL, Oban para jobs e
agendamento, Req para HTTP, ExUnit e Mox para testes, Credo e Dialyzer, ExDoc, Docker
Compose em desenvolvimento, Phoenix Releases em produção, GitHub Spec Kit e YAML como base
de conhecimento versionada.

As versões exatas MUST ser fixadas em `mix.exs` e registradas no `plan.md` da feature. Toda
dependência nova MUST trazer justificativa escrita no plano, avaliando manutenção,
segurança e compatibilidade.

Tecnologia nova MUST NOT ser introduzida quando a atual atende.

As decisões a seguir MUST ser precedidas de ADR em `docs/adr/NNNN-titulo.md`, contendo
contexto, decisão, alternativas consideradas, consequências e status: abandonar o monólito
modular; introduzir microserviços; introduzir Python, Go ou backend adicional; frontend
separado; substituir PostgreSQL; substituir Oban; introduzir broker externo; banco de
grafos; pgvector; alterar a estratégia multitenant; alterar a organização por ontologias;
alterar YAML como base de conhecimento; alterar o versionamento dos YAMLs; alterar a
separação entre fonte externa e domínio; alterar contratos públicos; abandonar o Spec Kit.

Segredo MUST NOT ser commitado nem colocado em YAML. Log MUST NOT expor token nem payload
sensível completo.

## Fluxo de desenvolvimento

Branches: `feature/<issue>-<descricao>`, `fix/`, `refactor/`, `docs/`, `test/`, `chore/`.

Commits seguem Conventional Commits com escopo igual à ontologia ou ao subsistema afetado.

O Pull Request MUST informar: feature, spec, plan, issues, ontologias afetadas, conceitos e
relações afetados, YAMLs alterados, a tabela de mapeamentos semânticos (origem, ontologia,
conceito, equivalência, limitação), migrações, testes, resultado dos quality gates,
perguntas de competência validadas, evidências e riscos residuais.

A seção de issues do PR MUST seguir o padrão adotado no PR #543: um bloco por user story —
título, número da issue e prioridade — e, dentro dele, uma tabela com uma linha por tarefa:
issue, ID da tarefa e **o resumo do que ela entregou**, escrito na frente. Lista de números
sem resumo MUST NOT ser usada: quem revisa decide pelo que foi entregue, e obrigá-lo a
abrir quatorze issues para descobrir é esconder o PR atrás de links.

Features independentes MUST NOT ser misturadas no mesmo PR. Refatoração sem relação com a
feature em curso MUST NOT entrar nela.

**Definition of Done**: critérios de aceitação atendidos e avaliados um a um com evidência,
issues atualizadas, YAMLs validados, perguntas de competência testadas, testes passando,
Credo e Dialyzer aprovados, migrações testadas, mapeamento semântico revisado, documentação
atualizada, PR aprovado por outra pessoa ou outro agente, pipeline verde, merge feito e
issues encerradas.

**Regra de ouro**: diante de incerteza relevante — semântica, arquitetural ou de escopo —
pare e apresente alternativas. Não adivinhe.

## Governança

Esta constituição prevalece sobre qualquer outra prática, documento ou hábito de agente,
incluindo `AGENTS.md` e `CLAUDE.md`. Onde ela for silenciosa, o `AGENTS.md` governa; onde
houver conflito, ela vence. Uma ADR aprovada prevalece sobre o `AGENTS.md`, mas não sobre
esta constituição — contradizer um princípio exige emenda, não ADR.

**Emendas** MUST ser registradas neste arquivo, com data e versão, e MUST declarar o que
muda, por quê, e o que passa a ser exigido de quem já seguia a versão anterior. Delegação de
autonomia a agentes é emenda, não combinação verbal: enquanto não estiver escrita aqui, o
princípio vigente prevalece sobre qualquer instrução em contrário dada em sessão.

**Versionamento** semântico da constituição:

- MAJOR — remoção ou redefinição incompatível de princípio ou regra de governança;
- MINOR — princípio ou seção adicionados, ou orientação materialmente ampliada;
- PATCH — esclarecimento, redação, correção sem efeito semântico.

**Conformidade** MUST ser verificada em toda revisão de PR e no `/speckit-plan` de cada
feature, cujo Constitution Check avalia os princípios um a um. Violação identificada MUST
ser corrigida ou justificada na seção Complexity Tracking do plano, com a alternativa mais
simples e a razão de tê-la rejeitado. Violação sem registro MUST bloquear o merge.

`AGENTS.md` permanece como guia operacional de runtime — comandos, estrutura de diretórios,
convenções de código e perfis de agente.

**Version**: 1.6.0 | **Ratified**: 2026-08-09 | **Last Amended**: 2026-08-28
