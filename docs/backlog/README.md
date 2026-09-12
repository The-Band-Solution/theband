# Backlog

O que construir, em que ordem, e por quê. Cada documento traz a derivação do
escopo — não só a lista.

| Documento | Do que trata | Prioridade |
|---|---|---|
| [O backup restaurado de verdade](backup-restaurado-de-verdade.md) | o §6 do runbook — bloqueado na conta do S3, que ainda não existe; a 050/US2 segue não aceita | **alta — bloqueada em recurso** |
| [MinIO como destino do ensaio **e da produção**](minio-como-destino-do-ensaio-de-backup.md) | o ensaio do §6 deixa de esperar conta em provedor, e em 2026-09-12 a pessoa mantenedora decidiu que o MinIO vira **também o destino de produção, num segundo host** — o que traz TLS, credencial fora do repositório, escopo de escrita e retenção | **alta — destrava o ensaio; a produção depende de um host novo** |
| [A conta desativada](conta-desativada.md) | não existe estado de conta desativada: o desligamento é implícito, e na tela a conta desligada é indistinguível da recém-criada — risco em produção **hoje** | **alta — à frente da 061**, proposta de 2026-09-09 |
| [As recusas falam português, e a tela fala inglês](recusas-em-portugues-e-o-nome-da-coluna.md) | dez recusas dos atos da 055 chegam ao flash em português, e todas começam com o nome da coluna (`name: can't be blank`) — achado em 2026-09-10 ao ler o `flash-error` de cada caminho infeliz | média — é copy, não comportamento; o conteúdo das recusas está certo |
| [A versão em produção, e as novidades dela, na página](a-versao-em-producao-na-pagina.md) | a página tem de dizer que versão está no ar e o que a versão trouxe; hoje a aplicação **não sabe** a própria versão. Regra nova do papel ([#829](https://github.com/The-Band-Solution/theband/pull/829)) | **alta**, proposta de 2026-09-09 |
| [Entidades e CRUD](crud-entities.md) | como 220 conceitos viram ~94 entidades, e a ordem de construção | alta |
| [GitHub → SRO](github-to-sro.md) | ingestão do GitHub para a Scrum Reference Ontology, em fatias verticais | alta |
| [Papéis Scrum](papeis-scrum.md) | cadastro declarado e alocação de pessoas — o que o GitHub não expõe | alta |
| [Biblioteca de derivação](tooling-library.md) | extrair a transformação como biblioteca independente | **baixa** |
| [Setup inicial e a empresa com endereço próprio](setup-inicial-e-multiempresa.md) | o wizard que cria a empresa, conecta organizações do GitHub e dá a ela `<empresa>.theband.dev` | **alta** |
| [O projeto pertence a uma organização](projeto-pertence-a-organizacao.md) | o elo que falta entre projeto e organização, decidido em 2026-09-01, e a premissa da ontologia que ele vence | **alta** |
| [A organização do tenant, as organizações do GitHub, e o sign up](organizacao-do-tenant-e-sign-up.md) | separar a instituição que usa a plataforma da organização do GitHub que ela observa; a instituição nasce com a instalação, liga N organizações do GitHub, e o sign up cria as seguintes — spec [059](../../specs/059-organizacao-do-tenant/spec.md), rascunho com duas decisões em aberto | **alta — proposta de 2026-09-06, a confirmar na priorização** |
| [Português na interface](portugues-na-interface.md) | 23 ocorrências de português numa interface que serve em inglês — e o verificador que não as vê | média |
| [A tela da equipe: dashboard do gestor e estrutura](tela-da-equipe.md) | duas abas em `/teams/:id`; protótipo aprovado em 2026-09-07 com link e prompt; membros → subequipes → dashboard → fluxo — spec [060](../../specs/060-tela-da-equipe/spec.md) | **alta — foco de 2026-09-07** |
| [A tela da equipe complexa](tela-da-equipe-complexa.md) | os indicadores por subequipe sem soma, o foco da tela, e o defeito que a medida tem hoje ao ignorar o período do vínculo | **alta** |
| [O vínculo observado sem papel](vinculo-observado-sem-papel.md) | o que a regra `github.team_membership_evidence` precisa dizer na versão 2 — a participação observada vira vínculo com papel declaradamente ausente —, a razão ontológica, e o que mais na base a decisão de 2026-09-06 alcança | **alta — decidido em 2026-09-06; o YAML ainda é v1** |
| [O burn da pessoa parte de zero](burn-da-pessoa-sem-linha-de-base.md) | a página da pessoa mede o que nasceu na janela, e o rótulo diz trabalho em aberto | média — a pergunta precisa ser decidida antes do código |
| [A API pública com token](api-publica.md) | o primeiro contrato público do The Band: token gerado na área administrativa e mostrado uma única vez, `/api/v1` somente leitura com proveniência e limitações no mesmo objeto, e Swagger gerado do código — spec [061](../../specs/061-api-publica/spec.md), rascunho com oito perguntas abertas, três bloqueando o plano | **média — proposta de 2026-09-08, a confirmar na priorização** |
| [Um servidor MCP para os dados](servidor-mcp.md) | expor as respostas da plataforma a agentes de terceiros, com a proveniência junto | **desbloqueada em 2026-09-09** — a autenticação e o tenant foram decididos pela [spec 061](../../specs/061-api-publica/spec.md) e pela [ADR 0009](../adr/0009-api-publica-com-token.md); virou a [spec 062](../../specs/062-servidor-mcp/spec.md), que fica **atrás** da 061 por dependência real: o servidor é consumidor da API |
| [Decisões pendentes](decisoes-pendentes.md) | o que não pode ser implementado sem uma resposta humana — o quadro do Conecta Fapes, o conector do ArgoCD, a skill de humanização | **bloqueadas** |

## A fila de 2026-09-09 — o que consertar primeiro, e por quê

Ordenada pelo papel de Product Owner em 2026-09-09, **a confirmar pela pessoa alocada**. A
tabela acima diz a importância de cada item; esta diz a **ordem**, que é outra pergunta —
importância alta e bloqueio em recurso alheio não produzem a mesma posição na fila.

**Recorte declarado**: o papel de Security entregou
[`docs/seguranca/2026-09-09-o-que-consertar-agora.md`](../seguranca/2026-09-09-o-que-consertar-agora.md)
enquanto esta fila era escrita — dezesseis achados, **H1 a H16**, com H1, H2 e H3 em severidade
**Alta** e **medidos com teste**. A fila abaixo já os incorpora, e **foi reordenada por causa
deles**: a primeira versão dela, escrita antes do documento chegar, punha a cronometragem da
US3 em primeiro lugar. Deixou de fazer sentido — item barato não vence risco medido em
produção.

**A severidade é do papel de Security; a prioridade é deste papel.** As duas coisas são
distintas, e o documento é explícito ao dizer que H1, H2 e H3 são **recomendação** de bloqueio
da próxima release, não bloqueio declarado. **Assumo a recomendação**: os três entram à frente
de qualquer funcionalidade nova, e a razão está na coluna de posição.

### O que a v0.7.0 fechou, e o que a fila abaixo passa a ser

**Escrito em 2026-09-09T23:19Z, depois de derivar os vereditos em
[`docs/releases/v0.7.0.md`](../releases/v0.7.0.md).** A fila que vem a seguir foi escrita mais
cedo no mesmo dia e **continua abaixo como estava** — não a reescrevo, corrijo-a aqui, que é
como esta casa trata registro que envelheceu.

| Item da fila | O que aconteceu |
|---|---|
| **1 — H1** | **fechado e ACEITO** ([#835](https://github.com/The-Band-Solution/theband/pull/835)) |
| **2 — H3** | **parte A fechada e ACEITA** ([#837](https://github.com/The-Band-Solution/theband/pull/837)); **parte B fechada e NÃO ACEITA** ([#844](https://github.com/The-Band-Solution/theband/pull/844)) — ver [a conta desativada](conta-desativada.md) |
| **3 — H2** | **decidido e fechado, ACEITO** ([#838](https://github.com/The-Band-Solution/theband/pull/838), [#845](https://github.com/The-Band-Solution/theband/pull/845)). A decisão **D-d** virou a **FR-024** da spec 045, e a resposta foi mais fina que a recomendação: **três naturezas**, e só o *agregado* segue o veredito |
| **4 — a versão na página** | **não feito**, e **dispensado para a v0.7.0** com o custo declarado. **Pré-condição da v0.8.0** — ver o item |
| **5 — cronometrar a US3** | **não feito.** A 060/US3 continua `sro.not_accepted_deliverable`, pela segunda release |
| **6 — H7 e H8** | **não feitos.** Continuam sendo os dois que se consertam **sem release**, e por isso não há razão para esperar por uma |
| **7 — SC-004 e SC-005** | **não feitos**, pela quarta release. Continuam recuperáveis **agora** |
| **8 — H4 e H5** | **H4 fechado e NÃO ACEITO** ([#849](https://github.com/The-Band-Solution/theband/pull/849)) — cinco dos oito eventos continuam sem registro, e **duas funções foram escritas e nunca chamadas**. **H5 não feito** |
| **9 — os pedidos de revisão** | **não feito, e piorou**: os 21 PRs da v0.7.0 nasceram **todos** sem revisor pedido. São 27 PRs a recuperar |
| **10 a 14** | inalterados |

**Três itens novos, e os três nascem de recusa de aceitação:**

| # | O quê | Fecha com | Por que está alto |
|---|---|---|---|
| **N1** | **os três registros do H6** — o `@moduledoc` de `access.ex` ainda diz *"nenhum ramo aqui olha `users.role`"* e `pode_ver/3` passou a olhar; a **FR-012j** da spec 023 continua sem marca; e a **US2** da spec 045 ainda afirma *"ser administrador não abre painel nenhum"* | **três edições de texto**, nenhuma linha de código | o achado H6 **era** a divergência entre o que a plataforma afirma e o que aplica. O conserto mudou o código e deixou a afirmação, e a contradição **aumentou**: antes uma função desmentia o cabeçalho, agora duas |
| **N2** | **as duas chamadas que faltam ao H4** — `AccessEvents.painel_recusado/4` e `espera_acionada/3` existem, estão documentadas e **não têm nenhum chamador** | chamar em `Access.pode_ver/3` no ramo `{:nao, motivo}` e em `Auth` no ramo `{:throttled, s}` | a **FR-024** apoia a mitigação do risco de agregação no H4. Com `painel_recusado/4` órfã, **o H4 não existe para o efeito de que a FR precisava**. E função escrita sem chamador é pior que ausente: quem fizer `grep` conclui que está registrado |
| **N3** | **o que falta à conta desativada** — a razão em desativar **e** em reativar, o ator na reativação, o teste de que roster e medidas não mudam, o texto do *revoke* dizendo que **não remove acesso**, e o **protótipo** da superfície de `/accounts` | ver [a conta desativada](conta-desativada.md) | está **em produção sem aceitação**, com migração de esquema, tela sem protótipo e quatro decisões de produto tomadas pelo código |
| **N4** | **`/deps/` no `.gitignore` não ignora um link simbólico chamado `deps`** — padrão terminado em barra só casa com **diretório**, e `git check-ignore -v deps` sai com **1** | trocar `/deps/` por `/deps` — **uma linha** | é o mecanismo pelo qual o **H12** nasceu, e ele continua de pé: a entrada sai do índice, mas nada impede um `git add -A` de a repor. O gate do #836 **pega** — depois, no `mix gates`, e não no `git add`. Prioridade **média**: há defesa, e ela é de segunda linha |

**A decisão D-e foi tomada, e contra a recomendação deste papel.** Eu recomendava *"não
concede, e corrige-se o ramo em vez do cabeçalho"*; a pessoa mantenedora escolheu **conceder**,
e a razão dela é melhor que a minha: `pode_ver_equipe/3` já concedia, o booleano dela libera a
quebra por pessoa nomeada, e portanto **administração já lia pessoa nomeada pela porta ao
lado** — enquanto a tela da pessoa recusava afirmando o contrário. Retirar a cláusula faria a
administração perder o que hoje usa. Registro a divergência e a razão em vez de reescrever a
recomendação como se eu sempre tivesse dito isso.

### O que decidi sobre a próxima release

> **Cumprido, e com uma ressalva.** Os três altos foram fechados **como código** na v0.7.0.
> O **H3-B não foi aceito**, e embarca como exceção declarada em
> [`docs/releases/v0.7.0.md`](../releases/v0.7.0.md) — que é o registro que esta decisão exigia.

**A v0.7.0 não sai com H1, H2 e H3 abertos.** Não é bloqueio herdado de outro papel — é decisão
deste, e a razão é uma só: os três têm caminho de exploração **medido** contra o código que está
em produção agora, com dado real de uma organização. Liberar com eles abertos exigiria
registrá-los como risco residual aceito em `docs/releases/v0.7.0.md`, com quem decidiu e por
quê, e eu não tenho argumento que sustente essa aceitação — ao contrário da exceção do
`decimal`, que tinha severidade baixa e nenhum caminho de exploração.

| # | O quê | Natureza da pendência | Fecha com | Posição, e por quê |
|---|---|---|---|---|
| **1** | **[H1](../seguranca/2026-09-09-o-que-consertar-agora.md) — `/set-password` troca a senha sem exigir a atual** | defeito, **medido** | uma cláusula em `session_controller.ex` | primeiro porque é o **mais barato dos altos** e o de consequência mais direta: quem alcança uma sessão por minutos converte-a em posse permanente da conta e expulsa a pessoa legítima. E a outra porta (`/profile/password`) **já faz certo** — não é controle a inventar, é controle que falta numa segunda porta |
| **2** | **[H3](../seguranca/2026-09-09-o-que-consertar-agora.md) — [a conta desativada](conta-desativada.md), em três partes** | defeito + trabalho, **medido** | ato próprio de desligar, `tenants.status` lido, e o texto de *revoke link* dizendo a verdade | o ato que a tela oferece para desligar alguém **não desliga** — medido. Quem sai continua entrando. A parte A não tem migração e fecha metade; a parte B é uma leitura que não existe. Ver o item para as três partes |
| **3** | **[H2](../seguranca/2026-09-09-o-que-consertar-agora.md) — o veredito de acesso vale em 2 de 24 rotas** | defeito, **medido** — e **espera decisão** | resposta da pessoa mantenedora, **depois** código | maior em alcance que os dois acima e **não é o primeiro**, porque *"qualquer código escrito ali é palpite"* sem a decisão de escopo. Pôr trabalho antes da resposta é o que produz retrabalho. A decisão é a **D-d** abaixo, e é a mais urgente das quatro |
| **4** | **[a versão e as novidades na página](a-versao-em-producao-na-pagina.md)** | trabalho, desbloqueado | a aplicação ler a própria versão + a superfície | primeira coisa não-segurança da fila. A regra passou a valer e a v0.6.0 subiu sem ela; enquanto não existir, **toda** release seguinte nasce em falta com a definição do papel. E fecha o [H7](../seguranca/2026-09-09-o-que-consertar-agora.md) pela raiz — hoje não há como dizer qual imagem está rodando |
| **5** | **cronometrar a US3** — registrar uma saída, do clique ao resultado | medida que falta | **um relógio, uma vez** | o mais barato do backlog inteiro, e destrava duas coisas: a aceitação da US3 e a linha dela na página de novidades. Só não é primeiro porque não é risco |
| **6** | **[H7](../seguranca/2026-09-09-o-que-consertar-agora.md) e [H8](../seguranca/2026-09-09-o-que-consertar-agora.md)** — `latest` no Dokploy, e ações de CI/CD por tag móvel | defeito | **os dois sem release** | agrupados porque são os dois que o documento marca como consertáveis **sem release**: entram sem esperar fila. O H8 é o mais desconfortável — um terceiro executa código com a credencial de publicação da produção |
| **7** | **as duas medidas do runbook §7 que não dependem do instante** — SC-004 (segredos na imagem e nos logs) e SC-005 (rotas recusam sem sessão) | medida que falta | rodar sobre a imagem publicada | recuperáveis **agora**, sem esperar release. Ficaram três releases à espera de um "momento do merge" que não é necessário para estas duas. A SC-005 tem sobreposição direta com o H2 — medir uma informa a outra |
| **8** | **[H4](../seguranca/2026-09-09-o-que-consertar-agora.md) e [H5](../seguranca/2026-09-09-o-que-consertar-agora.md)** — nenhum evento de acesso registrado; sessão encerrada serve no LiveView conectado | defeito | código | o H4 tem uma propriedade que o torna urgente apesar da severidade média: **se H1, H2 ou H3 já foram explorados desde a v0.6.0, não há como saber**. Ele não conserta o passado, e é o que permite responder no futuro |
| **9** | **a revisão dos PRs mergeados sem pedido** — #822, #824 a #828 | pendência de registro, **recuperável** | uma chamada de API por PR | subiu de "resíduo permanente" porque acabou de se descobrir que **é** recuperável: pedir revisão de PR mergeado funciona, provado no #823. Alcança também o **#89**, aberto desde a feature 001 |
| **10** | **as tarefas da US6, US7 e US8 da 060** | decomposição que falta | `/speckit-tasks` sobre as três | **US7 e US8 já têm código em produção sem tarefa alguma** — escopo que entrou sem planejamento (`sro.rule01`). São as únicas da fila em que o trabalho está adiantado em relação ao registro, e é o registro que precisa alcançar |
| **11** | **a republicação do protótipo do cartão de subequipe** | decisão tomada, registro pendente | Design republicar nos três arquivos | as sete mudanças foram decididas em 2026-09-09 com o dado real medido; o endereço aprovado ainda serve o cartão de 2026-09-07. A régua do QA está no lugar errado |
| **12** | **[H10](../seguranca/2026-09-09-o-que-consertar-agora.md) a [H16](../seguranca/2026-09-09-o-que-consertar-agora.md)** — os de severidade baixa | defeito e endurecimento | código, cada um pequeno | ficam juntos e depois porque nenhum tem caminho de exploração hoje. **Exceção: o H12** (`deps` commitada como link simbólico para si mesma) sobe se a `main` for alcançada — quebra a reprodutibilidade da build, e está no `git status` desta árvore agora |
| **13** | **[a 061 — a API pública](api-publica.md)** | **bloqueada no Design** | protótipo da tela de tokens, aprovado | US1 e US3 não se decompõem sem protótipo. A US2, a US4 e a US5 não têm tela e podem começar antes — é por elas que a 061 avança enquanto o protótipo não vem. E o H3 resolvido **antes** dela é o que evita publicar a limitação da FR-074 no primeiro contrato público do produto |
| **14** | **[o backup restaurado de verdade](backup-restaurado-de-verdade.md)** — 050/US2 | **bloqueada em recurso** | a pessoa mantenedora criar a conta no S3 | **importância altíssima e a última posição**, e a contradição é só aparente: nenhuma quantidade de trabalho a fecha. Não aceita desde a v0.1.0, por cinco releases. Não é despriorizada — é **bloqueada**, e as duas coisas aparecem iguais numa lista ordenada, que é por isso que a coluna de natureza existe |

**"Despriorizado" não é "resolvido"**, e a formulação é do próprio documento de segurança.
Nenhum achado desta fila fecha por ter descido de posição: fica **aberto** até ser corrigido ou
explicitamente aceito, com quem aceitou e por quê.

### As decisões que a fila espera, e que não são trabalho

Nenhuma destas fecha com esforço. Esperam **escolha**, e por isso não têm posição na fila
acima — estão aqui para serem levadas à pessoa mantenedora. As três primeiras vêm do documento
de segurança e **estão no caminho crítico**: sem elas, o código que as implementaria é palpite.

| # | Decisão | Recomendação deste papel |
|---|---|---|
| **D-d** | **H2 — o regime da FR-012 vale para todo dado nominal de pessoa, ou só para as medidas da aba?** É a que bloqueia o item 3 da fila, e alcança 22 rotas | **para todo dado nominal**, e a razão é o caso que o documento nomeia: `/work/verifications/people` chama-se *"Who merged red"* e é um **ranking nominal** aberto a qualquer conta do tenant. Se o regime protege a vazão de uma pessoa, não há leitura em que deixe de proteger quem integrou vermelho. Escopo menor precisa de argumento, e eu não achei nenhum |
| **D-e** | **H6 — administrar concede visão de equipe, sim ou não?** Hoje `pode_ver_equipe/3` concede por `users.role`, contra o cabeçalho do próprio módulo | **não concede**, e corrige-se o ramo em vez do cabeçalho. `MAINTAINER` foi retirado da tela da equipe nesta release exactamente por confundir nível de acesso com papel; conceder visão de equipe por `users.role` é o mesmo equívoco um nível abaixo. Mas é decisão da pessoa mantenedora, e ela **desbloqueia a spec da API** |
| **D-f** | **H9 — a base roda no mesmo host da aplicação?** É pergunta para quem opera, e é anterior ao conserto | **sem recomendação** — não tenho o dado e não vou inferi-lo. A resposta é o que define a severidade do `ssl: true` comentado, e inventá-la seria declarar limitação sem olhar o dado |
| **D-a** | ***Skills* e *Process warnings* estão na tela e não no protótipo.** A [060](../../specs/060-tela-da-equipe/spec.md) manda-as *"permanecer no Dashboard como estão"* (FR-046) e o protótipo aprovado não as desenha — o de estrutura só cobre as habilidades **dentro do perfil da pessoa** | **o protótipo absorve as duas, como estão.** *"Como estão"* não é especificação: é um apontador para a implementação, o que faz a implementação ser a própria régua — a inversão que este papel existe para impedir. Uma régua com buracos é uma régua que não pode recusar |
| **D-b** | **a ordem das duas medidas no cartão de subequipe** — `open items · median wait` ou o inverso | **`open items · median wait`**, a mesma ordem da tabela. Endosso a recomendação do Design: ordens diferentes obrigam quem compara as duas apresentações a reordenar de cabeça |
| **D-c** | **onde vive `MAINTAINER`.** Saiu da tela da equipe na v0.6.0 — corretamente, porque nível de acesso não é papel — e não entrou em nenhuma outra. O dado continua gravado, sem consumidor visível | **declarar que não se mostra ao lado de papel**, e decidir se aparece na administração de acesso. O que não pode é ficar coletado e sem destino: dado sem consumidor é coleta que ninguém sabe se está certa |

## Dívidas e defeitos com issue aberta

Levantados ao fechar o sprint 005. Nenhum tem iteration: entram quando forem priorizados.

| Issue | Tipo | O que é | Por que ainda não foi feito |
|---|---|---|---|
| [#175](https://github.com/The-Band-Solution/theband/issues/175) | defeito | job `discarded` deixa o `sync` em `running` e bloqueia toda coleta da ferramenta | só há saída por SQL; a 005 aumenta a exposição ao acrescentar recálculo assíncrono |
| [#176](https://github.com/The-Band-Solution/theband/issues/176) | processo | sprints 003, 004 e 005 sem iteração no Projects v2 | configurar iterations recria as existentes — L11, 96 itens reatribuídos |
| [#177](https://github.com/The-Band-Solution/theband/issues/177) | dívida | validador Elixir faz 4 verificações; o Python faz 12 | declarada desde o sprint 002 |
| [#178](https://github.com/The-Band-Solution/theband/issues/178) | dívida | `connected_tools.status` materializa situação, contra a ADR 0004 D7 | declarada e **não ampliada** desde a feature 002 |
| [#179](https://github.com/The-Band-Solution/theband/issues/179) | escopo | comentários e timeline das issues | multiplicaria o consumo da origem por issue |
| [#180](https://github.com/The-Band-Solution/theband/issues/180) | escopo | campo de quadro → atributo da ontologia | depende de coletar quadros como entidade |
| [#181](https://github.com/The-Band-Solution/theband/issues/181) | escopo | quadros, campos e iterações do Projects v2 | fase F4 da feature 004, fora do MVP entregue |

Herança anterior, ainda sem iteration: [#81](https://github.com/The-Band-Solution/theband/issues/81), [#82](https://github.com/The-Band-Solution/theband/issues/82) (feature 002),
[#98](https://github.com/The-Band-Solution/theband/issues/98) a [#100](https://github.com/The-Band-Solution/theband/issues/100) (papéis Scrum), [#104](https://github.com/The-Band-Solution/theband/issues/104) (ajustar ferramenta
conectada), [#107](https://github.com/The-Band-Solution/theband/issues/107) e [#108](https://github.com/The-Band-Solution/theband/issues/108) (quadros e escopo de repositórios).

## Como isto se relaciona com o resto

O backlog diz **o que**. As decisões que o sustentam estão em
[ADRs](../adr/README.md), e o que ainda não foi decidido está em
[RFCs](../rfc/README.md).

Um item de backlog que dependa de questão aberta traz a referência explícita —
começar por ele antes da questão ser resolvida costuma significar refazer.

## Estado

| Área | Situação |
|---|---|
| Base de conhecimento | 12 ontologias, 220 conceitos, validada |
| Classificação OntoUML | 4 de 12 ontologias — EO, SPO, CMPO e SRO |
| Modelo de informação | derivável para as 4 classificadas, e reprodutível no CI |
| Especificação | 001 a 006 completas — ciclo Spec Kit inteiro em cada uma |
| Aplicação Elixir | features 001 a 004 entregues; 006 aguardando revisão — **250 testes** |
| Dado real coletado | 4471 issues, 135 repositórios, duas organizações, 22 877 promoções |
| Promoção a conceito | **1020 de 4471** — os outros 77% são o que a feature 005 resolve |
