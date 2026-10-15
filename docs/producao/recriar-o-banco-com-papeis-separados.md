# Recriar o banco de produção com os papéis separados (#1131)

**Para quem:** a pessoa mantenedora, executando em produção no Dokploy.
**Quando:** numa janela em que ninguém esteja usando a plataforma. Em 2026-10-12, não havia uso.
**Tempo:** cerca de 30 minutos, mais o tempo da coleta do GitHub, que roda sozinha depois.
**Resultado:** a aplicação passa a servir com `the_band_app`, que **não** desliga as guardas do
banco, e a migrar com `the_band_owner`. A conferência responde `papéis: separação em vigor`.

---

## Por que isto existe

Hoje a aplicação conecta ao banco como **superusuário** (`postgres`). Um superusuário consegue
desligar os triggers e as regras que protegem os dados que nunca podem ser alterados ou apagados: a
auditoria, as mudanças de papel, os episódios de suspensão. Se alguém um dia executar SQL pela
aplicação, por falha, dependência comprometida ou erro de código, poderia apagar o histórico e
esconder o que fez.

O log da subida da v0.12.0 (2026-10-09) mediu isso em produção:
`papéis: separação NÃO em vigor (superusuario, …)`. É a issue **#1131**, de segurança.

A separação divide o poder:

| usuário | para quê | o que pode |
|---|---|---|
| `the_band_owner` | migrar o esquema, só no deploy | criar e alterar tabelas |
| `the_band_app` | servir, a aplicação no dia a dia | ler e gravar linhas. **Não** desliga trigger, **não** altera tabela |
| `postgres` | administração e backup | tudo, e a aplicação deixa de usá-lo |

## O caminho escolhido, e por quê

Como ninguém usa a plataforma, **recriar a base** é mais simples do que transferir a posse da
atual, e o resultado é mais limpo: a base nova já nasce com os papéis separados desde a primeira
migração.

- **A aplicação no Dokploy fica.** Domínio, HTTPS, webhook do CD, credencial do registry, variáveis
  e backup agendado continuam como estão.
- **Uma base nova, `the_band_v2`, é criada no mesmo Postgres**, com dono `the_band_owner`.
- **A base antiga fica intacta** até você conferir a nova. É o seu caminho de volta.

Apagar a aplicação e o serviço de banco do Dokploy **não** resolve sozinho: o usuário que o
formulário do Dokploy cria nasce superusuário, e a criação dos dois papéis continua obrigatória. E
ainda obrigaria a refazer o webhook (e o secret `DOKPLOY_WEBHOOK_URL` do GitHub), o domínio, as
variáveis e o backup. Ver o *Apêndice*.

### O que se perde (irreversível, quando a base antiga for apagada)

| dado | volta? |
|---|---|
| issues, PRs, commits, revisões que ainda existem no GitHub | **sim**, pela coleta |
| a conta de administrador atual | recriada pelo bootstrap, com as variáveis do passo 4 |
| a fonte do GitHub cadastrada, com o token | **cadastrar de novo** (passo 6) |
| o histórico de auditoria, os eventos de acesso e as sessões | **não** |
| o que o GitHub já não devolve (itens apagados lá, timelines truncadas) | **não** |

### Ensaio

Em 2026-10-12, no banco local, o mesmo procedimento:
- os papéis foram criados, e a base nasceu com dono `the_band_owner`;
- as **116 migrações** rodaram do zero com o dono, inclusive a que cria a extensão `pgcrypto`;
- com quem serve, `conferir_papeis()` respondeu **`papéis: separação em vigor`**, e
  `ALTER TABLE … DISABLE TRIGGER` foi recusado com `insufficient_privilege`.

---

## Passo 1: backup de segurança

Dokploy → **Database** → o Postgres → **Backups** → rodar agora. Espere terminar com sucesso.

## Passo 2: gerar duas senhas, na sua máquina

```bash
openssl rand -hex 32   # senha do dono: the_band_owner
openssl rand -hex 32   # senha de quem serve: the_band_app
```

Guarde as duas com você. **Não as cole em chat, issue, commit ou log.** Elas são só hexadecimais
de propósito, para não quebrar a URL.

Anote também, do `DATABASE_URL` atual (Dokploy → a aplicação → *Environment*), só o **host** e a
**porta**, no formato `ecto://postgres:…@HOST:PORTA/BASE`. **Não** anote a senha.

## Passo 3: criar os papéis e a base nova

Dokploy → **Database** → o Postgres → **Terminal**:

```bash
psql -U postgres -d postgres
```

```sql
CREATE ROLE the_band_owner LOGIN NOSUPERUSER NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS;
CREATE ROLE the_band_app   LOGIN NOSUPERUSER NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS;
\password the_band_owner
\password the_band_app
CREATE DATABASE the_band_v2 OWNER the_band_owner;
\q
```

O `\password` pede cada senha duas vezes e não a mostra: o psql calcula o hash no cliente, e a
senha não vai para o histórico nem para o log do Postgres.

**Nunca** `GRANT the_band_owner TO the_band_app`: isso devolveria a quem serve o poder de desligar
as guardas.

## Passo 4: apontar a aplicação para a base nova

Dokploy → a aplicação:

1. **Advanced → Mounts → Add → File Mount**
   - caminho: `/run/secrets/database_migration_url`
   - conteúdo, numa linha só: `ecto://the_band_owner:SENHA_DO_DONO@HOST:PORTA/the_band_v2`

   A credencial que migra vai num arquivo, e não numa variável. Assim ela não aparece em
   `docker inspect` nem em `docker exec` (#1140).
2. **Environment**
   - troque o `DATABASE_URL` para
     `ecto://the_band_app:SENHA_DE_QUEM_SERVE@HOST:PORTA/the_band_v2`;
   - se existir `DATABASE_MIGRATION_URL`, **apague-a**;
   - acrescente a primeira conta (runbook §8):

     | variável | o quê |
     |---|---|
     | `THE_BAND_TENANT_NOME` | nome legível da organização |
     | `THE_BAND_TENANT_SLUG` | minúsculas, números e hífen |
     | `THE_BAND_ADMIN_EMAIL` | o e-mail de entrada |
     | `THE_BAND_ADMIN_SENHA` | no mínimo 12 caracteres |
     | `THE_BAND_ADMIN_NOME` | opcional |
3. Salve e clique em **Deploy**.

O contêiner começa como root só para ler o arquivo, migra as 116 migrações com o dono, concede os
privilégios a `the_band_app` e desce para o usuário `band` antes de servir.

## Passo 5: conferir

1. **No log do deploy**, procure:
   - `papéis: …` logo depois das migrações;
   - **`primeira conta criada: <email>, admin de <slug>.`**
2. **No terminal da aplicação** (Dokploy → a aplicação → *Terminal*):

   ```bash
   /app/bin/the_band rpc 'IO.puts(TheBand.Release.conferir_papeis())'
   ```

   O esperado é **`papéis: separação em vigor`**. Qualquer outra resposta lista os motivos, sem
   segredo nenhum.
3. `curl -s https://app.theband.dev/version` deve responder a versão no ar (`0.12.0` ou a mais
   nova).
4. **Entre** em `https://app.theband.dev` com o e-mail e a senha da primeira conta.

**Registre na #1131** a linha do item 2, sem mais nada. É ela que fecha a issue (SC-004).

## Passo 6: logo depois de entrar

1. **Remova `THE_BAND_ADMIN_SENHA` do painel.** Enquanto ela existir, a senha do primeiro
   administrador fica legível para quem acessa o painel.
2. **Cadastre de novo a fonte do GitHub**: a organização `leds-conectafapes`, com o token. A coleta
   começa sozinha. A rede de revisão e a análise de rede são calculadas depois dela, e o log mostra
   as linhas `rede de revisão calculada` e `análise de rede`.
3. **Confira o backup agendado do Dokploy.** Ele precisa incluir a base `the_band_v2`. Se o backup
   estiver configurado por nome de base, troque para a nova.

## Passo 7: fechar

Só depois de os passos 5 e 6 estarem conferidos:

1. **Gire a senha do `postgres`** no serviço de banco do Dokploy. Ela esteve no `DATABASE_URL` desde
   o primeiro deploy, e a separação sozinha não a invalida. Depois, rode um backup manual para
   confirmar que ele continua funcionando.
2. **Apague a base antiga**, no psql do `postgres`:

   ```sql
   DROP DATABASE <nome da base antiga>;
   ```

   **Isto é irreversível.** Até aqui, a base antiga era o seu caminho de volta.

---

## Se algo der errado

| sintoma | o que fazer |
|---|---|
| o deploy não sobe, e o log diz `papéis: N migração(ões) pendente(s) e DATABASE_MIGRATION_URL ausente` | o File Mount não foi lido. Confira o caminho exato (`/run/secrets/database_migration_url`) e se o conteúdo está numa linha só |
| `URL de banco malformada: confira DATABASE_URL ou DATABASE_MIGRATION_URL` | a senha tem caractere fora de `0-9a-f`, ou a URL está incompleta. Gere a senha de novo com `openssl rand -hex 32` e use `\password` outra vez |
| `password authentication failed` | a senha da URL não é a definida no `\password`. Rode `\password` de novo |
| a conferência lista `membro_do_dono` ou `dono_de_objeto` | houve um `GRANT` a mais, ou a base foi criada com outro dono. Pare e registre a linha na #1131 |
| qualquer outra falha | **volte**: o `DATABASE_URL` para o valor antigo (o `postgres` e a base antiga), remova o File Mount e reimplante. A base antiga está intacta, e tudo volta como era |

---

## Apêndice: se preferir apagar a aplicação e o banco, e recriar tudo

Funciona, mas dá mais trabalho e não tem volta. Nesta ordem:

1. No serviço de banco novo, um usuário admin qualquer, com a senha guardada só no painel. Esse
   usuário nasce **superusuário**, então a aplicação **não** pode usá-lo.
2. O **passo 3**: os dois papéis e a base com dono `the_band_owner`.
3. A aplicação pelo runbook §3: imagem `ghcr.io/the-band-solution/theband:latest`, auto-deploy
   **desligado**, porta 4000, domínio `app.theband.dev`, credencial do registry (`read:packages`).
4. As variáveis do runbook §2 (`SECRET_KEY_BASE`, `THE_BAND_MASTER_KEY`, `PHX_HOST`) e os **passos
   4 a 6** deste documento.
5. **Atualize o secret `DOKPLOY_WEBHOOK_URL` no GitHub** com o webhook da aplicação nova. Sem isso,
   o CD da próxima release falha.
6. **Reconfigure o backup agendado** (runbook §4).
