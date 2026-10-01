# PROMPT — o aviso de fila parada em `/syncs` (issue #801, parte 3)

Endereço: https://claude.ai/artifact/P1rCXLJdM4EqQCoUYZLjci · cópia: `syncs-queue-stalled.html`

## 1. Os pedidos, textuais e em ordem

**Da issue #801** (pessoa mantenedora, 2026-09-04), seção "O que fecharia", terceiro item:

> e a tela `/syncs` dizendo **"a fila não avança há X"** — hoje ela mostra o sync como
> `running` e não distingue *rodando* de *abandonado*.

**Do contrato `docs/producao/saude-da-fila.md`** (PR #1029), seção "O que este contrato NÃO
cobre":

> **A tela `/syncs` dizendo "a fila não avança há X".** É mudança de tela, e passa pelo
> protótipo antes do código. Fica numa entrega seguinte da #801.

**Do pedido ao papel Design** (2026-10-01, repassado pelo agente que coordena a sessão):

> Desenhe:
> 1. o estado normal (fila andando) — o que muda, se algo;
> 2. o estado de fila parada: o aviso com **há quanto tempo** (minutos/horas desde o último
>    job completado), o que isso significa para as sincronizações listadas como `running`
>    (elas não estão avançando), e **o que quem opera pode fazer** (o runbook: reiniciar o
>    contêiner; o healthcheck já marca `unhealthy`) — sem prometer o que a plataforma não faz;
> 3. o caso "nunca completou nada, e há job esperando há X" (instalação onde o Oban nunca
>    rodou).
> Respeite: quem vê `/syncs` é admin ou escopo organization (tela de operação); o aviso diz o
> fato e a ação, sem alarmismo; nada de cor sozinha. Use dado REAL do banco de dev (SÓ
> LEITURA — SELECT; nunca escreva) para o estado normal, e marque como `example` o estado de
> fila parada se ele não existir no dev.

## 2. O brief que segui

- **Quem lê:** quem opera — administrador ou concessão `organization`. Pessoa que talvez não
  tenha acesso ao servidor.
- **O trabalho da tela:** separar *rodando* de *abandonado* sem afirmar mais do que se sabe.
  O fato observado (hora do último job completado) vem antes do veredito derivado (parada,
  pela regra de 15 min), que vem antes da ação.
- **Tom:** operação, não incidente. Âmbar e hachura (a forma de "derivado"), nunca clay. Nada
  de *error*, *failure*, *down*.
- **Honestidade:** dizer o que não se sabe (a causa), o que não foi medido (se o Dokploy
  reinicia sozinho) e o que não se perde (cada página é salva depois de processada).
- **Tenants:** `oban_jobs` é global. A tela mostra só tempos, nunca contagens, workers ou
  tenants.
- **Design system herdado:** tokens de `specs/060-tela-da-equipe/prototipo/`, marcas
  `observed` / `derived` / `absent` com forma e texto, ausência escrita, inglês na tela,
  mobile-first.
- **Dado:** real na tela 1 (banco de dev, leitura); `example` nas telas 2–4.

## 3. A estrutura aprovada, seção por seção — é contra ela que o QA confere

> Estado: **aprovada — Decided 2026-10-01, pela pessoa mantenedora.** D1–D8 aprovadas; Q1, Q2 e Q3
> decididas pela opção A. Esta seção vale como está. P3 (segurança) em curso em paralelo.

### Tela 1 · `/syncs` · fila andando

1. Abas `Collection` (ativa) e `Profile generation`, e o cabeçalho `Syncs` /
   `Bring in from the tool what the platform comes to know.`, como hoje.
2. **Novo — linha da fila**, logo abaixo do cabeçalho e acima de tudo o mais:
   marca `observed` · `Job queue moving` · `last job finished <duração> ago, at <HH:MM UTC>` ·
   `checked <HH:MM:SS UTC>`. (Q1: *Decided 2026-10-01*, mostrar.)
3. Variante sem histórico e sem espera (instalação nova): mesma linha com marca `absent` e
   `no job has run yet`. Nenhum aviso.
4. O resto da tela é o de hoje, sem mudança.

### Tela 2 · `/syncs` · fila parada (último completado ≥ 15 min)

1. Abas e cabeçalho como hoje.
2. **O aviso**, no lugar da linha da fila, acima da cota da API e das ferramentas:
   1. faixa: hachura + `Job queue stalled · derived from the last finished job`;
   2. título: `The job queue has not moved for <duração>`;
   3. fatos, três linhas, nesta ordem:
      - `last job finished` — `<AAAA-MM-DD HH:MM UTC>` + marca `observed`;
      - `stalled since` — marca `derived` + `no job finished for 15 min or more. The scheduler
        queues work every 5 min, so a moving queue finishes something at least that often.`;
      - `checked` — `<HH:MM UTC>, updated every minute`;
   4. bloco `What this means here`, três parágrafos:
      - `Runs marked running below are not advancing. Their status still says running because
        the job that closes stuck runs waits in the same queue.`
      - `Nothing collected so far is lost: each page is saved after it is processed.`
      - `Sync and Reprocess are paused on this screen until the queue moves. A new run would
        only wait in the queue.` (Q2: *Decided 2026-10-01*, desabilitar com a razão)
   5. bloco `What you can do`, lista numerada:
      1. `Restart the application container. This needs access to the server. If you do not
         have it, send this notice to whoever runs the platform. Steps: runbook, stalled
         queue` (link para a seção do runbook, P1);
      2. `In production, the container healthcheck already reports unhealthy and /health
         answers 503. Whether the server restarts the container by itself has not been
         measured.`
      3. `This notice clears by itself once a job finishes. If it is still here 15 min after a
         restart, restarting is not the fix: report it with the time shown above.`
   6. rodapé: `What this notice does not know: why the queue stopped.`
3. Cartão da ferramenta: botão `running` desabilitado (como hoje quando há execução) com a
   razão `already running, and not advancing: the queue is stalled`. Sem execução em curso, o
   botão é `Sync` desabilitado com `paused: the queue is stalled` (Q2, decidida).
4. Cartão `Reprocess mappings`: botão desabilitado com `paused: reprocessing runs in the
   stalled queue` (Q2, decidida).
5. Cada execução `running`:
   1. badge `running` **mantido**, e ao lado a marca `derived` `not advancing · queue
      stalled`;
   2. duas caixas lado a lado: `the run record says` — `running, since <HH:MM UTC>. Nobody
      closed it.` / `the queue says` — `no job has finished since <HH:MM UTC>, this run's
      included.`;
   3. as fases como hoje; fase sem checkpoint escreve `not run yet` (nunca `—`);
   4. a linha de último avanço como hoje (`no progress for <duração>`);
   5. sem trabalho em `executing`: o texto `Close stuck sync is not offered: this run's work
      is still in the queue, and closing the record would not move it. Restart first.` Com
      job em `executing`: o botão e a confirmação de hoje (D5).
6. Nenhum número de jobs, nome de worker ou tenant em lugar nenhum do aviso (D3).

### Tela 3 · `/syncs` · nunca completou, e há job esperando ≥ 15 min

Igual à tela 2, com estas diferenças:

1. faixa: `Job queue stalled · derived from the oldest waiting job`;
2. título: `No job has ever finished here, and work has waited <duração>`;
3. fatos, quatro linhas: `last job finished` — marca `absent` + `none on this installation`;
   `oldest waiting job` — `queued at <AAAA-MM-DD HH:MM UTC>` + marca `observed`;
   `stalled since` — marca `derived` + `work has waited 15 min or more and nothing has ever
   run.`; `checked`;
4. `What this means here`: `Background work has not run on this installation since at least
   <HH:MM UTC>. The run below was started and has not collected its first page.` e `Sync and
   Reprocess are paused on this screen until the queue moves.`;
5. `What you can do`: só os itens 1 e 3 da tela 2 (o item do healthcheck sai: o contêiner
   pode nunca ter sido o de produção);
6. rodapé: `What this notice does not know: why the queue never started.`;
7. execução `running` sem checkpoint: caixa tracejada com marca `absent` e `no page collected
   yet: the run is waiting in a queue that has never run`.

### Tela 4 · telefone (360 px)

Os fatos empilham rótulo sobre valor; os dois blocos empilham; nenhuma rolagem lateral.
Todos os textos da tela 2 permanecem (o protótipo encurta só para caber na moldura).

### Regras transversais

- duração: `47 min` · `3 h 12 min` · `4 d 2 h`, sempre com o horário absoluto UTC (D6);
- a tela reconfere a fila a cada minuto, sem recarregar (D4);
- o aviso some sozinho quando um job completa;
- nenhuma informação só por cor: toda marca tem forma e texto, e `title` para leitor de tela.

## 4. Como cada papel usa este arquivo

| papel | uso |
|---|---|
| **Product Owner** | Q1–Q3 já decididas (2026-10-01); registra link e este prompt no item do backlog da #801; cobra P1 (runbook) e P3 (segurança) antes do plano |
| **Security** | avalia P3 e D3 antes do código: estado de tabela global mostrado a escopo `organization` |
| **Elixir/Phoenix Developer** | implementa exatamente a seção 3; o que não couber volta ao protótipo, não ao código. Precisa da função de leitura NOVA ao lado de `fila/2` (Q3, decidida: `fila/2` e `/health` intactos) e de um timer de 60 s (D4) |
| **Knowledge Base** | declara as três medidas do README e a necessidade de informação antes do código |
| **QA** | confere a tela entregue item a item contra a seção 3, com captura nos estados 1, 2 e 3 (fila parada se induz parando o Oban num banco de teste, nunca em produção) |
| **Design** | marca *Decided <data>* nas respostas e republica no mesmo endereço |
