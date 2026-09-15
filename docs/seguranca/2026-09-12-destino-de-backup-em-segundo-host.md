# A superfície de risco do destino de backup em segundo host

**Decisão da pessoa mantenedora em 2026-09-12**: o MinIO deixa de ser só o destino do
**ensaio** do §6 e passa a guardar **o backup de produção**, num segundo host.

Este documento declara a superfície de risco dessa decisão. Ele **não** decide se ela entra,
nem quando — severidade é deste papel, prioridade é do Product Owner. Cada achado abaixo é
dimensionável: onde, caminho concreto, consequência de negócio, correção proposta e o cenário
de teste que fecha.

**Recorte declarado**: esta é uma passagem sobre **a decisão**, e não uma varredura do
repositório. O que a decisão muda é o que tem risco novo. A §9 diz o que ficou fora.

---

## 0. O que esta passagem mediu, e com quê

Zero achados é o estado normal desta base, e é indistinguível de ferramenta quebrada. Por isso
a lista abaixo diz **o que cada comando leu**, e não só que rodou.

| medida | comando | resultado |
|---|---|---|
| o que um dump carrega | `pg_dump -U postgres -d the_band_dev` no contêiner `the_band_postgres` | **247,8 MB** em texto; 37,5 MB comprimido; banco de 220 MB |
| a chave mestra está no dump? | valor de `THE_BAND_MASTER_KEY` do `.env` local, por *pipe*, contra o dump | **0 ocorrências** |
| o segredo da credencial está cifrado no dump? | leitura do campo 5 do `COPY public.tool_credentials` | `\x…` com o rótulo `AES.GCM.` em hexadecimal — **texto cifrado** |
| há segredo em claro no dump? | busca por padrão de token do GitHub e de chave de LLM | **1 ocorrência** de token do GitHub, em `oban_jobs.errors` → **H17** |
| o balde nasce protegido? | `mc version info`, `mc retention info`, `mc ilm rule ls`, `mc encrypt info`, `mc anonymous get` no MinIO local | privado **sim**; versionamento, trava, ciclo de vida e cifra **não** → **H20** |
| a credencial do destino fica legível? | `docker inspect the_band_minio_balde --format '{{json .Config.Entrypoint}}'` | usuário e senha **resolvidos em claro** na configuração do contêiner → **H22** |
| a aplicação fala com o destino? | `grep -rin "minio\|s3\b\|aws_" lib/ --include="*.ex"` | **nenhum cliente** — as ocorrências são `US3`, `--s3` de CSS e nomes de spec |

**Nenhum segredo foi lido, escrito ou transportado para este documento.** A verificação da
chave mestra foi feita por *pipe* (`printf | grep -F -f -`), sem o valor passar por argumento
de processo nem por arquivo. O trecho do H17 é impresso **até o caractere anterior** ao
casamento.

O valor medido do dump vem do **banco de desenvolvimento**. O de produção não é legível daqui,
e a §9 registra isso como o que é.

---

## 1. O que a decisão muda, em uma frase

Até 2026-09-12 o MinIO guardava **arquivos de ensaio**: um `.txt` escrito e lido de volta, num
volume descartável, numa máquina de desenvolvimento. A partir desta decisão ele guarda **o
banco de produção inteiro**, todo dia, para sempre.

O que muda com isso **não é o MinIO** — o protocolo é o mesmo, e o que o ensaio de 2026-09-12
provou continua provado. O que muda é **o valor do alvo**, e é isso que reordena tudo:

| antes | depois |
|---|---|
| perder o balde custa um ensaio | perder o balde custa **o caminho de volta da produção** |
| ler o balde não revela nada | ler o balde revela **contas, hashes, sessões, escopos e credenciais** |
| o host é a máquina de quem desenvolve | o host é **infraestrutura de produção**, com as obrigações dela |
| credencial de desenvolvimento, declarada pública | credencial que, comprometida, entrega tudo acima |

E há uma diferença que atravessa este documento inteiro: **nada disso é observável pela
plataforma**. Não há sessão, não há log de aplicação, não há tela. O regime de registro de
`AGENTS.md` §15 e a FR-009 da 050 valem para a aplicação; o destino de backup fica fora dele.
Um acesso indevido ao balde não produz sinal nenhum — que é a forma mais pura do "sucesso
silencioso" desta base: não há erro, e não há resultado.

---

## 2. O que este host passa a guardar — medido, não suposto

O dump é o banco **inteiro**. Não há recorte, não há redação, não há coluna que fique de fora.
Conferido no dump de 2026-09-12, pelas linhas de `COPY` que ele contém:

| linha do dump | tabela | o que sai da máquina junto |
|---:|---|---|
| 194864 | `users` | `email`, `password_hash`, `password_set_at`, **`session_token`**, `failed_attempts`, `role`, `disabled_at`, e o elo conta↔pessoa completo (`person_id`, quem declarou, quando, quem revogou) |
| 1695 | `access_scope_grants` | todo o escopo de acesso: `level`, `target_id`, quem concedeu, quem revogou, quando |
| 194839 | `tool_credentials` | `secret` **cifrado**, `last_four` em claro, `owner_login`, `scopes` |
| 1711 | `ai_provider_credentials` | `secret` **cifrado**, `base_url`, `provider` |
| 138282 | `oban_jobs` | `args` e **`errors`** — e é aqui que mora o H17 |

E o volume, que importa para a retenção: as cinco maiores tabelas do banco de desenvolvimento
são `collected_verifications` (35 MB), `raw_payloads` (30 MB), `collected_change_requests`
(27 MB), `collected_commits` (27 MB) e `spo_performed_project_activities` (19 MB).
`raw_payloads` é a proveniência do princípio III — a resposta bruta do GitHub, com o que ela
trouxer dentro.

**A frase que resume**: comprometer o destino de backup é comprometer a produção inteira, com
a agravante de que a produção não tem como saber.

---

## 3. Os achados, ordenados por severidade

A numeração continua a de `2026-09-09-o-que-consertar-agora.md`, que foi de **H1 a H16**.

### H17 — o dump carrega um token do GitHub **em claro**, e a cifra do Vault não o protege

**Severidade: Alta** · OWASP **A02** (falhas criptográficas) e **A09** (registro) · ASVS
**V7.1.1** (dado sensível não vai para registro) e **V6.2** (segredo em repouso)

**Este é o achado que muda a premissa da decisão.** A pergunta feita ao papel foi: *o dump
carrega o texto cifrado, e a chave está fora dele?* A resposta é **sim para a chave e sim para
o texto cifrado — e mesmo assim há um segredo em claro dentro do dump**, por um caminho que
não passa pelo Vault.

**Onde.** `lib/the_band/integrations/github/client.ex:252`:

```elixir
def graphql(instance_url, token, query, variables \\ %{}, opcoes \\ []) do
```

O token é o **segundo argumento posicional**, um `binary` nu. Os chamadores são a coleta
inteira — `lib/the_band/ingestion/github_projects.ex:100` e `:376`,
`github_change_requests.ex:427` e `:503`, `github_issue_comments.ex:270`,
`github_branches.ex:222`, `github_commit_files.ex:92`, entre outros, todos na forma
`Client.graphql(ctx.tool.instance_url, ctx.token, …)`.

**O mecanismo.** Quando a exceção é `UndefinedFunctionError` ou `FunctionClauseError`, o quadro
da pilha carrega a **lista de argumentos reais**, e `Exception.format/3` a imprime com
`inspect/1`. O Oban grava essa string formatada em `oban_jobs.errors`. O `redact: true` do
schema (`lib/the_band/sources/tool_credential.ex:31` e
`lib/the_band/ai/provider_credential.ex:27`) protege o `inspect` **da struct**; não protege um
argumento solto que já foi decifrado por `Sources.fetch_secret/1`
(`lib/the_band/jobs/sync_github_eo.ex:60`).

**Medido, e não deduzido.** No dump do banco de desenvolvimento de 2026-09-12
(259.813.424 bytes), **linha 138649**, campo 6 (`errors`) do `COPY public.oban_jobs` declarado
na linha 138282:

```
queue=ingestion  worker=TheBand.Jobs.SyncGitHubEO  state=cancelled  attempt=5
campo com o match: 6 (errors)  tamanho=9462
posicao do match no campo: 5711 de 9462
```

O cabeçalho do erro, nos primeiros 240 caracteres do campo:

```
{"{\"at\": \"2026-09-04T18:07:40.297990Z\", \"error\": \"** (ArgumentError) unknown registry:
TheBand.PubSub. Either the registry name is invalid or the registry is not running, …
```

E os **200 caracteres imediatamente anteriores** ao casamento — nada do token é impresso:

```
Client.graphql/4 is undefined (module TheBand.Integrations.GitHub.Client is not available)
    (the_band 0.5.0) TheBand.Integrations.GitHub.Client.graphql(\"https://github.com\", \"
```

O que vem depois dessa aspas é o segundo argumento. É o token.

**O caminho de exploração.** Quem obtiver um arquivo de backup — por credencial do destino, por
acesso ao host, por objeto legível por engano — lê um token de ferramenta do GitHub por
extenso, **sem precisar da chave mestra**. Com ele, alcança no GitHub o que os `scopes`
daquela credencial permitirem, fora da plataforma e sem passar por nenhuma das defesas dela.

**E o Pruner não conserta.** `config/config.exs:98` — `{Oban.Plugins.Pruner, max_age: 60 * 60 *
24 * 7}`. A linha sai da base em sete dias; **não sai do backup que já foi escrito**. Cada
cópia diária tirada enquanto a linha existia guarda o token para sempre. Sem regra de ciclo de
vida no destino (H20), "para sempre" é literal.

**Consequência para o negócio.** Um token de acesso ao GitHub da organização observada, válido
e em claro, dentro de um arquivo que a partir desta decisão é copiado todo dia para outra
máquina e guardado indefinidamente.

**O que fecha:**

1. **rotacionar a credencial encontrada.** Segredo que apareceu, apareceu — o achado é
   rotacionar, não apagar a linha. Vale para a credencial do banco de desenvolvimento onde a
   medida foi feita, e para o que a varredura da produção encontrar;
2. **varrer `oban_jobs.errors` na produção** pelo mesmo padrão e **redigir** as linhas — e a
   varredura precisa acontecer **antes** da primeira cópia para o novo destino, senão o
   problema é copiado com ela;
3. **o token deixa de ser `binary` nu na fronteira**: um tipo opaco com
   `@derive {Inspect, except: [...]}`, ou carregado dentro de uma struct redigida no `ctx`. É o
   único conserto que sobrevive ao próximo `FunctionClauseError` — apagar linhas trata o
   sintoma, e o sintoma volta;
4. **`redact` não basta, e isso vai escrito**: o achado existe apesar de os dois schemas o
   terem.

**Cenário de teste para o QA** (a asserção é `refute`, e a garantia é sobre o texto formatado):

> Provocar um `FunctionClauseError` numa chamada de `Client.graphql/5` que recebeu um token de
> teste reconhecível, formatar a exceção com `Exception.format(:error, erro, pilha)`, e asserir
> que a string **não contém** o valor do token. Guarda obrigatória: asserir antes que a string
> formatada tem tamanho maior que zero e contém o nome da função — senão o teste celebra uma
> string vazia.
>
> O teste tem de **reprovar hoje**. Se passar antes da correção, ele não mediu o caminho certo.

---

### H18 — o dump atravessa a rede em claro se o destino falar `http://`

**Severidade: Alta** (condicional à topologia do segundo host) · OWASP **A02** · ASVS
**V9.1.1** (TLS em toda comunicação de saída)

**Onde.** `compose.yaml:160` — `mc alias set local http://minio:9000 …` — e `compose.yaml:124`
— `command: server /data --console-address ":9001"`, sem `--certs-dir`. O MinIO de hoje só
fala HTTP.

**Isto está correto para o que existe hoje** e é preciso dizê-lo: no ensaio local, `minio` é um
nome da rede do compose e o tráfego não sai da máquina. O comentário do `compose.yaml:106-110`
já declara que este é o destino do ensaio.

**O que a decisão muda.** Com o destino noutro host, `http://` significa **o banco de produção
inteiro em claro no fio**, todo dia: os hashes de senha, os `session_token`, os escopos, o
`raw_payloads`. O texto cifrado atravessa cifrado e continua protegido; todo o resto, não.

**A relação com o H9, que continua aberto.** `config/runtime.exs:86` ainda traz `# ssl: true,`
comentado, e o H9 dizia que a severidade dependia de uma topologia não verificada. Esta decisão
**acrescenta uma segunda superfície à mesma pergunta**: agora não é só se a base fala com a
aplicação em claro, é também se o dump sai da base em claro para outro host. As duas se
respondem juntas, e com a mesma informação.

**O que fecha.** Endpoint `https://` com certificado válido e **verificação de par**; o MinIO
sobe com `--certs-dir` e certificado próprio. E a recusa de TLS tem de ser **erro**, nunca
queda para HTTP — um cliente S3 que "tenta HTTPS e volta para HTTP" reintroduz exatamente o
problema depois da configuração, e é o antipadrão de fallback silencioso do princípio VIII.

**Cenário de teste.** Não é teste de suíte — é medida de operação, e o número dela vai para
`docs/producao/`: `openssl s_client -connect <destino>:<porta>` devolve certificado válido, e
uma tentativa de escrita por `http://` **falha**.

---

### H19 — a credencial que escreve o backup não pode ser a raiz do destino

**Severidade: Alta** · OWASP **A01** (quebra de controle de acesso — privilégio além do
necessário) · ASVS **V4.1.3** (menor privilégio)

**Onde.** `compose.yaml:128-129` e `:160` — a criação do balde usa `MINIO_ROOT_USER` e
`MINIO_ROOT_PASSWORD`. No MinIO, a raiz cria e **apaga** balde, apaga objeto, troca política e
cria outras chaves de acesso.

**O caminho concreto.** A credencial do destino tem de estar **no lado que escreve** — no host
de produção, no painel que agenda o job. Quem comprometer a produção alcança essa credencial;
é a premissa, não a exceção. Se ela for a raiz, o comprometimento não para na produção: apaga o
balde. **Um incidente vira perda do caminho de volta**, que é o oposto exato do que o backup
existe para garantir. É o mesmo movimento de um ransomware: primeiro o backup, depois o resto.

**O que fecha.** Chave de acesso **dedicada ao job**, com política restrita a um balde e a um
prefixo:

| a política concede | a política **não** concede |
|---|---|
| `s3:PutObject` no prefixo do backup | `s3:DeleteObject` |
| `s3:ListBucket` **só se** o cliente exigir para escrever | `s3:DeleteBucket` |
| — | `s3:GetObject`, se o cliente não precisa reler o que escreveu |
| — | qualquer operação administrativa do MinIO |

E **a leitura para restaurar é outra credencial**, usada por pessoa, na hora do ensaio, e não
publicada no ambiente do job. São dois papéis diferentes e não têm razão para compartilhar
chave.

**Cenário de teste.** Medida de operação, feita uma vez e registrada: com a credencial do job,
`mc rm` sobre um objeto recém-escrito **falha com negação de acesso**, e `mc rb` sobre o balde
**falha**. Se passarem, a política não é a que se pensa que é. É a mesma disciplina de injetar
o defeito de mentira: o controle só está provado quando a operação proibida **reprova**.

---

### H20 — o balde nasce sem versionamento, sem trava, sem ciclo de vida e sem cifra — e a trava **só** se liga na criação

**Severidade: Alta** · OWASP **A08** (integridade) e **A05** (configuração) · ASVS **V14.1**,
**V10**

**Onde.** `compose.yaml:161-162`:

```
mc mb --ignore-existing local/${MINIO_BUCKET:-the-band-backup} &&
mc anonymous set none local/${MINIO_BUCKET:-the-band-backup}
```

**Medido em 2026-09-12** contra o MinIO local, pelas ferramentas do próprio servidor:

| pergunta | comando | resposta |
|---|---|---|
| é privado? | `mc anonymous get` | **`private`** — o único que já está certo |
| tem versionamento? | `mc version info` | `is un-versioned` |
| tem trava de objeto (WORM)? | `mc retention info` | `does not support locking` |
| tem regra de ciclo de vida? | `mc ilm rule ls` | `lifecycle configuration does not exist` |
| tem cifra do lado do servidor? | `mc encrypt info` | `server side encryption configuration was not found` |

**O caminho concreto.** Sem versionamento e sem trava, uma escrita por cima ou um `rm` remove o
objeto **definitivamente** — é o que dá ao H19 a consequência que ele tem. Sem cifra do lado do
servidor, o dump em repouso no segundo host é um arquivo legível por quem tiver o disco, o
volume ou a máquina.

**E há um detalhe que é o motivo desta ter severidade alta, e não média**: no protocolo do S3 a
trava de objeto **só pode ser habilitada na criação do balde** (`mc mb --with-lock`). Reusar a
forma do ensaio em produção **fecha a porta do WORM para aquele balde de vez** — corrigir
depois exige balde novo e recópia de todo o histórico. É uma decisão irreversível tomada por
omissão, e o custo dela só aparece no dia em que se precisa dela.

**O que fecha.** O balde de produção nasce com `--with-lock`, com versionamento ligado, com
cifra do lado do servidor, e com regra de ciclo de vida que implemente a retenção decidida
(H24). O de ensaio pode continuar como está — e a diferença entre os dois vai escrita, porque
"o ensaio prova o formato, o comando e o tempo" já está no item de backlog e continua
verdadeiro.

---

### H21 — o segundo host herda o valor da produção sem herdar nenhuma das defesas dela

**Severidade: Alta** · OWASP **A05** (configuração) e **A09** (registro e monitoramento) ·
ASVS **V14**, **V7**

**O que foi verificado, e é bom:** a aplicação **não fala com o destino de backup**.
`grep -rin "minio\|s3\b\|aws_" lib/ --include="*.ex"` não devolve cliente nenhum — as
ocorrências são `US3` de spec, `--s3` de CSS e nomes de arquivo. O `mix.exs` não traz
dependência de S3. Toda a superfície desta decisão é **de infraestrutura**, e isso é um recorte
útil: nenhum código de aplicação precisa mudar, e nenhum teste da suíte cobre o que vem a
seguir.

**E é exatamente por isso que o achado existe.** O que a plataforma não toca, os gates da
plataforma não medem:

| o que protege a aplicação | vale para o destino de backup? |
|---|---|
| `mix sobelow --exit low --skip` | **não** — não há código |
| `mix hex.audit` e `mix deps.audit` | **não** — auditam pacotes Hex, não imagem de contêiner |
| o veredito de `TheBand.Tenants.Access` | **não** — não há sessão nem tenant |
| o registro de `AGENTS.md` §15 e a FR-009 | **não** — não há `Logger` da aplicação |
| a CSP, o `force_ssl`, o `check_origin` | **não** |

Consequência: **um objeto lido indevidamente não deixa rastro**. A pergunta *"alguém baixou o
backup?"* não tem como ser respondida — do mesmo jeito que o H4 registra que *"não se sabe se
algo já aconteceu"*. Registro esta impossibilidade como resultado, e não como lacuna desta
passagem.

**O que fecha.**

1. **registro de auditoria do destino ligado.** O MinIO tem alvo de auditoria (por webhook),
   **desligado por padrão**. Os eventos mínimos: objeto escrito, objeto lido, objeto apagado,
   autenticação recusada, política alterada. Sem eles, um incidente no destino é indetectável
   por construção;
2. **o painel de administração (`:9001`) fora da internet** — `compose.yaml:131-132` publica
   `9000` e `9001`. Em produção, o console é uma interface administrativa completa sobre tudo
   que este documento lista;
3. **a imagem entra no regime de atualização.** A tag está fixada
   (`quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z`, `compose.yaml:122`), e isso está certo
   — mas tag fixa que ninguém revisa é versão que envelhece com CVE. **Não auditei as CVEs
   desta versão** (§9). Quem opera precisa de uma rotina, porque nenhum gate desta base a
   cobre;
4. **as obrigações de host de produção valem**: acesso por chave, sem senha; superfície de rede
   mínima; atualização do sistema.

---

### H22 — a credencial do destino em claro na configuração do contêiner, se a forma do ensaio for copiada

**Severidade: Média** · OWASP **A05** e **A02** · ASVS **V2.10** (segredo em repouso),
**V14.1**

**Onde.** `compose.yaml:158-164` — a credencial vai na linha de comando do `mc alias set`. O
compose resolve `${...}` **antes** de criar o contêiner, então o valor fica gravado na
configuração dele.

**Medido em 2026-09-12** (saída com o valor mascarado por esta passagem, e não pelo Docker):

```
docker inspect the_band_minio_balde --format '{{json .Config.Entrypoint}}'
["/bin/sh","-c"," mc alias set local http://minio:9000 <USUARIO> <SENHA-RESOLVIDA-EM-CLARO>
 && mc mb --ignore-existing local/the-band-backup && …"]
```

**Hoje isto é inofensivo, e a razão está escrita no próprio arquivo**: as credenciais são as de
`.env.example:85-86` (`theband` / `theband-ensaio-local`), declaradas de desenvolvimento no
comentário de `compose.yaml:126-127`. Nada vazou e nada precisa ser rotacionado.

**O que a decisão muda.** Copiar esta forma para produção põe o segredo do destino em texto
legível por qualquer processo com acesso ao daemon do Docker, e persistido no JSON de
configuração do contêiner **no disco do host**. É o mesmo tipo de defeito do `THE_BAND_ADMIN_SENHA`
que o runbook §8.4 manda remover do painel: enquanto o valor existir ali, é legível por quem
alcança ali.

**Onde as credenciais de produção têm de viver.** No **painel do Dokploy**, na configuração do
job de backup — que é onde a lista fechada do runbook §2 já põe `DATABASE_URL`,
`SECRET_KEY_BASE`, `THE_BAND_MASTER_KEY` e `PHX_HOST`. E o que **não** pode acontecer,
explicitamente:

- **não** no repositório, em nenhuma forma — `.env` está no `.gitignore:56-58`, e `.env.example`
  continua sem valor;
- **não** no `compose.yaml`, nem como padrão de `${VAR:-valor}`;
- **não** na linha de comando de nenhum contêiner, pelo motivo medido acima;
- **não** em chat, nem mascarada, nem "só para testar".

Se o painel do Dokploy não cifrar as variáveis em repouso — **o que eu não verifiquei** (§9) —,
isso é uma pergunta em aberto para quem opera, e vale para todos os segredos que já vivem lá,
não só para este.

---

### H23 — a chave mestra e o dump precisam de domínios de falha diferentes, e o ensaio precisa provar a decifragem

**Severidade: Média** · OWASP **A02** · ASVS **V6.4** (gestão de chave), **V2**

**Primeiro, a resposta à pergunta que foi feita: o dump carrega o texto cifrado, e a chave está
fora dele. Verificado, em três lugares:**

1. **no dump**: o campo `secret` da linha de `tool_credentials` é `\x…` em hexadecimal e
   contém o rótulo `AES.GCM.` (`4145532e47434d2e` em hexa) — a marca que
   `lib/the_band/vault.ex:56-58` deriva da própria chave. É texto cifrado, e ele carrega **qual
   chave** o cifrou, que é o detalhe de que a rotação depende (L10);
2. **a chave não está no dump**: o valor de `THE_BAND_MASTER_KEY` do `.env` local aparece
   **0 vezes** nos 247,8 MB;
3. **não há onde ela estar**: a chave vem só do ambiente —
   `config/runtime.exs:14` (`System.get_env("THE_BAND_MASTER_KEY")`) e `:33`
   (`THE_BAND_PREVIOUS_MASTER_KEY`) —, lida por `TheBand.Vault.master_key/0`
   (`lib/the_band/vault.ex:34, 90-94`). Não existe coluna que a guarde em tabela nenhuma. A
   FR-005 exige isso, e a exigência está cumprida.

**Então o risco não é do dump — é da operação, e tem duas metades.**

**A primeira: a chave não pode morrer com o host que ela protege.** Se `THE_BAND_MASTER_KEY`
viver apenas no painel do Dokploy do host de produção, o desastre que leva o host leva a chave
junto. O dump restaurado abre, as telas sobem, as pessoas aparecem — e `tool_credentials` fica
**ilegível para sempre**. O caminho de volta existe pela metade, e a metade que falta é a que
faz a plataforma voltar a coletar. É o item que a memória do projeto já registra como *"chave
mestra perdida, e o caminho de volta"*.

**A segunda: a chave não pode viver onde o dump vive.** Se a guarda da chave ficar no host de
backup, a cifra deixa de proteger: quem alcança o balde alcança as duas metades, e o texto
cifrado vira texto claro. A chave e o dump precisam de **domínios de falha diferentes** pela
mesma razão que o dump e a produção precisam — e não é a mesma decisão, é uma a mais.

**O que fecha.**

1. **guarda da chave fora dos dois hosts** — fora da produção e fora do backup;
2. **o ensaio do §6 ganha um sexto passo**: decifrar **uma** credencial na instância
   restaurada, e conferir que os quatro últimos caracteres batem com `last_four`, que está em
   claro na mesma linha e serve exatamente para isso. Restaurar sem decifrar não prova o
   caminho de volta — prova metade dele, e a metade provada não é a difícil;
3. **conferir se `THE_BAND_PREVIOUS_MASTER_KEY` continua publicada em produção.** Mantê-la viva
   mantém a chave que se quis aposentar — e a partir desta decisão ela passa a ser copiada
   junto do resto do ambiente, se o ambiente for copiado. **Não verificado** (§9); é pergunta
   para quem opera.

---

### H24 — retenção não existe, e "o disco encheu" é o modo de falha mais provável — em silêncio

**Severidade: Média** · OWASP **A08** e **A09** · constituição, princípio **VIII** (fallback
silencioso é antipadrão declarado) · ASVS **V7**

**Os números, medidos:** banco de desenvolvimento com **220 MB**; `pg_dump` em texto com
**247,8 MB**; comprimido, **37,5 MB**. Um por dia, sem regra de ciclo de vida (H20), é
crescimento **sem limite** — e este é o banco de **uma** organização, em desenvolvimento. O de
produção cresce com a coleta, e `raw_payloads` cresce com ela por construção (princípio III:
a proveniência não se apaga).

**O caminho concreto, e ele é o mais provável de todos deste documento:** o volume do segundo
host enche. O destino passa a recusar a escrita. O dump do dia **não existe**. E ninguém sabe,
porque:

- a plataforma não participa (H21) e não tem como registrar;
- o destino não tem auditoria ligada (H21);
- a falha aparece no painel do Dokploy, que **ninguém abre por rotina** — e a FR-007 exige
  literalmente que *"a falha da rotina MUST ser visível para quem administra"*.

O resultado é o defeito reincidente desta base na sua forma mais cara: **ausência de erro lida
como resultado**. A produção continua de pé, as telas continuam abrindo, e a rede de proteção
deixou de existir há semanas.

**O que fecha.**

1. **a retenção é decidida e escrita** — quantas cópias, por quanto tempo. **É decisão de
   negócio, não técnica**: a pergunta é *quantos dias de trabalho a organização aceita perder*,
   e quem responde é o Product Owner com a pessoa mantenedora. Sem o número, não há regra a
   configurar;
2. **regra de ciclo de vida no destino** que implemente esse número, e capacidade dimensionada
   a partir dele;
3. **o alerta é sobre a AUSÊNCIA, não sobre o erro.** A pergunta certa é *"o objeto de hoje
   chegou?"* — um job que falha silenciosamente não gera erro nenhum para alertar, e um job que
   nem roda, menos ainda. A ausência é o sinal;
4. **SC-006 medido**: a rotina roda 7 dias seguidos sem intervenção, e a **mais antiga**
   restaura. O critério já existe na spec 050 e nunca foi medido. "O backup mais antigo ainda
   abre" é uma pergunta diferente de "o backup de ontem abre", e só a segunda o ensaio do §6
   responde.

---

### H25 — o caminho de volta do próprio destino não existe

**Severidade: Média** · OWASP **A08** · ASVS **V14**

**Se o host de backup morrer, perde-se todo o histórico de cópias de uma vez** — e a produção
continua de pé, sem nenhum sinal de que está sem rede de proteção. A segunda camada declarada
no runbook §4.3 é o snapshot da Contabo, que cobre **o host de produção**; ela não cobre o host
de backup, e ninguém prometeu que cobriria.

O risco não é o de perder dado — é o de **estar desprotegido sem saber**, que é a condição em
que a 050/US2 já está desde a v0.1.0.

**O que fecha** — e são duas saídas legítimas, não uma:

| saída | o que custa | o que garante |
|---|---|---|
| terceira cópia noutro domínio de falha (o clássico 3-2-1) | um destino a mais para operar e pagar | a perda de um host não é a perda do histórico |
| **declarar o risco como aceito**, com quem decidiu, quando e por quê | nada, hoje | que a decisão seja **explícita** e releia-se no dia seguinte |

**O que não é aceitável é a terceira opção**, que é não decidir: o risco fica implícito,
ninguém o lê, e ele reaparece como surpresa. Liberação com risco em aberto vai para
`docs/releases/` como risco residual aceito — é o mesmo registro que o PR já exige.

---

### H26 — restaurar é reabrir sessões

**Severidade: Baixa** · OWASP **A07** · ASVS **V3** (gestão de sessão)

`users.session_token` está no dump (a coluna aparece no `COPY` da linha 194864), e
`lib/the_band_web/plugs/current_scope.ex:54` decide a sessão comparando o token do cookie com o
da linha:

```elixir
user.session_token != get_session(conn, :session_token) ->
```

Uma restauração devolve os `session_token` que existiam **no momento da cópia**. Quem tiver um
cookie daquele momento volta a ser aceito — inclusive uma sessão que foi encerrada depois, por
troca de senha ou por desligamento de conta. O mesmo vale para `password_hash`: restaurar
desfaz uma troca de senha feita após a cópia.

Não é exploração nova — é uma **consequência do procedimento** que precisa estar escrita no
runbook, porque quem restaura na pressa não a deduz. O passo é uma linha
(`UPDATE users SET session_token = NULL`), e a decisão de executá-la ou não é de quem opera: ela
derruba todo mundo, o que é aceitável num desastre e irritante num ensaio.

---

## 4. "Fora da máquina que ele protege": a leitura fraca, a forte, e qual a decisão precisa

A frase está na FR-007 (*"guardada fora da máquina de produção"*) e no item de backlog
(*"o incêndio que leva o banco leva o backup junto"*). Ela admite duas leituras, e a diferença
entre elas só aparece no dia do desastre.

| | **leitura fraca** — outro host | **leitura forte** — outro **domínio de falha** |
|---|---|---|
| o que exige | uma segunda máquina | outro provedor, outra conta, outra região, **outra credencial** |
| o disco da produção morre | **protege** | protege |
| o host da produção morre | **protege** | protege |
| a conta do provedor é suspensa ou perdida | **não protege** — os dois hosts caem juntos | protege |
| o data center tem incêndio ou queda longa | **não protege**, se os dois estiverem lá | protege |
| a credencial de administração do provedor é comprometida | **não protege** — quem entra alcança os dois | protege |
| um comprometimento da produção alcança o destino | depende só do H19 | H19 **mais** a separação de conta |

**Qual a decisão precisa.** A leitura fraca cobre o caso que motivou a frase — o disco e o
host —, e é honesto dizer que ela já é **muito melhor que o estado de hoje**, que é nenhum
destino. Mas ela não cobre os três últimos, e os três últimos têm uma coisa em comum: são
exatamente os cenários em que se precisa do backup e **não se pode pedir nada ao provedor**.

**A recomendação deste papel**: a leitura **forte** para o destino de produção, com um mínimo
que já a satisfaz sem custo alto — **outra conta no provedor, com credencial própria e
faturamento próprio**, ainda que na mesma região. É o que quebra o elo "uma credencial
comprometida alcança os dois", que é o pior dos três.

**E vale o registro de que isto é mudança de contrato.** A FR-014 da 050 diz, com todas as
letras: *"as cópias dos dados MUST usar o backup gerenciado do provedor da hospedagem
(snapshot/backup automático do VPS, guardado fora da máquina) — decisão de 2026-08-28"*. Um
MinIO operado pela casa **não é** o backup gerenciado do provedor. A própria FR-014 previu a
saída — *"se o backup do provedor não satisfizer a cadência ou o ensaio, o plano MUST
acrescentar uma rotina própria em vez de afrouxar o requisito"* —, e é isso que esta decisão
faz. Mas o princípio VI é explícito: **requisito de segurança que não vira FR não é rastreado,
e o que não é rastreado não é entregue.** A decisão de 2026-09-12 precisa virar emenda à
FR-014, ou FR nova numerada, com o que ela troca — e não uma linha de documento de backlog.

---

## 5. O que foi verificado nesta passagem e está correto

Afirmação de que algo está certo vem com como foi conferido. Estas quatro estão:

1. **a cifragem das credenciais sobrevive ao dump.** `tool_credentials.secret` sai como `bytea`
   hexadecimal com o rótulo `AES.GCM.<8 hex>` derivado da chave
   (`lib/the_band/vault.ex:56-58`) — texto cifrado, e ele diz qual chave o cifrou;
2. **a chave mestra não viaja no dump, e não tem onde estar.** 0 ocorrências do valor nos
   247,8 MB; e o único caminho de leitura é `System.get_env` em `config/runtime.exs:14` e `:33`
   (`lib/the_band/vault.ex:34, 90-94`). Não há coluna nem tabela que a guarde;
3. **o balde nasce privado.** `mc anonymous get` devolve `private` — o que o item de backlog
   afirmou em 2026-09-12 está conferido por medida independente;
4. **a aplicação não é superfície desta decisão.** Nenhum cliente S3 em `lib/`, nenhuma
   dependência de S3 no `mix.exs`. Nenhuma linha de código da plataforma muda por causa disto —
   o que significa que **nenhum gate desta base a cobre**, e é o H21.

---

## 6. Para o Product Owner — os itens de backlog propostos

**Propostos, não criados.** Quem prioriza é o papel de Product Owner, e severidade não é
prioridade. Os itens estão dimensionados para que a decisão seja sobre algo comparável.

| # | item | achado | severidade | o que fecha | se não entrar agora |
|---|---|---|:---:|---|---|
| **B1** | **o token em claro no `oban_jobs.errors`** — rotacionar a credencial, varrer e redigir a produção **antes** da primeira cópia, e fazer o token deixar de ser `binary` nu na fronteira | H17 | **Alta** | o teste de formatação da exceção reprova hoje e passa depois; a varredura da produção devolve zero | cada cópia diária leva um token válido para fora da máquina, e "para sempre" é literal sem ciclo de vida |
| **B2** | **a topologia do destino, decidida e escrita** — leitura forte ou fraca de "fora da máquina", TLS no transporte, e a FR-014 emendada | H18, §4 | **Alta** | a spec 050 tem a FR nova ou a emenda numerada; `openssl s_client` no destino devolve certificado válido | o dump atravessa a rede em claro e a decisão fica sem rastro no Spec Kit |
| **B3** | **a credencial do job escreve e só escreve** — chave dedicada, política sem `Delete`, leitura em credencial separada | H19 | **Alta** | `mc rm` e `mc rb` com a credencial do job **falham** com negação | um comprometimento da produção vira perda do caminho de volta |
| **B4** | **o balde de produção nasce protegido** — `--with-lock`, versionamento, cifra do servidor | H20 | **Alta** | os quatro comandos de `mc` da §3 devolvem o oposto do que devolvem hoje | a trava **só se liga na criação**: nascer sem ela fecha o WORM para aquele balde de vez |
| **B5** | **retenção decidida, ciclo de vida configurado, e alerta pela ausência** | H24 | **Média** | número de dias escrito; regra no destino; alerta que dispara quando o objeto do dia **não** chegou; SC-006 medido | o disco enche, o backup para, e ninguém sabe — pelo tempo que levar até alguém precisar dele |
| **B6** | **a chave mestra guardada fora dos dois hosts, e o ensaio prova a decifragem** | H23 | **Média** | passo 6 no runbook §6: decifrar uma credencial na instância restaurada e conferir contra `last_four` | a restauração devolve `tool_credentials` ilegíveis, e só se descobre no dia |
| **B7** | **as credenciais do destino no painel, e a forma do compose não é copiada** | H22 | **Média** | `.env.example` sem valor; nada de credencial em linha de comando de contêiner em produção | o segredo do destino fica legível por quem alcança o daemon do Docker, e gravado no disco do host |
| **B8** | **o segundo host entra no regime de infraestrutura** — auditoria do destino ligada, console fora da internet, rotina de atualização da imagem | H21 | **Média** | eventos de escrita, leitura e recusa registrados; `:9001` inalcançável de fora | acesso indevido ao backup é **indetectável por construção** |
| **B9** | **o caminho de volta do destino: terceira cópia ou risco aceito por escrito** | H25 | **Média** | ou o terceiro destino existe, ou `docs/releases/` registra quem aceitou, quando e por quê | o histórico inteiro se perde com um host, e a produção não sabe que está desprotegida |
| **B10** | **restaurar é reabrir sessões — o passo vai para o runbook §6** | H26 | **Baixa** | o runbook diz o que acontece com `session_token` e oferece a linha que os invalida | quem restaurar na pressa reabre sessões encerradas sem perceber |

**Sobre bloqueio.** Os quatro itens de severidade **Alta** são **recomendação** de bloqueio da
mudança de destino — não bloqueio declarado; a decisão é do Product Owner. A consequência,
escrita para que a decisão seja sobre ela:

> **B1 antes da primeira cópia.** As outras três podem ser feitas com o destino já em uso e
> corrigidas depois — **B1 não**, porque cada cópia tirada antes da correção guarda o token
> para sempre, e nenhuma correção posterior alcança o arquivo já escrito. B4 tem a mesma forma
> por outro motivo: a trava de objeto não se liga depois.

**E há um item que este documento não propõe, e diz por quê**: nada aqui pede que o **ensaio do
§6 espere**. O ensaio contra o MinIO local continua liberado e continua correto — ele prova
formato, comando e tempo, e nada nos dez achados acima muda isso. Adiá-lo trocaria um risco
medido por um risco desconhecido, que é o pior negócio disponível.

---

## 7. Para o QA — a ordem entre nós

Dos dez achados, **um** vira teste de suíte; os outros nove são medidas de operação, e a
diferença é que o segundo grupo não tem onde asserir.

| achado | quem escreve | onde vive |
|---|---|---|
| **H17** | eu escrevo o cenário, o QA escreve o teste | `test/`, nas convenções da casa |
| H18, H19, H20, H21, H22, H23, H24, H25 | medida de operação, feita uma vez e registrada | `docs/producao/`, com data, comando e saída |
| H26 | passo de procedimento | `docs/producao/runbook.md` §6 |

**O cenário do H17, completo:**

> **Quem**: quem obtém um arquivo de backup. **O que já tem**: o arquivo, e nada mais — nem a
> chave mestra, nem acesso à plataforma. **O que obtém**: um token do GitHub em claro.
>
> **O teste**: provocar um `FunctionClauseError` numa chamada de `Client.graphql/5` que recebeu
> um token de teste reconhecível (string óbvia de fixture, nunca segredo real), formatar com
> `Exception.format(:error, erro, pilha)` e **`refute`** que a string contém o valor do token.
>
> **A guarda que impede o verde falso**: antes do `refute`, asserir que a string formatada não
> é vazia e contém o nome da função. Sem isso, o teste passa com uma string vazia e celebra a
> medida que não aconteceu.
>
> **A prova de que ele mede**: ele tem de **reprovar hoje**, contra o código atual. Se passar
> antes da correção, ele não está medindo este caminho.

**A regra entre nós continua a mesma**: o achado vira teste **antes** de virar correção, senão
ele reincide num refactor e nada acusa. E o veredito dos gates é do QA, com o código de saída
lido.

---

## 8. O que este documento NÃO pede

Registrado para que não seja lido como mais do que é:

- **não pede que a decisão seja revertida.** MinIO num segundo host é melhor que nenhum
  destino, e "nenhum destino" é o estado de hoje;
- **não pede provedor gerenciado.** A FR-014 previa a rotina própria, e a §4 diz o que trocar
  para que ela seja legítima;
- **não pede que o ensaio do §6 espere** — ver a última nota da §6;
- **não declara que algo está seguro.** Declara o que foi verificado, com que ferramenta, e o
  que ficou fora.

---

## 9. O que eu NÃO verifiquei, e por quê

Esta seção é resultado, não ressalva. Sem ela o documento seria lido como *"o resto está
coberto"*, e não é isso que ele diz.

1. **o banco de produção.** Todas as medidas de dump desta passagem são sobre o **banco de
   desenvolvimento**, que é o que está legível daqui. O mecanismo do H17 é código
   compartilhado, e portanto vale nos dois; **se existe uma linha de `oban_jobs.errors` com
   token na produção, eu não medi**. A varredura é o primeiro passo do B1, e ela precisa
   acontecer antes da primeira cópia;
2. **o job de backup do Dokploy** — não sei como ele gera a cópia (`pg_dump` em texto? `-Fc`?
   comprimido?), se ele fala TLS com o destino, se ele faz verificação de par, nem como ele
   guarda o segredo do destino na própria base. Não abri o painel e não tenho acesso. **Tudo
   que este documento diz sobre o transporte e sobre a credencial vale para a forma do
   `compose.yaml`, que é o que existe escrito** — se o Dokploy fizer diferente, as severidades
   de H18 e H22 mudam, e para melhor ou para pior;
3. **o segundo host** — se ele já existe, em que provedor, em que conta, em que rede, e se a
   porta do MinIO fica alcançável da internet. É a informação que decide a severidade de H18 e
   H21, e ela é de quem opera;
4. **os segredos e as variáveis de produção** — não peço, não leio e não aceito em conversa.
   Inclui a pergunta do H23 sobre `THE_BAND_PREVIOUS_MASTER_KEY` continuar publicada, e a
   pergunta do H22 sobre o painel do Dokploy cifrar as variáveis em repouso;
5. **as CVEs da versão do MinIO fixada** (`RELEASE.2025-09-07T16-13-09Z`) e do `mc`
   (`RELEASE.2025-08-13T08-35-41Z`). `mix hex.audit` e `mix deps.audit` auditam pacotes Hex e
   **não** imagem de contêiner — não há gate nesta base que olhe para isto, e eu não rodei
   varredura de imagem;
6. **se o objeto escrito no ensaio de 2026-09-12 ainda está no balde local**, e o que ele
   contém. Medi as propriedades do balde, não o conteúdo dele;
7. **a restauração de verdade.** Este documento é sobre o **destino**; o item
   `backup-restaurado-de-verdade.md` continua aberto e continua sendo outra pergunta. Nada aqui
   prova que um dump desta base restaura;
8. **`mix gates`** — a árvore desta passagem toca apenas `docs/seguranca/`, e nenhum gate lê
   documentação. O código de saída está no fim deste documento, lido e não presumido;
9. **o custo.** Um segundo host, uma segunda conta e uma terceira cópia têm preço, e eu não o
   estimei. É informação que a priorização precisa e que este papel não produz.

**E o mais importante**: esta é uma passagem sobre **uma decisão**, guiada pelas oito perguntas
que a pessoa mantenedora escreveu. Dez achados não é o total do que existe na superfície de um
destino de backup — é o que uma leitura do repositório e uma medida do que está rodando
produzem sobre o que a decisão muda.

---

## Referências

**Nesta base**: `docs/backlog/minio-como-destino-do-ensaio-de-backup.md` ·
`docs/backlog/backup-restaurado-de-verdade.md` · `docs/producao/runbook.md` §2, §4, §6, §8 ·
`specs/050-em-producao/spec.md` (FR-007, FR-008, FR-009, FR-014, SC-003, SC-006) ·
`specs/001-github-eo-ingestion/contracts/credential-rotation.md` ·
`docs/seguranca/2026-09-09-o-que-consertar-agora.md` (H1–H16; H4 e H9 citados aqui) ·
`.specify/memory/constitution.md` (princípios III, V, VI, VIII, XI) · `AGENTS.md` §14, §15, §17

**Arquivos citados com linha**: `compose.yaml:116-164` · `.env.example:75-89` ·
`config/config.exs:98` · `config/runtime.exs:14, 33, 86` · `lib/the_band/vault.ex:34, 56-58,
90-94` · `lib/the_band/integrations/github/client.ex:252` ·
`lib/the_band/jobs/sync_github_eo.ex:60` · `lib/the_band/sources/tool_credential.ex:31` ·
`lib/the_band/ai/provider_credential.ex:27` · `lib/the_band_web/plugs/current_scope.ex:54`

**OWASP**: Top 10 (2021) A01, A02, A05, A07, A08, A09 · ASVS V2, V3, V4, V6, V7, V9, V10, V14

---

## O veredito dos gates

```
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"
EXIT=0
```

**16 gates verdes**, código de saída **0**, lido e não presumido — rodado em
2026-09-12 na árvore desta passagem, sobre `origin/development` mais este documento.
Sem `| tail`: o pipe devolveria o código do `tail`, e o veredito é o do `mix gates`
(constituição, princípio XI).

E o que isso **não** diz: nenhum dos 16 gates lê `docs/`, nenhum deles mede
infraestrutura, e **nenhum deles encontraria o H17** — o token está num dado do banco,
não no código. Verde aqui é o estado normal desta base, e é indistinguível de nada ter
sido procurado. O que este documento acrescenta é a busca que eles não fazem.
