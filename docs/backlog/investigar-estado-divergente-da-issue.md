# Investigar: o estado da issue no The Band divergindo do GitHub

**Registrado em 2026-09-09** pela pessoa mantenedora, com dois casos reais e
identificados. **É item de investigação, não de conserto**: as hipóteses abaixo vêm de
leitura de código e **nenhuma foi medida**.

> ⚠️ **Os dois casos têm o mesmo sintoma e são defeitos diferentes.** Tratá-los como um
> só manda a investigação para o lado errado — e o segundo é o mais grave dos dois.

---

## Caso 1 — a issue foi **apagada** no GitHub, e o The Band a mostra aberta

| | |
|---|---|
| na origem | [`leds-conectafapes/conectafapes-project#333`](https://github.com/leds-conectafapes/conectafapes-project/issues/333) — **apagada** |
| no The Band | [`c1311780-…`](https://app.theband.dev/work/issues/c1311780-5999-416d-b879-121514eb1d87) — **aberta** |
| contexto | *"era da época da Malu, não tinha sentido nenhum, estava no project errado — então eu deletei"* |

### A hipótese, e o fato que a sustenta

`collected_issues` **tem** o campo `no_longer_observed_at`
(`work_items/schemas/collected_issue.ex:62`) — o vocabulário para *"a origem deixou de
trazer isto"* existe.

Mas o `grep` por quem o **marca** encontra apenas as coisas **dentro** da issue:

- `work_items/commands.ex:104` — **designações** que saíram da lista;
- `work_items/commands.ex:145` — **etiquetas** que saíram da lista.

Nas duas outras ocorrências (`:44` e `:120`) o campo é posto em `nil` — que é
**reobservar**, o caminho inverso.

**Nada, aparentemente, marca a issue em si.** Se for isso, a coleta faz *upsert* do que
a origem devolve e nunca pergunta o que **deixou de vir** — e uma issue apagada mantém
para sempre o último estado conhecido.

**É a mesma classe de defeito que o `no_longer_observed_at` foi criado para resolver**,
aplicada um nível acima e nunca fechada.

### O que mediria primeiro

1. **existe caminho que marque `collected_issues.no_longer_observed_at`?** Se não
   existir, a hipótese está confirmada sem precisar de mais nada;
2. **quantas issues estão neste estado?** Não é um caso: é uma medida. Um número aqui
   decide se isto é conserto de coleta ou limpeza pontual;
3. **e o efeito nas medidas derivadas**: issue apagada contada como aberta entra em
   *Problems now*, no burn, na previsão e no que cada pessoa tem aberto. **Se o número
   do passo 2 for grande, várias medidas publicadas estão erradas** — e a tela não tem
   como dizer isso.

### A decisão que a investigação vai exigir, e não é técnica

**Apagada na origem não é "fechada".** Fechar é ato de trabalho; apagar é a origem
dizendo que aquilo nunca devia ter existido. Marcar como fechada faria a issue **contar
como entrega** — e este repositório não confunde as duas coisas em lugar nenhum.

O caminho coerente com a casa é `no_longer_observed_at` — *deixou de ser observada* —, e
aí a tela precisa de palavra para isso. É decisão de produto, com o Design.

---

## Caso 2 — a issue foi **fechada** no GitHub, e o The Band a mostra aberta

| | |
|---|---|
| na origem | [`leds-conectafapes/plataformas-project#703`](https://github.com/leds-conectafapes/plataformas-project/issues/703) — **fechada** pela pessoa mantenedora |
| no The Band | [`30637f82-…`](https://app.theband.dev/work/issues/30637f82-4fff-4bef-822e-4ec89f22e7a6) — **aberta** |
| contexto | *"tinha sido criada errada, porque teve erro no bot de planning. Eu marquei como fechada e ela não fechou no the band"* |

### Por que é mais grave que o caso 1

Aqui a issue **continua existindo** na origem, com o estado novo, e a coleta tinha tudo
o que precisava para trazê-lo. **Se a mudança de estado não chega, a plataforma não é
confiável para nenhuma medida de fluxo** — burn, throughput, previsão e *prometido ×
entregue* todos dependem de `state` estar correto.

O caso 1 é uma lacuna de vocabulário; este é possivelmente uma **falha de coleta**.

### As hipóteses, em ordem de custo para descartar

1. **a coleta não rodou** para aquele repositório desde o fechamento. Descarta-se
   olhando a última execução em `/syncs` e a data do fechamento — dois minutos;
2. **rodou e o repositório não está no alcance.** `plataformas-project` é um *project*,
   e as issues vêm por repositório: se o repositório dono desta issue não está entre os
   observados, ela entrou por outro caminho (item de project) e não é reconciliada;
3. **rodou, trouxe, e o *upsert* não atualizou `state`.** Seria o pior: significa que
   mudança de estado é perdida em silêncio, e o número 2 acima não explicaria os outros
   casos que existirem;
4. **atualizou e a tela lê outra coisa** — a issue está fechada no banco e a página
   mostra o estado de outra fonte, ou de um cache.

**As quatro se distinguem com uma consulta ao banco de produção**: o `state` da linha e
o `collected_at` dela, contra a data do fechamento no GitHub. Comece por aí, e não pelo
código.

---

## O que os dois casos têm em comum, e é o que os torna urgentes

**A tela afirma "aberta" com a mesma confiança nos dois casos**, e nos dois a afirmação
está errada. Não há marca, ressalva ou data que permita a quem lê desconfiar — e esta
plataforma existe para que número carregue de onde veio.

Uma issue que a origem apagou e outra que a origem fechou aparecem, hoje, exactamente
como uma issue legitimamente aberta.

---

## Como este item fecha

- o número do passo 2 do caso 1, medido no banco de produção;
- a causa do caso 2 identificada entre as quatro hipóteses, com evidência;
- a decisão de produto sobre **como a tela diz** *"a origem deixou de trazer isto"* —
  que não é "fechada";
- e um teste por caso, com o cenário reproduzido: issue que desaparece da origem, e
  issue que muda de estado entre duas coletas.

## Referências

- `lib/the_band/work_items/commands.ex` — o *upsert* da coleta e as duas marcas de
  `no_longer_observed_at` que existem;
- `lib/the_band/work_items/schemas/collected_issue.ex:62` — o campo que existe e
  aparentemente ninguém marca;
- `lib/the_band/work_items/queries.ex:56` — *"vigente é `no_longer_observed_at`
  nulo"*, a regra que a consulta já aplica e que dependeria da marca existir.
