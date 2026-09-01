# Fase 0 — Pesquisa: o que foi conferido antes de decidir

Cada achado abaixo foi lido na fonte, e a fonte está citada. O que não foi
conferido está dito como não conferido.

---

## R1 — Como a aceitação de origem funciona hoje, na letra

**Decisão**: a lista declarada substitui o padrão `true`, e passa a ser
`["https://<host principal>" | extras]`.

**O que a fonte diz** (`deps/phoenix/lib/phoenix/socket/transport.ex`):

- o padrão do endpoint é `check_origin: true`
  (`endpoint/supervisor.ex:241`). Com `true`, a comparação é **só do host**
  contra o host de `:url` — ou seja, contra o `PHX_HOST`;
- com **lista**, cada item é parseado por `URI.parse/1` e vira
  `{scheme, host, port}`. A comparação é `scheme` **e** `port` **e** `host`, com
  a regra `is_nil(allowed) or igual`: um item escrito como `//exemplo.com`
  aceita qualquer esquema e qualquer porta, e `https://exemplo.com` fixa os três;
- `"*.exemplo.com"` casa o próprio domínio e qualquer subdomínio;
- item sem host **levanta** na subida, com mensagem nomeando o valor inválido.

**Consequência que muda o desenho**: escrever `https://theband.dev` é mais
restritivo do que o comportamento de hoje, não menos — hoje o esquema e a porta
não são comparados. Isso é ganho, e precisa estar dito no contrato para ninguém
"consertar" a diferença depois.

**Alternativas consideradas**: `check_origin: :conn` (comparar com o host da
própria requisição) foi descartado — aceita qualquer host que chegue até a
aplicação, o que é o buraco silencioso que o FR-007 proíbe.

---

## R2 — A recusa já é registrada, nomeando a origem

**Decisão**: não escrever registro próprio (decisão 3 do plano).

**O que a fonte diz**: no ramo em que a origem não é permitida, o transporte
chama `Logger.error/1` com um texto que inclui `Origin of the request: <origem>`,
e só então devolve **403** e interrompe. O FR-008 está atendido pelo que já
existe.

**O que o plano faz com isso**: um teste captura o registro e falha se a mensagem
deixar de nomear a origem. É a diferença entre *acreditar* que a biblioteca
registra e *provar* que registra — e o teste é quem avisa no dia em que ela mudar.

---

## R3 — Requisição sem cabeçalho de origem passa, e isso é limitação declarada

**O que a fonte diz**: a primeira cláusula é
`is_nil(origin) or check_origin == false -> conn`. Uma conexão que **não envia**
o cabeçalho de origem **não é checada**.

**Por que não é defeito nosso**: navegador sempre envia origem no handshake do
socket. Quem não envia é cliente programático — e contra ele a defesa é a
sessão, não a origem.

**Por que entra no contrato mesmo assim**: porque um teste que só provasse
"origem estranha é recusada" poderia ser lido como "só quem está na lista
conecta", e isso é falso. Limitação escrita é limitação que não vira surpresa.

---

## R4 — `.dev` não tem plano B

**O que foi conferido**: o TLD `.dev` está na lista de pré-carregamento de HSTS
dos navegadores. Consequência prática: o navegador **recusa** HTTP para
`theband.dev` antes de qualquer requisição sair — não existe "abre inseguro e a
pessoa clica em prosseguir".

**Consequência para a ordem dos passos**: o nome só pode ser anunciado depois de
o certificado existir. É o que o AS3 da US1 exige, e é a razão de o runbook
mandar emitir antes de divulgar.

**Não conferido**: se o registrador ou a rede à frente oferece cabeçalho HSTS
próprio. Irrelevante para a decisão — o TLD já decide.

---

## R5 — A ordem dos passos no provedor, e por que ela não é arbitrária

**Decisão**: DNS sem intermediário → certificado emitido → intermediário ligado
com cifra ponta a ponta → conferência do socket.

**Racional**:

1. quem emite o certificado hoje precisa **provar** que controla o nome, e a
   prova chega por requisição ao próprio endereço. Com o intermediário ligado
   antes, a prova pode nunca chegar a quem emite;
2. com o certificado emitido, ligar o intermediário em modo que cifra até ele e
   fala em claro com a aplicação produz **laço de redirecionamento** — a
   aplicação exige cifra (`force_ssl` em `config/prod.exs`) e o intermediário
   responde que já cifrou. O modo correto é o que cifra também entre o
   intermediário e a aplicação, e valida o certificado;
3. o socket é a última conferência porque é a única que a camada HTTP não
   consegue fazer por ele (L85).

**Alternativa considerada**: ligar o intermediário primeiro e usar validação por
registro de DNS em vez de requisição. Descartado — exige credencial de API do
provedor de DNS dentro do ambiente, e o FR-011 mantém credencial nova fora do
repositório e da imagem. Trocar um passo manual por um segredo novo é piorar o
que a 050 mediu.

---

## R6 — O cabeçalho que diz "a origem era cifrada" atravessa dois intermediários

**O que existe**: `config/prod.exs` traz
`force_ssl: [rewrite_on: [:x_forwarded_proto]]`. A aplicação confia nesse
cabeçalho para saber que a requisição chegou cifrada.

**O que muda**: passa a haver **dois** intermediários em série. O cabeçalho
precisa sobreviver aos dois; se o de fora não o envia, ou se o de dentro o
substitui, a aplicação passa a redirecionar em laço.

**Estado hoje**: com um intermediário só, foi conferido em 2026-09-01 — `/sign-in`
responde 200 sem laço. Com dois, **não foi conferido**, e é exatamente o que a
[P2 da 050](../050-em-producao/pendencias.md) já registrava como risco sem teste.

**O que o plano faz**: a conferência entra no quickstart como medida, não como
suposição. Não há teste automatizado possível aqui — o comportamento depende de
infraestrutura de terceiro, e testar contra um dublê provaria o dublê.
