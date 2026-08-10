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

**Version**: 1.2.0 | **Ratified**: 2026-08-09 | **Last Amended**: 2026-08-09
