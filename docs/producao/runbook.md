# Runbook — o The Band em produção (Contabo + Dokploy)

Feature 050 · [spec](../../specs/050-em-producao/spec.md) ·
[contrato do pipeline](../../specs/050-em-producao/contracts/pipeline-de-release.md)

Escrito para UMA pessoa executar sem esta sessão aberta. Os passos marcados
**[MARCO — pessoa]** são atos que só quem administra faz; todo o resto ou já está
no repositório ou é o CD fazendo sozinho. **Nenhum segredo aparece neste documento,
no repositório ou em chat — nunca.**

## §1 [MARCO — pessoa] O VPS e o Dokploy

1. Criar o VPS na Contabo — 8 GB de RAM cobrem painel + app + Postgres na escala
   de hoje; Ubuntu LTS; chave SSH própria (não senha).
2. Instalar o Dokploy (site oficial: `curl -sSL https://dokploy.com/install.sh | sh`
   — conferir o script antes de rodar, como qualquer curl-pipe).
3. Acessar o painel, criar a conta de administração do PAINEL (não confundir com as
   contas da plataforma), e anotar o endereço — sem domínio próprio por ora, o
   domínio gerado do Traefik serve (FR-013; HTTPS incluso).
4. **Atualizações do próprio Dokploy e snapshots da Contabo ligados** — o Dokploy
   também é infraestrutura (spec: quem opera é uma pessoa; o snapshot cobre o
   painel e a config dele).

## §2 [MARCO — pessoa] Os segredos — a lista é FECHADA (contrato)

| Onde | Chave | De onde vem |
|---|---|---|
| GitHub → Settings → Secrets → Actions | `DOKPLOY_WEBHOOK_URL` | o webhook de deploy que o §3 gera |
| Painel do Dokploy (env do app) | `DATABASE_URL` | o §4 gera ao criar o banco |
| Painel do Dokploy | `SECRET_KEY_BASE` | `mix phx.gen.secret` local, colar direto |
| Painel do Dokploy | `THE_BAND_MASTER_KEY` | `mix the_band.gen_key` — chave NOVA de produção, nunca a de dev |
| Painel do Dokploy | `PHX_HOST` | o host do §1.3 |
| Painel do Dokploy (registry) | credencial `read:packages` | o pacote ghcr é privado: token **classic** só com `read:packages`, usuário = o login do GitHub. **Anote a data de vencimento** — ela venceu entre a v0.11.0 e a v0.12.0, e o deploy falhou com `ghcr.io/v2/: denied` (nota da v0.12.0, *O que se observou depois*) |
| GitHub → Settings → Secrets → Actions | `PRODUCAO_URL` | o endereço público da aplicação; o último passo do CD mede `/version` nele |

Nada além disto. Chave que vazar se ROTACIONA (a mestra pelo §12, e não por `mix`, que a
release não tem), nunca se "monitora".

## §3 [MARCO — pessoa] O app no Dokploy

1. Criar Application → **Docker Image** → `ghcr.io/the-band-solution/theband:latest`.
2. **Auto-deploy on push: DESLIGADO** (FR-015 — quem deploya é o CD, depois dos
   gates; o Dokploy só obedece ao webhook).
3. Copiar o **webhook de deploy** do app → é o valor de `DOKPLOY_WEBHOOK_URL` (§2).
4. Porta interna 4000; domínio do §1.3 apontando para ela; HTTPS automático.
5. Env vars do §2.

## §4 [MARCO — pessoa] O banco e o backup

1. Criar Database → PostgreSQL 16 no Dokploy; a URL interna gerada é o
   `DATABASE_URL` do app (§2).
2. **Backup agendado DIÁRIO** no Dokploy para um destino S3-compatível (fora da
   máquina — FR-007/FR-014); a falha do job aparece no painel, e o §6 diz como
   conferi-la por rotina.
3. Snapshot da Contabo ligado (§1.4) — a segunda camada.

## §5 Rollback

O Dokploy guarda o histórico de imagens: reimplantar a versão anterior é apontar o
app para `ghcr.io/...:vX.Y.(Z-1)` e reimplantar — as migrações são só-acréscimo por
princípio da casa (nunca se apaga dado), então a versão anterior sobe sobre o
esquema novo. Migração que quebre isso é decisão de ADR ANTES do release, nunca
descoberta no rollback.

## §6 O ensaio de restauração — ANTES de dado real (FR-008/SC-003)

O backup só existe depois de restaurado uma vez. O ensaio:

1. Anotar TRÊS números da produção AINDA sem dado real (pós-seed): pessoas, issues,
   organizações — de `/people` e `/organizations`.
2. Baixar o backup mais recente do destino S3 (o arquivo `.sql`/`.dump` do job).
3. Criar um banco VAZIO no Dokploy (`band_ensaio`), restaurar nele
   (`pg_restore`/`psql < dump`), apontar uma SEGUNDA aplicação temporária no
   Dokploy para ele (mesma imagem, `DATABASE_URL` do ensaio).
4. Conferir os três números NA TELA da instância de ensaio — bateram, o ensaio
   passou; anotar data e números em `docs/releases/` junto do release.
   **Desde a spec 071**: os papéis não entram no `pg_dump`. No cluster de ensaio, criar
   `the_band_owner` e `the_band_app` antes de restaurar (§14.2), restaurar como `postgres`, e
   subir a instância de ensaio com `DATABASE_MIGRATION_URL` do dono e `DATABASE_URL` do papel que
   serve. O deploy reaplica a concessão. O ensaio só passa se a conferência do §14.4, rodada
   contra a instância de ensaio, disser **"separação em vigor"**.
5. Derrubar a instância e o banco de ensaio.

Falhou qualquer passo: o backup NÃO existe de verdade — resolver antes de qualquer
release com dado real.

> **Numa restauração DE VERDADE, e não no ensaio, o último passo é o §10: encerrar
> todas as sessões. É obrigatório** (feature 064, decisão P5), e o §10.1 diz por quê. Repetir o ensaio a cada mudança no desenho do backup, e no
mínimo uma vez por mês (SC-006: a rotina roda 7 dias e a mais antiga restaura).

### Dry-run local (sem VPS — o teste da T006)

```bash
docker exec 3d665aae71e6 pg_dump -U postgres -d the_band_dev > /tmp/ensaio.sql
docker exec 3d665aae71e6 psql -U postgres -c "CREATE DATABASE band_ensaio"
docker exec -i 3d665aae71e6 psql -U postgres -d band_ensaio < /tmp/ensaio.sql
# subir o contêiner da 050 contra band_ensaio e conferir /people
```

## §7 [MARCO — Product Owner] O primeiro release

1. Aceitação do sprint confirmada; versão decidida (semver sobre ACEITOS — FR-016).
2. PR de release `development → main` com o bump no `mix.exs`
   (`chore: release vX.Y.Z`) e o corpo apontando o registro de aceitação.
3. Merge = deploy: o CD builda, publica `vX.Y.Z` no ghcr, cria a tag e chama o
   webhook. Acompanhar o workflow — cada passo diz seu veredito no log (L60).
4. Medir e registrar em `docs/releases/vX.Y.Z.md`: SC-001 (entrar e ver painel em
   <2min), SC-002 (<15min procedimento, <2min indisponibilidade), SC-004
   (varredura de segredos em imagem — `docker history` — e logs), SC-005 (a
   varredura das 27 rotas da 045 contra o endereço real).
5. O ensaio do §6 com dado real entra no calendário do mês.

## §8 A primeira conta — feature 052

A plataforma sobe com o banco vazio, e o `seeds.exs` levanta em produção de
propósito: senha padrão conhecida seria a porta aberta que a 045 existe para
fechar. Sem este passo, ninguém entra.

1. No painel, na aba de ambiente da aplicação, acrescentar às que já existem:

   | variável | o quê |
   |---|---|
   | `THE_BAND_TENANT_NOME` | nome legível da organização |
   | `THE_BAND_TENANT_SLUG` | identificador estável — minúsculas, números e hífen |
   | `THE_BAND_ADMIN_EMAIL` | e-mail de entrada |
   | `THE_BAND_ADMIN_SENHA` | senha escolhida na hora, no mínimo 12 caracteres |
   | `THE_BAND_ADMIN_NOME` | opcional — sem ele a pessoa preenche em `/profile` |

2. Implantar. No log do contêiner, uma destas quatro linhas:

   | o que aparece | o que significa |
   |---|---|
   | `primeira conta criada: <email>, admin de <slug>.` | deu certo |
   | `já existe administrador — nada a criar.` | a instalação já tinha conta |
   | `sem <VAR>, <VAR> — nenhuma conta criada.` | variável faltando, e a linha diz quais |
   | `primeira conta recusada: <campo> <motivo>.` | valor inválido, e a linha diz qual regra |

   **Nos quatro casos a plataforma sobe.** Ao contrário de `DATABASE_URL`, cuja
   ausência derruba, aqui a falta não impede: sem banco, subir significaria
   servir zero em toda tela; sem primeira conta, a plataforma está correta e
   apenas vazia.

3. Entrar pela tela de entrada com esse e-mail e essa senha.

4. **REMOVER `THE_BAND_ADMIN_SENHA` do painel.**

   Enquanto a variável existir, a senha do primeiro administrador é **legível
   por quem tem acesso ao painel**. Esse é o custo declarado da escolha por
   variáveis de ambiente, e não um descuido — uma tela de instalação levaria a
   senha do teclado ao hash sem parada intermediária, e foi descartada por
   simplicidade.

   Removê-la não afeta nada: no boot seguinte o log dirá `já existe
   administrador`. E trocar a senha pela interface depois disso vale para sempre
   — reiniciar não a sobrescreve.

5. As contas seguintes nascem em `/accounts`, com senha temporária gerada por
   quem administra. Este passo é só para a primeira.

## §9 [MARCO — pessoa] O domínio próprio — feature 054

**A ordem é a parte que importa.** Cada inversão produz um sintoma diferente, e
nenhum deles nomeia a causa. Está escrito na ordem em que precisa acontecer.

### Antes de tudo: o repositório pronto

`THE_BAND_ORIGENS_EXTRAS` já precisa existir na versão que está em produção.
Publicar o nome novo com uma versão que não conhece a variável entrega um
endereço que responde 200 e não é interativo — as telas não atualizam, e não há
erro visível. É a P1 da 050, e é o defeito que esta feature existe para não
introduzir.

Conferir antes de mexer no DNS:

```bash
bash scripts/medir-enderecos.sh https://theband.5.189.161.85.sslip.io
```

### 1. O DNS aponta — SEM o intermediário na frente

No provedor do domínio, **um** registro de endereço:

| Nome | Aponta para | Observação |
|---|---|---|
| `app.theband.dev` | o IP da produção | **com o intermediário desligado** — no Cloudflare, a nuvem **cinza** |

**Não toque no apex nem no `www`.** `theband.dev` serve o **site público**, hoje
no GitHub Pages (`185.199.108.153` e irmãos). Apontá-lo para a produção tiraria o
site do ar; adicioná-lo à aplicação no painel faria os dois serviços disputarem o
mesmo certificado.

*Se inverter*: quem emite o certificado precisa provar que controla o nome, e a
prova chega por requisição ao próprio endereço. Com o intermediário na frente,
ela pode nunca chegar — e o sintoma é um certificado que não sai, sem dizer por
quê.

### 2. O nome entra no painel, e o certificado é emitido

No painel de quem hospeda, na aplicação: adicionar **`app.theband.dev`** — e só
ele — apontando para a porta da aplicação (`4000`), com HTTPS por Let's Encrypt.
Esperar o certificado.

> ⚠️ **Em 2026-09-01 este passo NÃO funcionou, e o caminho foi outro.** O que se
> mediu: DNS resolvendo direto na origem, rota existindo (`Host: app.theband.dev`
> → 301 para o host certo), aplicação respondendo 200 por trás do certificado
> errado, caminho do desafio ACME aberto (404 do handler, não redirecionamento),
> nenhum CAA no domínio, e o campo `Certificate` do domínio já em `Let's
> Encrypt`. Mesmo assim a origem seguiu servindo `CN=TRAEFIK DEFAULT CERT`.
>
> **A causa não foi diagnosticada** — o log do Traefik não chegou a ser lido. Está
> registrado como o que é: passo que falhou sem explicação, e não passo que
> funciona. Quem retomar começa por `dokploy-traefik` → Logs, filtrando `acme`.
>
> O caminho usado no lugar está no **§9-B**, adiante.

**`.dev` não tem plano B.** O TLD está na lista de pré-carregamento de HSTS dos
navegadores: sem certificado válido, o navegador recusa antes de qualquer
requisição sair. Não existe "abre inseguro e a pessoa prossegue" — existe
inalcançável. **Não divulgue o nome antes deste passo terminar.**

Conferir:

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://app.theband.dev/sign-in   # 200
curl -s -o /dev/null -D - http://app.theband.dev/sign-in | head -2         # 301 → https
```

### 3. As duas origens são declaradas — ANTES de trocar o `PHX_HOST`

No painel, nas variáveis da aplicação:

```
THE_BAND_ORIGENS_EXTRAS=https://theband.5.189.161.85.sslip.io
PHX_HOST=app.theband.dev
```

**Nessa ordem, e no mesmo deploy.** `THE_BAND_ORIGENS_EXTRAS` é *por onde as
pessoas chegam*; `PHX_HOST` é *o endereço que a plataforma escreve nos links*.
Trocar só o segundo deixa o endereço antigo sem conexão viva — que é o mesmo
defeito, na direção contrária.

Deixar a medida contínua rodando durante o deploy, para provar o SC-004:

```bash
while true; do
  printf '%s %s\n' "$(date +%H:%M:%S)" \
    "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
       https://theband.5.189.161.85.sslip.io/sign-in)"
  sleep 5
done
```

### 4. O intermediário entra — e a cifra vai até a aplicação

Só agora ligar o proxy (nuvem **laranja**), com:

- **modo de cifra**: o que cifra também **entre o intermediário e a aplicação** e
  valida o certificado. No Cloudflare, `Full (strict)`;
- **conexões vivas (WebSockets)**: ligadas.

*Se escolher o modo que cifra só até o intermediário*: a aplicação exige cifra
(`force_ssl` em `config/prod.exs`), o intermediário responde que já cifrou, e
nasce um **laço de redirecionamento** — a página nunca carrega, e o erro não
nomeia a causa.

*Se as conexões vivas estiverem desligadas*: HTTP responde 200 e nenhuma tela
atualiza. O mesmo sintoma da P1, com origem diferente — por isso o passo 5 existe
mesmo quando o passo 2 passou.

### 5. A conferência que decide: o socket, nos dois endereços

```bash
bash scripts/medir-enderecos.sh https://app.theband.dev
bash scripts/medir-enderecos.sh https://theband.5.189.161.85.sslip.io
```

**Os dois têm de passar.** Um `200` no HTTP não é evidência de nada aqui: o
defeito desta feature produz exatamente um 200 com o socket recusado (L85). O
script imprime a leitura dos códigos — `403` é recusa de origem, `400` é o
handshake incompleto do `curl` com a origem **aceita**.

### §9-B — O caminho alternativo: certificado de origem do intermediário

**Foi por aqui que a produção subiu em 2026-09-01**, depois de o Let's Encrypt não
emitir. Vale como alternativa permanente, e não só como remendo — com uma
diferença que precisa estar escrita: **a renovação deixa de ser automática**.

1. **Cloudflare → SSL/TLS → Origin Server → Create Certificate**. Hostnames
   `*.theband.dev` e `theband.dev` — o curinga de um nível cobre `app`. Validade
   padrão de 15 anos;
2. **a chave privada aparece uma vez só.** Vai do painel do Cloudflare direto
   para o do Dokploy: nunca por chat, nunca por arquivo do repositório (FR-011);
3. **Dokploy → Certificates** → certificado customizado, colando certificado e
   chave. Depois, **Domains → `app.theband.dev`** → campo `Certificate` apontando
   para ele;
4. **Cloudflare → DNS** → registro `app` → **Proxied** (laranja);
5. **Cloudflare → SSL/TLS → Overview** → modo **`Full (strict)`**. Na interface
   nova: *Configure* → *Custom SSL/TLS* → `Full (strict)`;
6. **Network → WebSockets: ON**.

**Quem apresenta o certificado ao navegador passa a ser o Cloudflare**, com o
Universal SSL dele — medido em 2026-09-01: `CN=theband.dev`, emissor
`Google Trust Services`. O certificado de origem cifra e **autentica** o trecho
Cloudflare↔servidor.

> **Não use `Full` sem o `(strict)`.** Ele aceita qualquer certificado na origem,
> inclusive autoassinado: o trecho fica cifrado e **não autenticado**, e um
> intermediário ali passa despercebido. Com o certificado de origem instalado,
> `Full (strict)` funciona de primeira — não há motivo para o modo fraco.

**O que este caminho deixa em aberto**: a renovação. O certificado do Let's
Encrypt renovava sozinho; este vence em 15 anos e ninguém será lembrado. Quando o
Let's Encrypt voltar a funcionar, trocar o `Certificate` do domínio de volta e
seguir em `Full (strict)`.

### 6. A pendência é encerrada

Com os dois endereços medidos, marcar a **P1 da 050** como encerrada em
`specs/050-em-producao/pendencias.md`, com a data e o que a substituiu.

## §10 As sessões — o que uma restauração faz com elas, e como encerrar todas

Feature 064 (US2, T015 e T016). Desde a T013, cada entrada abre uma linha em
`user_sessions`, e o banco guarda **só o resumo** do token. O token que abre a sessão
vive só no cookie do navegador.

### §10.1 O que uma restauração faz com as sessões

Restaurar um backup devolve as linhas de sessão **do instante da cópia**. São três casos:

| a sessão foi… | depois de restaurar | por quê |
|---|---|---|
| aberta **depois** da cópia | **cai**, e a pessoa entra de novo | a linha não existe no banco restaurado |
| aberta **antes** da cópia, e ainda dentro dos 7 dias | **continua valendo** | a linha voltou igual |
| **encerrada entre a cópia e o desastre** | **VOLTA A VALER** | a linha voltou sem o `ended_at` |

**O terceiro caso é o que surpreende, e é o perigoso.** As sessões encerradas nesse
intervalo incluem as encerradas **por segurança**: alguém que saiu de um computador
compartilhado, uma senha trocada por suspeita, uma conta desativada. A restauração as
reabre sem ninguém ter pedido.

**O mesmo vale para a senha.** Uma senha trocada depois da cópia volta a ser a
antiga, porque o `password_hash` e a época também voltam.

É por isso que o passo abaixo é **obrigatório** depois de toda restauração, e não
recomendado.

### §10.2 Encerrar todas as sessões

> **Isto encerra a sessão de TODO MUNDO, em TODAS as organizações, inclusive a de
> quem roda o comando.** Todas as pessoas precisam entrar de novo. Não há como
> escolher quem fica.

No contêiner do app, pelo Dokploy (*Advanced → Terminal*, ou `docker exec` no
contêiner da aplicação). **São dois comandos, e qual usar depende de a aplicação estar no ar**
(#1050):

| a aplicação | comando | por quê |
|---|---|---|
| **no ar** (o caso normal) | `/app/bin/the_band rpc 'IO.puts(TheBand.Release.girar_sessoes())'` | roda **dentro do nó que serve**, e o aviso derruba as telas abertas |
| **parada**, por exemplo logo depois de restaurar, antes de subir | `/app/bin/the_band eval 'TheBand.Release.encerrar_todas_as_sessoes()'` | sobe outra VM só para isto; não há tela aberta a derrubar |

Pelo `eval` com a aplicação no ar, as sessões ficam encerradas no banco, mas uma tela já aberta
segue respondendo até reconectar. É o defeito da #1042 no caminho de incidente, e foi por isso
que o `rpc` entrou.

A saída diz **quantas** sessões encerrou, e só o número:

```
7 sessão(ões) encerrada(s), e as telas abertas foram avisadas. Todas as pessoas precisam entrar de novo.
```

O comando escreve `ended_at` em toda sessão aberta e **não apaga nada**. As linhas
saem sozinhas 90 dias depois, pela retenção (T020). Rodar duas vezes não faz mal: a
segunda encerra zero.

**Quando rodar:**

| situação | obrigatório? |
|---|---|
| **depois de restaurar um backup** | **sim** (§10.1, decisão P5) |
| suspeita de que o `SECRET_KEY_BASE` vazou | recomendado. **Trocar a chave (§2) é o que protege**: todo cookie assinado com a antiga deixa de valer. A chave sozinha não abre sessão, porque o banco não tem o token bruto. Encerrar registra a queda em `ended_at` |
| a varredura de segredos (`mix the_band.varre_segredos`, FR-010) achou um token de sessão | sim |
| suspeita de sessão roubada, sem saber de quem | sim |
| uma conta só | **não use isto.** Desativar a conta (`/accounts`) encerra as sessões dela, e reativar não as devolve |

**Como conferir que funcionou:** abra a plataforma num navegador que estava logado.
Ele precisa cair em `/sign-in`.

### §10.3 O que isto não faz

- **Pelo `eval`, não derruba um LiveView já conectado** (achado S14, depois #1042 e #1050).
  Pelo `rpc`, derruba: a tela aberta reconfere a sessão e cai em `/sign-in`.
- **Não troca a chave.** Se a suspeita é sobre o `SECRET_KEY_BASE`, trocá-la é um passo
  separado, no §2.

## §11 A fila parada — quando `/syncs` diz que a fila não anda

Issue #801. A tela `/syncs` avisa quando nenhum job do Oban completou nos últimos **15 minutos**.
A regra está em `docs/producao/saude-da-fila.md`: o `Cron` agenda trabalho a cada 5 minutos, e
três ciclos sem nada completado é fila parada, e não lentidão. A mesma regra faz o healthcheck do
contêiner ficar `unhealthy` e `/health` responder `503`.

### §11.1 O que isso significa

- **As execuções marcadas `running` não estão avançando.** O registro diz `running` porque
  ninguém o encerrou, e a fila não roda o trabalho.
- **Nada do que já foi coletado se perde.** Cada página é gravada depois de processada, com o
  checkpoint. Quando a fila voltar, a reconciliação **encerra** a execução que ficou `running`
  sem avançar (§11.2, passo 5), e a **próxima** coleta da ferramenta recomeça do checkpoint
  gravado, sem recoletar o que já veio.
- **Sync e Reprocess ficam desabilitados** enquanto durar, porque cada clique criaria mais um
  registro `running` que também não andaria.

### §11.2 O que fazer

1. **Conferir de fora:**

   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' "$PRODUCAO_URL/health"   # 503 = parada
   ```

2. **Antes de reiniciar, confira se há coleta longa de verdade em andamento.** A coleta de uma
   organização grande leva horas, e o aviso pode aparecer se várias rodarem ao mesmo tempo. Na tela
   `/syncs`, uma execução cuja linha de último avanço mostra progresso recente **está andando**:
   espere em vez de reiniciar. Reiniciar derruba as coletas que estão rodando.
3. **Reiniciar o contêiner da aplicação** no Dokploy: *Applications → the_band → **Restart***. **Não
   use Redeploy:** ele puxa a imagem de novo e pode trocar de versão, e uma fila parada não se
   resolve mudando de versão. Reiniciar é o que resolveu em 2026-09-04: 0 jobs completados em 20
   minutos antes, 122 em 3 minutos depois.
4. **Conferir que voltou:** `/health` responde `200`, e a tela `/syncs` volta a mostrar *Job queue
   moving* em até um minuto, porque ela reconfere a cada 60 segundos.
5. **As execuções que ficaram `running` sem avançar** são encerradas pela reconciliação
   (`ReconcileStuckSyncs`), que volta a rodar com a fila. Não é preciso encerrá-las à mão.

**Não altere `oban_jobs` por SQL para "destravar" a fila.** Mudar `state` à mão já foi preciso
uma vez, em 2026-09-04, no desenvolvimento, e numa fila parada pela causa errada ele esconde o
problema em vez de resolvê-lo. Se reiniciar não resolver, a causa é outra: conexão com o banco, ou
o supervisor do Oban desistindo. Investigue antes de mexer na tabela.

### §11.3 O que este procedimento não sabe

**Por que a fila parou.** O verificador detecta, e não explica. A causa da parada de 2026-09-04
nunca foi achada.


## §12 Rotacionar a chave mestra — issue #1052

A chave mestra (`THE_BAND_MASTER_KEY`) cifra **todos** os campos de
`TheBand.Rotacao.campos_cifrados/0`: as credenciais das ferramentas e a credencial do provedor de
IA. Antes da #1052, a rotação recifrava só as primeiras, e a do provedor ficava ilegível.

A release não tem `mix`, e por isso `mix the_band.rotate_key` não existe em produção. O caminho
é este, pelo Dokploy:

1. **Gerar a chave nova** fora do servidor (`mix the_band.gen_key`, numa máquina com o
   repositório). Ela não passa por chat, commit nem log.
2. **No painel do Dokploy**, copiar o valor atual de `THE_BAND_MASTER_KEY` para
   `THE_BAND_PREVIOUS_MASTER_KEY`, e pôr a chave nova em `THE_BAND_MASTER_KEY`.
3. **Reimplantar** (*Redeploy*), para o `Vault` subir com as duas chaves.
4. **Recifrar**, no terminal do contêiner, dentro do nó que serve:

   ```bash
   /app/bin/the_band rpc 'IO.puts(TheBand.Release.rotacionar_chave())'
   ```

   A saída diz quantos registros recifrou por tabela, e nunca um valor. Se disser
   **"NADA FOI GRAVADO"**, há registro ilegível com as duas chaves. Pare e confira o passo 2,
   **sem** remover a chave anterior.
5. **Só depois de recifrar**, remover `THE_BAND_PREVIOUS_MASTER_KEY` do painel e reimplantar.
   Manter a chave antiga publicada mantém viva a chave que se quis aposentar.

**Como conferir:** depois do passo 5, abrir uma ferramenta conectada e a tela de credencial de
IA. As duas precisam continuar funcionando: a coleta segue, e a rodada de perfis não acusa
credencial ilegível.

## §13 O operador da plataforma — spec 070

O operador da plataforma suspende e reativa organizações, em `/platform`. Ele não é conta de
organização nenhuma, e **nenhuma tela concede, reinicia ou revoga o papel** (FR-001): só os três
comandos abaixo, rodados no terminal do contêiner, pelo Dokploy. Quem roda o comando já tem o
banco, e o comando é o caminho **registrado** para isso.

`quem executa` é **declarado**, e não autenticado: o comando grava o que se escreveu ali. A prova de
quem rodou é o acesso ao Dokploy, fora da aplicação.

### §13.1 Antes da primeira concessão: o relógio do servidor

O segundo fator é TOTP, com códigos de 30 segundos. Um servidor com o relógio fora por mais de 30
segundos recusa **todo** código, e dez recusas seguidas travam o segundo fator até o reinício
(T11 de `seguranca-totp.md`). No servidor:

```bash
timedatectl
```

A saída precisa dizer `System clock synchronized: yes`. Se disser `no`, acerte o NTP antes de
conceder. Registre a conferência na nota da release, com a data. Se o relógio não foi conferido,
escreva "não medido", e não "ok".

### §13.2 Conceder o papel

**A pessoa que vai ser operadora roda o comando ela mesma**, ou recebe o código **por voz**. Nunca
por chat, e-mail, issue, commit nem captura de tela (A17): o código abre a definição de senha da
conta mais poderosa da plataforma.

```bash
/app/bin/the_band eval 'TheBand.Release.conceder_operador("<e-mail>", "<nome>", "<quem executa>")'
```

A saída imprime **uma vez** o código de definição, com a validade de 30 minutos. Ele não fica
guardado em lugar nenhum além do resumo no banco: perdido, emite-se outro com §13.5.

Conceder de novo a quem já teve o papel não devolve nada de antes: a senha, o segundo fator, os
códigos de recuperação e as sessões antigas são apagados.

### §13.3 O cadastro, em três passos

Em `https://<endereço>/platform/setup`:

1. **A senha.** O e-mail, o código de definição e a senha nova, de 12 a 128 caracteres, duas vezes.
   O código vale uma vez.
2. **O autenticador.** A tela mostra a **chave de configuração** em texto e o endereço
   `otpauth://`. Não há QR code, por decisão de 2026-10-01. No aplicativo autenticador, escolha
   "inserir chave" e digite a chave; depois, confirme com um código do aplicativo. **A chave aparece
   só nesta página**: se a página for fechada antes da confirmação, é preciso um código novo
   (§13.5). Este passo vence em 10 minutos.
3. **Os códigos de recuperação.** A tela mostra dez códigos, **uma vez**. Guarde-os fora do
   computador e do celular do autenticador. Marque a caixa e conclua. Este passo também vence em 10
   minutos.

**Até o terceiro passo, a entrada é recusada**, mesmo com a senha e o código certos.

### §13.4 Entrar

Em `https://<endereço>/platform/sign-in`, com o e-mail, a senha e o código do aplicativo. Sem o
aplicativo, use um código de recuperação no mesmo campo. Cada código vale **uma** entrada.

Toda recusa diz a mesma frase, qualquer que seja o campo errado, inclusive durante a espera depois
de várias tentativas. A sessão dura 8 horas, e cai depois de 30 minutos sem uso.

### §13.5 Perder o celular, ou travar o segundo fator

**Celular perdido é reinício pelo comando, mesmo que ainda haja códigos de recuperação** (T9 de
`seguranca-totp.md`). O código de recuperação dá uma entrada, mas não revoga o aparelho perdido, e
o segredo que está nele continua valendo até o reinício.

O reinício é o mesmo para quem errou dez códigos seguidos (o segundo fator trava) e para quem
perdeu a senha:

```bash
/app/bin/the_band eval 'TheBand.Release.reiniciar_credencial_do_operador("<e-mail>", "<quem executa>")'
```

O reinício apaga a senha, o segundo fator e os códigos de recuperação, encerra as sessões e imprime
um código de definição novo, **uma vez**, com a mesma regra de §13.2 para entregá-lo. O cadastro
recomeça de §13.3.

### §13.6 Revogar o papel

```bash
/app/bin/the_band eval 'TheBand.Release.revogar_operador("<e-mail>", "<quem executa>", "<nota>")'
```

A revogação encerra as sessões do operador na mesma transação, e um ato em voo é recusado. Ela é
definitiva: para devolver o papel, concede-se de novo (§13.2).

### §13.7 O que este roteiro não cobre

- **O limite por endereço de origem (A4).** Existe desde a spec 077, e em produção **só observa**
  até a medição #1063: ver o §15. Até ligar o estado `proxy`, a espera do operador é só por conta.
- **Aviso ao operador.** A plataforma não avisa a pessoa quando o segundo fator é trocado ou quando
  um código é reusado (T9). O registro fica no log de acesso, com o prefixo `acesso: operador`.
- **Phishing em tempo real.** O TOTP não resiste a ele (T10). O endereço da área do operador é o
  da plataforma, e nenhum link para ela é enviado por e-mail.

## §14 Os papéis do banco — spec 071 (#1131)

A aplicação **migra** com um papel dono do esquema e **serve** com outro, sem posse e só com
leitura e escrita de linhas. Sem isso, quem executasse SQL pela aplicação conseguiria desligar as
guardas que vivem no banco: os triggers somente-acréscimo, as `CHECK` e as FKs.

- **O alvo** (decidido em 2026-10-02): `the_band_owner`, dono e **não** superusuário, só para
  migrar; `the_band_app`, sem posse, para servir. O `postgres` fica só para administração e
  backup.
- **Nenhuma senha passa por chat, issue, commit ou log.** Gere e guarde você mesma, no painel do
  Dokploy.

### §14.1 Medir antes de trocar

No terminal do Postgres do Dokploy, como `postgres`, na base da aplicação:

```sql
SELECT rolname, rolsuper FROM pg_roles WHERE rolname = current_user;          -- quem é você
SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = current_database();
SELECT tableowner, count(*) FROM pg_tables WHERE schemaname = 'public' GROUP BY 1;
```

Anote, sem senha, na issue #1131:
- qual papel o `DATABASE_URL` de hoje usa;
- se ele é superusuário;
- quem é o dono das tabelas;
- se o backup agendado do Dokploy usa `--no-acl` ou `--no-owner`.

### §14.2 Criar os papéis e transferir a posse

Gere duas senhas **só hexadecimais**, que não quebram a URL:

```bash
openssl rand -hex 32
```

E, como `postgres`, na base da aplicação, com as senhas no lugar de `<…>`:

```sql
CREATE ROLE the_band_owner LOGIN NOSUPERUSER NOCREATEROLE NOCREATEDB PASSWORD '<senha do dono>';
CREATE ROLE the_band_app   LOGIN NOSUPERUSER NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS
                            PASSWORD '<senha de quem serve>';
REASSIGN OWNED BY <o dono de hoje, de §14.1> TO the_band_owner;   -- só nesta base
ALTER DATABASE <a base> OWNER TO the_band_owner;
```

**Nunca** `GRANT the_band_owner TO the_band_app`, nem a base com `OWNER the_band_app`. Qualquer um
dos dois devolve a quem serve o poder de desligar as guardas, e a conferência diz
`membro_do_dono` ou `dono_de_objeto`.

### §14.3 Trocar as credenciais no painel, ANTES do deploy

No app do Dokploy:
- **a credencial que migra é um arquivo, e não variável** (#1140). Em *Advanced → Mounts*, crie um
  **File Mount** com o caminho `/run/secrets/database_migration_url` e o conteúdo
  `ecto://the_band_owner:<senha do dono>@<host>/<base>`, numa linha só;
- `DATABASE_URL`: `ecto://the_band_app:<senha de quem serve>@<host>/<base>`;
- se `DATABASE_MIGRATION_URL` existir no painel, **apague-a**. Pelo ambiente, a credencial fica em
  `docker inspect` e em todo `docker exec`. Ela continua aceita para a transição, com aviso, e o
  arquivo vale se os dois existirem.

Reimplantar. O contêiner começa como root só para ler o arquivo:
- ele prova que `band` não consegue abri-lo, e **não sobe** se conseguir;
- migra, e concede os privilégios a quem serve;
- desce a `band` antes do servidor.

O processo que serve não tem capacidade nenhuma e não lê o arquivo. Sem a primeira, o deploy segue os três estados de FR-008:
- se quem serve ainda é dono, migra como hoje, e diz "NÃO em vigor";
- se não é dono e não há migração pendente, sobe;
- se não é dono e há pendente, **não sobe**.

### §14.4 Conferir

No terminal do contêiner da aplicação:

```bash
/app/bin/the_band rpc 'IO.puts(TheBand.Release.conferir_papeis())'
```

**Esperado**: `papéis: separação em vigor`. Cole a linha na issue #1131: é ela, e não o merge,
que fecha a issue (SC-004). Qualquer outro resultado lista os motivos, por exemplo
`superusuario`, `membro_do_dono` ou `tentativa_passou`.

### §14.5 Desfazer uma migração

O `rollback/2` precisa do dono. Rode-o com a credencial **só na própria linha**:

```bash
DATABASE_URL="$(cat /run/secrets/database_migration_url)" /app/bin/the_band eval 'TheBand.Release.rollback(TheBand.Repo, <versão>)'
```

Como root, no terminal do contêiner. O `eval` não abre distribuição, e por isso continua root.

### §14.6 O que isto não fecha

- **Quem é root no contêiner tem a credencial que migra.** Isso inclui o terminal do Dokploy, que
  entra como root, e o painel, onde está o File Mount. Quem executa código como `band`, o processo
  que serve, não a alcança (#1140, medido em `specs/071-papeis-do-banco/evidencia-1140.md`).
- **Todo comando que conecta ao nó** (`rpc`, `remote`) roda como `band`, mesmo digitado por root:
  é a guarda de `rel/env.sh.eex` (A1), porque a distribuição Erlang é simétrica.
- **Quem executa código pela aplicação** lê e escreve todo dado de todo tenant. A separação
  impede **desligar as guardas**, e não o acesso a dado.
- **Uma tabela criada à mão por outro papel** nasce sem privilégio para quem serve, e falha alto
  na primeira escrita.

## §15 A origem do visitante e o limite por origem — spec 077 (#1229, #1106)

As cinco portas que verificam segredo sem sessão — `POST /session` e os quatro `POST` públicos de
`/platform` — contam as **falhas por origem**: 10 em 300 s (`access.origin_limit` na base de
conhecimento). A 11.ª recebe a recusa de sempre daquela porta, sem verificar nada. O que é
"origem" depende de uma declaração no ambiente, e **nenhum estado liga por ausência**.

### §15.1 Os três estados

| variáveis no painel do Dokploy | estado | o que acontece |
|---|---|---|
| nenhuma (o de hoje) | não declarado | conta pelo socket, que atrás do Traefik é **o proxy**: todo visitante é uma origem só. Por isso **não recusa**: registra a transição no log e segue. A #1229 e a A4 continuam abertas, declaradas |
| `THE_BAND_ORIGEM=socket` | socket | conta pelo socket e recusa. **Só** para a aplicação exposta sem proxy: atrás do Traefik, nega a entrada a todos a ~0,04 requisição por segundo (`specs/077-limite-por-origem/seguranca.md`, L1) |
| `THE_BAND_ORIGEM=proxy`, `THE_BAND_ORIGEM_CABECALHO=x-forwarded-for`, `THE_BAND_ORIGEM_PROXIES=<sub-rede medida>` | proxy | lê o cabeçalho **só** quando o socket é um proxy da lista, e conta pelo valor mais à direita que não é proxy. Recusa |

A linha do log de subida diz o estado: `limite por origem: só observado — …` (`warning`), ou
`limite por origem: ligado, pelo cabeçalho x-forwarded-for vindo de <lista>` (`info`).

**A aplicação não sobe** com `THE_BAND_ORIGEM` desconhecido, cabeçalho fora de `[a-z0-9-]+`, lista
vazia, bloco malformado, `/0`, ou bloco que não seja de rede local (RFC 1918, `100.64.0.0/10`,
laço local, `fc00::/7`). A mensagem nomeia a variável, nunca o valor. Isso é de propósito: um bloco
público na lista deixaria qualquer cliente escolher a própria origem (L3).

A linha da transição — `limite por origem: contas passou do limite · estado=… prefixo=… falhas=11`
— leva só o prefixo (`/24` do IPv4, `/48` do IPv6). O endereço inteiro não vai para o log nem para
a telemetria; quem precisa bloquear um endereço usa o log do Traefik.

### §15.2 A medição #1063 — 👤 pessoa mantenedora

Mede o que **um contêiner atrás do mesmo Traefik recebe**, sem tocar a aplicação, sem credencial e
com endereços de documentação (`seguranca.md` da 077, *Procedimento seguro da medição #1063*):

1. **Ponto de partida.** Data, versão do Traefik (`docker exec <contêiner do traefik> traefik
   version`) e só o bloco `entryPoints.*.forwardedHeaders` (`trustedIPs`, `insecure`) da
   configuração estática do Traefik do Dokploy.
2. **Um eco temporário.** No Dokploy, uma aplicação com a imagem `traefik/whoami` **fixada por
   digest**, na mesma rede da aplicação, com um domínio **temporário de `sslip.io`** — nunca um
   subdomínio de `theband.dev`, para que nenhum cookie da plataforma seja enviado a ele.
3. **Medir sem credencial**, da sua máquina, sem cookie e sem `Authorization`:

   ```bash
   E=https://<eco>.sslip.io
   curl -s "$E" -H 'X-Forwarded-For: 203.0.113.7'
   curl -s "$E" -H 'X-Forwarded-For: 203.0.113.7' -H 'X-Forwarded-For: 198.51.100.9'
   curl -s "$E" -H 'Forwarded: for=192.0.2.60' -H 'X-Real-IP: 192.0.2.61'
   curl -s -6 "$E" -H 'X-Forwarded-For: 203.0.113.7'   # se o servidor tiver IPv6
   ```

   Para cada um, anote o `X-Forwarded-For` que chegou e **em que posição** está o seu endereço —
   comparado, e **não transcrito**: no registro ele aparece como `<endereço de quem mediu>`.
4. **O `RemoteAddr`** que o eco mostra é o Traefik **na rede do Docker**. Anote a sub-rede
   (`docker network inspect <rede> --format '{{json .IPAM.Config}}'`) e se outros serviços a usam.
5. **Pelo Cloudflare**, se a nuvem laranja estiver ligada em `app.theband.dev`: um nome temporário
   com a nuvem laranja apontando para o eco, e os mesmos casos. Diz se há um salto ou dois.
6. **Derrubar o eco e o domínio temporário**, e anotar que foram derrubados.
7. **A porta 4000 da aplicação está publicada no host?** `docker ps`, coluna de portas, no
   contêiner da aplicação.
8. **Registrar na #1063**: data, método, versão do Traefik; para cada caso, "sobrescreve" ou
   "acrescenta"; o que houve com as duas linhas, com `Forwarded` e com `X-Real-IP`; a sub-rede;
   se há Cloudflare; e a porta. Só endereços de documentação e `<endereço de quem mediu>`.

**Como ler o resultado.** Com um salto (cliente → Traefik → aplicação), o estado `proxy` está
certo **nos dois** comportamentos — "sobrescreve" e "acrescenta" —, porque ele usa o valor mais à
direita, que é o que o Traefik escreveu. O que muda a configuração é a sub-rede (a lista) e o
Cloudflare: com ele na frente, o valor mais à direita é a borda do Cloudflare, e confiar nas faixas
dele é decisão posterior, com medição própria. Porta 4000 publicada é um caminho direto que não
passa pelo Traefik: fechar antes de ligar.

### §15.3 Ligar o estado `proxy` — 👤, depois da #1063 (077/T012, #1407)

1. No painel do Dokploy, na aplicação: `THE_BAND_ORIGEM=proxy`,
   `THE_BAND_ORIGEM_CABECALHO=x-forwarded-for` e `THE_BAND_ORIGEM_PROXIES=<a sub-rede do passo 4>`.
   **Só a sub-rede do proxy**, e não uma faixa maior "para garantir": quem estiver na lista escolhe
   a origem que quiser. Se a sub-rede é compartilhada com outros serviços, confiar nela é confiar
   neles — risco declarado até a rede dedicada (074, S7).
2. Redeploy, e conferir a linha do log de subida: `ligado, pelo cabeçalho x-forwarded-for vindo de
   <lista>`. Se a aplicação não subiu, a mensagem nomeia a variável errada.
3. **Conferir de fora**, porque "ligado" é afirmação sobre a configuração, e não sobre o
   comportamento: da sua máquina, 11 entradas com um e-mail inexistente em `/sign-in` — a 11.ª dá a
   mesma frase, e o log mostra a transição com o **seu** prefixo, e não o do Traefik; da rede do
   celular, a entrada certa entra.
4. Registrar na #1229 e na #1106 a linha do log de subida e o resultado de fora. **Só então** as
   duas fecham.

### §15.4 O que isto não faz

- **Quem tem muitas origens** (rede de bots, um `/48` de IPv6) não é contido pelo limite por
  origem; só pela espera por conta.
- **Vizinhos sob NAT** dividem a cota com quem ataca: a senha certa deles é recusada enquanto a
  campanha durar. O limite conta falhas, e não entradas certas, o que poupa uma turma que entra junto.
- **Deploy zera a contagem**, e com mais de uma instância o limite efetivo é N × 10.
- **A fila de telemetria** continua recebendo os passos da campanha (`limite_por_origem`).
