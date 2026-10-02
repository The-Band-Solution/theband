# Avaliação de segurança — o aviso de fila parada em `/syncs` (issue #801, parte 3)

| | |
|---|---|
| papel | Security (`AGENTS.md` §13, §14.0), **antes do código** |
| quem desenhou | Design, em `README.md` e `PROMPT.md` desta pasta. Esta avaliação **não** é de quem desenhou |
| data | 2026-10-01 |
| base lida | `origin/development` em `44fcc3d`, mais o rascunho do §11 de `docs/producao/runbook.md`, ainda não commitado no worktree `fix/801-tela-fila-parada` |
| tipo de trabalho | leitura do desenho e do código que ele toca. Não é varredura da superfície inteira, e nada foi executado contra banco ou produção |

## O que muda na superfície

Hoje o estado da fila aparece em **um** lugar, `GET /health`, que é anônimo e diz só `ok` ou
`queue stalled` (`lib/the_band_web/controllers/saude_controller.ex:16-24`). A tela passa a mostrar a
quem tem acesso operacional (`lib/the_band_web/router.ex:264-267`, `require_operacao` no pipeline
**e** no `on_mount`, `lib/the_band_web/live/hooks.ex:72-92`) três coisas novas: **durações**,
**horários absolutos** (último job completado, job esperando mais antigo, hora da conferência) e a
**pausa** de Sync e Reprocess. A fonte é `oban_jobs`, uma tabela **global**: os jobs de todos os
tenants e os do `Cron`, que não têm tenant (`config/config.exs:105-107`).

## Achados

| # | achado | OWASP / ASVS | severidade | bloqueante do código? |
|---|---|---|---|---|
| S1 | falso positivo por saturação da fila `ingestion` faz o veredito dizer "parada" com a fila trabalhando, e o desenho transforma isso em pausa de Sync para **todos** os tenants e em ordem de reiniciar | A04 desenho inseguro (disponibilidade entre tenants); ASVS V1.1, V11.1 (lógica de negócio) | **Média** | **Sim**, para Q2 = A e para o item 1 de *What you can do* |
| S2 | o horário absoluto do último job completado, no estado normal, é canal lateral sobre a atividade de outros tenants | A01 (isolamento entre tenants, canal lateral); ASVS V1.4, V8.3 | **Baixa** | Não. Decisão barata antes do código (pergunta P-1) |
| S3 | a leitura nova é exceção declarada ao princípio V e precisa nascer assim: sem filtro de tenant e sem devolver linha, `args`, worker ou fila | A01; ASVS V4.1, V8.3 | **Média** (de desenho: a garantia some no primeiro refactor se não estiver no contrato e no teste) | **Sim**: o contrato e o teste de não exposição antes da função |
| S4 | o timer de 60 s multiplicado por `load/1`, e `load/1` faz escrita global | A04; ASVS V11.1 (anti-automação e limites) | **Baixa**, que vira **Média** se o timer for armado em `load/1` | Sim, a regra do timer entra no contrato |
| S5 | a pausa de Sync e Reprocess é só o atributo `disabled` | A04; ASVS V11.1 | **Informativo** | Não. Declarar que é conveniência, não controle |
| S6 | o runbook manda "Redeploy" como alternativa a "Restart" | A08 integridade (o que se implanta) | **Baixa** | Não, mas o texto do runbook se corrige na mesma entrega |
| S7 | dado real de uma organização no protótipo, num repositório público | A01 / exposição de dado (ASVS V8.3) | **Baixa** | Não |
| S8 | veredito global mascara uma fila específica parada (falso negativo) | A09 monitoramento | **Informativo** | Não |

Nenhum achado **alto**. Nenhum dado de um tenant fica alcançável por outro com D3 como escrito;
S2 é o resíduo, e é tempo, não conteúdo.

### S1 — falso positivo por saturação: a pausa e o reinício viram arma contra outros tenants

**O que é.** O veredito de `TheBand.Saude.fila/2` é "nenhum job completou em 15 min"
(`lib/the_band/saude.ex:30-48`). Os dois jobs do `Cron` que garantem uma conclusão a cada 5 min,
`ReconcileStuckSyncs` e `ScheduleDueSyncs`, estão na fila **`ingestion`**
(`lib/the_band/jobs/reconcile_stuck_syncs.ex:27`, `lib/the_band/jobs/schedule_due_syncs.ex:23`),
a mesma da coleta, que tem **5 vagas** (`config/config.exs:96`). E uma coleta é **um** `perform` só
(`lib/the_band/jobs/sync_github_eo.ex:23,52`), que dura horas: a execução de 2026-09-28 no
desenvolvimento foi de 12:49 a 15:03 (`README.md` desta pasta), e só devolve a vaga em `snooze` por
cota ou no fim.

**O caminho.** Cinco coletas simultâneas de 15 min ou mais ocupam as 5 vagas. Os dois jobs do
`Cron` ficam `available`, nada completa, e em 15 min `fila/2` diz `{:parada, _}` **com a fila
trabalhando**. Quem provoca isso não precisa de nada além do acesso legítimo: um operador de
**um** tenant com cinco ferramentas apertando Sync em cada uma, ou cinco tenants com intervalo
vencido no mesmo ciclo de `ScheduleDueSyncs`. Daí:

1. com Q2 = A, **Sync e Reprocess ficam pausados na tela de todos os tenants** (a pausa decorre do
   estado global);
2. o aviso manda reiniciar o contêiner, e reiniciar **interrompe as cinco coletas legítimas**;
3. o healthcheck do PR #1029 já marca `unhealthy` pela mesma regra
   (`docs/producao/saude-da-fila.md:43-51`). Se o orquestrador reiniciar sozinho (não medido, P2),
   coletas longas podem nunca terminar: cada uma volta a encher as vagas e o ciclo se repete.

A parte 3 deste item é **anterior** a esta tela, e é do #1029. A tela a amplifica: dá a ordem de
reiniciar a quem pode, e pausa quem não pode.

**Consequência para o negócio.** O operador de uma organização grande, sem fazer nada errado,
pausa a coleta de todas as outras organizações da instalação e faz o aviso pedir um reinício que
derruba o trabalho de todo mundo.

**O que não verifiquei.** Não medi a saturação. Não sei quantas ferramentas e tenants há em
produção nem quantas coletas costumam se sobrepor. Não sei se outros jobs, como `RecomputePromotions`
em `transformation` ou o que a coleta enfileira, completariam durante a saturação e salvariam o
veredito: pela leitura, nada garante que completem. O caminho vem **do código**, não de medição.

**O que fecha (recomendação).** Tirar os dois jobs do `Cron` da fila da coleta: uma fila própria
de manutenção, com 1 vaga. Assim "nenhum completou em 15 min" volta a significar o que o contrato
diz, que o Oban não está processando, e não que a coleta está ocupada. A mudança é pequena, em
`config/config.exs` e nos dois workers, e preserva o porquê dos 15 min em
`docs/producao/saude-da-fila.md:22-25`. Quem decide a forma é o Architect. A alternativa mais
fraca, se a fila própria não entrar agora: Q2 = **B** (botões habilitados, com o aviso) e o item 1
de *What you can do* passa a mandar conferir antes se há coleta longa em `executing`.

**Cenário de ataque para o QA (o teste ANTES da correção).**

- *Guarda estrutural*: os workers do `Cron` não estão na fila de `SyncGitHubEO`. Asserção:
  `TheBand.Jobs.ReconcileStuckSyncs.__opts__()[:queue]` e a de `ScheduleDueSyncs` são diferentes de
  `TheBand.Jobs.SyncGitHubEO.__opts__()[:queue]`. **Defeito a injetar**: voltar um deles para
  `:ingestion`. O teste tem de reprovar.
- *Guarda de comportamento*: com dois tenants povoados e cinco jobs `SyncGitHubEO` em `executing`
  com `attempted_at` 20 min antes, nenhum completado na fila de coleta e um job de manutenção
  completado 3 min antes, `fila/2` devolve `:ok` e a tela do tenant **B** mostra Sync
  **habilitado**. Antes da correção, esse mesmo cenário sem o completado de manutenção (que é o que
  a saturação produz hoje) devolve `{:parada, _}`. O teste prova o defeito.

**Se não entrar agora.** O defeito já existe no healthcheck. Com a tela, ele ganha um botão
desabilitado em todo tenant e uma instrução de reiniciar.

### S2 — o horário do último job é de qualquer tenant

**O que é.** No estado normal, o valor de `max(completed_at)` muda a cada 5 min pelo `Cron`, que é
de todos. **Entre** dois ciclos, ele só muda quando outro job completa: uma coleta que termina
(`SyncGitHubEO`, um job por coleta), um `ReprocessMappings`, uma geração de perfil
(`lib/the_band/profiles/generate_worker.ex:18`). A linha discreta de Q1, com `at <HH:MM UTC>` e
reconferida a cada 60 s, dá a quem olha **o minuto em que algum trabalho da instalação terminou**.
Se o observador sabe que não foi ele, sabe que foi de outro tenant ou da instalação.

**Severidade baixa, e por quê.** Não diz qual tenant, nem quantos, nem o quê. O atacante é um
operador autenticado de um tenant. O que ele obtém é o ritmo de atividade dos vizinhos, com
resolução de minuto, numa instalação onde saiba quantos tenants existem. É canal lateral real e
de valor baixo. **Não medi** quantos tenants há em produção: com dois, a atribuição é quase
direta.

**Com a fila parada**, o horário fica congelado no último job antes da parada. Diz quando a
instalação parou, que é fato da instalação, e é o dado que o operador precisa repassar a quem
reinicia. Ali o valor é legítimo e o resíduo é aceitável.

**Recomendação.**

- **estado normal**: só o veredito e a hora da conferência. `Job queue moving · checked HH:MM:SS
  UTC`. Isso basta para a razão de Q1 ("sem aviso" ≠ "a conferência não rodou"), e o horário do
  último job sai;
- **fila parada**: duração em minutos inteiros e o horário absoluto do último completado, como
  em D1 e D6. Arredondar para baixo ao múltiplo de 5 min seria endurecimento adicional, mas
  atrapalha o operador e não recomendo;
- **tela 3** (nunca completou): o `min(scheduled_at)` de `available` também é de qualquer tenant.
  Só existe em instalação que nunca rodou, e aceito como está.

**Cenário para o QA.** Dois tenants povoados; o último job completado é de B, com `args.tenant_id`
de B e worker `TheBand.Profiles.GenerateWorker`, 2 min antes. A tela de A em estado normal:
`refute` o horário desse job no HTML, `refute` o id e o nome do tenant B, `refute` o nome do
worker. `assert` o veredito `moving` e a hora da conferência, para provar que a linha foi
desenhada. **Defeito a injetar**: renderizar `at <HH:MM>` do último completado. O `refute` do
horário tem de reprovar.

### S3 — a leitura nova é exceção ao princípio V, e precisa ser escrita como exceção

**A pergunta: filtrar por tenant?** **Não**, e a razão é de semântica, não de conveniência. Os
jobs de tenant carregam `args.tenant_id` (`lib/the_band/jobs/sync_github_eo.ex:52`), mas os do
`Cron` não têm tenant, e são justamente eles que garantem a conclusão a cada 5 min. Filtrar por
tenant faria todo tenant sem coleta nos últimos 15 min ver "parada": falso positivo permanente.
O estado da fila é **da instalação** (do nó Oban), e não do tenant, como `fila/2` já é.

**Quem pode ver.** O veredito já é público em `/health`, que é anônimo. Mostrá-lo a quem tem
`require_operacao` não expõe nada novo. O que é novo são os tempos, e S2 trata deles. A
`live_session :operacao` está certa: pipeline e `on_mount`, as duas metades.

**O que tem de valer, e onde.** Como é uma consulta de domínio **sem** tenant, ela só é aceitável
se for **agregado escalar**:

- a função nova devolve, no máximo, `{veredito, base, desde :: NaiveDateTime | nil, agora}`, onde
  `base` diz qual dos dois casos é (`:ultimo_completado` | `:esperando_mais_antigo` | `:sem_historico`).
  Nunca linhas, `args`, `worker`, `queue`, `id` de job ou contagem;
- o contrato, ao lado de `docs/producao/saude-da-fila.md`, declara a exceção ao princípio V com a
  razão acima, **e o que não expõe**;
- o `@moduledoc` repete a exceção, para quem tocar `saude.ex` depois.

**Cenário para o QA.** Teste de unidade da função nova: o retorno casa com o tipo declarado e
`refute` qualquer chave ou valor que seja `args`, `worker`, `tenant_id` ou inteiro de contagem. Com
dois tenants povoados e jobs de ambos, o retorno é **o mesmo** chamado pela tela de A e pela de B.
**Defeito a injetar**: acrescentar `worker` ao `select`. O teste tem de reprovar.

### S4 — o timer: custo baixo, se armado no lugar certo

**O custo, como desenhado.** Duas consultas por aba por minuto, sobre `oban_jobs` podada em 7 dias
(`config/config.exs:98`). Mil abas de um usuário dão uns 33 `SELECT` agregados por segundo, menos
que o próprio `mount` dessas abas custa. **Não é vetor de DoS que valha medida específica**. E
`/health` já roda as mesmas duas consultas por requisição, **anônima e sem limite de taxa**, que é
a superfície maior, anterior a esta tela e fora deste escopo.

**O risco real é o lugar do timer.** `load/1` é chamado em 10 pontos de `index.ex`, inclusive a cada
`{:sync_finished, _}`. E ele roda `Ingestion.reconcile_stuck_syncs()`, uma **escrita global, sem
tenant** (`lib/the_band_web/live/sync_live/index.ex:670-679`). Duas formas erradas, e as duas são
fáceis de cometer:

1. `Process.send_after` dentro de `load/1`: cada evento arma mais um timer, e as consultas por aba
   crescem sem limite;
2. o `handle_info` do timer chamando `load/1`: cada aba aberta passa a reconciliar as execuções
   **de todos os tenants** a cada minuto.

**Recomendação para o contrato.** O timer é armado **uma vez**, em `mount/3` sob `connected?/1`, e
rearmado **só** no próprio `handle_info`. O `handle_info` chama **só** a função de leitura nova,
nunca `load/1`. Nada de log por conferência: com N abas, seria N linhas por minuto. Logar só na
**transição** de veredito é opcional e cabe na decisão de observabilidade.

**Cenário para o QA.** Com a LiveView montada, enviar 20 `{:sync_finished, id}` e então
contar, por telemetria do `Repo` numa janela de 60 s com o relógio controlado, as consultas a
`oban_jobs` vindas da conferência: exatamente 2. E nenhuma chamada a `reconcile_stuck_syncs` vinda
do timer. **Defeito a injetar**: mover o `send_after` para `load/1`. A contagem tem de reprovar.

### S5 — a pausa é conveniência, não controle

`handle_event("sync", …)` e `handle_event("reprocess", …)` não conferem nada da fila
(`lib/the_band_web/live/sync_live/index.ex:82-117,155-170`). Um evento `phx-click` forjado passa
pelo `disabled`. **Não é vulnerabilidade**: o efeito é sobre o próprio tenant (mais um `running`
que não anda) e `start_sync` já impede duas por ferramenta (`lib/the_band/ingestion.ex:105`).
**Recomendação**: a spec declara Q2 como orientação de tela, e **não** coloca a fila dentro de
`Ingestion.start_sync`. Fazer isso ligaria a regra de domínio ao veredito global e transformaria o
falso positivo de S1 numa recusa de verdade, inclusive para `ScheduleDueSyncs`. Sem teste
específico.

### S6 — o runbook: o texto não induz SQL, mas oferece "Redeploy"

O rascunho do §11 do runbook já diz **"Não altere `oban_jobs` por SQL"**, com o motivo. O aviso
da tela não sugere comando nenhum. As duas coisas estão certas, e o ponto 5 da avaliação está
atendido.

Três correções ao texto, na mesma entrega:

1. **§11.2 passo 2 oferece *Redeploy* ou *Restart*.** Redeploy puxa de novo a imagem configurada.
   Se o Dokploy aponta para `latest`, o reinício pode trocar de versão sem PR, e `latest` é
   apontador, nunca identidade (A08). Para fila parada, só **Restart**. Não verifiquei qual tag o
   Dokploy usa;
2. **antes de reiniciar, conferir se há coleta longa em `executing`**, enquanto S1 não for fechado:
   reiniciar interrompe todas;
3. **§11.1 diz que "a coleta continua de onde parou quando a fila voltar"**, e o §11.2 passo 4 diz
   que a reconciliação **encerra** as execuções presas. As duas coisas são diferentes: o checkpoint
   se preserva, mas a continuação exige uma coleta nova. Não é de segurança, mas é texto que
   orienta ação, e o aviso da tela tem a mesma frase (*Nothing collected so far is lost*), que está
   correta e não promete retomada.

### S7 — dado real no protótipo, em repositório público

O repositório é **público** (`gh repo view`: `PUBLIC`). O `README.md` e o `syncs-queue-stalled.html`
desta pasta trazem o login da organização (`example-org`) e os números da coleta real (1 240
coletados, 601 criados, contagem por worker). O login é de organização pública no GitHub, e os
números são agregados. Baixa. **Recomendação**: manter o login, se a pessoa mantenedora considerar
a organização pública, e trocar as contagens da execução por `example` ou arredondá-las. Ou então
declarar no README que a exposição foi aceita.

### S8 — o veredito é global e mascara uma fila parada específica

`fila/2` olha `completed` em **qualquer** fila. Se `ingestion` parar e `transformation` continuar
completando (um `ReprocessMappings` de qualquer tenant), o aviso diz *moving* com a coleta parada.
Um tenant pode, sem querer, esconder a parada dos outros. É limitação de monitoramento, não
exposição. Fica registrada para a medida `operation.queue.stalled`, que deve declarar o que **não**
cobre.

## Bloqueantes do código

1. **S1**: não implementar Q2 = A nem o item "Restart" do aviso sobre o veredito atual sem
   (a) tirar os jobs do `Cron` da fila `ingestion`, com a guarda estrutural vista reprovando com o
   defeito injetado; **ou** (b) adotar Q2 = B e a conferência de coleta longa no texto, declarando
   S1 como risco aberto na issue #801.
2. **S3**: o contrato da função de leitura nova existe antes dela, declara a exceção ao princípio V
   e o que ela **não** devolve. O teste de não exposição com dois tenants é visto reprovando com
   `worker` injetado.
3. **S4**: o mesmo contrato fixa onde o timer é armado e que o `handle_info` não chama `load/1`.

## Perguntas fechadas para a pessoa mantenedora

| | pergunta | opções | recomendação |
|---|---|---|---|
| P-1 | No estado normal, a linha discreta mostra o horário do último job? | A. só veredito + hora da conferência · B. como no protótipo, com `last job finished … at HH:MM` | **A**: fecha S2 sem perder a razão de Q1 |
| P-2 | Como fechar o falso positivo por saturação (S1)? | A. fila própria para os jobs do `Cron`, nesta entrega · B. Q2 = B (botões habilitados com aviso) e S1 aberto · C. aceitar S1 como risco residual | **A**: é a correção de raiz e corrige também o healthcheck do #1029 |
| P-3 | O protótipo publica números reais da coleta de uma organização num repositório público. Manter? | A. trocar as contagens por `example` · B. manter, registrando a aceitação no README | **A** |

## O que NÃO verifiquei

- **A saturação de S1 não foi medida.** Não sei quantas ferramentas e tenants existem em produção,
  quantas coletas se sobrepõem, nem se outro job completa durante a saturação. O caminho vem da
  leitura de `config/config.exs:96` e dos três workers;
- **se o Dokploy reinicia sozinho** um contêiner `unhealthy` (P2 do desenho), e **qual tag de
  imagem** o Redeploy usa;
- **o número de tenants em produção**, de que depende o valor do canal lateral de S2;
- **a API `/api/v1/syncs`** (`lib/the_band_web/router.ex:111`): o desenho não a toca. Se um dia
  ela expuser o estado da fila, a avaliação é outra e S2 e S3 valem para ela;
- **a função `/health` sem limite de taxa**: anterior, fora deste escopo, citada só em S4;
- **`Ingestion.reconcile_stuck_syncs/0` sem tenant, chamada de `load/1`**: anterior, decisão
  documentada no próprio código, e não reavaliada aqui;
- **`inspect(reason)` no flash de erro de `handle_event("sync")`** (`index.ex:110-115`): anterior,
  não auditado quanto ao que `reason` pode carregar;
- **a issue #1009** (sessão que sobrevive à suspensão da organização), aberta com label `security`,
  toca o `require_operacao` por onde a tela é vista. Não avaliei a interação: um operador suspenso
  com sessão viva continuaria vendo `/syncs` e esta linha;
- **Sobelow, `hex.audit`, `deps.audit` e `mix gates` não foram rodados**. A avaliação é de desenho,
  sem código novo a medir, e o worktree é compartilhado com outro agente que estava editando
  `docs/producao/runbook.md` durante a leitura. O veredito dos gates fica com o QA, na entrega do
  código.
