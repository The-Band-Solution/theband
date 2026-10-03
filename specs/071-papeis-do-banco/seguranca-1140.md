# Avaliação de segurança da #1140, antes do código: a credencial que migra fora do alcance de `band`

Agente `security`, 2026-10-02. Faço a avaliação antes do código, como pede `AGENTS.md` §14.0. Ela
fecha o achado **S5** de [`seguranca.md`](seguranca.md), que também é meu. Avalio o desenho
proposto por quem implementa, conforme a decisão da pessoa mantenedora de 2026-10-02 (opção **a**:
credencial em arquivo legível só por root, entrypoint começando como root e trocando para `band`
com `setpriv`). Não decido prioridade nem aceito entregável: os dois são do Product Owner.

**O que foi feito.** Montei um protótipo do desenho só no scratchpad. Ele tem um `Dockerfile`
derivado de `the_band:071`, um entrypoint, um script de healthcheck e uma guarda no `env.sh`. Não
mexi em `lib/`, `test/`, `rel/` nem no `Dockerfile` do repositório. Medi contra uma base e dois
papéis temporários no `the_band_postgres` (`t1140`, `t1140_dono`, `t1140_serve`). As senhas foram
geradas por `openssl rand -hex` e nunca foram impressas. Base, papéis, contêineres, volume e imagem
foram removidos ao final, e a contagem deu 0 em cada um. Os arquivos do protótipo ficaram em
`…/scratchpad/m1140/` (`entrypoint.sh`, `saude.sh`, `guarda_env.sh`, `Dockerfile`, `varre.sh`) como
referência, sem segredo.

**O que foi medido, e como.** O medidor é `varre.sh`, rodando **como `band`**. Ele procura a senha
do dono em todo `/proc/*/environ` e `/proc/*/cmdline` legível e em `/app`, `/tmp`, `/home`, `/var` e
`/run`. O padrão fica num arquivo em `/dev/shm`, fora da varredura, para que o medidor não se
encontre. Cada zero abaixo tem um **controle positivo** ao lado: um processo de `band` com a senha
no ambiente, que a varredura tem de achar e achou. Duas medições minhas saíram contaminadas no
caminho: o medidor carregava a senha no próprio ambiente. Foram descartadas, e estão descritas
onde aconteceram.

## Veredito

**O desenho fecha S5 contra quem executa código como `band`, mas só com duas correções. Sem elas,
abre uma escalada para root que hoje não existe.**

1. **Achado novo, de severidade alta (A1).** A distribuição Erlang é simétrica. Todo
   `bin/the_band rpc` ou `remote` aberto **como root** conecta-se ao nó de `band`, e o nó de `band`
   passa a poder executar código no nó root. Medido: o código no nó que serve rodou `id -u` → `0`
   no nó do `rpc` e leu o arquivo da credencial. O passo 5 do desenho protege o HEALTHCHECK. Mas o
   desenho também faz o `docker exec` entrar como root, e o runbook (§14.4, §11, rotação de chave)
   manda o operador rodar `bin/the_band rpc` justamente pelo terminal. A correção é uma guarda em
   `rel/env.sh.eex` que reexecuta como `band` todo comando que conecta ao nó. Ela foi medida e
   fecha o caminho;
2. **o modo do arquivo não é a propriedade (A3).** Confiro a legibilidade **lendo como `band`**,
   não pelos bits do modo. No meu ambiente, o `chmod 0400` atravessou para o host e, mesmo assim,
   `band` continuou lendo dentro do contêiner.

Com as duas correções, medi o seguinte: zero ocorrências da senha em tudo o que `band` alcança;
o arquivo é recusado a `band`; `/app` não é gravável por `band`; o PID 1 é `band` sem capacidade
nenhuma e com `NoNewPrivs=1`; `docker inspect` não mostra a credencial. O fallback pela variável de
ambiente continua com S5 parcialmente aberto (A2), e isso precisa ser dito na nota.

## Respostas às perguntas

| Pergunta | Resposta | Como foi verificado |
|---|---|---|
| O desenho fecha S5 contra quem executa código como `band`? | **Sim, com A1 e A3 corrigidos.** Sem A1, não: piora, porque passa a haver caminho até root | varredura como `band`: 0 em 13 a 19 arquivos de `/proc`, 0 em arquivos; controle positivo 1 e 2. Escalada medida e fechada pela guarda |
| `/proc/<pid>/environ` do processo de migração (root) é legível por `band`? | **Não.** `Permission denied` (o kernel exige mesmo uid ou `CAP_SYS_PTRACE`) | processo root com a senha no ambiente; `band` tentou ler e foi recusado, e a varredura deu 0 |
| E o `/proc/1/cmdline` e o `environ` depois do `exec`? | `cmdline` é público, mas só carrega `beam.smp … -root /app …` e o **cookie** (`-setcookie`), nunca a URL. `environ` do PID 1 é de `band`, tem `DATABASE_URL` de quem serve e **não** tem a que migra | `DATABASE_MIGRATION_URL` aparece 0 vezes; guarda de que mediu: `DATABASE_URL` aparece 1 vez. `HOME=/home/band`. Root no `docker exec` também não lê o `environ` do PID 1 (sem `CAP_SYS_PTRACE`) |
| O processo que serve lê o arquivo montado? | **Não** (`-r-------- root root`; `band`: recusado) | `cat` como `band` falha; a busca em `/run` como `band` deu 0 |
| O `eval` root da migração abre distribuição? | **Não.** O ramo `eval` de `bin/the_band` não passa `--sname`, e o `epmd -names` durante o `eval` só listou `the_band` (o servidor) | lido no script da release e medido |
| Core dump | o `ulimit -c` local é 0 e o `core_pattern` é `core` (Docker Desktop). **Não é o host de produção** | ver "o que não verifiquei" |
| Crash dump do Erlang (`erl_crash.dump`) | **contém a senha** quando o BEAM com o `Repo` iniciado morre: 2 ocorrências, em base64. Nasce `0640 root:root` em `/app`, e `band` não lê | dump decodificado pelo próprio BEAM; o marcador de controle aparece 1 vez. `grep` literal e hexadecimal dão 0, porque o dump da OTP 29 escreve binários em base64. Zero ali seria medida cega |
| `ps` | igual ao `cmdline`: sem credencial | varredura de `cmdline` |
| `docker inspect` | modo arquivo: **0** ocorrências (só o caminho do mount). Modo variável: **1** (`Config.Env`) | `docker inspect … \| grep -c` |
| Logs | o entrypoint não ecoa a credencial nem usa `set -x`. S6 (URL malformada no log) não foi medido de novo | leitura do protótipo |
| Dokploy File Mount | **não verifiquei** se existe nesta versão nem com que dono e modo o arquivo chega | sem acesso ao painel nem ao host |

## Achados

### A1 — Alta. Nó root conectado ao nó de `band` executa o código de `band`

**O que é (A01/A04; ASVS V1, V4).** O desenho faz o contêiner começar como root (`USER root` na
imagem), e com isso o `docker exec` passa a entrar como root por padrão, inclusive no terminal do
Dokploy. `bin/the_band rpc`, `remote`, `restart`, `stop` e `pid` sobem um nó Erlang oculto e o
conectam, pelo cookie, ao nó que serve. A distribuição é **simétrica**: depois de conectados, o nó
que serve chama `:rpc.call(nó_do_operador, :os, :cmd, …)`. O módulo `:net_kernel.monitor_nodes/2`
com `node_type: :all` avisa da chegada do nó oculto.

**Caminho, medido.** (1) O atacante executa código no BEAM que serve, como `band`. É o mesmo
atacante de S5: dependência comprometida, `eval` indevido ou `binary_to_term` inseguro. (2) Ele deixa
armado um processo que espera `nodeup`. (3) O operador segue o runbook e roda pelo terminal
`/app/bin/the_band rpc 'IO.puts(TheBand.Release.conferir_papeis())'`, ou `girar_sessoes()`, ou
`rotacionar_chave()`. (4) O processo armado executa no nó do operador, que é root, e lê
`/run/secrets/database_migration_url`. Resultado no protótipo:
`{:"rpc-a003-the_band@…", ~c"0\nLEU_O_ARQUIVO\n"}`. A janela é a duração da sessão: segundos num
`rpc`, minutos num `remote`. Com o HEALTHCHECK como root, que é o passo 5 sem o `setpriv`, a mesma
escalada aconteceria **a cada 60 segundos, sem operador nenhum**. Além da credencial, root no
contêiner dá escrita em `/app`, que vale como persistência até o contêiner ser recriado.

**Consequência para o negócio.** O conserto de S5 vira o caminho mais curto até a credencial que
migra. Enquanto a credencial que migra for o `postgres`, ela é de superusuário, e chega até a
execução de comando no contêiner do banco (`COPY … TO PROGRAM`). E a credencial é entregue
justamente quando alguém da operação está seguindo o runbook.

**Onde.** É o passo 6 do desenho (`docker exec` como root). O runbook está em
`docs/producao/runbook.md`: §14.4 (linha 543), a girada de sessões (linha 359) e a rotação (linha
463).

**O que fecha.** Uma guarda em `rel/env.sh.eex`, que hoje não existe. O `mix release` usa o padrão
quando o arquivo falta, e o `env.sh` é lido por **todo** comando do `bin/the_band`. Se `id -u` for
0 e o `RELEASE_COMMAND` for `rpc`, `remote`, `restart`, `stop`, `pid`, `start`, `start_iex`,
`daemon` ou `daemon_iex`, a guarda reexecuta o próprio script com
`env -u DATABASE_MIGRATION_URL setpriv … --reuid=band …`. Medido com a guarda no lugar: o `rpc`
aberto como root chegou ao nó que serve como `1000`, e a leitura do arquivo falhou. O `eval` como
root continua root, e isso é aceitável: o ramo `eval` não abre distribuição (medido), então não há
canal de volta. A guarda também cobre o HEALTHCHECK, como segunda defesa ao lado do passo 5.

**Se não entrar agora.** O desenho não pode ir para produção sem A1. É a **recomendação de
bloqueio** do desenho, e não da release: hoje, sem o desenho, esse caminho não existe.

### A2 — Média. O fallback por variável de ambiente mantém S5 aberto, e por mais lugares do que parece

**O que é (A02; ASVS V2).** Com `DATABASE_MIGRATION_URL` na configuração do contêiner, o valor:

- aparece em `docker inspect` (`Config.Env`, medido: 1 ocorrência). No modo arquivo, 0;
- é herdado por todo `docker exec -u band`, medido. Um `env` dentro do terminal aberto como `band`
  mostra a credencial, e o BEAM que serve lê o `/proc/<pid>/environ` desse processo;
- vaza por **qualquer** troca para `band` que esqueça o `env -u`. Medido com o defeito D2,
  HEALTHCHECK com `setpriv` e sem `env -u`: até **4** ocorrências por varredura. Com `env -u`:
  **0 em 10**.

O `env -u` no healthcheck e na guarda de A1 fecha os caminhos que conhecemos. O defeito é de
desenho, A04: a proteção depende de cada chamador lembrar, e o próximo não vai lembrar.

**O que fecha.** O fallback continua, porque a pessoa mantenedora o decidiu, mas com três regras:

1. o aviso no log de deploy diz que S5 está aberto **e** diz qual é o caminho (`docker exec -u band`,
   `docker inspect`);
2. se o arquivo **e** a variável existirem ao mesmo tempo, vale o arquivo, e o aviso diz que a
   variável continua na configuração do contêiner e precisa sair do painel;
3. toda troca para `band`, no entrypoint, no healthcheck e na guarda do `env.sh`, passa por **uma
   função só** que já faz o `env -u`, e não pela linha do `setpriv` copiada em vários lugares.

Remover o fallback vira item de backlog, a fazer quando produção estiver no modo arquivo.

### A3 — Média. O modo do arquivo não é a propriedade; a legibilidade por `band` é

**O que é (A05; ASVS V14).** O passo 1 pergunta: "se o arquivo for legível por outros, recusa ou
corrige o modo (qual?)". Medido com o arquivo montado em 0644 por bind mount no Docker Desktop:
o entrypoint, como root, fez `chown 0:0` e `chmod 0400`. A mudança **atravessou para o host** (o
arquivo virou `-rw-------` no macOS), e, mesmo assim, `band` **continuou lendo** dentro do
contêiner. O sistema de arquivos do bind mount traduz dono e modo. Nos Linux de produção, sem user
namespace, a tradução provavelmente não acontece, mas eu não medi lá. O que essa medição prova é
que checar `stat -c %a` testa a palavra e não o controle.

**O que fecha.** Testar o controle: o entrypoint tenta **abrir o arquivo como `band`**
(`setpriv --reuid=band … sh -c 'exec 3<"$1"'`), o que cobre modo, grupo, ACL e diretório pai de uma
vez. Se `band` abre: tenta `chown 0:0` e `chmod 0400` e **testa de novo como `band`**. Se `band`
ainda abre, **recusa subir**, nomeando o arquivo sem ler o conteúdo. Recusar sem tentar corrigir
também é defensável, e é mais previsível: não muda arquivo do host nem falha diferente em mount
`:ro`. A escolha entre as duas é da pessoa mantenedora. O que não pode acontecer é subir com o
arquivo legível por `band`, porque aí S5 fica aberto, e em silêncio.

### A4 — Baixa. O crash dump da migração contém a credencial que migra

**O que é (A09; ASVS V7, V6).** Um BEAM que morre por `halt/1`, falta de memória ou falha no boot
grava `erl_crash.dump` no diretório de trabalho. Medido com o `Repo` iniciado pela credencial que
migra: a senha aparece **2 vezes**, em base64. No desenho, o arquivo nasce `0640 root:root` em
`/app`, e `band` **não** o lê (medido: `Permission denied`). A severidade é baixa porque hoje não há
caminho para `band`. Mas a proteção depende de três coisas que outra mudança pode desfazer: o
diretório de trabalho ser de root, o modo que o BEAM escolhe, e `band` não pertencer ao grupo root.
E o dump sobrevive a `docker restart`, na camada gravável.

**O que fecha.** `ERL_CRASH_DUMP_SECONDS=0` na linha do `eval` root (medido: o dump não nasce), mais
`umask 077` no entrypoint. O dump de uma migração que caiu vale pouco para diagnóstico, e o que
importa sai no stderr.

**Fora do escopo, registrado.** O crash dump do servidor, que é de `band`, tem a credencial que
serve e a chave mestra. Com `/app` de root, ele **deixa de ser gravável em `/app`**. Se alguém
quiser os dumps de volta, o destino é `ERL_CRASH_DUMP=/tmp/…`, e não um diretório gravável dentro
de `/app`.

### A5 — Baixa. `/app` de root e nenhum diretório de `band` dentro dele

**O que é (A08; ASVS V10, V14).** O passo 2 do desenho está correto, e eu o reforço com o que foi
medido:

- **`RELEASE_TMP` não precisa de diretório gravável.** `sys.config` tem `RUNTIME_CONFIG=false` e o
  provedor tem `reboot_system_after_config=false`, então `start`, `eval` e `rpc` **não gravam nada**
  em `RELEASE_TMP`. Só `daemon` grava, e ele não é usado. Lido no `bin/the_band` e no `sys.config`
  da imagem;
- **não crie `/app/tmp` de `band`.** Se um dia a configuração em runtime passar a gravar, o root
  do `eval` faria `cat … > $RELEASE_TMP/<nome com data e 16 bits aleatórios>` num diretório
  controlado por `band`. É ataque de link simbólico: root sobrescrevendo arquivo escolhido por
  `band`. Com `/app` de root, o servidor falharia alto, com
  "could not write … runtime.sys.config", e isso é o comportamento certo. Se for preciso,
  `RELEASE_TMP=/tmp/the_band` **só no processo de `band`**;
- **o cookie:** `releases/COOKIE` fica `root:root 0644`, legível por `band`, e o `rpc` funcionou
  (medido, contêiner `healthy`);
- **a aplicação não grava em `/app`:** em `lib/` há só leituras de `priv`. A única escrita é
  `Segredo.Varredura` em `System.tmp_dir()` (`/tmp`);
- **o que `band` alcança para escrever**, medido: `/tmp`, `/var/tmp`, `/run/lock`, `/var/lock` e
  `/home/band`. Nada disso é lido pelo entrypoint root. O `HOME` do root é `/root`, então o `.erlang`
  de `band` não alcança o BEAM root.

### A6 — Média, anterior à #1140, fora do escopo dela. Distribuição em `0.0.0.0` com o cookie dentro da imagem

**O que é (A05/A07; ASVS V14, V2).** O `epmd` (porta 4369) e a porta de distribuição escutam em
**todas as interfaces** do contêiner (medido em `/proc/net/tcp`). O cookie é gerado no
`mix release` e gravado em `releases/COOKIE`, **dentro da imagem**: é o mesmo em todo contêiner
dessa versão, inclusive nas instâncias de ensaio e de restauração.

**Caminho.** Quem tem a imagem e alcança a rede Docker do contêiner executa código **como `band`**.
É exatamente o atacante de S5, sem precisar de falha na aplicação. A imagem **não** é puxável
anonimamente (`ghcr.io`, `tags/list` → `403`, medido), então o cookie fica restrito a quem tem
acesso ao pacote. Não verifiquei quais outros contêineres compartilham a rede do Dokploy no VPS.

**O que fecha, em issue própria:** distribuição só no loopback (`ERL_EPMD_ADDRESS=127.0.0.1` e
`-kernel inet_dist_use_interface {127,0,0,1}` no `vm.args.eex` e no `remote.vm.args.eex`), e o
cookie vindo de segredo por ambiente (`RELEASE_COOKIE` por arquivo), e não da imagem. Não bloqueia
a #1140, mas o conserto de S5 vale menos enquanto esta porta existir.

### A7 — Baixa, regressão declarada. O contêiner volta a começar como root (CIS Docker 4.1)

**O que é.** Só o processo do entrypoint e a migração rodam como root. Depois do `exec`, medido no
PID 1: `Uid 1000`, `CapInh`, `CapPrm`, `CapEff`, `CapBnd` e `CapAmb` todos zero, `NoNewPrivs: 1`.
O que fica como root de forma duradoura é o **`docker exec`** (A1) e o HEALTHCHECK, que roda como o
`USER` da imagem e por isso precisa do passo 5.

**Compensações, medidas.** O protótipo subiu e disse `separação em vigor` com
`--cap-drop ALL --cap-add SETUID --cap-add SETGID --security-opt no-new-privileges`. O
`no-new-privileges` não atrapalha o `setpriv`, porque ele só larga privilégio. Com isso, o root do
`docker exec` fica sem `DAC_OVERRIDE`, `CHOWN`, `FOWNER` e `KILL`. Se A3 for "corrigir o modo",
entram também `CHOWN` e `FOWNER`. **Não verifiquei** se o Dokploy aceita `cap_drop`/`cap_add` e
`security_opt` numa *Application*. Se não aceitar, a regressão fica com as capacidades padrão do
Docker.

**A alternativa que evita a regressão inteira** é a opção **b** de S5: migrar fora do contêiner que
serve. Ela continua não verificada, porque eu não sei se o Dokploy tem passo de pré-deploy.

## O desenho proposto, passo a passo, com as correções

| Passo proposto | Avaliação | Correção |
|---|---|---|
| 1. Arquivo, variável de shell não exportada; recusar ou corrigir o modo; fallback por env com aviso | correto na ideia | a legibilidade se testa **abrindo como `band`** (A3). A variável `DATABASE_MIGRATION_URL` recebe `unset` **antes** de qualquer processo de `band` nascer. Se arquivo e variável coexistem, vale o arquivo, com aviso (A2). O caminho do arquivo é configurável (`THE_BAND_MIGRATION_URL_FILE`) e o padrão é `/run/secrets/database_migration_url`. Arquivo vazio é recusa |
| 2. `/app` de root, não gravável por `band`; `RELEASE_TMP` para diretório de `band`; cookie legível | correto, e confirmado | **não** crie diretório de `band` para `RELEASE_TMP`: não é preciso (A5). O guarda em teste é `find /app -writable` como `band` dar vazio |
| 3. Migração como root; `semear_primeira_conta` como `band` | correto | acrescentar `ERL_CRASH_DUMP_SECONDS=0` na linha root e `umask 077` no topo (A4). `migrar_sem_credencial()` também roda como `band`, porque não precisa de root |
| 4. `exec setpriv --reuid=band --regid=band --init-groups --inh-caps=-all --bounding-set=-all --no-new-privs …` | **as flags estão certas para o util-linux 2.38.1 do bookworm** (medido: o binário está na imagem de runtime, e o resultado no PID 1 está em A7) | acrescentar `env HOME=/home/band USER=band LOGNAME=band`: o `setpriv` não troca o `HOME`, e o servidor herdaria `/root`. **Não** use `--reset-env`: ele apaga `DATABASE_URL`, `SECRET_KEY_BASE` e o resto |
| 5. HEALTHCHECK por `setpriv` | correto e **portador de carga** (sem ele, A1 a cada 60 s) | `env -u DATABASE_MIGRATION_URL` **antes** do `setpriv`, no processo root, e não depois. Medido: D2 vaza. Melhor num script (`/app/bin/saude`) do que numa linha longa no `Dockerfile`, e a guarda de A1 cobre o caso de alguém tirar o `setpriv` |
| 6. `docker exec` como root | aceitável **só com a guarda de A1** | guarda em `rel/env.sh.eex`; runbook §14.5 (rollback) muda para `DATABASE_URL="$(cat /run/secrets/database_migration_url)" /app/bin/the_band eval …`; runbook §14.6 reescrito (o limite deixa de ser "quem tem o Dokploy tem a credencial" via env, e passa a ser "quem é root no contêiner") |

**Ordem do entrypoint corrigido** (o protótipo medido está em `…/scratchpad/m1140/entrypoint.sh`):

1. `set -e`, `umask 077`; confere as quatro obrigatórias, como hoje;
2. `id -u` = 0, senão recusa e nomeia o motivo (S5). Nada no CI nem na suíte roda a imagem com
   `--user` (conferido em `.github/` e `test/`);
3. **uma** função `como_band` = `env -u DATABASE_MIGRATION_URL setpriv --reuid=band --regid=band
   --init-groups --inh-caps=-all --bounding-set=-all --no-new-privs env HOME=/home/band USER=band
   LOGNAME=band "$@"`;
4. lê a credencial: arquivo (com a prova de A3) ou, se não houver arquivo, a variável (com o aviso de
   A2); `unset DATABASE_MIGRATION_URL`;
5. com credencial: `ERL_CRASH_DUMP_SECONDS=0 DATABASE_URL="$cred" THE_BAND_URL_QUE_SERVE="$url" bin/the_band eval 'TheBand.Release.migrate()'`, como root. Sem credencial: `como_band … migrar_sem_credencial()`;
6. `cred=""; unset cred`;
7. `como_band bin/the_band eval 'TheBand.Release.semear_primeira_conta()'`;
8. `exec` da linha do passo 4 do desenho, mais o `env HOME=…`, e `"$@"`.

**Imagem:** `chown -R root:root /app && chmod -R go-w /app`; entrypoint e `bin/saude` `root:root
0755`; `USER root` (declarado, com comentário apontando para este documento); HEALTHCHECK
`/app/bin/saude | grep -qx ok`. **Release:** `rel/env.sh.eex` = o padrão do Elixir mais a guarda de
A1.

## Cenários de teste — cada um com o defeito a injetar, mensuráveis no Docker local

Todos rodam contra a imagem construída do branch, com uma base e papéis descartáveis. O padrão de
busca fica em `/dev/shm` como `band`, e o medidor roda com `env -u DATABASE_MIGRATION_URL`. **Sem
isso o medidor se encontra no modo variável**, e eu medi esse erro duas vezes. A suíte `mix test`
não roda o entrypoint, então estes testes vivem fora dela (um roteiro em `quickstart.md` ou um job
de CI que suba a imagem). Quem os escreve é o QA.

| # | Cenário de ataque | Asserção | Guarda de que mediu | Defeito a injetar → tem de reprovar |
|---|---|---|---|---|
| T1 | código como `band` varre `/proc` e o disco atrás da credencial | `refute`: 0 ocorrências da senha em `environ`, `cmdline` e arquivos | controle positivo: processo de `band` com a senha no ambiente → ≥ 1; e `arquivos_proc_legiveis` > 0 | entrypoint que **exporta** a credencial (`export DATABASE_MIGRATION_URL`) antes do `exec` → ≥ 1 |
| T2 | `band` lê o arquivo montado | `refute`: `cat` como `band` falha | `cat` como root lê, e não está vazio | montar o arquivo 0644 **e** tirar a prova de A3 do entrypoint → `band` lê |
| T3 | arquivo legível por `band` na subida | o contêiner **não sobe** (`exit 1`) e a mensagem nomeia o arquivo e **não** contém a senha | a mesma imagem sobe com o arquivo 0400 root | trocar a prova por `stat -c %a` (o defeito de A3), num ambiente em que o bind mount traduz o modo → sobe com `band` lendo |
| T4 | **A1:** nó de `band` armado com `nodeup`; operador roda `bin/the_band rpc` como root | o código armado vê `id -u` = `1000` e **não** lê o arquivo | sem a guarda, o mesmo roteiro devolve `0` e `LEU_O_ARQUIVO` (medido) | tirar a guarda de `rel/env.sh.eex` → `0` |
| T5 | HEALTHCHECK como root | o processo do `rpc` do healthcheck tem uid 1000 | o contêiner fica `healthy` | trocar `bin/saude` por `bin/the_band rpc …` direto **e** tirar a guarda → uid 0 (é T4 sem operador) |
| T6 | **A2/D2:** modo variável; healthcheck em laço; `band` varre | 0 ocorrências em N varreduras | controle positivo de T1 | tirar o `env -u` de `como_band` → até 4 por varredura (medido) |
| T7 | `/app` como persistência para o próximo start root | `find /app -writable` como `band` é vazio; `touch /app/entrypoint.sh` falha | `touch /tmp/x` como `band` funciona | voltar `--chown=band` no `COPY` → lista não vazia |
| T8 | PID 1 depois do `exec` | `Uid 1000`, `CapEff`/`CapBnd` = 0, `NoNewPrivs` = 1, `HOME=/home/band`, sem `DATABASE_MIGRATION_URL` | `DATABASE_URL` presente no mesmo `environ` | tirar `--bounding-set=-all` → `CapBnd` ≠ 0 |
| T9 | **A4:** crash da migração | nenhum `erl_crash.dump` depois de um `eval` root que faz `:erlang.halt(~c"x")` com o `Repo` de pé | sem a variável, o dump nasce e contém a senha decodificada do base64 (2 ocorrências, medido) | tirar `ERL_CRASH_DUMP_SECONDS=0` → o dump nasce |
| T10 | `docker inspect` no modo arquivo | 0 ocorrências da credencial | no modo variável, 1 (medido) | — (controle do cenário) |
| T11 | funcionalidade | migração aplicada, `papéis: separação em vigor`, `healthy`, `conferir_papeis()` por `rpc` como root responde | — | — |
| T12 | capacidades mínimas | T11 vale com `--cap-drop ALL --cap-add SETUID --cap-add SETGID --security-opt no-new-privileges` | — | tirar `SETUID` → o `setpriv` falha e o contêiner não sobe (falha alta, que é o certo) |

**Prova de que o teste mede (L69, princípio VII):** cada linha da coluna "defeito" tem de ser vista
reprovando antes de a guarda ser aceita, com o comando e o código de saída na issue #1140.

## O que muda para o Dokploy, e o que eu não sei

- **File Mount:** não verifiquei se a *Application* desta versão do Dokploy oferece *File Mounts*,
  onde o conteúdo fica no host, com que dono e modo chega ao contêiner, se pode ser `:ro`, nem se o
  Dokploy reescreve o arquivo a cada deploy. Por isso o entrypoint **prova** a legibilidade em vez
  de presumir (A3). O conteúdo também fica no banco do próprio Dokploy, como as variáveis de hoje:
  quem administra o Dokploy continua tendo a credencial, e isso não muda;
- **terminal:** presumo que entra como o `USER` da imagem, isto é, root. Não verifiquei;
- **`cap_drop`/`security_opt`:** não verifiquei se a *Application* aceita (A7);
- **passo de pré-deploy (opção b):** não verifiquei.

## O que eu não verifiquei

- **o host de produção:** o `core_pattern`, o `ulimit -c` e o `fs.suid_dumpable` do VPS da Contabo.
  O `core_pattern=core` e o `ulimit -c 0` medidos são do Docker Desktop. Core dump do BEAM root
  carregaria a credencial, e o destino depende do host;
- **user namespace e tradução de dono no bind mount em Linux:** A3 foi medido só no macOS;
- **o Dokploy inteiro:** veja a seção acima;
- **S6** (URL malformada impressa no log de deploy) com a credencial vindo de arquivo: `release.ex:125`
  sugere tratamento, mas não medi de novo;
- **o `rollback/2` do runbook §14.5** no desenho novo: só redigi a forma, não a executei;
- **quem compartilha a rede Docker do contêiner no VPS** (A6);
- **a visibilidade exata do pacote `ghcr.io`:** só medi que o pull anônimo é negado, porque o token
  local não tem `read:packages`;
- **o `remote` (IEx) como root com a guarda:** medi `rpc`; `remote` passa pelo mesmo `case` do
  `env.sh`, mas não o executei;
- **o comportamento com `docker restart`** (camada gravável preservada), além da não gravabilidade
  de `/app`;
- **funcionalidades que gravam em disco fora do boot:** a varredura de segredo em `/tmp` agora nasce
  `0600` sob `umask 077`, mas não a executei;
- **`mix gates`:** não rodei, por instrução de quem me chamou. Nenhum veredito de gate está implícito
  aqui.
