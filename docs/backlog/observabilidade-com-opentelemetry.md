# Épico — Observabilidade com OpenTelemetry

**Estado**: proposta de épico. **Impacta a arquitetura**, e por isso exige ADR antes de
qualquer código (constituição, seção *Decisões que exigem ADR*).

Pedido da pessoa mantenedora em 2026-09-04, no dia em que três defeitos invisíveis
apareceram um atrás do outro.

## De onde este épico vem, e por que não é preferência de ferramenta

A plataforma inteira é construída sobre uma tese: **ausência não é zero, e ausência de
erro não é funcionamento.** Ela aplica isso ao dado das organizações com rigor — a tela
recusa mostrar `0` onde não sabe, o `{:aguardando, _}` existe para a espera não virar
tempo zero, o `{:sem_projeto, _}` para a taxa não virar fracasso.

E não aplica a si mesma.

Em 2026-09-04, na primeira coleta contra dado real, três coisas quebraram **sem produzir
um único erro visível**:

| o que quebrou | por quanto tempo | o que se via |
|---|---|---|
| o Oban parou de processar ([#801](https://github.com/The-Band-Solution/theband/issues/801)) | **4 dias** | `HTTP 200` em toda rota, healthcheck verde |
| o upsert da equipe derivada com corrida ([#800](https://github.com/The-Band-Solution/theband/issues/800)) | uma coleta inteira | sync `failed` **depois** de gravar quase tudo |
| o tratamento de falha que quebrava ao registrar a falha | 5 tentativas, depois silêncio | job `discarded`, etapas seguintes nunca rodaram |

As três foram encontradas **por acaso**, olhando o banco com `psql`. Nenhuma delas teria
sido encontrada olhando a aplicação — porque a aplicação, vista de fora, estava bem.

**É o defeito da casa, aplicado à casa.** Este épico existe para fechar essa assimetria.

---

## O que se pretende

Instrumentar a plataforma com **OpenTelemetry** — traços, métricas e logs correlacionados
— de modo que a resposta a *"está funcionando?"* deixe de ser *"responde 200"*.

O alvo não é ter painéis. É poder responder, com evidência e sem `psql`:

1. **a coleta está andando?** — não *"há um sync com status running"*, que é o que a tela
   diz hoje e não distingue *rodando* de *abandonado*;
2. **o que uma coleta fez?** — um traço por sync, com um span por etapa e por repositório,
   dizendo onde o tempo foi e onde ela parou;
3. **o que a origem respondeu?** — latência e código do GitHub, rate limit restante,
   página truncada;
4. **quanto custa uma tela?** — o teto de consultas é hoje um teste; com métrica, ele vira
   também observação do que roda de verdade;
5. **o que parou de acontecer?** — a pergunta que nenhuma das três falhas de hoje teria
   sobrevivido.

---

## O impacto na arquitetura, dito antes de decidir

Este épico **muda a forma da aplicação**, e é por isso que ele é épico e não tarefa:

| camada | o que entra |
|---|---|
| dependências | `opentelemetry`, `opentelemetry_exporter`, e os instrumentadores de Phoenix, Ecto, Oban e Finch/Req |
| supervisão | o exportador OTLP vira processo supervisionado — mais uma coisa que pode falhar, e que precisa falhar **ruidosamente** |
| configuração | endpoint, cabeçalhos, amostragem e nome do serviço por ambiente, em `runtime.exs`, com o mesmo cuidado de segredo que a chave mestra tem |
| implantação | um **coletor** OTLP, e um backend que guarde. No Dokploy isso é serviço novo no mesmo VPS, com custo de memória e disco medível |
| código | spans manuais onde o automático não alcança — cada etapa da coleta, a promoção, a derivação |

**Nada disso é reversível de graça.** Instrumentação mal colocada polui o código com
`Tracer.with_span` em toda função e envelhece pior do que a ausência dela.

---

## As decisões que a spec vai precisar registrar

Estão aqui porque **cada uma delas tem um jeito errado que parece certo**.

### 1. Onde os dados ficam, e quanto isso custa

Backend próprio no VPS (Tempo/Loki/Prometheus, ou SigNoz) contra serviço gerenciado. O
primeiro não tem custo por evento e tem custo de operação — **mais uma coisa para
observar, e quem observa o observador**. O segundo tem custo por volume, e volume de
traço cresce com repositório coletado.

A decisão precisa vir com **número medido**, não com preferência: quantos spans uma coleta
de 125 repositórios produz.

### 2. Segredo nunca vai para atributo de span

Token da ferramenta, chave mestra, credencial de LLM, corpo de payload da origem. Um span
com `http.request.header.authorization` exporta a credencial para fora do processo — e
traço costuma ter retenção maior e controle de acesso menor que o banco.

Isto não é *boa prática a lembrar*: é **filtro no exportador, com teste**. A regra de
segurança da casa já diz que segredo não vai para log, e span é log com outro nome.

### 3. Cardinalidade, e o `tenant_id`

Pôr `tenant_id` como atributo permite responder *"a coleta de qual organização está
lenta?"*. Pôr como **rótulo de métrica** multiplica as séries por tenant e é o jeito
clássico de derrubar o backend.

A distinção é técnica e tem resposta certa: **atributo de span sim, rótulo de métrica
não** — e a spec precisa dizer isso, porque o erro é fácil e o efeito aparece meses
depois.

### 4. Amostragem, e o que ela apaga

Amostrar 10% dos traços custa 10% do volume — e apaga 90% das coletas que falharam uma
vez. Para uma plataforma cujo defeito característico é **o evento raro que não produz
erro**, amostragem uniforme é exatamente a decisão errada.

O caminho provável é *tail sampling*: guardar o traço inteiro quando ele contém erro ou
passa de uma duração. Isso exige coletor com estado, e é decisão de arquitetura.

### 5. O que OTel **não** resolve

**Nada disso teria pegado o Oban parado.** Um Oban inerte não emite span — ele não emite
nada, e essa é a definição do problema. Traço mostra o que aconteceu; a falha era o que
**deixou** de acontecer.

O que fecha aquele buraco é uma verificação **de ausência**: uma métrica de *"jobs
completados nos últimos N minutos"* com alerta quando ela zera, ou um *dead man's switch*
— um sinal periódico cuja falta é o alarme.

Registrar isto na spec importa mais do que parece: é o ponto em que o épico deixa de ser
*"instalar OpenTelemetry"* e passa a ser *"conseguir perceber o silêncio"*. A ferramenta
sozinha entrega a primeira coisa e não a segunda, e um épico que confunda as duas
entregaria painéis bonitos com o mesmo ponto cego de hoje.

---

## Fatiamento sugerido

Cada fatia entrega valor sozinha, e a primeira é a que teria evitado o dia de hoje.

| # | User story | O que ela entrega |
|---|---|---|
| **US1** | **Percebo quando a coleta para** | métrica de jobs concluídos por minuto, e o alerta pela **ausência** dela; rota de saúde que compara o relógio com o último job — fecha a [#801](https://github.com/The-Band-Solution/theband/issues/801) |
| **US2** | **Vejo o que uma coleta fez** | um traço por sync, span por etapa e por repositório, com o motivo da parada onde ela parou |
| **US3** | **Vejo o que a origem respondeu** | latência, status e rate limit do GitHub, com página truncada dita |
| **US4** | **Vejo o custo de cada tela** | duração de render e consultas por requisição — o teto de consultas vira observação, além de teste |
| **US5** | **Nada disso vaza segredo** | filtro de atributos no exportador, **com teste que injeta um token e prova que ele não sai** |

**US5 não é a última por ser menos importante** — ela é a condição de as outras poderem
ir para produção, e o ideal é que nasça junto com a US1.

---

## O que este épico não é

**Não é APM para achar lentidão.** A plataforma não tem problema de desempenho conhecido;
tem problema de **saber o que aconteceu**. Se virar caça a milissegundos, terá comprado
complexidade por um problema que não existe.

**Não substitui o `ReconcileStuckSyncs`.** Aquele trabalho lê **estado**, e estado
sobrevive a nó que morre — é a defesa certa para o que ele defende. O que falta é o nível
acima: perceber quando o próprio processador parou.

**Não é pré-requisito de nada que está no roadmap.** Nenhuma feature depende dele. O que
depende é a confiança em dizer *"a plataforma está funcionando"* — e hoje essa frase não
tem evidência atrás.
