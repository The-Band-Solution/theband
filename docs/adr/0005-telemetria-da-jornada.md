# ADR 0005 — Telemetria da jornada: `:telemetry` como barramento, coletor local, e taxonomia declarada

## Status

**Aceita — 2026-10-03**, decidida pela pessoa mantenedora em 2026-10-03, com o SigNoz como
backend e as decisões D1–D7 abaixo.

Histórico: Proposta em 2026-09-04 · emendada em 2026-10-03 com a escolha do backend, a
hospedagem, a retenção, a rede e as dependências Hex — ver
[Emenda de 2026-10-03](#emenda-de-2026-10-03--o-backend-é-o-signoz) · aceita no mesmo dia.

### As decisões da pessoa mantenedora (2026-10-03)

Opções e razões em [seguranca.md da 074](../../specs/074-jornada-entrar-e-sair/seguranca.md),
*Decisões da pessoa mantenedora*. Todas seguiram a recomendação.

| | decisão |
|---|---|
| **D1** identificador de pessoa | `users.id` cru, **com minimização**: a identidade só nos desfechos que pedem ação, e no `concluiu` da entrada só quando o sucesso apagou tentativas falhas. Passa para HMAC quando outra pessoa ganhar acesso ao SigNoz |
| **D2** acesso ao painel | **só por túnel SSH**; nenhuma rota no Traefik |
| **D3** hospedagem | **mesmo VPS, via Dokploy** (opção A de E3), teto de 3 GB nos quatro contêineres, rede dedicada só entre a aplicação e o coletor, nenhuma porta publicada. **Cai** se o VPS tiver menos de 4 GB livres — conferido na T024 da 074 |
| **D4** retenção | traços 7 dias, métricas 30 dias, nenhum log; o volume do ClickHouse fica **fora** do backup |
| **D5** dependências | aceitas: `opentelemetry_api` 1.5.0, `opentelemetry` 1.7.0, `opentelemetry_exporter` 1.11.0, com versão exata, e `grpcbox ~> 0.18.0` pelo teto; `mix.lock` revisado; nenhuma porta nova escutando |
| **D6** ordem | segue a regra do §14.0: o código da 074 espera o PR #1227 (#1222) mergeado. A #887 (064/US3) tem as tarefas entregues (#871, #872, #873 fechadas) e espera só a aceitação do Product Owner. A #1162 vem antes do deploy do SigNoz |
| **D7** limite por IP em `POST /session` | issue própria, fora da 074: [#1229](https://github.com/The-Band-Solution/theband/issues/1229) |

Origem: [ÉPICO #802](https://github.com/The-Band-Solution/theband/issues/802), pedido da
pessoa mantenedora · Depende de: [ADR 0001](0001-monolito-modular-elixir.md),
[ADR 0002](0002-yaml-como-base-de-conhecimento.md)

Fecha, se aceita: [#801](https://github.com/The-Band-Solution/theband/issues/801)

## Contexto

Em 2026-09-04, na primeira coleta contra dado real, três defeitos quebraram a plataforma
**sem produzir um único erro visível**: o Oban parou de processar por quatro dias com a
aplicação respondendo `HTTP 200`; um upsert com corrida derrubou o sync depois de gravar
quase tudo; e um tratamento de falha quebrou ao registrar a falha, descartando o job e as
etapas seguintes.

As três foram encontradas por acaso, com `psql`.

A plataforma é construída sobre a tese de que **ausência não é zero e ausência de erro não
é funcionamento** — aplica isso ao dado das organizações com rigor, e não aplicava a si
mesma.

A pessoa mantenedora definiu o eixo: **observar a jornada de quem usa, e derivar as
métricas disso** — *"quero saber quem deu erro ao fazer login ou logout"*.

### A restrição que decide o desenho

**Um Plug não vê a jornada desta aplicação.** Depois do `GET` inicial, LiveView troca
mensagens no WebSocket — `handle_event`, `handle_params`, `handle_info`. Um middleware
veria o primeiro carregamento da tela da equipe e nada do que a pessoa fez ali dentro.

O login por `POST /session` passaria por Plug. *"Abriu a equipe, tentou promover um
vínculo, foi recusada"* não passa por nenhum.

## Decisão

### 1. `:telemetry` é o barramento, e ele já existe

A aplicação já tem `TheBandWeb.Telemetry` com métricas de Phoenix e Ecto declaradas —
falta o exportador. Phoenix, LiveView, Ecto e Oban **já emitem** eventos.
`:telemetry.execute/3` sem handler anexado é um lookup em ETS: custo desprezível.

Nada no domínio conhece OpenTelemetry. O domínio emite evento; quem traduz para span é o
handler, e ele é substituível sem tocar em regra de negócio.

```
domínio · LiveView · Plug
        ↓  :telemetry.execute          barramento, acoplamento zero
   handlers finos (attach)
        ↓  criam span/métrica
   BatchProcessor do OTel              processo próprio, assíncrono
        ↓  OTLP para localhost
   coletor (contêiner ao lado)         retry, buffer, backend fora do ar
        ↓
   backend
```

### 2. A jornada é capturada em três camadas

| camada | onde | o que dá |
|---|---|---|
| `on_mount` | `TheBandWeb.Live.Hooks`, que já tem três | identidade e início da jornada em **toda** LiveView, num lugar só |
| `attach_hook(:handle_event)` | no mesmo `on_mount` | cada interação, sem instrumentar tela por tela — **só o nome do evento e a tela, nunca os parâmetros** (emenda de 2026-10-03; seguranca.md da 074, S2) |
| eventos de domínio | `:telemetry.execute` explícito | *"login falhou por conta sem senha definida"* |

> **Emenda de 2026-10-03 (avaliação de segurança da 074, S2)**: os parâmetros de
> `handle_event` carregam o token do GitHub e a chave do provedor de modelos digitados nas
> telas de ferramenta (`source_live/index.ex`, `ai_live/index.ex`). O gancho, quando existir,
> emite **só** o nome do evento e `socket.view`, e entra com avaliação de segurança própria.
> A 074 não o implementa.

As duas primeiras são quase de graça e pegam a jornada inteira. **A terceira é a que dá o
valor pedido**, e é a única que exige escrever código nos passos — porque nenhum
instrumentador automático sabe a diferença entre *senha errada* e *conta sem senha
definida*.

### 3. A jornada **não** é um traço

Uma sessão LiveView dura dezenas de minutos. Um traço aberto todo esse tempo não fecha,
não exporta, e estoura o processador de lote.

**Span por passo**, com `journey.id` como atributo correlacionando. A jornada se remonta
na consulta, não na memória do processo.

### 4. Dois eixos de classificação, e eles não se misturam

| eixo | responde | exemplo |
|---|---|---|
| **jornada** | o que a pessoa veio fazer | `entrar`, `sair`, `ler_painel_da_pessoa`, `coletar` |
| **domínio** | sobre o que é | `eo.team`, `spo.performed_project_activity` |

Login não é conceito de ontologia, e `eo.team` não é jornada. Usar um eixo só coloca
`login` na mesma lista que `equipe`, e nenhuma das duas perguntas fica respondível.

```
nome do span    the_band.<dominio>.<passo>      the_band.acesso.entrar_com_senha
atributos       journey.name / journey.id / journey.step
                outcome           concluiu | falhou | abandonou
                failure.reason    conta_sem_senha
                tenant.id, user.ref            opacos
                ontology.concept               só quando houver
```

*Vocabulário alinhado em 2026-10-03 à taxonomia da base de conhecimento
(`rules/journey_entrar_e_sair.yaml`, spec 074), que é a fonte única: o filtro do que sai (S1)
valida o **valor** contra ela, e duas enumerações produziriam dois filtros. Era
`ok | falha | abandonada`, `conta_sem_senha_definida` e `user.id`.*

**`outcome` e `failure.reason` são atributos, nunca parte do nome.** Um span chamado
`login_falhou_senha_errada` explode a cardinalidade de nomes e perde a pergunta mais
básica — *quantas tentativas de login houve?*. **Nome é o que foi tentado; atributo é como
terminou.**

### 5. A taxonomia é declarada na base de conhecimento, com gate

`priv/knowledge_base/journeys/` declara cada jornada, seus passos e a **lista fechada de
motivos de falha**. Um gate reprova span cujo `journey.name` ou `failure.reason` não esteja
declarado — o mesmo desenho que a [ADR 0002](0002-yaml-como-base-de-conhecimento.md)
estabeleceu para conceitos e medidas, e que a
[#527](https://github.com/The-Band-Solution/theband/issues/527) fechou para módulos de
ontologia.

Três consequências:

1. **`failure.reason` vira enumeração fechada** — e enumeração fechada pode ser rótulo de
   métrica sem estourar cardinalidade. `user.ref` não pode; `conta_sem_senha` pode,
   porque são cinco valores conhecidos;
2. **a taxonomia não apodrece**: falha nova sem declaração reprova no gate, em vez de virar
   valor órfão que ninguém agrega;
3. **o vocabulário é um só** — traço, spec, base e tela usam os mesmos nomes.

---

## Segurança da telemetria

Esta seção é normativa. Telemetria é **uma cópia do que acontece na aplicação saindo do
processo** — com retenção mais longa e controle de acesso mais frouxo que o banco. É o
caminho pelo qual um segredo deixa o sistema sem ninguém decidir que ele deveria sair.

### S1. O que NUNCA entra em span, evento ou log

Lista fechada, e nenhuma exceção é aceita "para depurar":

| proibido | por quê |
|---|---|
| senha tentada, **inclusive truncada ou com hash** | prefixo de senha é material de ataque; hash de senha fraca é reversível por dicionário |
| token de sessão, cookie, `Authorization` | quem tem o traço passa a poder se passar por quem foi observado |
| token da ferramenta, chave mestra, credencial de LLM | são as credenciais que a plataforma cifra no banco — exportá-las em texto anula a cifra |
| código ou `state` do OAuth | trocáveis por token enquanto a janela estiver aberta |
| corpo de payload da origem | carrega dado das organizações clientes, e não é dado da plataforma |
| e-mail, nome, login de pessoa | ver S2 |

**A garantia é filtro no exportador, não disciplina de quem escreve.** ~~Um `deny-list` de
atributos aplicado antes do envio~~ — **emendado em 2026-10-03** (avaliação de segurança da
074, S1): uma lista proibida falha aberta, porque o atributo novo que ninguém pôs nela sai. O
filtro é uma **lista do que pode sair**, e **reconstrói** cada span no último ponto antes do
envio: nome de span de uma enumeração fechada; atributos permitidos **por nome e pela forma do
valor** (as enumerações validadas contra a base de conhecimento; UUID, HMAC ou correlator
conferidos pela forma); **nenhum evento** (nada de `record_exception`, cuja pilha traz os
argumentos); **status sem descrição**; **recurso reconstruído** só com `service.name`,
`service.version` e `deployment.environment`. Todo descarte é contado. Mais um teste que injeta
uma senha e um token numa jornada e **prova que eles não saem** — a mesma técnica da revisão de
segurança de hoje: injetar o defeito e verificar que o mecanismo o pega.

Sem esse teste, a regra é comentário.

### S2. Identidade é dado pessoal, e o pedido é legítimo

O pedido — *"quero saber **quem** deu erro"* — é operacionalmente necessário: sem
identificar, ninguém reinicia a senha de ninguém.

E a decisão de privacidade tomada nesta mesma data (FR-024 da feature 058) diz que **ler o
trabalho de uma pessoa nomeada exige alcance sobre a equipe dela**. Telemetria não pode ser
a porta dos fundos disso.

As regras:

- **`user.ref` opaco, nunca e-mail.** O id resolve tudo o que o e-mail resolveria, e não
  vaza nada sozinho. Quem precisa do e-mail resolve no banco, onde há controle de acesso;
- **retenção mais curta para traço com identidade** do que para métrica agregada. A métrica
  *"três falhas por conta-sem-senha hoje"* pode viver meses; o traço que diz **quem**, não;
- **quem vê a telemetria é decisão declarada**, como tudo aqui. Um painel de *"quem errou a
  senha"* aberto a qualquer conta da organização é vigilância com outro nome — e
  contradiria a FR-024 no mesmo dia em que ela foi escrita;
- **agregado por tenant é público interno; individual não.** Mesma linha que a feature 058
  traçou entre a mediana da equipe e a quebra por pessoa.

### S3. A distinção que vale na telemetria e **não** vale na tela

*"Conta não existe"* e *"senha errada"* precisam ser **distintos na telemetria** — as ações
são diferentes — e **idênticos na tela**, porque distingui-los ali entrega um oráculo de
enumeração de contas a quem estiver adivinhando e-mails.

É a mesma informação dizendo duas coisas conforme o público, e é o tipo de decisão que se
perde quando não está escrita.

### S4. A telemetria não pode virar vetor

- **O endpoint OTLP é `localhost`.** A aplicação nunca fala com a rede externa para
  exportar; quem atravessa a fronteira é o coletor, e ele é configurado por quem opera;
- **o coletor não é exposto publicamente.** Um coletor OTLP aberto aceita spans forjados de
  qualquer origem, e telemetria envenenada é pior que telemetria ausente — ela produz
  decisão errada com aparência de evidência;
- **o backend tem autenticação própria**, e o segredo dele segue a mesma regra da chave
  mestra: variável de ambiente, nunca no repositório;
- **falha do exportador não derruba a aplicação, e não é silenciosa.** O exportador é
  supervisionado, e o que ele descartar por fila cheia **precisa ser contado** — telemetria
  perdida em silêncio é o defeito desta casa aplicado à própria observabilidade.

### S5. `:telemetry` desanexa handler que levanta exceção

Comportamento da biblioteca, não do nosso código: um handler que falha é **removido
automaticamente**, a aplicação segue normalmente, e a telemetria some sem avisar.

Isso é exatamente o modo de falha dos quatro dias do Oban, um nível acima. **Exige teste**:
handler que levanta não pode derrubar a observabilidade inteira sem que nada acuse.

### S6. O que a telemetria observa sobre acesso é auditoria, e auditoria tem outro dono

Falha de login, concessão de escopo e promoção a administrador são **eventos de segurança**.
Registrá-los na telemetria é útil para operação, e **não** os torna trilha de auditoria: a
trilha exige retenção longa, imutabilidade e cadeia de custódia — o oposto da retenção curta
que S2 exige para dado com identidade.

Esta ADR **não** cria trilha de auditoria, e essa lacuna fica declarada em vez de suposta.

---

## Emenda de 2026-10-03 — o backend é o SigNoz

**Origem**: direção da pessoa mantenedora em 2026-09-24 (*o foco passa a ser tracing com
SigNoz*) e em 2026-09-27, no [comentário do #802](https://github.com/The-Band-Solution/theband/issues/802):
*"criar os tracing no signoz, baseado nos cenários e nas jornadas"*. Fecha a decisão 6 de
`docs/backlog/observabilidade-com-opentelemetry.md` (*onde os dados ficam*). A primeira fatia
que a usa é a [spec 074](../../specs/074-jornada-entrar-e-sair/spec.md), a J1.

A escolha do produto é da pessoa mantenedora, e está tomada. Esta emenda registra **o que
ela custa, onde roda, e o que precisa ser verdade para ela não abrir uma porta nova** — as
quatro coisas que a ADR original deixava para "quando houver número".

### E1. As alternativas, comparadas no que importa aqui

| | Tempo + Loki + Prometheus (+ Grafana) | Serviço gerenciado (Grafana Cloud, Honeycomb, SigNoz Cloud) | **SigNoz no próprio servidor** |
|---|---|---|---|
| o que é | quatro produtos, um por sinal, e o Grafana por cima | o backend de outra empresa | um produto: traço, métrica, log e alerta sobre ClickHouse |
| peças a operar | 4 serviços, 3 armazenamentos, a correlação traço↔métrica configurada à mão | nenhuma | 4 contêineres de longa duração (ClickHouse, ZooKeeper, SigNoz, coletor) e 2 de migração |
| para onde vai o dado com identidade | fica no VPS | **sai para terceiro** — o `user.id` de quem errou a senha passa a morar fora, sob contrato alheio | fica no VPS |
| autenticação do painel | a do Grafana | a do fornecedor | própria, com papéis (admin, editor, viewer) |
| alerta pela **ausência** (US3 do épico) | Prometheus/Alertmanager, sim | sim | sim, alerta sobre métrica e sobre traço |
| custo | memória de 4 serviços; sem custo por evento | por volume; gratuito até um teto, e o teto muda por decisão do fornecedor | memória e disco do VPS (E3); sem custo por evento |
| licença | Grafana, Loki e Tempo em AGPL-3.0; Prometheus em Apache-2.0 | contrato comercial | MIT fora de `ee/` e `cmd/enterprise/` (licença própria lá); ClickHouse em Apache-2.0 |
| o que pesa contra | quatro coisas para observar, num projeto com uma pessoa operando | **S2**: identidade de pessoa sai do sistema por decisão de configuração, e a [FR-024 da 058](../../specs/058-medidas-da-equipe/spec.md) deixa de ser verificável | o ClickHouse é o maior consumidor de memória do VPS depois do Postgres (E3), e a SigNoz trocou o jeito de instalar (E2) |

**Por que SigNoz**: das três, é a única que cumpre ao mesmo tempo **S2** (o dado com
identidade não sai do servidor) e **o custo de operação de uma pessoa** (um produto, e não
quatro). O gerenciado ganharia em operação, e perde no requisito que esta ADR declarou
normativo. A pilha Grafana ganharia em memória por componente, e perde em número de coisas
a manter de pé — que é, ironicamente, o defeito que este épico existe para enxergar.

**O que fica pior**: um produto com opinião própria sobre armazenamento (ClickHouse), cuja
instalação suportada mudou de forma no meio de 2026 (E2), e cuja edição empresarial convive
no mesmo repositório. Trocar de backend continua barato **porque o domínio não conhece o
backend** (decisão 1 desta ADR): a aplicação fala OTLP, e OTLP é o que os três aceitam.

### E2. Como o SigNoz é instalado — e a armadilha da versão

Medido em 2026-10-03:

- a última versão é `v0.144.0` (`gh api repos/SigNoz/signoz/releases/latest`);
- **o `docker-compose.yaml` empacotado deixou de existir**: `deploy/docker/` está presente em
  `v0.125.0` e ausente em `v0.130.0`. `deploy/MIGRATION.md` de `v0.144.0` diz que o
  `install.sh` e o compose sob `deploy/` estão **deprecados** em favor do *Foundry*
  (`foundryctl forge` gera os manifestos a partir de um `casting.yaml`; `foundryctl cast` os
  aplica). A página de instalação em Docker já descreve só o Foundry;
- o compose de `v0.125.0` publica `4317`, `4318` e `8080` em **todas as interfaces** do host,
  e traz `SIGNOZ_TOKENIZER_JWT_SECRET=secret` escrito no arquivo.

Consequências, todas vinculantes para a implantação:

1. **O compose implantado é gerado e versionado**, e não baixado no dia. `foundryctl forge`
   roda na máquina de quem opera, o resultado entra no repositório com as imagens fixadas por
   tag, e o Dokploy implanta **aquele** arquivo. Imagem `latest` não identifica o que roda —
   o mesmo argumento do achado H7 da casa;
2. **nenhuma porta do coletor, do ClickHouse ou do ZooKeeper é publicada no host.** A
   aplicação alcança o coletor pela rede interna do Docker;
3. **o segredo do emissor de token do SigNoz vem do ambiente** (variável no Dokploy, nunca
   no arquivo). O valor do compose de referência, `secret`, é público, e quem o conhece
   forja sessão no painel.

### E3. Onde o SigNoz roda, e quanto custa

**Medido nesta máquina** (Docker Desktop, aarch64, 10 CPUs, 7,75 GiB para o Docker), com o
compose de `v0.125.0` (`signoz/signoz:v0.125.0`, `signoz/signoz-otel-collector:v0.144.4`,
`clickhouse/clickhouse-server:25.5.6`, `signoz/zookeeper:3.7.1`), as portas trocadas para
`127.0.0.1` e o projeto isolado (`docker compose -p signoz-medida up -d`), sem tocar no
`the_band_postgres`:

```bash
docker compose -p signoz-medida up -d          # o compose de v0.125.0, portas em 127.0.0.1
docker stats --no-stream signoz signoz-otel-collector signoz-clickhouse signoz-zookeeper-1
python3 carga.py 100000                        # 100 000 spans OTLP/HTTP no formato da J1
docker exec signoz-clickhouse clickhouse-client -q \
  "SELECT table, sum(rows), sum(bytes_on_disk) FROM system.parts
   WHERE database='signoz_traces' AND active GROUP BY table"
docker system df -v
docker compose -p signoz-medida down -v        # nada ficou de pé
```

| contêiner | ocioso (~4 min após subir) | logo após 100 000 spans | 20 s depois |
|---|---|---|---|
| `signoz-clickhouse` | 1,27 GiB | 1,63 GiB | 1,48 GiB |
| `signoz-zookeeper-1` | 773 MiB | 774 MiB | 774 MiB |
| `signoz` (consulta e painel) | 54 MiB | 54 MiB | 54 MiB |
| `signoz-otel-collector` | 28 MiB | 291 MiB | 291 MiB |
| **total** | **≈ 2,1 GiB** | **≈ 2,7 GiB** | **≈ 2,6 GiB** |

- **disco por span**: 100 000 spans da J1 (seis atributos, ids aleatórios) ocuparam
  **≈ 18,8 MB** no ClickHouse — `signoz_index_v3` 11,1 MB, `tag_attributes_v2` 5,1 MB,
  `trace_summary` 2,7 MB —, ou seja **≈ 190 bytes por span**. Os 100 000 entraram em 4,8 s;
- **disco das imagens**: 2,58 GB (ClickHouse 851 MB, ZooKeeper 779 MB, coletor 705 MB,
  SigNoz 248 MB). Volumes vazios: ~70 MB;
- **o que esta medida NÃO é**: não é o VPS (é aarch64 com Docker Desktop), não é a versão
  atual do SigNoz (é a `v0.125.0`, a última com compose empacotado), e o ClickHouse não teve
  teto de memória. Serve de ordem de grandeza, e bate com a fonte externa abaixo.

**Um defeito encontrado na própria medida, e ele é do tipo que esta casa persegue.** Na
primeira subida, o coletor (`v0.144.4`) recebia a configuração do servidor (`v0.125.0`) por
OpAMP; o servidor respondeu erro, e o coletor aplicou uma configuração **`nop`** — sem
receptor OTLP nas pipelines. Ficou de pé, *healthy*, e **recusava toda conexão em 4318**. Um
coletor que sobe verde e não recebe nada é o Oban dos quatro dias, no backend de telemetria.
Rodar o coletor só com `--config` resolveu na medida; na implantação, a defesa é a do E2 —
versões do servidor e do coletor **fixadas juntas**, e o quickstart da 074 conferindo que um
span de teste **chegou** ao ClickHouse, e não que o contêiner subiu.

**A J1 em disco**: com 50 pessoas entrando e saindo duas vezes por dia, uns 300 spans por dia
— **≈ 57 KB por dia, menos de 1 MB em 7 dias**. O disco da J1 é desprezível; o custo é a
memória ociosa.

**A fonte externa, para conferir a ordem de grandeza**: a Virtua Cloud mediu a `v0.116.1`
num VPS de 4 vCPU e 8 GB — ~1,6 GB ociosa (ClickHouse ~775 MB, ZooKeeper ~775 MB, SigNoz
~50 MB, coletor ~35 MB), ~3,4 GB sob ~1 000 linhas de log/s e 100 traços/s, imagens com
~2,7 GB e ~4,2 GB de disco em 24 h **naquela carga**
([virtua.cloud](https://www.virtua.cloud/learn/en/tutorials/self-host-signoz-openobserve-vps)).
A documentação oficial exige **pelo menos 4 GB de memória para o Docker**
([signoz.io/docs/install/docker](https://signoz.io/docs/install/docker/)).

**A carga da J1 é outra ordem de grandeza.** Entrar e sair produz um punhado de spans por
pessoa por dia; a carga da fonte é ~8,6 milhões de traços por dia. O que domina o custo aqui
é a **memória ociosa** do ClickHouse e do ZooKeeper, e não o volume.

**O VPS de produção**: o runbook (§1.1) dimensiona **8 GB** para painel + app + Postgres. O
tamanho real e a memória livre **não foram medidos** nesta emenda — a sessão não tem acesso
ao servidor, e a regra da casa proíbe afirmar o que não se mediu.

| opção | o que custa | o que pesa contra |
|---|---|---|
| **A. No mesmo VPS, via Dokploy, com teto de memória** | ≈ 2,1 GiB de RAM ociosa, ≈ 2,7 GiB no pico medido; ≈ 2,6 GB de imagens e menos de 1 MB por semana de dado da J1; nenhum custo mensal novo | divide memória com o Postgres e com a aplicação: sem teto, um pico do ClickHouse vira OOM de quem atende |
| B. Num segundo VPS | um VPS pequeno a mais por mês, e o preço é o da Contabo no dia | o coletor deixa de ser local: o traço atravessa a internet, e o coletor passa a precisar de TLS e autenticação — S4 fica mais difícil, não mais fácil |
| C. Gerenciado | por volume | recusado em E1 (S2) |

**Recomendação: A**, com três condições, e o critério que a derruba escrito antes:

1. **Teto de memória** nos contêineres do SigNoz (`mem_limit`) e no ClickHouse
   (`max_server_memory_usage` em 1,5 GB, abaixo do pico medido de 1,63 GiB, que veio de uma
   rajada de 100 000 spans em 5 s que a J1 não produz), somando no máximo **3 GB** para os
   quatro contêineres;
2. **medir antes de subir**: a pessoa mantenedora roda `free -m` e `docker stats --no-stream`
   no VPS e registra na tarefa 👤 correspondente. **Se a memória disponível, com a aplicação e
   o Postgres de pé, for menor que 4 GB** (o teto de 3 GB mais 1 GB de folga para o cache de
   página do Postgres), a opção A cai e vale B;
3. **medir depois de subir**: o mesmo `docker stats` com o SigNoz ocioso por 5 minutos, no
   VPS, substitui a medida desta máquina neste documento.

### E4. Retenção

O SigNoz retém **por sinal** (traços, logs, métricas), e não por atributo. Então a regra de
S2 — *retenção mais curta para o que tem identidade* — se cumpre pelo sinal que carrega a
identidade:

| sinal | carrega identidade? | retenção recomendada | por quê |
|---|---|---|---|
| **traços** | sim — `user.ref` e `tenant.id` (spec 074) | **7 dias** | o que diz **quem** errou serve para agir esta semana: reiniciar a senha, investigar uma campanha. Depois disso é vigilância guardada |
| **métricas** | **não** — rótulos só de enumeração fechada (`journey.name`, `journey.step`, `outcome`, `failure.reason`) e `tenant.id` | **30 dias** | é a série que responde *"isto piorou?"*, e não diz quem |
| **logs** | a primeira fatia **não envia log** ao SigNoz | — | o log da aplicação continua onde está; mandar log é decisão de outra fatia, com a mesma redação da #1222 |

Configura-se na tela do SigNoz (*Settings → General → Retention*). A configuração **não é
código**, e por isso a fatia que a usa tem uma tarefa 👤 com conferência, e não um teste.

### E5. Autenticação, acesso e rede

- **O painel do SigNoz não é público.** Recomendado: nenhuma rota no Traefik; acesso por
  túnel SSH (`ssh -L`) até a porta do painel. Alternativa, se túnel for incômodo demais:
  rota no Traefik com HTTPS **e** lista de IPs permitidos **e** o login do SigNoz. A
  primeira conta criada no SigNoz vira administradora — **o painel não pode ficar alcançável
  antes de a pessoa mantenedora criar essa conta**;
- **quem vê**: só quem opera a plataforma. Nenhuma conta de organização cliente vê o SigNoz.
  É o que mantém S2 e a FR-024 da 058 verdadeiras: o painel tem identidade de pessoas de
  **todas** as organizações, e por isso não pode ser oferecido a nenhuma delas;
- **a rede** (refinada em E7, item 2: uma rede só entre aplicação e coletor): a aplicação e o coletor na mesma rede Docker; **o coletor não
  publica porta no host**, e o endpoint OTLP da aplicação é o nome do serviço na rede
  interna. Isto **corrige a redação de S4**: "o endpoint é `localhost`" não vale para uma
  aplicação em contêiner, onde `localhost` é o próprio contêiner. O que S4 queria — *nenhum
  coletor alcançável de fora* — vale como **nenhuma porta publicada**;
- **o protocolo**: OTLP sobre HTTP (`4318`), sem TLS **dentro** da rede Docker, porque não
  atravessa a máquina. Se a opção B de E3 for escolhida, TLS e cabeçalho de autenticação
  passam a ser obrigatórios, e esta linha muda.

### E6. As dependências Hex — o que entra, e o que não entra

Versões e datas medidas em `hex.pm/api` em 2026-10-03:

| pacote | versão | publicada | licença | entra? | por quê |
|---|---|---|---|---|---|
| `opentelemetry_api` | 1.5.0 | 2025-10-17 | Apache-2.0 | **sim** | a API que o handler chama para abrir e fechar span. Mantida pelo projeto OpenTelemetry (`open-telemetry/opentelemetry-erlang`); ~32 M downloads |
| `opentelemetry` | 1.7.0 | 2025-10-17 | Apache-2.0 | **sim** | o SDK: o processador em lote, a amostragem e o recurso. Exige `opentelemetry_api ~> 1.5.0`. **A 1.4.1 foi aposentada** por *breaking bug* |
| `opentelemetry_exporter` | 1.11.0 | 2026-09-16 | Apache-2.0 | **sim** | o exportador OTLP. Exige `opentelemetry ~> 1.7.0`, `opentelemetry_api ~> 1.5.0`, `tls_certificate_check ~> 1.18` e `grpcbox` |
| `grpcbox` | 0.18.0 | 2026-07-11 | Apache-2.0 | **declarada direto, `~> 0.18.0`** | o exportador a exige **sem teto** (`>= 0.0.0`) mesmo usando HTTP; declarar direto é só para pôr o teto (seguranca.md da 074, S9). Exige `gproc ~> 1.2.0`, `ctx ~> 0.6.0`, `acceptor_pool ~> 1.0.0`, `ts_chatterbox ~> 0.16.0` |
| `ts_chatterbox` (transitiva) | 0.16.0 | 2026-06-28 | MIT | vem junto | exige `hpack_erl ~> 0.3.0` |
| `hpack_erl` (transitiva) | 0.3.0 | 2023-06-03 | — | vem junto | — |
| `ctx` (transitiva) | 0.6.0 | 2020-12-23 | Apache-2.0 | vem junto | **sem release há quase seis anos** |
| `gproc` (transitiva) | **1.2.0** | 2026-04-11 | Apache-2.0 | vem junto | `~> 1.2.0` não aceita a 1.3.0 |
| `acceptor_pool` (transitiva) | 1.0.1 | 2025-12-15 | Apache-2.0 | vem junto | — |
| `tls_certificate_check` (transitiva) | 1.35.0 | 2026-08-13 | MIT | vem junto | as versões ≤ 1.6.0 foram aposentadas por *Outdated Certification Authorities*; exige `ssl_verify_fun ~> 1.1` |
| `ssl_verify_fun` (transitiva) | 1.1.7 | 2023-06-20 | MIT | vem junto | não está no `mix.lock` de hoje |
| `opentelemetry_phoenix` | 2.0.1 | 2025-02-21 | Apache-2.0 | **não, na primeira fatia** | o span de rota carrega `url.path` e `url.query`, e a query é onde mora o que S1 proíbe. Responde *"o servidor está bem?"*, que esta ADR já recusou como eixo |
| `opentelemetry_bandit` | 0.3.0 | 2025-08-21 | Apache-2.0 | **não** | mesmo motivo |
| `opentelemetry_ecto` | 1.2.0 | **2024-02-06** | Apache-2.0 | **não** | 20 meses sem release. E o span de consulta é exatamente o caminho que a [#1222](https://github.com/The-Band-Solution/theband/issues/1222) fechou no log. A regra de `TheBand.Repo.LogDaConsulta.redigir?/2` (sobre `TheBand.Rotacao.campos_cifrados/0`) é **necessária e não suficiente**: a consulta do login passa o identificador digitado sobre `users`, e o `UPDATE` da senha leva o `password_hash` — tabelas sem campo cifrado. Se entrar um dia, entra com avaliação própria e redigindo também `users`, `user_sessions` e as credenciais do operador (seguranca.md da 074, S3) |
| `opentelemetry_oban` | 1.2.0 | 2026-02-27 | Apache-2.0 | **não, nesta fatia** | é da J2/US3 (coleta e o Oban parado) |
| `opentelemetry_req` | 1.0.0 | 2024-11-21 | Apache-2.0 | **não** | o span de saída HTTP leva URL e cabeçalhos da chamada à origem — onde viaja o token da ferramenta |
| `opentelemetry_telemetry` | 1.1.2 | 2024-09-24 | Apache-2.0 | **não** | o handler próprio da casa já anexa ao `:telemetry` (decisão 1); a ponte genérica é generalidade sem segundo uso |

**Nenhum instrumentador entra na primeira fatia.** Os spans são os **passos de jornada**,
emitidos pelo domínio em `:telemetry.execute` e traduzidos por **um** handler — que é onde a
lista do que pode sair (S1) é aplicada. Cada instrumentador automático seria um segundo
caminho de atributos para fora do processo, sem passar por essa lista.

**São onze pacotes novos**: três diretos, `grpcbox` declarado direto só pelo teto, e sete
transitivos (inventário corrigido em 2026-10-03 pela avaliação de segurança da 074, S9; a
primeira versão desta emenda contava nove e dava `gproc` 1.3.0). Passam por `mix hex.audit`
**e** `mix deps.audit` **antes** do merge, com o diff do `mix.lock` revisado linha a linha
(pacote novo no lock é decisão, e não efeito colateral), e com a conferência, depois do boot da
release, de que **nenhuma porta nova escuta** — `grpcbox`, `ts_chatterbox` e `acceptor_pool` são
cliente **e servidor** HTTP/2, e o exportador por HTTP não usa nenhum deles.

**Risco que os gates não cobrem**: uma única conta pessoal no Hex publica `grpcbox`, `ctx`,
`ts_chatterbox` e `hpack_erl` (a do mantenedor do OpenTelemetry Erlang). `hex.audit` vê
aposentadoria e `deps.audit` vê avisos conhecidos; nenhum dos dois vê uma versão maliciosa
recém-publicada. O `mix.lock` protege as versões já publicadas, e não as próximas — por isso
versão exata nas diretas e o teto em `grpcbox`.

A aceitação das onze é decisão da pessoa mantenedora, junto com a desta ADR.

### E7. O que a avaliação de segurança da 074 acrescentou a esta emenda

A [avaliação](../../specs/074-jornada-entrar-e-sair/seguranca.md), feita por quem não escreveu
este desenho, achou três pontos **altos** (S1, S2, S6) e onze médios. Os que mudam esta ADR já
estão aplicados acima (S1 da ADR, decisão 2, alternativas, E6, vocabulário). Os que mudam a
**implantação** valem como condição da opção A de E3:

1. **Bloqueio da implantação do SigNoz até haver evidência lida** (S6): compose versionado sem
   nenhuma chave `ports:`; no VPS, `ss -ltnp` sem 8080, 4317, 4318, 8123, 9000, 2181; **e** uma
   tentativa de conexão de fora do VPS, recusada — porque porta publicada pelo Docker entra pela
   cadeia `DOCKER` do `iptables` **antes** do `ufw`, e conferir o firewall não prova nada; a
   chave do JWT sem valor padrão no compose (sem a variável, o contêiner não sobe); a primeira
   conta criada pelo túnel, e a lista de usuários conferida depois; ClickHouse com senha vinda do
   ambiente; imagens fixadas por **resumo** (`@sha256:`), e não só por tag;
2. **redes separadas** (S7): uma rede só entre a aplicação e o coletor; ClickHouse, ZooKeeper e
   painel em outra, sem a aplicação. O coletor roda com `--config` versionado e **sem OpAMP** —
   que, na medida de E3, reescreveu o pipeline para `nop` e, em geral, deixaria quem administra o
   painel trocar o destino dos dados. Token de portador no receptor OTLP é recomendado na opção A
   e obrigatório na B;
3. **a #1162** (distribuição Erlang em `0.0.0.0`) é pré-requisito da opção A: pôr quatro imagens
   de terceiros ao alcance da aplicação é construir sobre a porta que se sabe aberta;
4. **o que sai pelo próprio SigNoz** (S8): a telemetria de uso do produto desligada, conferida
   pelo **tráfego de saída** do contêiner e não pela variável; o alerta é sobre métrica, sem
   atributo de traço no corpo, e o canal é declarado no runbook;
5. **a retenção real** (S13): o TTL do ClickHouse age na fusão de partes, então a conferência é a
   idade do traço mais antigo depois de oito dias; o volume do ClickHouse fica **fora** do
   backup (ou o backup tem a mesma retenção); as dimensões de qualquer métrica derivada de traço
   são uma segunda lista do que pode sair, versionada, sem `user.ref` nem `journey.id`;
6. **a configuração do SDK** (S10): o SDK lê `OTEL_*` do ambiente por conta própria. A aplicação
   o configura **explicitamente**, valida o destino contra os hosts permitidos e, sem variável,
   não configura exportador nenhum — o padrão do exportador é `localhost:4318`, que no contêiner
   é a própria aplicação, e seria telemetria "ligada" falhando em silêncio.

### E8. O que esta emenda NÃO decide

- **o custo por requisição** (Verificação 1) e **o volume de uma coleta** (Verificação 2)
  continuam sem número: o primeiro só existe com a J1 instrumentada, o segundo com a J2. A
  J1 é volume desprezível, e por isso a escolha do backend não depende dele; a J2 depende,
  e reabre E3 quando chegar;
- **amostragem**: a J1 é exportada **inteira** (sem amostragem). *Tail sampling* volta a ser
  pergunta quando a J2 trouxer volume;
- **onde a taxonomia mora, por enquanto**: a decisão 5 previa `priv/knowledge_base/journeys/`.
  Para **uma** jornada, a 074 a declara como `derivation_rule` em `rules/` (precedente:
  `access.account_lifecycle`), sem schema novo — research R7 da 074. A pasta própria entra na
  terceira jornada declarada, e a decisão 5 continua valendo para o que ela exige: lista
  fechada, e gate;
- **pseudonimização do identificador de pessoa**: decidida em D1 (id cru com minimização; HMAC
  quando outra pessoa ganhar acesso ao SigNoz);
- **a ordem** (D6): o código da 074 espera o PR #1227
  ([#1222](https://github.com/The-Band-Solution/theband/issues/1222)) mergeado — §14.0, item 2:
  mesma superfície. A [#887](https://github.com/The-Band-Solution/theband/issues/887) (064/US3)
  tem as três tarefas entregues (#871, #872, #873 fechadas, conferido em 2026-10-03) e espera só a
  aceitação do Product Owner; não bloqueia. A
  [#1162](https://github.com/The-Band-Solution/theband/issues/1162) é pré-requisito da
  implantação na opção A (E7, item 3).

---

## Alternativas consideradas

### Plug/middleware como ponto de captura

**Recusada** pela restrição do contexto: LiveView não passa por Plug depois do mount. Um
middleware entregaria a jornada de login e perderia todo o resto — e daria a impressão de
cobertura, que é pior do que não ter.

### Instrumentação automática apenas

Ligar os instrumentadores de Phoenix, Ecto e Oban e parar aí. **Recusada**: entrega
latência de rota e contagem de consulta, que responde *"o servidor está bem?"* — e o
servidor **estava bem** nos quatro dias em que o Oban esteve parado. Não distingue os cinco
desfechos do login, que é o pedido.

~~Fica como **base**, não como solução: os automáticos entram, e os spans de domínio são
acrescentados por cima.~~ **Emendado em 2026-10-03** (avaliação de segurança da 074, S2 e S3):
os automáticos **não** entram por padrão. Cada um é um segundo caminho de atributos para fora
do processo — a rota leva a query string; a consulta leva o identificador digitado e o
`password_hash` como parâmetro, sobre tabelas que a redação da #1222 não cobre; a chamada HTTP
leva o token da ferramenta. Um instrumentador só entra numa fatia própria, com avaliação de
segurança própria, e passando pelo mesmo filtro do S1 (E6).

### Traço por sessão LiveView

**Recusada** por mecânica: traço de 40 minutos não fecha e estoura o processador de lote.

### Log estruturado em vez de OTel

**Recusada** com ressalva. Log estruturado com `journey_id` responderia boa parte, e é mais
barato. Perde a correlação automática entre aplicação, banco e jobs, e não dá métrica sem
uma segunda ferramenta.

A ressalva: se a medição do custo (ver Verificação) mostrar impacto relevante, esta
alternativa volta à mesa — ela não está descartada por princípio.

## Consequências

**Ganha-se** a capacidade de responder *quem não conseguiu entrar e por quê*, *onde a
jornada de conectar trava*, e *quantas vezes a tela recusou mostrar um número* — a métrica
que só esta plataforma tem, e que mede quanto da promessa do produto está alcançável com o
dado que a organização tem.

**Paga-se**:

- **mais um processo que pode falhar** — o exportador, supervisionado, com descarte contado;
- **mais um contêiner no VPS** — o coletor, com memória e disco medíveis;
- **spans manuais nos passos de jornada.** É onde a instrumentação envelhece mal: `span` em
  toda função polui o código. A defesa é o eixo — span existe onde há **passo de jornada**,
  não onde há função;
- **uma taxonomia a manter**, com gate. Custo de disciplina, e é o mesmo que a base de
  conhecimento já cobra.

**Não se resolve**: nada disso teria pegado o Oban parado. Um Oban inerte não emite span —
não emite nada, e essa é a definição do problema. Traço mostra o que aconteceu; a falha era
o que **deixou** de acontecer. O que fecha aquele buraco é verificação **de ausência** —
métrica de jobs concluídos com alerta quando zera, ou *dead man's switch*. Está na US3 do
épico, e é a parte que não vem da ferramenta.

## Verificação

Esta ADR só é aceita com números medidos, e não com estimativa:

1. **custo por requisição** — instrumentar apenas a jornada de login e comparar a latência
   com e sem, no mesmo cenário. É o número que decide se o desenho paga;
2. **volume** — quantos spans uma coleta de 125 repositórios produz. Decide backend próprio
   ou gerenciado, e hoje ninguém sabe;
3. **o teste do vazamento** — injetar senha e token numa jornada e provar que não saem no
   exportador (S1);
4. **o teste do handler que falha** — provar que um handler com exceção não apaga a
   observabilidade em silêncio (S5);
5. **o teste do gate da taxonomia** — `journey.name` não declarado reprova (item 5).

Sem 1 e 2, a decisão de backend seria escolha no escuro. Sem 3, 4 e 5, as regras desta ADR
são comentário.

## Referências

- [ÉPICO #802](https://github.com/The-Band-Solution/theband/issues/802) — a proposta e o
  fatiamento em jornadas
- [#801](https://github.com/The-Band-Solution/theband/issues/801) — o Oban que parou sem
  produzir erro
- [#800](https://github.com/The-Band-Solution/theband/issues/800) — a corrida no upsert
- `specs/058-medidas-da-equipe/spec.md` — FR-024, a fronteira de acesso que S2 não pode
  contornar
- `docs/backlog/observabilidade-com-opentelemetry.md` — as cinco jornadas mapeadas
