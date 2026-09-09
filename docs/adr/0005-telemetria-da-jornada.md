# ADR 0005 — Telemetria da jornada: `:telemetry` como barramento, coletor local, e taxonomia declarada

## Status

Proposta — 2026-09-04

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
| `attach_hook(:handle_event)` | no mesmo `on_mount` | cada interação, sem instrumentar tela por tela |
| eventos de domínio | `:telemetry.execute` explícito | *"login falhou por conta sem senha definida"* |

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
nome do span    the_band.<dominio>.<passo>      the_band.acesso.entrar
atributos       journey.name / journey.id / journey.step
                outcome           ok | falha | abandonada
                failure.reason    conta_sem_senha_definida
                tenant.id, user.id             opacos
                ontology.concept               só quando houver
```

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
   métrica sem estourar cardinalidade. `user.id` não pode; `conta_sem_senha_definida` pode,
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

**A garantia é filtro no exportador, não disciplina de quem escreve.** Um `deny-list` de
atributos aplicado antes do envio, mais um teste que injeta uma senha e um token numa
jornada e **prova que eles não saem** — a mesma técnica da revisão de segurança de hoje:
injetar o defeito e verificar que o mecanismo o pega.

Sem esse teste, a regra é comentário.

### S2. Identidade é dado pessoal, e o pedido é legítimo

O pedido — *"quero saber **quem** deu erro"* — é operacionalmente necessário: sem
identificar, ninguém reinicia a senha de ninguém.

E a decisão de privacidade tomada nesta mesma data (FR-024 da feature 058) diz que **ler o
trabalho de uma pessoa nomeada exige alcance sobre a equipe dela**. Telemetria não pode ser
a porta dos fundos disso.

As regras:

- **`user.id` opaco, nunca e-mail.** O id resolve tudo o que o e-mail resolveria, e não
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

Fica como **base**, não como solução: os automáticos entram, e os spans de domínio são
acrescentados por cima.

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
