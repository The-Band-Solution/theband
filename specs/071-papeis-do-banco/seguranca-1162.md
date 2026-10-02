# Avaliação de segurança antes do código — #1162 (A6 de `seguranca-1140.md`)

**Papel:** Security (`AGENTS.md` §13, §14.0). **Data:** 2026-10-02. **Branch avaliado:**
`fix/1140-credencial-em-arquivo` (PR #1163, empilhado sobre #1161), commit `d63aee2`.
**Escopo:** o desenho proposto para fechar A6, que é a distribuição Erlang alcançável pela rede com
o cookie dentro da imagem. Não fiz varredura da superfície inteira. Não alterei `lib/`, `test/`,
`rel/` nem o `Dockerfile` do worktree. O protótipo foi feito numa cópia em scratchpad, construído
com `docker build` (passando por `mix release` de verdade) e apagado ao final, junto com contêineres,
rede, imagens, volume e as credenciais descartáveis de teste.

## Veredito

**O desenho fecha A6 contra quem alcança a rede Docker do contêiner, desde que entrem quatro
correções.** Medi a linha de base e o protótipo no Docker local:

| | linha de base (`d63aee2`) | protótipo com as correções |
|---|---|---|
| epmd (4369) | `0.0.0.0` e `::` | `127.0.0.1` e `::1` |
| porta de distribuição | `0.0.0.0` | `127.0.0.1` |
| nó do `remote` (IEx), enquanto vive | não medido | `127.0.0.1` |
| `rpc` de outro contêiner da mesma rede, com o cookie da imagem | **executou `id` → `uid=1000(band)`** | `RPC failed with reason :noconnection` |
| `rpc` de outro contêiner com o cookie **certo**, lido do alvo | (não se aplica) | `:noconnection`, tanto para `the_band@<IP>` quanto para `the_band@127.0.0.1` |
| TCP do vizinho para 4369 e para a porta de distribuição | aberta | recusada; a 4000 (HTTP), usada como controle da sonda, aberta |
| cookie | o mesmo em todo contêiner da imagem (`releases/COOKIE`) | diferente entre dois contêineres e trocado a cada start (hash medido antes e depois de `docker restart`) |

A linha de base confirma A6 como exploração completa, e não só como porta aberta: um contêiner
vizinho, usando a própria imagem como ferramenta, executou comando como `band` no nó que serve.

**As quatro correções** (detalhes nos achados abaixo):

1. **B1:** apagar `releases/COOKIE` da imagem e **recusar** `start`/`rpc`/`remote`/… quando o
   arquivo de cookie não existir. Sem isso, "usar o arquivo quando existir" volta em silêncio ao
   cookie da imagem;
2. **B2:** a interface vai em **`rel/vm.args.eex` e em `rel/remote.vm.args.eex`**, e o `env.sh`
   fixa `RELEASE_VM_ARGS`/`RELEASE_REMOTE_VM_ARGS`. Uma variável no ambiente desfez a guarda
   (medido);
3. **B4:** `DNS_CLUSTER_QUERY` definido passa a ser recusa no boot, e não cluster quebrado em
   silêncio;
4. a ordem no `entrypoint.sh`: o cookie é gerado **antes** de qualquer processo de `band` e de
   qualquer `eval`, com escrita atômica.

A decisão de prioridade é do Product Owner. A6 era Média e continua Média até isto entrar.

## Respostas às perguntas de quem implementa

| Pergunta | Resposta | Como verifiquei |
|---|---|---|
| Fecha A6 contra a rede Docker? | Sim, com B1 e B2 | `rpc` do vizinho, com o cookie da imagem e com o certo, recebe `:noconnection`. Sondas TCP para 4369 e para a porta de distribuição foram recusadas |
| O epmd ainda abre 4369 em `0.0.0.0` com `ERL_EPMD_ADDRESS`? | Não. Escuta em `127.0.0.1` e em `::1` (o epmd sempre acrescenta o loopback) | `/proc/net/tcp` e `/proc/net/tcp6` no contêiner. O epmd roda como `uid=1000`, e não como root, porque quem o sobe é o `start` já rebaixado |
| A porta de distribuição fica só em `127.0.0.1`? | Sim, **se** `inet_dist_use_interface` estiver no `vm.args`. Só `ERL_EPMD_ADDRESS` **não basta**: com o defeito injetado, a porta foi para `0.0.0.0` e abriu ao vizinho | `RELEASE_VM_ARGS=/dev/null` no ambiente, `/proc/net/tcp` → `00000000:A5B5`, sonda TCP do vizinho → aberta |
| `vm.args.eex` ou `ELIXIR_ERL_OPTIONS`? | **Os dois `.eex`.** O nó do `rpc`/`remote` também abre uma porta de escuta enquanto vive, e o `bin/the_band` lhe passa `remote.vm.args`, e não `vm.args`. Prefiro os arquivos porque esse é o mecanismo documentado do `mix release` (o próprio `vm.args` gerado diz *"requires changing both vm.args and remote.vm.args"*), e porque `ELIXIR_ERL_OPTIONS` vindo do painel seria sobrescrito ou concatenado de forma ambígua | `mix release` usou os `.eex` (cmdline do PID 1 traz `-kernel inet_dist_use_interface {127,0,0,1}`). O nó `rem-…-the_band@127.0.0.1` escutou em `0100007F:8F1B` |
| Produção é um nó só? | O código aceita cluster (`lib/the_band/application.ex:35`, `config/runtime.exs:107`, `:ignore` quando a variável falta). O nome `the_band@127.0.0.1` impede o cluster. **Não verifiquei** se `DNS_CLUSTER_QUERY` está no painel do Dokploy | B4 |
| `/run` é tmpfs no Docker? | **Não.** Sem mount em `/run`, que fica na camada gravável do contêiner | `mount` no contêiner. Ver B5 |
| `releases/COOKIE` apagar ou ignorar? | **Apagar.** Com `RELEASE_COOKIE` exportado o `bin/the_band` não lê o arquivo, mas um cookie conhecido de todo mundo que tem a imagem, à espera de o arquivo faltar, é o fallback silencioso de B1 | `ls /app/releases` no protótipo: só `0.12.0` e `start_erl.data` |
| `RELEASE_COOKIE` no environ do PID 1 é legível por quem? | `/proc/1/environ` é `0400`, dono `band`. O root do `docker exec` recebeu **`Permission denied`**, porque o perfil padrão do Docker não lhe dá `CAP_SYS_PTRACE` sobre processo de outro uid. O root do host lê | `stat` e `cat` no contêiner |
| O cookie aparece em `ps`/cmdline? | **Sim**: `-setcookie <valor>` na cmdline do PID 1 (`beam.smp`) e de cada `rpc`/`remote`. Já era assim antes. `docker top` mostra, e o `ps` do host mostra a qualquer usuário do VPS | contagem de `-setcookie` em `docker top`: 1. Ver B3 |
| Regressões em HEALTHCHECK, `rpc`, `remote`, `eval`? | Nenhuma medida | ver a tabela de regressões |

### Regressões medidas no protótipo

| Comando | Como | Resultado |
|---|---|---|
| HEALTHCHECK | `/app/bin/saude` como root; `docker inspect` | `ok`, `EXIT=0`; `healthy` |
| `rpc` do runbook | `docker exec` (root) | `id -u` dentro do nó → `1000`. A guarda A1 continua valendo |
| `rpc` | `docker exec -u band` | `node()` → `the_band@127.0.0.1` |
| `pid` | root | `1` |
| `remote` | root, IEx com stdin aberto | conectou (`iex(the_band@127.0.0.1)1>`), nó remoto com `uid=1000`, escuta em loopback |
| `eval` com o contêiner no ar | root e `band` | `:erlang.is_alive()` → `false` (o `eval` não abre distribuição) |
| `eval` com o contêiner **parado** (restauração, `docker run --entrypoint`) | sem arquivo de cookie | funciona, com cookie efêmero (B1) |
| `start`/`rpc` sem o arquivo | `docker run --entrypoint /app/bin/the_band` | `RECUSADO: /run/the_band/cookie ausente ou ilegível (#1162)` |
| `docker restart` | | cookie regenerado, `saude` → `ok` |

## Achados

### B1 — Média. "Usar o arquivo quando existir" volta em silêncio ao cookie da imagem

**O que é (A04, desenho inseguro; A05; ASVS V14.1, V1.4). Princípio VIII, fallback silencioso.**
O desenho proposto faz `export RELEASE_COOKIE="$(cat …)"` *quando o arquivo existe*. O
`bin/the_band` gerado faz em seguida `RELEASE_COOKIE="${RELEASE_COOKIE:-"$(cat "$RELEASE_ROOT/releases/COOKIE")"}"`.
Quando o arquivo falta, vale o cookie da imagem, e nada avisa. Ele falta em qualquer caminho que
não passe pelo entrypoint: `docker run --entrypoint`, um entrypoint futuro reescrito, ou um
`compose` de ensaio.

**Caminho.** Junto com uma regressão de B2, ou numa instância de ensaio ou restauração que suba
sem o entrypoint, o nó volta a aceitar o cookie que todo detentor da imagem conhece. É o mesmo
atacante de A6.

**O que fecha.**
- `Dockerfile`: `rm /app/releases/COOKIE` depois do `chown`. A falta passa a ser ruidosa, e não há
  mais segredo dentro da imagem;
- `env.sh.eex`: arquivo legível → `RELEASE_COOKIE` vem dele, e **sobrescreve** o que vier do
  ambiente, para que um `RELEASE_COOKIE` posto no painel não apareça no `docker inspect`. Arquivo
  ausente e comando `eval` → cookie efêmero aleatório. O `eval` não abre distribuição (medido:
  `is_alive` → `false`), então o cookie dele não tem função de segurança, e isto não é fallback de
  segurança. É o que mantém o `eval` de restauração do runbook (`docs/producao/runbook.md:360`)
  funcionando com o contêiner parado. Arquivo ausente e qualquer outro comando → **recusa** com
  mensagem nomeando o arquivo.

### B2 — Média. A interface só no `vm.args`, ou só no epmd, deixa a porta de distribuição aberta

**O que é (A05; ASVS V14.4).** Três formas de errar, todas plausíveis:
- **só `ERL_EPMD_ADDRESS`:** o epmd vai para o loopback, mas a porta de distribuição continua em
  `0.0.0.0`. Medido com o defeito injetado: o vizinho abriu conexão TCP com ela. Esconder a porta
  do epmd não a fecha, porque ela se acha por varredura. Com o `rpc` de fábrica a conexão falhou
  na conferência de nome do nó. **Não desenvolvi** cliente de distribuição sob medida para
  contornar isso, porque o papel é defensivo. O teste, então, assere o **endereço de escuta** e
  não o fracasso do `rpc`;
- **só `vm.args.eex`, sem `remote.vm.args.eex`:** o nó do `rpc`/`remote` escuta em `0.0.0.0`
  enquanto vive. Para o `remote`, que é IEx aberto por minutos, isso é uma janela real;
- **`RELEASE_VM_ARGS` no ambiente:** o `bin/the_band` respeita a variável. Com
  `RELEASE_VM_ARGS=/dev/null` a porta foi para `0.0.0.0` (medido). Quem controla o painel já é
  confiável, então o risco é de **erro**, e não de ataque. Mesmo assim, a guarda que um valor
  esquecido desfaz não é guarda.

**O que fecha.** `rel/vm.args.eex` e `rel/remote.vm.args.eex` com
`-kernel inet_dist_use_interface {127,0,0,1}`. O `env.sh.eex` fixa
`RELEASE_VM_ARGS="$REL_VSN_DIR/vm.args"` e `RELEASE_REMOTE_VM_ARGS="$REL_VSN_DIR/remote.vm.args"`,
como faz com `RELEASE_NODE`. A variável `REL_VSN_DIR` já está definida quando o `env.sh` é
incluído (conferido no `bin/the_band` gerado).

### B3 — Baixa, anterior ao desenho. O cookie na linha de comando

**O que é (A02; ASVS V8.3).** O `bin/the_band` passa `--cookie "$RELEASE_COOKIE"`, que vira
`-setcookie` na cmdline do `beam.smp` (PID 1) e de cada `rpc`/`remote`. `/proc/<pid>/cmdline` é
legível por qualquer uid. No contêiner só existem root e `band`. No host, `ps` mostra o valor a
qualquer usuário do VPS.

**Caminho, e por que é Baixa.** Depois de B2, o cookie sozinho não dá acesso de fora do namespace
de rede do contêiner (medido: com o cookie certo, o vizinho recebe `:noconnection`). Quem lê o
`ps` do host e consegue entrar no namespace do contêiner já é root no host. Não há correção barata:
o script é gerado pelo Elixir, e evitar o `-setcookie` exige reescrevê-lo. Recomendo declarar e
não corrigir agora.

### B4 — Baixa. `DNS_CLUSTER_QUERY` passa a quebrar o cluster em silêncio

**O que é (A04; princípio VIII).** Com o nome fixo `the_band@127.0.0.1`, um `DNS_CLUSTER_QUERY`
definido faz o `DNSCluster` tentar nós que nunca respondem. A aplicação sobe, e o cluster não
existe. O desenho declara que o loopback quebra cluster, e a declaração precisa virar
comportamento.

**O que fecha.** O entrypoint **recusa subir** quando `DNS_CLUSTER_QUERY` não estiver vazio, com a
mensagem *"distribuição só no loopback (#1162): cluster exige outro desenho"*. Cluster passa a
ser feature própria (TLS na distribuição, `inet_tls_dist`, e cookie por segredo compartilhado).
**Não verifiquei** se a variável existe no painel de produção. Se existir, isto derruba o deploy,
e é melhor descobrir no ensaio.

### B5 — Informativo. `/run` não é tmpfs

O arquivo fica na camada gravável do contêiner. Sobrevive a `docker restart`, mas é regenerado a
cada start (medido: o hash mudou), então o que sobrevive é um cookie morto até o boot seguinte. Um
`docker commit` ou `docker export` do contêiner **no ar** leva o cookie vigente. Isso só ajuda quem
já alcança o loopback do contêiner, e por isso não é achado. O entrypoint deve fazer `rm -rf
/run/the_band` antes de recriar, para não herdar modo nem dono de um start anterior. Não use
`/run/secrets`, que é o ponto de montagem do Dokploy.

### B6 — Informativo. O que o desenho não muda

- a porta HTTP 4000 continua em `::`, por desenho, porque é o serviço;
- `127.0.0.11` em escuta é o resolvedor DNS embutido do Docker, e não é desta aplicação;
- quem já executa como `band` (o atacante de S5 pós-exploração) continua no nó. A6 era sobre
  chegar **pela rede**, e é só isso que este conserto fecha.

## Desenho corrigido

**`rel/vm.args.eex` e `rel/remote.vm.args.eex`** (iguais, com comentário do porquê):

```
## #1162: a distribuição escuta só no loopback, inclusive o nó do rpc/remote.
-kernel inet_dist_use_interface {127,0,0,1}
```

**`rel/env.sh.eex`**, antes da guarda de root existente, para que root também seja recusado sem o
arquivo:

```sh
export ERL_EPMD_ADDRESS=127.0.0.1
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=the_band@127.0.0.1
export RELEASE_VM_ARGS="$REL_VSN_DIR/vm.args"
export RELEASE_REMOTE_VM_ARGS="$REL_VSN_DIR/remote.vm.args"
if [ -r /run/the_band/cookie ]; then
  RELEASE_COOKIE=$(cat /run/the_band/cookie)
  export RELEASE_COOKIE
elif [ "$RELEASE_COMMAND" = eval ]; then
  # o eval não abre distribuição; o cookie só precisa existir
  RELEASE_COOKIE=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
  export RELEASE_COOKIE
elif [ "$RELEASE_COMMAND" != version ]; then
  echo "RECUSADO: /run/the_band/cookie ausente ou ilegível (#1162)" >&2
  exit 1
fi
```

**`rel/entrypoint.sh`**, depois de conferir que é root e **antes** da migração e de qualquer
`como_band`. O `umask 077` que já existe faz o arquivo nascer `0600`:

```sh
if [ -n "$DNS_CLUSTER_QUERY" ]; then echo "RECUSADO: …(#1162)" >&2; exit 1; fi
rm -rf /run/the_band
install -d -o root -g band -m 0750 /run/the_band
openssl rand -hex 32 > /run/the_band/cookie.novo
chgrp band /run/the_band/cookie.novo
chmod 0440 /run/the_band/cookie.novo
mv /run/the_band/cookie.novo /run/the_band/cookie
```

**`Dockerfile`**: `… && chmod -R go-w /app && rm /app/releases/COOKIE`.

No protótipo, a versão sem as linhas de `RELEASE_VM_ARGS`, `version` e `DNS_CLUSTER_QUERY` foi a
medida acima. As três linhas acrescentadas **não foram executadas**. Não há passo manual para a
pessoa mantenedora, salvo tirar `DNS_CLUSTER_QUERY` do painel, se estiver lá.

## Cenários de teste, com o defeito a injetar

Dono da forma: QA. A prova é no contêiner, como em `evidencia-1140.md`. A guarda textual em
ExUnit, se houver, lê o arquivo **sem comentários** e assere o controle, e não a prosa.

| # | Cenário (atacante, meio, esperado) | Asserção | Defeito a injetar, que deve reprovar |
|---|---|---|---|
| T1 | no contêiner no ar, nada da distribuição escuta fora do loopback | todo socket `0A` de `/proc/net/tcp{,6}` é `0100007F`/`::1` ou é a 4000; **e** há ao menos um socket de distribuição (senão a medida é vazia) | tirar a linha de `vm.args.eex` → porta em `00000000` (medido) |
| T2 | epmd só no loopback | 4369 (`1111`) nunca em `00000000` | tirar `ERL_EPMD_ADDRESS` → `00000000:1111` (medido na linha de base) |
| T3 | o nó do `remote` escuta no loopback | durante um `remote` aberto, o socket novo é `0100007F` | tirar a linha de `remote.vm.args.eex` |
| T4 | vizinho na mesma rede Docker, com o cookie da imagem anterior, tenta `rpc` | `refute` execução; `:noconnection`. **Controle positivo** obrigatório: o mesmo comando contra a imagem antiga executa `id` | reverter T1+T2 → o vizinho executa (medido na linha de base) |
| T5 | vizinho com o cookie **certo** | `:noconnection`; sonda TCP à porta de distribuição recusada, e à 4000 aberta (controle da sonda) | reverter T1 → porta alcançável (medido) |
| T6 | dois contêineres da mesma imagem, e um contêiner antes e depois de `docker restart` | cookies diferentes (comparar hash, nunca imprimir) | cookie fixo no entrypoint |
| T7 | imagem sem cookie embutido; `start` e `rpc` sem o arquivo | `/app/releases/COOKIE` ausente; recusa com a mensagem; `eval` funciona | tirar o `rm` do Dockerfile e a recusa do `env.sh` → `start` sobe com o cookie da imagem |
| T8 | `RELEASE_VM_ARGS=/dev/null` no ambiente | a porta continua em loopback | tirar o fixar de `RELEASE_VM_ARGS` → `00000000` (medido) |
| T9 | arquivo e diretório | `0440 root:band` e `0750 root:band`; `band` não escreve no diretório | `chmod 0644` / diretório `0770` |
| T10 | `DNS_CLUSTER_QUERY=x` | o contêiner não sobe, e a mensagem nomeia #1162 | tirar a recusa → sobe |
| T11 | regressões | `saude` → `ok`; `rpc` root → `id -u` `1000`; `remote` conecta; `eval` com `is_alive` `false`; `healthy` | — |

## O que não verifiquei

- **quem compartilha a rede Docker do contêiner no VPS** e se o Dokploy roda esta *Application* com
  `network_mode: host`. Com rede do host, o loopback seria o do VPS, e qualquer processo do host
  alcançaria a distribuição, e aí o cookie volta a ser a única barreira;
- **o Docker de produção:** medi no Docker Desktop, que é kernel Linux numa VM. A semântica de
  namespace de rede é a mesma, mas não medi no VPS;
- **se `DNS_CLUSTER_QUERY` está no painel** (B4), e se o Dokploy monta algo sobre `/run` além de
  `/run/secrets`;
- **as três linhas acrescentadas ao desenho depois da medição** (fixar `RELEASE_VM_ARGS`/
  `RELEASE_REMOTE_VM_ARGS`, isentar `version`, recusar `DNS_CLUSTER_QUERY`): não foram executadas;
- **`restart`, `stop`, `start_iex`, `daemon`:** passam pelo mesmo `rpc`/`start` e pelo mesmo
  `env.sh`, mas não os executei;
- **cliente de distribuição sob medida** contra a porta exposta (B2): não desenvolvido, por ser
  exploit. A conclusão "porta alcançável é exposição" não depende dele;
- **distribuição em IPv6:** `inet_tcp_dist` é IPv4, e não vi socket de distribuição em `tcp6`. Não
  testei `-proto_dist inet6_tcp`;
- **a cache de build do Docker:** apaguei imagens, contêineres, rede e volume. Não rodei
  `docker builder prune`, para não apagar a cache de outras sessões. As camadas intermediárias do
  protótipo podem ter ficado nela, e nenhuma contém o cookie gerado em runtime;
- **`mix gates`, `mix test`:** não rodei, por instrução. Nenhum veredito de gate está implícito
  aqui.
