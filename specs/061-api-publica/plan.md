# Implementation Plan: a API pública com token — fatia 1

**Branch**: `061-api-publica` | **Date**: 2026-09-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/061-api-publica/spec.md`

---

## Summary

A primeira fatia vertical abre a porta e prova o caminho inteiro: quem administra
**gera** um token na área administrativa, vê o valor **uma vez**, **revoga** quando
quiser, e um cliente com esse token chama **`GET /api/v1/teams`** e recebe as equipes
do tenant dele.

É uma fatia, e não uma fundação: nada de infraestrutura sem consumidor visível. O
token nasce junto com a tela que o gera e com a rota que o consome — as três na
mesma entrega.

**Histórias**: US1 inteira, US3 inteira, e US2 reduzida a **uma** rota.
**Requisitos**: FR-001 a FR-017, FR-025 a FR-031, FR-045 a FR-049, e FR-069.

---

## Technical Context

**Language/Version**: Elixir 1.20.2 / OTP 29

**Primary Dependencies**: Phoenix 1.8, Phoenix LiveView, Ecto SQL, Postgrex,
`Plug.Crypto` (já presente, vem do Phoenix). **Nenhuma dependência nova nesta fatia**
— `open_api_spex` pertence à US4, que é P2 e fica fora.

**Storage**: PostgreSQL. Uma tabela nova, `api_access_tokens`.

**Testing**: ExUnit, `Phoenix.ConnTest` para as rotas, `Phoenix.LiveViewTest` para a
tela, e o contador de consultas de `test/support/contador_de_consultas.ex` para o
teto por requisição.

**Target Platform**: a mesma imagem de produção — VPS Contabo com Dokploy.

**Project Type**: monólito modular multitenant (princípio V). A API é uma **porta
nova para o mesmo domínio**, nunca um serviço separado.

**Performance Goals**: o custo por requisição é dominado pela decisão Q3 — **sem
cache de token**. Cada chamada faz: uma busca por id público (índice único), um
SHA-256, uma comparação em tempo constante, e a recomputação de alcance por
`Access`. Teto declarado nesta fatia: **uma consulta para o token, e o mesmo número
de consultas da tela `/teams` para o recurso**, medido pelo contador.

**Constraints**: o valor em claro não pode existir em log, resposta, página ou banco
(SC-001). Recusa uniforme byte a byte (SC-003). Nenhuma escrita (SC-006).

**Scale/Scope**: 2 tenants e 10 equipes no ambiente local; a ordem de grandeza do
Conecta Fapes é dezenas de equipes por tenant. Não é o volume que decide nada aqui.

### NEEDS CLARIFICATION resolvido na Phase 0

A premissa 2 da spec levantava: *"`Access` responde por projeto e por sync, ou o
recorte desses dois vem de outro lugar?"*. **Resolvido e fora do caminho desta
fatia** — ver [research.md](./research.md), R4. Projeto e sync não entram aqui.

---

## Constitution Check

*GATE: passa antes da Phase 0, reavaliado depois da Phase 1.*

| Princípio | Como esta fatia o honra |
|---|---|
| **I — domínio pelas ontologias** | o token **não é conceito de ontologia**. É credencial de acesso à plataforma, como `users` e `access_grants`, e por isso vive em `TheBand.Tenants`, não em `TheBand.Ontology`. Nomear `api.access_token` na rede seria inventar conceito para caber numa regra |
| **II — fonte externa não é domínio** | não se aplica: nada aqui vem de fonte externa |
| **III — proveniência e idempotência** | a criação do token **é declaração**, e registra autor e instante. A revogação **marca** (`revoked_at`, `revoked_by_user_id`) e nunca apaga — SC-012 exige 0 linhas removidas |
| **IV — semântica em YAML versionado** | os dois limiares de expiração vão para `priv/knowledge_base/rules/api_access_thresholds.yaml`, id `api.access.thresholds` (Q8, FR-069). **Nenhum deles em constante de módulo** |
| **V — monólito modular multitenant** | a API é porta nova do mesmo monólito. `tenant_id` `NOT NULL` na tabela, e nenhuma consulta emitida sem tenant (FR-031) |
| **VI — Spec Kit e sprint backlog** | spec escrita e aprovada; este plano; tarefas e issues depois; **protótipo da tela antes do código** |
| **VII — gates e revisão** | `mix gates` com código de saída 0, e a lacuna de revisão declarada no PR se não houver revisora |
| **VIII — desenho que o problema justifica** | as três respostas estão na seção seguinte, uma por padrão introduzido |
| **IX — ontologias modulares** | não se aplica: nenhuma ontologia muda |
| **X — responsabilidade única** | a tela de tokens faz **uma** coisa: gerir credencial. Não lista contas, não concede escopo, não mostra sincronização |
| **XI — estado conferido antes, sinal nunca silenciado** | a recusa uniforme para fora convive com **o motivo real no log interno** (SC-004): calar para o cliente não é calar para quem opera |

### Restrições tecnológicas

A constituição fixa a stack e exige justificativa escrita para dependência nova.
**Esta fatia não traz nenhuma.** `Plug.Crypto.secure_compare/2` e `:crypto.hash/2`
vêm do que já está instalado.

---

## As decisões de desenho, com as três respostas (princípio VIII)

### 1. O token tem DUAS partes — id público e segredo

```
tb_api_<id_publico>_<segredo>
```

- **Problema concreto**: buscar a linha por `where: t.token_hash == ^hash` entrega a
  comparação ao Postgres, fora do nosso controle de tempo. A decisão Q1 exige tempo
  constante, e o SQL não a dá.
- **Existe agora ou é previsão?** **Existe agora**, e é consequência direta de Q1,
  que é decisão registrada do papel Security em 2026-09-09.
- **O que fica pior**: o token fica mais comprido, o parser precisa de um formato
  fixo e de teste para entrada malformada, e o id público é um dado a mais que
  vaza em qualquer log de cabeçalho — então o log de cabeçalho **não pode existir**.

### 2. Um `Plug` de autenticação, e não uma função no controlador

- **Problema concreto**: FR-016 exige que inexistente, revogado e expirado produzam
  respostas **idênticas byte a byte**. Três controladores implementando a mesma
  recusa divergem no primeiro deles que alguém editar.
- **Existe agora ou é previsão?** **Previsão parcial** — nesta fatia há **um**
  controlador. O plug se justifica mesmo assim porque a recusa uniforme é um
  requisito com critério de sucesso automatizado (SC-003), e um caminho único é o
  que o torna verificável; e porque a fatia seguinte traz as outras 7 rotas de
  FR-021.
- **O que fica pior**: o veredito fica longe do lugar onde é usado, e quem lê o
  controlador não vê a autenticação. Mitigado por `pipe_through` explícito no
  roteador, onde o nome do plug fica visível ao lado da rota.

### 3. `Access` é chamado na forma EM LOTE, nunca por item

- **Problema concreto**: é a lição **L38**, citada 70 vezes no repositório, e o
  próprio `access.ex:288-290` diz que `pessoas_alcancadas/2` existe para evitá-la.
  Uma coleção que chama `pode_ver/3` por linha é N+1 de autorização.
- **Existe agora ou é previsão?** **Existe agora** e já tem guardião: sete testes
  contam consultas por render, e um deles afirma que dez pessoas custam o mesmo que
  cem, que custa o mesmo que uma.
- **O que fica pior**: cada recurso novo da API precisa de uma forma em lote no
  `Access`, e onde ela não existir a fatia **para e levanta a lacuna** em vez de
  improvisar no controlador. Para `/api/v1/teams` a lacuna **não existe** — ver R4.

### 4. REST, e não GraphQL

- **Problema concreto**: FR-023 manda limitação e interpretação incorreta viajarem
  **no mesmo objeto**, **copiadas e não resumidas**, e **nunca como campo
  opcional** — de 1 342 a 3 411 bytes de prosa obrigatória por medida. A premissa do
  GraphQL é o cliente escolher campos: quem não pedir `limitations` recebe o número
  nu, e o consumidor previsto é um modelo de linguagem, que afirmaria o número sem a
  ressalva. Honrar a regra exigiria tornar esses campos não selecionáveis — que é
  desligar o que justifica GraphQL.
- **Segundo problema, medido**: há 62 schemas Ecto no domínio com **uma**
  `belongs_to` e **duas** `has_many`, todas em infraestrutura (`user.ex:90`,
  `tenant.ex:24`, `connected_tool.ex:38`). As chaves estrangeiras do domínio são
  campos `:binary_id` crus. O Dataloader do Absinthe agrupa **sobre associação
  Ecto**, e aqui não há nenhuma: cada aresta seria resolver e função de lote
  escritos à mão, contra os sete testes que contam consultas.
- **Existe agora ou é previsão?** **Existe agora**: as duas medidas são do código de
  hoje.
- **O que fica pior com REST**: sobrebusca. A resposta carrega a ressalva inteira
  mesmo para quem não a quer, e a spec já **recusou** `?fields=` como alívio, por
  ser *"uma rota que ninguém revisou"* por combinação. O custo é aceito, não
  mitigado.
- **A condição em que a decisão vira**: um consumidor que precise de travessia
  arbitrária sobre as 177 relações da rede **e** um jeito de manter as ressalvas
  obrigatórias. Nesse dia o desenho é **dividir** — REST para medidas, GraphQL para
  o grafo —, nunca trocar, e exige a modelagem de ameaça, o teto de profundidade e
  custo, e a ADR que `docs/seguranca/2026-09-09-api-com-token.md:889` já nomeia.
- **O que NÃO foi medido**: o **diâmetro do grafo** da rede e o caminho mais longo
  entre os conceitos que FR-021 expõe. O argumento "grafo profundo" está apoiado na
  contagem de 177 relações, não na profundidade real. É a única medida que poderia
  reabrir isto com rigor.

### 5. SHA-256, e não Cloak nem bcrypt

Já justificado na spec (Q1) a partir da avaliação de Security. **Não se rejustifica
aqui**; o que este plano acrescenta é que a divergência do padrão da casa —
credencial de terceiro usa `TheBand.Encrypted.Binary` — vira **ADR** (FR-004/005),
porque contrato e padrão público exigem ADR para mudar.

---

## Project Structure

### Documentation (this feature)

```text
specs/061-api-publica/
├── spec.md              # já existia
├── plan.md              # este arquivo
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/           # Phase 1
│   ├── api-v1-teams.md
│   └── erro.md
├── prototipo/           # ANTES do código — ver "A ordem da fatia"
└── tasks.md             # /speckit-tasks, não criado aqui
```

### Source Code (repository root)

```text
lib/the_band/tenants/
├── api_tokens.ex                    # comandos e consultas — a fronteira
└── schemas/api_access_token.ex      # o schema, com Inspect derivado

lib/the_band_web/
├── plugs/api_auth.ex                # o veredito único da recusa
├── controllers/api/v1/team_controller.ex
├── controllers/api/v1/fallback_controller.ex   # o formato único de erro
├── controllers/api/v1/team_json.ex             # a serialização
└── live/api_token_live/index.ex                # a tela, área administrativa

priv/repo/migrations/
└── <ts>_tokens_de_api.exs

priv/knowledge_base/rules/
└── api_access_thresholds.yaml       # FR-069, id api.access.thresholds

test/
├── the_band/tenants/api_tokens_test.exs
├── the_band_web/plugs/api_auth_test.exs
├── the_band_web/controllers/api/v1/team_controller_test.exs
└── the_band_web/live/tela_de_tokens_test.exs
```

**Structure Decision**: as pastas existem e o padrão é o da casa — fronteira em
`lib/the_band/<contexto>.ex` com `defdelegate` (ADR 0003), schemas privados atrás
dela, e nenhum `Repo` fora do contexto. A novidade é `lib/the_band_web/plugs/`, que
hoje não existe: um diretório novo para um arquivo. É menos ruim que pendurar o plug
em `router.ex` ou em `controllers/`, porque o plug não é rota nem controlador.

---

## A ordem da fatia — o protótipo primeiro

A casa manda **protótipo antes do código**, e a régua do QA sai dele. Para esta
fatia isso não é formalidade: a tela de tokens tem quatro momentos que só se
decidem vendo, e errar qualquer um deles é erro de segurança, não de estética.

1. **o momento do valor em claro** — aparece uma vez, com aviso de que não volta,
   com ação de copiar, e some ao navegar (FR-006, FR-048);
2. **a linha mascarada** — `••••••••••••••••` mais os quatro últimos (FR-007);
3. **o alcance vigente da conta dona**, na lista, para que a consequência de FR-028
   seja visível antes de ser reclamada (FR-047);
4. **a confirmação de revogação nomeando o rótulo** (FR-049).

A fatia começa pelo protótipo aprovado em `specs/061-api-publica/prototipo/`, com o
`PROMPT.md` que o gerou e as decisões da pessoa mantenedora. **A tela implementada é
exatamente a aprovada**, e o QA confere item a item.

Depois do protótipo, a ordem é: tabela e fronteira → tela → plug → rota → gates.

---

## O que esta fatia deixa de fora, e por quê

| Fora | Por quê |
|---|---|
| as outras 7 rotas de FR-021 | uma rota prova o caminho; sete provam o mesmo caminho sete vezes |
| **Swagger** (US4, FR-040) | é P2 e traz a única dependência nova. Sem ele a API é consumível com `curl` e a spec |
| **limite de taxa** (US5) | é P2 e contenção de risco operacional, não valor novo |
| paginação além do mínimo (FR-018/019) | `/api/v1/teams` devolve dezenas de linhas. O mínimo é o teto de página e *tem próxima*, sem total (Q5) |
| **as ressalvas obrigatórias** (FR-022/023/024) | entram com a primeira rota que devolve **medida**, e `/api/v1/teams` não devolve. Escrevê-las agora seria desenho sem o dado que as exige |
| expiração por desuso (`token_idle_expiry`) | o limiar vai para o YAML nesta fatia; **aplicá-lo** exige o carimbo de uso maduro, e é a fatia seguinte |
| revogação em massa por conta (Q4) | é requisito, e depende de mais de um token por conta existir em uso real |

---

## Complexity Tracking

> Preenchido só quando o Constitution Check tem violação a justificar.

| Violação | Por que é preciso | Alternativa mais simples, e por que foi recusada |
|---|---|---|
| `lib/the_band_web/plugs/` — diretório novo para um arquivo | o plug não é rota nem controlador, e `router.ex` já tem 160 linhas de rota | pendurar a função no `router.ex`: o veredito de recusa uniforme ficaria dentro do arquivo de rotas, onde ninguém procura por lógica de segurança |
| divergência do padrão de credencial (SHA-256 em vez de Cloak) | Q1, decisão de Security: Cloak é reversível e devolveria todos os tokens em claro com a chave mestra | manter o padrão da casa: protege credencial de **terceiro**, que a plataforma precisa **replicar**; aqui a plataforma só precisa **conferir**. Vira ADR (FR-004/005) |

---

## Post-Design Constitution Check

Reavaliado depois da Phase 1, com os artefatos escritos:

- **nenhuma dependência nova** — a restrição tecnológica segue intacta;
- **nenhuma ontologia tocada** — princípios I, IV e IX seguem intactos;
- **`tenant_id` `NOT NULL`** e nenhuma consulta sem tenant — princípio V honrado no
  esquema, e não só na intenção;
- **revogação que marca** — SC-012 é verificável por contagem, e o
  [data-model.md](./data-model.md) não tem `delete`;
- **o formato único de erro** está em [contracts/erro.md](./contracts/erro.md), e é
  o que torna SC-003 verificável byte a byte;
- **a lacuna declarada**: o carimbo de último uso é **campo**, e não série (Q6) —
  não haverá auditoria do *que* foi consultado nesta fatia. Está escrito no
  contrato, não só aqui.

**Veredito: passa.** Duas violações, as duas justificadas acima, nenhuma silenciosa.
