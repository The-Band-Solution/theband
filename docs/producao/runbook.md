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
| Painel do Dokploy (registry) | credencial `read:packages` | SÓ se o pacote ghcr for privado |

Nada além disto. Chave que vazar se ROTACIONA (`mix the_band.rotate_key` para a
mestra), nunca se "monitora".

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
5. Derrubar a instância e o banco de ensaio.

Falhou qualquer passo: o backup NÃO existe de verdade — resolver antes de qualquer
release com dado real. Repetir o ensaio a cada mudança no desenho do backup, e no
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
