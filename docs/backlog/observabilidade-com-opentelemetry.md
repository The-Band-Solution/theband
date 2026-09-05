# Épico — Observabilidade da jornada, com OpenTelemetry

**Estado**: proposta de épico. **Impacta a arquitetura**, e por isso exige ADR antes de
qualquer código (constituição, seção *Decisões que exigem ADR*).

Pedido da pessoa mantenedora em 2026-09-04, com o eixo definido por ela: **observar a
jornada de quem usa, e derivar as métricas disso** — não o contrário.

> *"quero saber quem deu erro ao fazer login ou logout"*

## O eixo, e por que ele muda tudo

Há dois jeitos de instrumentar uma aplicação, e eles produzem coisas diferentes.

O primeiro liga os instrumentadores automáticos, ganha latência de rota, contagem de
consulta e uso de memória, e monta painéis. Isso responde *"o servidor está bem?"* — e o
servidor **estava bem** nos quatro dias em que o Oban esteve parado.

O segundo começa pela **jornada**: o que uma pessoa veio fazer aqui, quais passos isso
tem, e o que acontece em cada um. As métricas então não são escolhidas — elas **caem**
das jornadas, porque cada passo tem três desfechos que interessam: concluiu, falhou por
um motivo nomeado, ou **foi abandonado**.

Este épico é o segundo. A diferença aparece no exemplo que originou o pedido: *"latência
média do `POST /session`"* é uma métrica de servidor e não responde nada. *"três pessoas
tentaram entrar, duas com senha errada e uma cuja conta nunca teve senha definida"*
responde, e ainda diz **o que fazer com cada uma**.

## De onde este épico veio

Em 2026-09-04, na primeira coleta contra dado real, três coisas quebraram **sem produzir
um único erro visível**:

| o que quebrou | por quanto tempo | o que se via |
|---|---|---|
| o Oban parou de processar ([#801](https://github.com/The-Band-Solution/theband/issues/801)) | **4 dias** | `HTTP 200` em toda rota, healthcheck verde |
| upsert da equipe derivada com corrida ([#800](https://github.com/The-Band-Solution/theband/issues/800)) | uma coleta inteira | sync `failed` **depois** de gravar quase tudo |
| o tratamento de falha quebrava ao registrar a falha | 5 tentativas, depois silêncio | job `discarded`, etapas seguintes nunca rodaram |

As três foram encontradas **por acaso**, com `psql`. A plataforma inteira é construída
sobre a tese de que **ausência não é zero e ausência de erro não é funcionamento** — e não
aplicava isso a si mesma.

---

## As jornadas, e o que cada passo precisa dizer

Uma jornada é um **traço**. Cada passo é um span. O desfecho de cada passo é o que vira
métrica.

### J1 — Entrar e sair *(a que o pedido nomeou)*

| passo | desfechos que precisam ser distinguidos |
|---|---|
| pedir a tela de entrada | — |
| entrar com senha | ✅ entrou · ❌ **senha errada** · ❌ **conta sem senha definida** · ❌ **conta não existe** · ❌ **tenant errado** |
| entrar pelo GitHub | ✅ entrou · ❌ recusou a autorização · ❌ **escopo faltando** · ❌ **conta do GitHub sem elo** · ❌ a origem não respondeu |
| primeira conta do ambiente | ✅ criada · ❌ já existia · ❌ variável ausente |
| definir a senha | ✅ definida · ❌ vínculo expirado · ❌ recusada pela regra |
| sair | ✅ saiu · ❌ **sessão já não existia** |

**As cinco falhas do segundo passo têm cinco ações diferentes**, e hoje as cinco produzem
a mesma coisa no log: nada. *Senha errada* é a pessoa; *conta sem senha* é quem
administra que precisa reiniciá-la; *conta não existe* pode ser alguém tentando adivinhar
e-mails. Contá-las juntas como *"erros de login"* apagaria exatamente a informação que faz
alguém agir.

**E `sair` está na lista de propósito.** Um logout que falha é invisível por definição —
a pessoa fecha a aba e vai embora, e a sessão que devia morrer não morreu. É a falha que
ninguém reporta.

### J2 — Conectar uma ferramenta e coletar pela primeira vez

Cadastrar a credencial · validar contra a origem · a primeira coleta · **ver dado na
tela**. A jornada só termina no último passo, e é ele que hoje ninguém mede: entre
*"conectou"* e *"viu dado"* houve três defeitos hoje, e do lado de fora tudo parecia
igual.

Desfechos que precisam de nome: escopo faltando · organização inexistente · a coleta
começou e **parou no meio** · a coleta terminou e **não trouxe nada**.

### J3 — Declarar a estrutura, e promover o que foi observado

Esta é a jornada que o dado real acabou de expor: **79 evidências de vínculo coletadas,
zero promovidas.** A plataforma observa o vínculo e exige confirmação humana do papel —
e enquanto ninguém confirma, toda medida de nível equipe fica sem base.

Vista como jornada, a pergunta muda de *"quantas promoções houve?"* para **"onde as
pessoas param?"**: abrem a tela e não veem a seção · veem e não escolhem papel · escolhem
e a promoção é recusada · promovem uma e abandonam as outras 78.

Cada uma dessas paradas pede uma correção diferente **de produto**, não de código.

### J4 — Ler uma medida

Abrir a tela · a medida existir · **ou a recusa ser dita**. Aqui a instrumentação tem um
uso que só esta plataforma tem: contar **quantas vezes a tela recusou mostrar um número, e
por qual motivo** — `{:sem_projeto, _}`, `{:aguardando, _}`, período parcial, equipe de
uma pessoa.

Essa métrica não é sobre desempenho: é sobre **quanto da promessa do produto está
alcançável com o dado que a organização tem**. Uma recusa que dispara em 90% das telas é
um pedido de feature, e hoje ninguém sabe que ela dispara.

### J5 — Administrar acesso

Conceder escopo · ligar conta a pessoa · promover a administrador. Falha aqui é a que
mais gera chamado, e a que menos deixa rastro.

---

## As métricas, derivadas — e não escolhidas

Nenhuma delas foi inventada: cada uma cai de um passo acima.

| métrica | de onde cai | a decisão que ela apoia |
|---|---|---|
| entradas por desfecho, **com o motivo nomeado** | J1 | reiniciar senha, investigar tentativa de enumeração |
| logouts que falharam | J1 | sessão que não morreu é risco, não incômodo |
| jornadas de conexão que **não chegaram a "viu dado"** | J2 | é onde os três defeitos de hoje moravam |
| evidências promovidas ÷ coletadas, por organização | J3 | onde o produto trava sem ninguém reclamar |
| recusas de medida por motivo | J4 | o que falta no dado para a promessa valer |
| **jobs concluídos por minuto** | transversal | o alerta é a **ausência** dela — foi o que faltou nos 4 dias |

---

## As decisões que a spec precisa registrar

Cada uma tem um jeito errado que parece certo.

### 1. Identificar quem falhou é dado pessoal, e isso tem regra

O pedido é explícito — *"quero saber **quem** deu erro"* — e é legítimo: sem identificar,
não há como reiniciar a senha de ninguém.

E a decisão de privacidade que esta casa acabou de tomar (FR-024, em 2026-09-04) diz que
**a leitura do trabalho de uma pessoa nomeada tem alcance**. Telemetria com identidade
não pode ser a porta dos fundos disso.

O que a spec precisa fixar:

- **identificador opaco** (`user_id`) no span, nunca o e-mail no atributo — e-mail é o
  dado que vaza melhor e não acrescenta nada que o id não dê;
- **jamais** a senha tentada, o token de sessão, o código do OAuth. Nem truncados;
- **retenção mais curta** para traço com identidade do que para métrica agregada — traço
  costuma ter retenção maior e controle de acesso menor que o banco, e é o caminho pelo
  qual um dado sensível sai do sistema sem ninguém decidir;
- **quem vê a telemetria** é decisão declarada, como tudo aqui. Um painel de *"quem errou
  a senha"* aberto a qualquer pessoa da organização é vigilância com outro nome.

### 2. A distinção que vale na telemetria e **não** vale na tela

*"Conta não existe"* e *"senha errada"* precisam ser **distintos na telemetria** — as
ações são diferentes — e **idênticos na tela**, porque distingui-los ali entrega um
oráculo de enumeração de contas a quem estiver tentando adivinhar e-mails.

É a mesma frase dizendo duas coisas conforme o público, e é o tipo de decisão que se perde
se não estiver escrita.

### 3. Cardinalidade: `tenant_id` e `user_id`

Atributo de span **sim**; rótulo de métrica **não**. Rótulo por usuário multiplica as
séries pelo número de contas e derruba o backend — e o efeito aparece meses depois, o que
faz dele o erro mais caro da lista.

### 4. Amostragem apaga justamente o que interessa

Amostrar 10% dos traços apaga 90% das falhas de login — e falha de login é evento raro por
definição. Para uma plataforma cujo defeito característico é o **evento raro que não
produz erro**, amostragem uniforme é a decisão errada.

O caminho provável é *tail sampling*: guardar o traço inteiro quando ele contém erro.
Exige coletor com estado, e é decisão de arquitetura.

### 5. O que OpenTelemetry **não** resolve

**Nada disso teria pegado o Oban parado.** Um Oban inerte não emite span — não emite nada,
e essa é a definição do problema. Traço mostra o que aconteceu; a falha era o que
**deixou** de acontecer.

O que fecha aquele buraco é verificação **de ausência**: métrica de jobs concluídos com
alerta quando ela zera, ou um *dead man's switch* — um sinal periódico cuja falta é o
alarme.

É aqui que o épico deixa de ser *"instalar OpenTelemetry"* e passa a ser **"perceber o
silêncio"**. Um épico que confunda os dois entrega painéis bonitos com o mesmo ponto cego
de hoje.

### 6. Onde os dados ficam, e quanto custa

Backend próprio no VPS (Tempo/Loki/Prometheus, ou SigNoz) contra serviço gerenciado. O
primeiro não tem custo por evento e tem custo de operação — **mais uma coisa para
observar**. O segundo tem custo por volume.

A decisão precisa vir com **número medido**: quantos spans uma coleta de 125 repositórios
produz. Hoje ninguém sabe, e escolher antes de medir é escolher no escuro.

---

## O impacto na arquitetura, dito antes de decidir

| camada | o que entra |
|---|---|
| dependências | `opentelemetry`, `opentelemetry_exporter`, instrumentadores de Phoenix, Ecto, Oban e do cliente HTTP |
| supervisão | o exportador vira processo supervisionado — mais uma coisa que pode falhar, e que precisa falhar **ruidosamente** |
| configuração | endpoint, cabeçalhos, amostragem e nome do serviço por ambiente, em `runtime.exs`, com o cuidado de segredo que a chave mestra tem |
| implantação | um coletor OTLP e um backend, no mesmo VPS via Dokploy, com custo de memória e disco medível |
| código | spans manuais nos **passos da jornada** — e é aqui que este épico difere: o instrumentador automático dá a rota, não dá o passo |

**Nada disso é reversível de graça.** Instrumentação mal colocada polui o código com
`Tracer.with_span` em toda função e envelhece pior do que a ausência dela. A defesa é o
eixo: span existe onde há **passo de jornada**, e não onde há função.

---

## Fatiamento sugerido

Cada fatia entrega uma jornada inteira, e a primeira é a que o pedido nomeou.

| # | User story | O que entrega |
|---|---|---|
| **US1** | **Sei quem não conseguiu entrar, e por quê** | J1 instrumentada com as cinco falhas nomeadas, identidade opaca, e o painel de quem precisa de senha reiniciada. Inclui o logout que falha |
| **US2** | **Nada disso vaza** | filtro de atributos no exportador, **com teste que injeta senha e token e prova que não saem**; retenção declarada; quem vê o painel |
| **US3** | **Percebo quando a plataforma para** | métrica de jobs concluídos e o alerta pela **ausência** dela; rota de saúde comparando o relógio com o último job — fecha a [#801](https://github.com/The-Band-Solution/theband/issues/801) |
| **US4** | **Vejo onde a jornada de conectar trava** | J2 ponta a ponta, de cadastrar a credencial até ver dado na tela |
| **US5** | **Vejo onde a promoção para** | J3 — os 79 evidências e zero promoções deixam de ser descoberta de `psql` |
| **US6** | **Sei quantas vezes a tela recusou um número** | J4, por motivo de recusa — a métrica que só esta plataforma tem |

**US2 não é a última por ser menos importante.** É a condição de a US1 ir para produção, e
o ideal é que as duas nasçam juntas.

## O que este épico não é

**Não é APM para achar lentidão.** Não há problema de desempenho conhecido; há problema de
saber o que aconteceu com quem usou.

**Não substitui o `ReconcileStuckSyncs`.** Aquele trabalho lê **estado**, e estado
sobrevive a nó que morre — é a defesa certa para o que ele defende. Falta o nível acima.

**Não é pré-requisito de nenhuma feature do roadmap.** O que depende dele é a confiança em
dizer *"a plataforma está funcionando"* — frase que hoje não tem evidência atrás.
