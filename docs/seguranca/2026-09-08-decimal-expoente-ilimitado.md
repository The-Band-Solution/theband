# EEF-CVE-2026-32686 (`decimal`) — avaliação de alcance nesta aplicação

**Data**: 2026-09-08 · **Papel**: Security (`AGENTS.md` §13) · **Ramo lido**: `development`
(`0b37a71`) · **Escopo**: avaliação de alcance de um aviso de dependência transitiva.
**Não decide prioridade e não escolhe saída** — isso é do Product Owner com a pessoa
mantenedora. Este documento diz **a que risco corrido o risco declarado corresponde**.

**Régua**: OWASP Top 10 (2021) para nomear o risco, OWASP ASVS para nomear a verificação.

---

## Resumo, antes do detalhe

| Pergunta | Resposta |
|---|---|
| Existe caminho de texto não autenticado até `Decimal.new`/`parse` ou operação decimal? | **Não existe.** |
| A versão instalada (3.1.1) rejeita a entrada do PoC do aviso? | **Sim**, por padrão, e isso foi medido — não deduzido |
| Severidade **nesta aplicação** | **Informativo** para o aviso; **baixa** para um achado de desenho adjacente (`person_work.ex:478`) |
| O gate 4/15 aceita exceção? | **Sim, nativamente** — `hex: [ignore_advisories: [...]]`, medido com código de saída |
| Existe versão corrigida a instalar? | Não há versão mais recente que 3.1.1; **e não é preciso**, porque a mitigação está na 3.0.0 |

O aviso é, nesta base, um **falso positivo de metadados** do registro OSV: não é risco
aceito, é divergência entre a base de avisos e o artefato instalado. A diferença importa,
porque muda o texto da exceção de "aceitamos correr o risco" para "aceitamos que a base de
avisos está errada quanto a esta versão", e essas duas frases têm prazos e sinais de
reavaliação diferentes.

---

## 1. O aviso, lido na fonte

Lido em `https://api.osv.dev/v1/vulns/EEF-CVE-2026-32686` e no GHSA
`GHSA-rhv4-8758-jx7v` (API de security advisories do repositório `ericmj/decimal`).

**Severidade declarada**: CVSS v4 **6.9 MEDIUM**, vetor
`CVSS:4.0/AV:L/AC:L/AT:N/PR:N/UI:N/VC:N/VI:N/VA:H/SC:N/SI:N/SA:N`. CWE-400
(*Uncontrolled Resource Consumption*), CAPEC-130.

**Nota sobre o vetor, porque ela muda a leitura**: o texto do aviso diz "unauthenticated
remote DoS", e o vetor CVSS diz `AV:L` — vetor de ataque **local**, com impacto apenas em
disponibilidade (`VA:H`). As duas metades não concordam. Registro a divergência sem
resolvê-la: o que decide a avaliação abaixo não é o vetor, é o alcance medido.

### Qual função dispara, e com que forma de entrada

Confirmado no texto do GHSA, que cita as linhas do `lib/decimal.ex` afetado. **A
construção não é o problema — a amplificação é.** `Decimal.new/1`, `parse/1` e `cast/1`
apenas *armazenam* o expoente (custo constante); o dano aparece quando uma segunda função
tenta materializar o número:

| Função | Mecanismo da amplificação (citado pelo aviso) |
|---|---|
| `add/2`, `sub/2`, `div/2` | via `add_align`, que chama `pow10(exp1 - exp2)` e constrói um bignum proporcional à diferença de expoentes |
| `to_string/2` com `:normal` ou `:xsd` (e o `String.Chars`) | `:lists.duplicate(exp, ?0)` |
| `to_integer/1` | recursão `coef * 10`, `exp - 1`, uma iteração por unidade de `exp` |
| `round/3` | mesmo `:lists.duplicate` sobre a diferença de expoentes |
| `compare/3` **com argumento de limiar** | recai em `add`/`sub` |

**A forma de entrada é específica, e vale enunciá-la com precisão**: é **texto decimal com
expoente positivo explícito** — `"1e1000000000"` — parseado e depois **operado**. Não é
coeficiente longo (uma string de 50 mil noves custa proporcional ao que ela já ocupa); é
expoente grande em representação compacta, que custa proporcional ao valor *expandido*.
Coeficiente grande é linear no tamanho da entrada; expoente grande é exponencial nele. Essa
é a assimetria que faz uma requisição derrubar o nó.

### A contradição nos metadados, que é a razão do gate reprovar

| Campo | O que diz |
|---|---|
| `details` do próprio registro OSV | *"This issue affects decimal: from 0.1.0 **before 3.0.0**"* |
| GHSA `vulnerable_version_range` | `>= 0.1.0 and < 3.0.0` |
| GHSA `patched_versions` | `3.0.0` |
| OSV `affected[].ranges[].events` | **apenas** `{"introduced": "0"}` — **sem evento `fixed`** |
| OSV `affected[].versions` (lista enumerada) | inclui `3.0.0`, `3.1.0` e `3.1.1` |

A range SEMVER sem `fixed` é o que produz a lista enumerada com todas as versões e é o que
faz `mix hex.audit` casar a 3.1.1. O `details` do mesmo documento contradiz a própria range.

O `references[type=FIX]` aponta `6a523f3a73b8c9974540e21c7aa88f1258bb35ae` ("Apply IEEE 754
decimal128 defaults"). Comparando `v3.1.1...6a523f3` na API do GitHub: `status: behind`,
`behind_by: 7` — ou seja, **esse SHA não é ancestral de nenhuma tag publicada**. Isso
poderia sugerir que a correção não saiu; o `CHANGELOG.md` da própria 3.1.1 instalada
desmente, na seção da **v3.0.0 (2026-05-07)**:

> **Security** — Make the v2.4.0 mitigations for CVE-2026-32686 the default. The default
> `Decimal.Context` and the public parse, cast, and to_string functions now follow IEEE 754
> decimal128 limits, rejecting inputs such as `1e1000000000` without materializing them.

Metadado contra metadado não decide nada. **O que decide é o artefato.**

---

## 2. O que a 3.1.1 instalada faz, medido

Executado contra o artefato do próprio projeto (`_build/dev/lib/decimal/ebin`), sem carregar
a aplicação e sem tocar em `lib/`, `test/` ou `priv/`:

| Chamada | Resultado observado |
|---|---|
| `%Decimal.Context{}` (default) | `precision: 34, emax: 6144, emin: -6143` — decimal128, **não** `:infinity` |
| `Decimal.parse("1e1000000000")` | `:error` |
| `Decimal.cast("1e1000000000")` | `:error` |
| `Decimal.new("1e1000000000")` | levanta `Decimal.Error` — `": number parsing syntax"` |
| `Decimal.parse("1e6145")` | `:error` (um acima de `emax`) |
| `Decimal.parse("1e6144")` | aceito — a fronteira está onde o CHANGELOG diz |
| `Decimal.parse(String.duplicate("9", 40))` | `:error` (excede `max_digits: 34`) |
| `Decimal.parse("12.50")` | aceito — valor normal continua passando |
| `Decimal.to_string(Decimal.new(1, 1, 1_000_000_000), :normal)` | `ArgumentError`: *":normal representation requires 1000000001 digits, but the configured maximum is 6178"* |

**A entrada do PoC do aviso não é aceita pela versão instalada.** As três portas de texto
(`new/1`, `parse/1`, `cast/1`) rejeitam, e `to_string/2` com `:normal` recusa materializar
mesmo um struct construído por outro caminho — defesa em profundidade, e é ela que cobre o
único furo restante.

**O furo restante, nomeado**: `Decimal.new/3` (aridade 3, `sign`/`coef`/`exp`) **não** aplica
limite — `Decimal.new(1, 1, 100_000)` é aceito, e essa é exatamente a porta que o Postgrex
usa. Ela importa para a seção 3.

Verificação de que a medição mede (técnica do defeito de mentira, `AGENTS.md` §17): com
`Decimal.Context.set/1` restaurando `emax: :infinity, emin: :infinity` — o comportamento
pré-3.0.0 — `Decimal.round(Decimal.new(1, 1, 7000), 0)` volta a **calcular** (1842 µs, 39
dígitos) em vez de recusar. A recusa observada acima é, portanto, consequência do contexto
decimal128 padrão, e não de o teste estar quebrado.

---

## 3. Os caminhos desta aplicação até `Decimal`

**Ponto de partida, e ele é curto**: `grep -rn "Decimal" lib/` devolve **quatro linhas**,
três delas comentários. **Uma única linha de código no repositório inteiro chama funções do
`Decimal`.**

```
lib/the_band/work_items/queries.ex:220     (comentário)
lib/the_band/work_items/queries.ex:221     (comentário)
lib/the_band/work_items/person_work.ex:475 (comentário)
lib/the_band/work_items/person_work.ex:478 defp dias(%Decimal{} = d), do: Decimal.to_integer(Decimal.round(d, 0))
```

### 3.1 Os três produtores de `%Decimal{}`

| # | Onde nasce | Como nasce | Quem consome | Origem do valor | Porta |
|---|---|---|---|---|---|
| 1 | `lib/the_band/work_items/person_work.ex:449-465` | `fragment("percentile_disc(0.5\|0.85) within group (order by extract(day from ? - ?))", i.external_closed_at, i.external_created_at)` → `numeric` | `dias/1` em `lib/the_band/work_items/person_work.ex:478` — **`Decimal.round/2` e `Decimal.to_integer/1`, as duas na lista do aviso** | dois `utc_datetime` gravados pela coleta do GitHub (terceiro) | autenticada + escopo |
| 2 | `lib/the_band/ontology/continuum/smpo/field_roles.ex:104` | `fragment("round(avg(?))", s.duration_days)` → `numeric` | interpolação em `lib/the_band_web/live/board_live/index.ex:365` → `String.Chars.Decimal` → `to_string(:scientific, max_digits: :infinity)` | coluna `:integer` (`priv/repo/migrations/20260815120000_create_sro_sprints.exs:50`), valor do campo de iteração dos Projects do GitHub | autenticada |
| 3 | `lib/the_band/work_items/queries.ex:224-225` | `type(sum(...), :integer)` — o cast é gerado **em SQL** | ninguém: Postgrex devolve inteiro, nenhum `Decimal` chega ao Elixir | contagens internas | autenticada |

Sobre o caminho 2: `:scientific` **não** está na lista do aviso. O `:lists.duplicate(exp, ?0)`
está em `:normal` e `:xsd`; `:scientific` escreve o expoente como texto e custa proporcional
ao coeficiente, não ao valor expandido. O `max_digits: :infinity` que o `String.Chars` usa é
decisão deliberada do `decimal` (para que `inspect` e log nunca falhem) e não abre o caminho
amplificador.

Sobre o caminho 1, a cadeia de autorização, conferida linha a linha:

- rota `live "/people/:id"` — `lib/the_band_web/router.ex:69`, dentro de
  `pipe_through [:browser, :require_user]` (`:65`) **e** de
  `live_session :autenticado, on_mount: {TheBandWeb.Live.Hooks, :current_scope}` (`:67`) — as
  duas metades, como o papel exige;
- `lib/the_band_web/live/people_live/show.ex:280` — `Tenants.pode_ver(tenant, current_user, pessoa.id)`
  devolve o relator `{alcance, motivo}`; `:287` deriva `ve_o_trabalho?`;
- `lib/the_band_web/live/people_live/show.ex:415` — único chamador de `lead_time/2`, e ele é
  `se_pode(ve_o_trabalho?, nil, fn -> ... end)`. Sem escopo, a consulta **não roda**.

### 3.2 O limite estrutural do lado do Postgres, que é o que de fato governa

`deps/postgrex/lib/postgrex/extensions/numeric.ex:116-120`:

```elixir
defp decode_numeric(_num_digits, weight, sign, scale, bin) do
  {value, weight} = decode_numeric_int(bin, weight, 0)
  sign = decode_sign(sign)
  coef = scale(value, (weight + 1) * 4 + scale)
  Decimal.new(sign, coef, -scale)
end
```

Três consequências, na ordem em que importam:

1. o Postgrex usa `Decimal.new/3` — **contorna** os limites decimal128 de `parse`/`cast`.
   Este é o furo da seção 2, e é por isso que ele foi nomeado lá;
2. o expoente resultante é `-scale`, e `scale` vem do cabeçalho binário do protocolo do
   Postgres como `int16` assinado. Portanto **`|exp| <= 32768` para qualquer `%Decimal{}`
   que entre nesta aplicação**, por construção do protocolo, independentemente do SQL;
3. `dscale` é o número de dígitos após a vírgula e o Postgres o envia não negativo para
   resultados de expressão, o que dá `exp <= 0` — e o ramo amplificador do aviso é o de
   **expoente positivo**.

O item 3 é semântica lida, não medida (ver seção 6). O item 2 é o limite duro, e nele o
custo foi **medido** no pior caso que o protocolo admite, com `emax: :infinity` para não
deixar a proteção do decimal128 mascarar a medida:

| Chamada no pior expoente do protocolo | Custo |
|---|---|
| `Decimal.to_integer(Decimal.new(1, 1, 32_768))` | 1792 µs |
| `Decimal.to_string(Decimal.new(1, 1, 32_768), :normal, max_digits: :infinity)` | 249 µs, 32 769 bytes |
| `Decimal.round(Decimal.new(1, 123456789, -32_767), 0)` | 523 µs |
| `Decimal.add(Decimal.new(1, 1, 32_768), Decimal.new(1, 1, 0))` | 16 µs |

Dois milissegundos e 33 KB no pior caso teórico. Não há amplificação a extrair deste caminho.

### 3.3 O esquema não tem onde guardar o problema

Contagem de tipos de coluna em `priv/repo/migrations/`, por `add :`:

```
171 string   125 utc_datetime   48 uuid   47 integer   12 text
 11 map        9 date            8 boolean  7 binary_id  2 jsonb   2 binary
```

**Nenhuma coluna `numeric`, `decimal` ou `float` existe no esquema**, e
`grep -rn ":decimal" lib/` não devolve nada — nenhum schema Ecto declara campo `:decimal`.
Os `%Decimal{}` da seção 3.1 são resultados de agregação, não conteúdo de coluna. Isso
fecha a via mais natural do aviso: não há campo onde um payload de terceiro deposite texto
decimal que depois volte como `Decimal`.

### 3.4 As portas indiretas, uma a uma

| Porta | Estado | Evidência |
|---|---|---|
| `Jason` decodificando para `Decimal` | fechada | só com `floats: :decimals`; o default é `:native` (`deps/jason/lib/jason.ex:240`) e a aplicação nunca passa a opção — os dois `Jason.decode` sobre texto de terceiro são `lib/the_band/profiles/generate_worker.ex:124` (resposta do LLM) e `lib/the_band/profiles/prompt.ex:51` (arquivo do próprio repositório) |
| `Ecto.Type` casteando `:decimal` | fechada, e **nasce limitada** se abrir | `deps/ecto/lib/ecto/type.ex:911` usa `Decimal.parse(term)` — **aridade 1**, que na 3.1.1 já aplica os limites decimal128. Um campo `:decimal` criado amanhã já nasce com a defesa |
| `Cloak.Ecto.Decimal` | não usada | `lib/the_band/encrypted/` contém apenas `binary.ex`; nenhuma referência a `Encrypted.Decimal` |
| Endpoint JSON | **não existe** | a pipeline `:api` é declarada em `lib/the_band_web/router.ex:44` e **nenhum `scope` faz `pipe_through :api`** |

### 3.5 A superfície não autenticada, enumerada

Tudo o que está fora de `require_user`, em `lib/the_band_web/router.ex:48-62`:

| Rota | Handler | Aceita número em texto? |
|---|---|---|
| `GET /` | `PageController, :home` | não |
| `live /sign-in` | `SessionLive.New` | não (e-mail e senha) |
| `POST /session` | `SessionController, :create` | não |
| `live /set-password` | `SessionLive.SetPassword` | não |
| `POST /set-password` | `SessionController, :set_password` | não |

`GET /dev/erro/:codigo` e o LiveDashboard estão atrás de
`Application.compile_env(:the_band, :dev_routes)` (`lib/the_band_web/router.ex:141`) e não
existem em produção.

---

## 4. A pergunta que decide

> **Não existe** nenhum caminho nesta aplicação em que texto de origem não autenticada
> chegue a `Decimal.new`, `Decimal.parse` ou a uma operação decimal.

A evidência é composta, e cada parte é verificável isoladamente:

1. **o alcance total do `Decimal` no repositório é uma linha de código** —
   `lib/the_band/work_items/person_work.ex:478` (`grep -rn "Decimal" lib/`, quatro linhas,
   três comentários);
2. essa linha só executa atrás de `require_user` (`router.ex:65`), do `on_mount`
   (`router.ex:67`) e de `Tenants.pode_ver/3` (`people_live/show.ex:280`, `:415`);
3. **nenhuma das cinco rotas públicas** aceita número em texto, e **não há endpoint JSON**
   (`router.ex:44`, sem scope);
4. o payload do GitHub — que é terceiro, e a pergunta manda tratá-lo como tal — entra por
   colunas `string`/`utc_datetime`/`integer`/`jsonb`; **não há coluna `numeric`**, e o
   `Jason` desta base não produz `Decimal`;
5. o único `%Decimal{}` vivo vem do Postgrex, que constrói o expoente como `-scale` com
   `scale` limitado a `int16` (`numeric.ex:116-120`) — expoente estruturalmente pequeno, com
   o custo medido em 2 ms no pior caso;
6. e ainda que 1–5 falhassem, a versão instalada **rejeita a entrada do PoC por padrão**
   (seção 2).

São seis camadas, e o aviso precisaria vencer todas. Ele não vence a primeira.

---

## 5. Severidade **nesta aplicação**

### Achado 1 — o aviso: **Informativo**

**Razão, pela tabela do papel**: não há caminho de exploração a descrever. A tabela reserva
"baixa" para endurecimento sem exploração conhecida *no desenho atual*; aqui não é o desenho
que fecha o caminho — é que a mitigação pedida pelo aviso **já está instalada e foi medida**.
Rotular "baixa" sugeriria um resíduo a endurecer. Não há.

Nomeando pela régua: o aviso pertence a **A06:2021 — Vulnerable and Outdated Components**,
que é a categoria do gate e do processo, não do código. O dano descrito (CWE-400, consumo
descontrolado) não tem categoria própria no Top 10 de 2021 e chegaria pela borda de
**A04:2021 — Insecure Design** se a defesa dependesse de alguém lembrar de passar
`max_digits`. **Não depende**: a defesa mora na dependência (limites decimal128 por padrão)
e no protocolo do Postgres (`int16` no `dscale`). **ASVS V10** (integridade de dependências)
para o gate e a exceção; **ASVS V5** (validação de entrada) para a verificação de alcance,
que é a seção 4.

### Achado 2 — desenho, adjacente: **baixa**

**Onde**: `lib/the_band/work_items/person_work.ex:478`.

```elixir
defp dias(%Decimal{} = d), do: Decimal.to_integer(Decimal.round(d, 0))
```

**O que é**: as duas funções amplificadoras da lista do aviso são chamadas sem limite
explícito e sem tratamento de erro. Hoje isso é **correto e não é vulnerabilidade** — a
garantia existe, mas mora **duas camadas abaixo**, no `int16` do protocolo do Postgres. É o
mesmo padrão que o papel descreve em A04 e que já vive nesta base em
`lib/the_band/ai/provider_credential.ex` (o changeset aceita, quem garante é
`TheBand.AI.put/3`): a defesa está fora do lugar onde a leitura procura por ela, e o segundo
chamador não vai saber.

**Caminho de exploração**: nenhum, hoje. O que existe é o custo de descobrir isso — foi
preciso ler o decoder do Postgrex para responder à pergunta 3.

**Consequência para o negócio**: se um `%Decimal{}` de expoente fora de faixa alcançasse
`dias/1`, o resultado **não** seria um número errado nem um `{:error, motivo}`: seria
exceção. Medido — `Decimal.round(Decimal.new(1, 1, 7000), 0)` com o contexto padrão levanta
`ArgumentError` com a mensagem `"1st argument: not an integer"`, que é um erro interno
vazado, não um erro de domínio. A pessoa veria a tela de 500 na página de uma pessoa, e a
investigação começaria olhando o LiveView. Isso é **A09/ASVS V7**: erro que não distingue "o
valor está fora de faixa" de "algo quebrou".

**O que fecha** (não implemento — é do desenvolvedor, via FR e tarefa): o teste de guarda da
seção 7.1, que prova que a faixa vale, mais um comentário na função dizendo **de onde vem** a
garantia. O comentário não é decoração: nesta base ele é o que impede que a próxima revisão
gaste o tempo que esta gastou.

**O que acontece se não entrar agora**: nada quebra. O risco de adiar é que a garantia
implícita sobreviva a uma mudança que a remova — uma coluna `numeric` nova, um campo
`:decimal`, um `fragment` com `::numeric` explícito — sem que nada acuse. É a forma da **L19**
(o filtro existe, é o filtro errado, e a ausência do certo é invisível), aplicada a um
limite em vez de a um `where`.

---

## 6. O que eu **NÃO** verifiquei

A seção obrigatória, e ela é o par da seção 4: sem ela, "não existe caminho" se lê como
"está seguro".

1. **Não consultei banco de dados nenhum.** Não há `psql` nesta máquina e não uso credencial
   de produção para confirmar achado. A afirmação de que o Postgres envia `dscale` não
   negativo (logo `exp <= 0`) vem da leitura de `numeric.ex:116-120` e da semântica do tipo
   `numeric` — **não** de uma consulta executada. O limite que **medi** é o do `int16`
   (`|exp| <= 32768`), e nele o custo é ≤ 2 ms / 33 KB. Se alguém quiser a afirmação mais
   forte, ela precisa de um `select` contra um Postgres real;
2. **não verifiquei a escala real de `extract(day from ...)`** contra um Postgres; li a
   semântica e li o consumo em `dias/1`;
3. **não verifiquei que `type(sum(...), :integer)` gera o cast em SQL** executando a consulta
   — li o comentário de `queries.ex:220-221` e a semântica de `Ecto.Query.API.type/2`. Se
   estiver errado, o caminho 3 da tabela 3.1 vira um consumidor de `Decimal` a mais (ainda
   autenticado, ainda com o mesmo limite de `int16`);
4. **não auditei todas as dependências.** Filtrei por menção a `Decimal.` e analisei as
   alcançáveis: `postgrex`, `ecto`, `jason`, `cloak_ecto`. Ficaram de fora, deliberadamente,
   `deps/phoenix/lib/mix/phoenix/schema.ex` (gerador, não runtime) e os `integration_test/`
   de `ecto`/`ecto_sql` (não compilam no app). Não li `oban`, `bandit`, `finch`, `mint`,
   `cloak`, `bcrypt_elixir`, `phoenix_live_view` procurando por `Decimal`;
5. **não verifiquei o perfil de custo sob OTP 29** contra o que o aviso descreve; as medidas
   da seção 3.2 são desta máquina (OTP 29, Elixir 1.20.2), não de produção;
6. **não rodei `mix gates`.** Rodei o gate 4/15 isoladamente, três vezes, com os códigos de
   saída anotados na seção 8. O veredito dos quinze é do QA, e nenhum comando que eu rodei o
   substitui;
7. **não escrevi teste, e registro que não existe nenhum**: `grep -rn "Decimal" test/` não
   devolve nada. Ou seja, **nenhum teste desta suíte exercita `dias/1`, a faixa do
   `Decimal.Context` ou o resultado de `percentile_disc`**. A seção 7 entrega o cenário ao QA;
8. **não avaliei negação de serviço por outras vias.** Em particular, `Jason.decode/1` sobre
   a resposta do LLM (`generate_worker.ex:124`) recebe JSON de terceiro e decodifica números
   como float nativo; o que acontece com `1e400` ali é outro assunto, não foi medido, e não
   pertence a este aviso;
9. **não comparei `development` com `main`.** Li `development` em `0b37a71`. Se a produção
   estiver em outro ponto, o mapeamento da seção 3 precisa ser reconferido — embora a
   superfície ser de quatro linhas torne a divergência improvável;
10. **não verifiquei se o registro OSV foi corrigido depois de 2026-09-08T03:45Z**, que é o
    `modified` do documento que li.

---

## 7. O cenário de teste, para o QA

O papel manda: **todo achado vira teste antes de virar correção**. Aqui o teste vale mais que
a exceção, porque é ele que sobrevive a um `mix.lock` distraído.

### 7.1 Guarda do artefato — o teste que substitui a exceção por evidência

**O que asserir**: que a dependência instalada está na faixa que torna o aviso inaplicável.

- `assert %Decimal.Context{precision: 34, emax: 6144, emin: -6143} = Decimal.Context.get()`
- `assert Decimal.parse("1e1000000000") == :error`
- `assert Decimal.cast("1e1000000000") == :error`
- `refute match?({%Decimal{}, ""}, Decimal.parse("1e1000000000"))`
- e a asserção que prova que o parser **ainda funciona** (senão o teste passa com o `decimal`
  desinstalado): `assert {%Decimal{}, ""} = Decimal.parse("12.50")`

**Por que este teste importa**: no dia em que alguém fizer downgrade do `decimal` para 2.x —
ou chamar `Decimal.Context.set/1` global com `emax: :infinity` em algum ponto de partida da
aplicação —, a suíte reprova. O gate não reprovaria: ele já reprova hoje, por metadado, e
uma exceção o cala nos dois casos. **A exceção sem este teste troca um falso positivo por um
possível falso negativo.**

**Prova de que o teste mede** (defeito de mentira, e **copiar o arquivo antes**, pela lição
do `git checkout`): dentro do próprio teste, `Decimal.Context.set(%Decimal.Context{... emax: :infinity, emin: :infinity})`
e confirmar que a asserção de `parse` reprova; restaurar em seguida. Foi assim que a seção 2
provou que não estava medindo o nada.

### 7.2 Guarda do consumidor — `lead_time/2`

`dias/1` é privada, então o cenário é sobre `WorkItems.lead_time/2`:

- **com a guarda de que mediu**: `assert %{count: c} = resultado; assert c > 0` **antes** de
  asserir qualquer coisa sobre a mediana — senão a suíte celebra a consulta vazia;
- `assert is_integer(median) and is_integer(p85)` — o contrato do `@spec` (`person_work.ex:441-442`)
  diz `integer()`, e é `dias/1` que o cumpre;
- **e o par que a constituição exige**, princípio V: **dois tenants povoados
  simultaneamente**, com `refute` que a mediana de um seja afetada por issue do outro. Este
  não é um teste do aviso — é o teste que `where i.tenant_id == ^tenant_id`
  (`person_work.ex:447`) merece de todo modo, e a ocasião é agora.

### 7.3 O teste que **não** vale a pena

Não construir `Decimal.new(1, 1, 1_000_000_000)` e empurrar por `dias/1` esperando exceção.
Isso assere sobre uma entrada que o sistema **não pode produzir** (seção 3.2) e congela uma
mensagem de erro interna do `decimal`. Envelhece mal e não protege nada.

---

## 8. O gate aceita exceção — sim, nativamente

**Qual é o gate**: o 4 de 15 é `{"auditoria de dependências", {:mix, ["hex.audit"]}}`,
definido em `lib/mix/tasks/gates.ex:63`. Confirmado com `mix gates --list`, que imprime
`auditoria de dependências` na quarta posição de quinze. **É `mix hex.audit`, não
`mix deps.audit`** — a distinção decide o resto desta seção, porque só um dos dois tem
mecanismo de exceção.

**Estado medido hoje** (Hex 2.5.1, Elixir 1.20.2), sempre com redirecionamento e leitura do
código de saída em um segundo ato, nunca com `| tail`:

| Comando | Saída | Código |
|---|---|---|
| `mix hex.audit` | `Advisories:` com **um único** achado, o do `decimal` | **EXIT=1** |
| `HEX_IGNORE_ADVISORIES=CVE-2026-32686 mix hex.audit` | `Ignored advisories:` com o mesmo achado | **EXIT=0** |
| `HEX_IGNORE_ADVISORIES=CVE-0000-0000 mix hex.audit` | `Advisories:` + aviso de entrada obsoleta | **EXIT=1** |
| `mix deps.audit` (mix_audit — **não** é gate) | `No vulnerabilities found.` | EXIT=0 |

Nada foi alterado para produzir essas medidas: a variável de ambiente foi usada exatamente
para **não** tocar em `mix.exs`.

**O mecanismo documentado** (`@moduledoc` de `Mix.Tasks.Hex.Audit`, Hex 2.5.1):

```elixir
def project() do
  [
    # ...
    hex: [
      ignore_advisories: ["CVE-2026-32686"],
      ignore_retirements: [:decimal, phoenix: "1.0.0"]
    ]
  ]
end
```

Casa por ID **primário ou alias** — então `CVE-2026-32686` cobre também `EEF-CVE-2026-32686`
e `GHSA-rhv4-8758-jx7v`. Equivalentes por ambiente: `HEX_IGNORE_ADVISORIES` e
`HEX_IGNORE_RETIREMENTS`, listas separadas por vírgula.

**Três propriedades que fazem deste mecanismo uma exceção aceitável, e não um gate
enfraquecido:**

1. **o achado continua visível.** Ele migra para a seção `Ignored advisories:` e continua
   sendo impresso a cada execução. Não é silêncio — é anotação, o mesmo desenho do
   `@sobelow_skip` desta base;
2. **é seletivo por ID.** Não muda severidade, não desliga o gate, não afeta nenhum outro
   pacote. Comparar com o que **seria** enfraquecer: trocar `--exit low` por `medium` no
   Sobelow, ou remover o passo de `gates.ex`. Nada disso está em jogo;
3. **a própria ferramenta denuncia a entrada obsoleta.** Medido: com um ID que não casa, ela
   imprime *"ignore_advisories entry \"CVE-0000-0000\" (set in environment variable
   HEX_IGNORE_ADVISORIES) does not match any advisory for the locked dependencies and can be
   removed"* — e mantém EXIT=1. **Este é o sinal automático de reavaliação**: no dia em que o
   registro OSV ganhar o evento `fixed`, ou o `decimal` sair do lock, ou o ID mudar de forma,
   a exceção passa a gritar sozinha em vez de emudecer para sempre.

**O que o mecanismo NÃO faz, e isto é a resposta à pergunta do prazo**: o Hex **não tem campo
de expiração**. Não existe `ignore_advisories: [{"CVE-2026-32686", until: ~D[2026-12-07]}]`.
Portanto **o prazo tem de ser mantido fora da ferramenta** — comentário no `mix.exs` com data
e motivo escrito (o padrão desta base: anotação sem motivo escrito é achado, não exceção) mais
item no sprint backlog.

**Sobre construir a ponte**: uma exceção com prazo *automático* exigiria **código novo no
gate** — um passo em `lib/mix/tasks/gates.ex` que lesse a data e reprovasse ao vencer. Isso é
decisão do Product Owner, e registro minha leitura técnica para que ele decida informado: eu
**não** a recomendaria. `mix gates` é a definição única dos gates, e acrescentar lógica de
expiração ali cria superfície nova em código privilegiado para resolver um problema que é de
metadado de terceiro — sendo que a propriedade 3 acima já dá um sinal, e a seção 7.1 dá a
guarda que de fato protege. Menos código, mais evidência.

**Uma nota que o `gates.ex` merece**: as linhas 60-61 do arquivo registram que em 2026-08-13
`mix deps.audit` dizia "No vulnerabilities found" para a mesma dependência que o `hex.audit`
apontava. Hoje o mesmo aconteceu de novo, no mesmo sentido: `deps.audit` EXIT=0, `hex.audit`
EXIT=1. **A lição continua válida e ganha a segunda metade**: bases de aviso divergem, e
nenhuma das duas é ausência de risco. Neste caso, o que decidiu não foi nenhuma das bases —
foi medir o artefato.

---

## 9. O texto da exceção, para o Product Owner

**Eu não registro isto em lugar nenhum.** O texto abaixo é o que o Product Owner *poderia*
registrar, se decidir por esta saída. Ele não escreve "aceito" nem "recusado" por mim, e a
decisão é dele com a pessoa mantenedora.

> ### Exceção declarada — EEF-CVE-2026-32686 (`decimal` 3.1.1)
>
> **Aviso**: `EEF-CVE-2026-32686`, alias `CVE-2026-32686` e `GHSA-rhv4-8758-jx7v` —
> *Unbounded exponent in decimal enables unauthenticated DoS*, CVSS v4 6.9 (MEDIUM), CWE-400.
> Dependência **transitiva**, exigida por `ecto` e `postgrex` como `~> 3.0`: não há como
> trocá-la nem removê-la, e 3.1.1 é a mais recente publicada no Hex.
>
> **O que se está aceitando**: que o gate 4/15 (`mix hex.audit`) deixe de reprovar por este
> aviso específico, por ID, mantendo o achado impresso na seção `Ignored advisories:`.
>
> **E o que NÃO se está aceitando — porque não é isto**: não se está aceitando correr o
> risco. A mitigação que o aviso pede **já está na versão instalada**: o `decimal` 3.0.0
> tornou os limites do IEEE 754 decimal128 o padrão de `parse/1`, `cast/1`, `new/1` e
> `to_string/2`, e a 3.1.1 os mantém — medido em 2026-09-08, `Decimal.parse("1e1000000000")`
> devolve `:error`, e `%Decimal.Context{}` nasce com `emax: 6144`. O `details` do próprio
> registro OSV e o GHSA declaram a faixa afetada como `< 3.0.0`; o registro casa a 3.1.1
> porque a range SEMVER dele **não tem evento `fixed`**. O que se aceita, portanto, é a
> divergência entre a base de avisos e o artefato — não uma exposição.
>
> **Alcance nesta aplicação, conferido**: nenhum caminho de texto não autenticado alcança
> `Decimal`. O `Decimal` aparece em quatro linhas de `lib/`, uma delas de código
> (`lib/the_band/work_items/person_work.ex:478`), atrás de `require_user`, do `on_mount` e de
> `Tenants.pode_ver/3`. Não há coluna `numeric` no esquema, não há campo `:decimal`, não há
> endpoint JSON, e o único `%Decimal{}` vivo vem do Postgrex com expoente limitado pelo
> `int16` do protocolo. Detalhe e o que ficou sem verificar em
> `docs/seguranca/2026-09-08-decimal-expoente-ilimitado.md`.
>
> **Nenhum gate é enfraquecido**: `--exit low` do Sobelow não muda, nenhum passo sai de
> `lib/mix/tasks/gates.ex`, a exceção é por ID e o achado continua sendo impresso.
>
> **Por quanto tempo**: até o registro OSV/EEF ganhar o evento `fixed`, e **no máximo até
> 2026-12-07** (90 dias), quando a entrada é reexaminada mesmo que nada tenha mudado.
> Reavaliação obrigatória no fechamento de cada sprint enquanto durar.
>
> **O sinal que obriga a reavaliar antes do prazo** — qualquer um destes:
>
> 1. `mix hex.audit` passar a avisar que a entrada `ignore_advisories` *"does not match any
>    advisory for the locked dependencies and can be removed"*. É emitido pela própria
>    ferramenta (verificado em 2026-09-08) e significa que o aviso mudou de forma, ganhou
>    `fixed`, ou o pacote saiu do lock;
> 2. **versão nova do `decimal` publicada no Hex** — atualizar e **remover a exceção** antes
>    de qualquer outra coisa;
> 3. **rota nova fora de `require_user` que aceite número em texto**, ou a pipeline `:api`
>    de `lib/the_band_web/router.ex:44` ganhando um `scope`;
> 4. **campo `:decimal` novo em schema**, ou coluna `numeric`/`decimal`/`float` nova em
>    migration, ou `fragment` com `::numeric` explícito;
> 5. `Decimal.new/3`, `Decimal.parse/2` ou `to_string/3` aparecendo no código com
>    `max_digits: :infinity` ou `max_exponent: :infinity`, ou qualquer chamada a
>    `Decimal.Context.set/1` que afrouxe `emax`/`emin`.
>
> **O que fecha a exceção de vez**, e é preferível a mantê-la: o teste de guarda descrito em
> `docs/seguranca/2026-09-08-decimal-expoente-ilimitado.md` §7.1, que assere a faixa do
> `Decimal.Context` e a recusa de `1e1000000000`. Com ele na suíte, um downgrade do `decimal`
> reprova nos **testes** — que é onde a regressão deve aparecer — e a exceção no gate deixa de
> ser a única linha de defesa.
>
> **Decidido por**: (a preencher) · **Em**: (a preencher) · **Avaliação de alcance**: papel
> Security, 2026-09-08.

### Onde essa exceção deveria morar

São **três lugares, com funções diferentes**, e confundi-los é o que produz exceção
esquecida:

| Lugar | Papel | Conteúdo |
|---|---|---|
| `mix.exs`, na chave `hex:` de `project/0` | onde a exceção **age** | `ignore_advisories: ["CVE-2026-32686"]` **com o motivo escrito em comentário imediatamente acima**, a data e o link para este documento. Anotação sem motivo escrito é achado, não exceção — é a regra do `@sobelow_skip` desta base, e vale igual aqui |
| `docs/releases/vX.Y.Z.md` da próxima release | onde a **decisão** fica registrada | o texto acima, na seção de risco residual aceito, com quem decidiu, quando e por quê. É o mesmo registro que o PR já exige em "riscos residuais" |
| `sprint-backlog` do sprint corrente | onde a exceção **volta a ser lida** | item com a severidade e a data-limite de 2026-12-07. Achado que atravessa dois sprints sem decisão é sinal de que a severidade foi mal escrita |

E o quarto lugar, que é o melhor de todos: **a suíte**, pela seção 7.1. Uma exceção com data
depende de alguém ler a data; um teste não depende de ninguém.

---

## 10. Encerramento

**O que verifiquei, e com quê**: o registro OSV e o GHSA na API de origem; o `CHANGELOG` e o
código do `decimal` 3.1.1 instalado em `deps/`; o comportamento do artefato compilado em
`_build/dev/lib/decimal/ebin`, medido, incluindo a verificação de que a medida mede; o
decoder `numeric` do Postgrex; o alcance de `Decimal` em `lib/` e em `test/`; os tipos de
coluna de todas as migrations; as rotas públicas e as pipelines do router; as portas
indiretas de `Jason`, `Ecto.Type` e `cloak_ecto`; a definição do gate em
`lib/mix/tasks/gates.ex` e `mix gates --list`; e o mecanismo de exceção do `mix hex.audit`,
com códigos de saída lidos em três configurações.

**O que não verifiquei**: a seção 6, com dez itens nomeados. O mais relevante é o primeiro —
**não consultei nenhum banco de dados**, então a afirmação mais forte sobre o expoente
(`exp <= 0`) é leitura de código, e a afirmação medida é a mais fraca e suficiente
(`|exp| <= 32768`, custo ≤ 2 ms).

**Código de saída do gate 4/15 em 2026-09-08**: `mix hex.audit` → **EXIT=1**, um único
achado, o do `decimal`. **`mix gates` completo não foi executado** — o veredito dos quinze é
do QA, e nada que eu rodei o substitui.

**Nota operacional, fora do escopo de segurança**: `mkdocs.yml` tem `nav` explícito
(linha 97). Este arquivo não está nele, então o MkDocs vai listá-lo como fora da navegação.
Incluí-lo é decisão de quem cuida do site; não alterei `mkdocs.yml`.
