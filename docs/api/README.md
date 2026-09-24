# A API pública — para quem vai integrar

Leitura em JSON do que a plataforma observou: equipes, pessoas, projetos e coletas.
**Só leitura.** Nenhum método de escrita responde.

**Endereço**: `https://theband.5.189.161.85.sslip.io`
**Versão no ar**: `0.9.0` — confira em `/version`, que é aberta.

> Todos os números deste documento foram **medidos em produção** em 2026-09-23. Onde um
> número aparece, ele veio de uma chamada real, e não de um exemplo inventado.

---

## Em três minutos

**1. Gere um token** em `/api-tokens`, logado na plataforma.

**Copie no momento da criação.** Ele não é reexibível: sair da tela o apaga, e a
plataforma guarda só o hash. Se perder, revogue e gere outro.

**2. Chame:**

```bash
TOKEN='tb_api_...'

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://theband.5.189.161.85.sslip.io/api/v1/teams?page_size=5"
```

**3. Leia a descrição** — ela é aberta, não precisa de token:

```
/api/openapi     a descrição OpenAPI, gerada do código
/api/docs        a interface para navegar, atrás de login
```

> **O token só é lido no cabeçalho `Authorization`.** Em query string, corpo ou cookie ele
> é ignorado e a requisição recebe `401` — query string vaza para log de servidor e para
> histórico de navegador.

---

## As oito rotas

| Rota | Responde |
|---|---|
| `GET /api/v1/teams` | as equipes do seu tenant |
| `GET /api/v1/teams/:id` | uma equipe: identidade, procedência, composição, roster |
| `GET /api/v1/teams/:id/members` | quem pertence, e **por qual afirmação** |
| `GET /api/v1/teams/:id/measures` | trabalho aberto, espera por revisão, competências |
| `GET /api/v1/people` | as pessoas observadas |
| `GET /api/v1/people/:id` | uma pessoa, com tudo o que a tela dela mostra |
| `GET /api/v1/projects` | os projetos declarados |
| `GET /api/v1/syncs` | as coletas, e **o que cada uma não alcançou** |

Nenhuma outra existe em `/api/v1`, e há teste que reprova se alguém acrescentar uma fora
desta lista.

---

## Seis armadilhas — leia antes de somar qualquer coisa

Esta seção existe porque cada uma dessas foi **medida em produção**, e um número lido errado
é pior que número nenhum.

### 1. As duas medianas de espera não se somam, e nem se escolhe uma

`/teams/:id/measures` devolve:

```json
"time_to_first_review": {
  "reviewed": { "count": 23, "median_hours": 0.2 },
  "waiting":  { "count": 79, "median_days": 46 }
}
```

Medido **em produção**, na equipe `LEDS - ConectaFapes`, em 2026-09-23:

```json
"reviewed": { "count": 20, "median_hours": 0.2 },
"waiting":  { "count": 64, "median_days": 43.0 }
```

Vinte revisadas em **doze minutos**. Sessenta e quatro esperando há **43 dias**.

Uma mediana só responderia *"doze minutos"* sobre 84 solicitações das quais 64 ninguém
tocou. **Omitir as em curso faz a medida melhorar quanto pior a equipe estiver**, porque
as que ninguém revisou são justamente as que mais interessam. Contá-las como zero afirmaria
revisão instantânea.

Se for mostrar um número só, mostre os dois.

Um exemplo real, da mesma medição:

```json
"competencies": [
  { "domain": "repository bootstrap and collaboration docs",
    "completed_tasks": 6, "evidence_issue_numbers": [1, 2, 3],
    "most_recent_period": "2026-02" },
  { "domain": "CloudEvents and Redis Streams",
    "completed_tasks": 3, "evidence_issue_numbers": [4, 7, 8],
    "most_recent_period": "2026-02" }
]
```

`completed_tasks` são tarefas **concluídas** — entrega, nunca promessa. Um domínio sem
tarefa concluída não aparece. E `evidence_issue_numbers` deixa cada competência descer até
o registro que a sustenta.

**`skills` é outra coisa.** São rótulos que o modelo escreveu, sem contagem e sem evidência.
Tratá-los como equivalentes daria a mesma autoridade a um domínio com 24 tarefas e a uma
palavra solta.

### 2. `null` e `[]` dizem coisas diferentes

Em `competencies`, na listagem de pessoas:

| Valor | Significa |
|---|---|
| `null` | **não houve leitura** — nenhum perfil foi gerado para esta pessoa |
| `[]` | **houve leitura, e nada foi demonstrado** |

Achatar as duas em `[]` transforma lacuna do registro em julgamento da pessoa. Quando é
`null`, o campo `competencies_note` diz por quê.

A mesma regra vale em toda a API: `null` é ausência **dita**, nunca zero.

### 3. `completed` não quer dizer *completo*

`/syncs` devolve, para cada coleta:

Medido **em produção**, nas três coletas mais recentes:

| `status` | coletados | repositórios pulados |
|---|---:|---:|
| `completed` | 5 233 | **29** |
| `completed` | 5 989 | 0 |
| `completed` | 479 | **34** |

**Duas das três terminaram sem alcançar dezenas de repositórios** — cota, permissão, ou a
origem indisponível.

Quem lê só o `status` conclui que o dado está inteiro. Por isso `gaps` viaja no mesmo
objeto. E os quatro contadores de registro **não se somam**: `collected` é o que a origem
devolveu; `created`, `updated` e `skipped` é o que se fez com cada um, e cada registro cai
em exatamente um dos três.

### 4. Dois totais que parecem o mesmo e não são

Em `/projects`:

| Projeto | `issues.direct` | `start_criterion.total` | Quadros |
|---|---:|---:|---:|
| ConectaFapes | **2 756** | **0** | 0 |
| Valida | 0 | **498** | 1 |

`issues` conta pelos **repositórios** do projeto; `start_criterion.total` conta pelos
**quadros**. Um projeto pode ter um sem o outro.

Sem perceber isso, a leitura de ConectaFapes seria *"2 756 issues sem critério de início"*.
O que há é que ele não tem quadro declarado. A resposta carrega `denominator_note`
avisando.

### 5. `assigned` e `authored` não se somam, e a diferença pode ser enorme

Medido em produção, numa pessoa real:

```json
"assigned": 3, "authored": 57
```

Três issues designadas, cinquenta e sete abertas por ela. Somar daria 60, que não é nada:
quem abre uma issue não necessariamente trabalha nela, e quem trabalha raramente é quem
abriu.

O mesmo vale em `verification`: `passed: 26` na mesma pessoa, ao lado de
`unattributed_in_tenant: 4653` — execuções que não casam com pessoa alguma. Elas ficam
**fora** das três primeiras contagens, e somá-las afirmaria medida onde não há.

### 6. Somar pessoas por organização dá mais que o total

Uma pessoa em duas organizações aparece **uma vez**, com as duas listadas. Então somar as
pessoas de cada organização dá mais que o total de pessoas — e está certo.

A organização de uma pessoa vem das **equipes** dela: não há laço direto. Quem não está em
equipe alguma vem com a lista vazia e a razão escrita.

---

## As marcas que viajam no corpo

**`origin`** diz de onde a plataforma soube:

| | |
|---|---|
| `observed` | veio de uma ferramenta conectada, e `source_system` diz qual |
| `declared` | alguém declarou nesta plataforma |

Em `/teams/:id/members`, a marca vive **em cada vínculo**, não na pessoa: alguém pode ser
observado numa equipe e declarado noutra, e as duas afirmações valem ao mesmo tempo.

**`ended_at` e `mistake`** são campos distintos: o primeiro diz *saiu*, o segundo *nunca
devia ter sido afirmado*. Achatá-los faria história virar erro.

**O perfil é `derived`** — escrito por um modelo de linguagem a partir do registro coletado.
A marca vem no objeto, junto das ressalvas que ele faz sobre si mesmo em `limits`.

---

## Paginação

Cursor, e não deslocamento:

```bash
# primeira página
curl -s -H "Authorization: Bearer $TOKEN" "$API/api/v1/people?page_size=100"

# as seguintes: passe o next_cursor
curl -s -H "Authorization: Bearer $TOKEN" "$API/api/v1/people?page_size=100&after=<next_cursor>"
```

Pare quando `page.has_next` for `false`.

**`total` vem `null` nas listagens**, com a razão junto em `total_note`: total estimado é
pior que total ausente. `/projects` e `/teams/:id/members` **têm** total, porque são
coleções limitadas.

Deslocamento pula ou repete linha quando a coleção muda entre páginas. Com cursor a ordem
passa a ser por identificador — é o preço, e é o que torna a travessia estável.

---

## Limite de uso

**120 chamadas por minuto, por token.**

Medido em produção: **200 chamadas com 20 em paralelo → 121 passaram, 79 recusadas.** O
corte é exato.

E uma coisa que só a medição mostra: **sequencialmente você não alcança o limite.** Com uma
latência de rede de ~1 s por chamada, o máximo é 60 por minuto — metade. O limite existe
para conter laço paralelo que não converge, não para atrapalhar quem percorre páginas.

Acima dele:

```
HTTP/1.1 429 Too Many Requests
retry-after: 8
x-ratelimit-limit: 120
x-ratelimit-remaining: 0

{"error":{"code":"too_many_requests",
          "message":"Rate limit of 120 requests per 60s exceeded. The window reopens in 8s.",
          "request_id":"..."}}
```

Toda resposta bem-sucedida traz `x-ratelimit-remaining`. Obedeça o `retry-after` em vez de
tentar de novo imediatamente.

A contagem é **por token**: um token ruidoso não gasta o limite de outro da mesma
organização.

**A janela desliza.** O minuto é contado em fatias de dez segundos, e o limite olha a soma
das que cobrem os últimos sessenta — não há um instante em que tudo zera e você pode emitir
o dobro. O `retry-after` aponta quando a próxima vaga abre, e não o fim de um minuto
arbitrário.

---

## Erros

Formato único, sempre:

```json
{"error": {"code": "unauthorized",
           "message": "The credential presented is not usable.",
           "request_id": "GNf8sTqAFGzHi6QAAA7i"}}
```

| Código | Quando |
|---|---|
| `unauthorized` | 401 — credencial ausente, inválida, revogada ou expirada |
| `not_found` | 404 — não existe, ou está fora do seu alcance |
| `method_not_allowed` | 405 — a API é só leitura; o cabeçalho `Allow` diz o que aceita |
| `too_many_requests` | 429 — limite de uso |
| `internal_error` | 500 |

**Duas coisas deliberadas, e vale entender por quê:**

**A mensagem nunca diz qual causa foi.** Para o `401`, ela é idêntica para token que nunca
existiu, revogado, expirado, e cuja conta foi desativada. Distingui-las confirmaria a quem
testa uma credencial roubada que ela um dia existiu.

**Fora de alcance devolve `404`, e não `403`.** Um `403` confirmaria que o recurso existe —
para quem varre, é metade da resposta.

O `request_id` liga a recusa que você vê ao motivo real, que fica no log interno da
plataforma. Cite-o ao pedir ajuda.

---

## O que a API **não** faz

| | |
|---|---|
| **escrita** | nenhuma. Não há autor honesto para a proveniência de uma escrita por token: a credencial diz de quem é a conta, e não quem decidiu |
| **e-mail** | não sai por rota alguma — nem o da pessoa observada, nem o de quem declarou um vínculo |
| **credenciais e chaves** | a API que as lista é a API que as vaza |
| **contas, concessões e papéis** | administrar acesso pela API amplia a superfície do recurso que **governa** o acesso |
| **dados brutos coletados** | o valor está no dado promovido, não no bruto |
| **escolher a janela das medidas** | fixa em 56 dias, e **declarada** em `window` |
| **buscar e paginar a lista de issues** de uma pessoa | vem a primeira página de 25, como a tela |

---

## O que fica registrado quando você chama

Toda leitura bem-sucedida grava uma linha: **qual credencial, qual rota, qual alvo, e
quando**. O corpo da resposta **não** é gravado — o registro diz *quem leu o quê*, nunca *o
que leu*.

Existe para que abuso seja detectável: alguém acumulando, chamada a chamada, o que o
veredito nega em cada consulta isolada.

**Esse registro é guardado por tempo indefinido** — decisão de 2026-09-23, em
`api.access.thresholds`. Não há expurgo.

## Onde o token fica é responsabilidade sua

A plataforma tem **um único controle** sobre um token que já saiu: a revogação.

- fora do repositório, fora do histórico de terminal;
- revogue quando a máquina sair de uso, ou quando alguém sair da equipe;
- revogar **marca**, nunca apaga: a linha continua, com a data e quem revogou.

---

## Duas limitações conhecidas, declaradas

**As medidas não trazem as limitações declaradas da base de conhecimento.** `/teams/:id/measures`
carrega notas escritas à mão e a janela, mas não a proveniência formal de cada medida. É o
critério SC-007 da spec, não cumprido — está registrado na
[aceitação da feature](../sprints/033-a-api-publica/aceitacao.md).

**O log interno não distingue as três causas de recusa de token.** Inexistente, revogado e
expirado produzem a mesma entrada. Não muda nada para quem integra — a resposta já é
idêntica de propósito —, mas limita o que a plataforma consegue dizer ao investigar.
[Item de backlog](../backlog/sc004-o-log-nao-distingue-as-tres-recusas.md).
