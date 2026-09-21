# Phase 0 — pesquisa: a API pública com token, fatia 1

O que foi medido no repositório antes de desenhar, e o que **não** foi.

---

## R1 — REST ou GraphQL

**Decisão: REST.**

**Justificativa, medida:**

| Fato | Onde |
|---|---|
| 62 schemas Ecto no domínio, com **1** `belongs_to`, **2** `has_many`, **0** `has_one`, **0** `many_to_many` — e as três em infraestrutura | `lib/the_band/tenants/user.ex:90`, `lib/the_band/tenants/tenant.ex:24`, `lib/the_band/sources/connected_tool.ex:38` |
| chave estrangeira do domínio é campo cru | `lib/the_band/ontology/continuum/sro/schemas/sprint.ex:39-61` — `field :connected_tool_id, :binary_id` |
| 7 testes contam consultas por render, com helper compartilhado | `test/support/contador_de_consultas.ex` |
| o mais duro afirma `dez == cem` e depois `cem == 1` | `test/the_band/work_items/rotulos_na_listagem_test.exs:92-104` |
| a prosa obrigatória por medida vai de 1 342 a 3 411 bytes; 17 912 no conjunto de 8 | `priv/knowledge_base/measurements/*.yaml` |
| a rede tem 240 conceitos e 177 relações, 23 cruzando ontologias | `priv/knowledge_base/ontology/*/*/modules/*.yaml` |
| a pipeline `:api` está declarada e sem uso | `lib/the_band_web/router.ex:44-46` |
| nenhuma biblioteca GraphQL nem OpenAPI instalada | `mix.exs:84-142`, `mix.lock` |

**O argumento que decide** não é a contagem de relações, é a regra: FR-023 manda a
ressalva viajar no mesmo objeto, copiada e nunca opcional. A premissa do GraphQL é o
cliente escolher campos. Para honrar a regra seria preciso tornar os campos não
selecionáveis — desligar o que justifica a escolha.

**Alternativas consideradas:**

- **GraphQL puro** — recusado pelo acima. Custo adicional: 2 a 3 dependências
  diretas (`absinthe`, `absinthe_plug`, `dataloader`), e **não elimina** o Swagger
  pedido por nome, porque introspecção GraphQL não produz OpenAPI;
- **híbrido agora** — recusado por prematuro: há 8 rotas previstas e **zero**
  consumidores em produção. Princípio VIII: o problema seria previsão, não fato;
- **híbrido depois** — é o caminho aberto, e a condição está escrita no plano.

**O que NÃO foi medido:** o **diâmetro do grafo** e o caminho mais longo entre os
conceitos que FR-021 expõe. Sem isso, "grafo profundo" é inferência a partir de 177
relações, não medida. É a única lacuna que poderia reabrir R1 com rigor.

---

## R2 — como guardar o token

**Decisão: SHA-256 do segredo, comparado com `Plug.Crypto.secure_compare/2`, e busca
pelo id público.**

Vem de Q1 da spec, que vem da avaliação de Security de 2026-09-09. **Não se
redecide aqui.** O que a pesquisa acrescenta:

- `Plug.Crypto` **já está disponível** — vem com Phoenix, é dependência transitiva
  presente no `mix.lock`. Zero dependência nova;
- `:crypto.hash(:sha256, segredo)` é da OTP. Idem;
- o formato de duas partes é **consequência**, não preferência: buscar por hash
  entrega a comparação ao Postgres, e Q1 exige tempo constante do nosso lado.

**Alternativas consideradas e por que não**, resumidas de Q1: `Cloak` é reversível
e devolveria todos os tokens em claro com a chave mestra — proteção certa para
credencial de terceiro, que a plataforma **replica**, e errada para verificador do
próprio segredo, que a plataforma só **confere**. `bcrypt` custa ~100 ms por
verificação, que é defesa contra senha humana e auto-negação de serviço numa API —
e impede busca por índice.

---

## R3 — onde o token vive no código

**Decisão: `TheBand.Tenants`, e não `TheBand.Ontology`.**

O token é credencial de acesso à plataforma, como `users` e `access_grants`. A rede
de ontologias descreve **processo de software observado**; um token de API não é
conceito dela. Nomear `api.access_token` na rede para caber no princípio I seria
inventar conceito para satisfazer uma regra — o contrário do que o princípio pede.

Precedente na própria casa: `TheBand.Tenants.Access` guarda concessões com
`revoked_at`/`revoked_by_user_id` e **não** é ontologia.

---

## R4 — `Access` responde por equipe? (a NEEDS CLARIFICATION da spec)

**Resolvido, e a resposta muda o escopo da fatia.**

A premissa 2 da spec perguntava se `Access` responde por projeto e por sync.
Medido:

| Função | Forma | Onde |
|---|---|---|
| `scopes/2` | — | `lib/the_band/tenants/access.ex:69` |
| `pode_ver/3` | unitária, por pessoa | `:226` |
| `pessoas_alcancadas/2` | **em lote**, por pessoa | `:317` |
| `pode_ver_equipe/3` | **unitária**, por equipe | `:390` |
| equipes alcançadas | **não existe forma em lote** | — |

**Mas a lacuna não bloqueia esta fatia**, e o motivo é um achado que precisa ficar
escrito para ninguém supor o contrário depois:

> A tela `/teams` **não filtra equipes por `Access`**. Ela chama
> `EO.list_teams(tenant, ...)` (`lib/the_band_web/live/teams_live/index.ex:198`), que
> recorta **por tenant** e mais nada (`lib/the_band/ontology/seon/eo/queries.ex:89`).
> A rota está atrás de `:require_user` e da hook `:current_scope`
> (`lib/the_band_web/router.ex:80`), e é isso.

Então FR-026 — *"o que o token alcança é exatamente o que aquela conta alcança"* —
para equipes significa hoje **todas as equipes do tenant**. A API espelha a tela, e
espelhar é o requisito.

**Consequências que ficam declaradas:**

1. `GET /api/v1/teams` recorta por tenant, como a tela. Não é frouxidão da API: é a
   mesma resposta que a pessoa vê logada;
2. se algum dia `/teams` passar a filtrar por `Access`, a API tem de mudar junto, e
   o teste de contrato é o que vai apanhar a divergência;
3. **projeto e sync ficam de fora desta fatia**, e a lacuna original da premissa 2
   continua aberta para quem planejar a fatia que os incluir — `Access` não tem
   forma em lote para eles, e improvisar no controlador seria a L38.

---

## R5 — o formato do token

**Decisão: `tb_api_<id_publico>_<segredo>`.**

- **prefixo fixo `tb_api_`** — FR-001. Serve para varredura de segredo vazado
  (GitHub secret scanning, varredura de log), **não** para triagem de validade:
  prefixo certo com resto inválido recebe a mesma recusa uniforme;
- **id público** — identificador curto, indexado e único, que é por onde a linha é
  buscada. É o que tira a comparação do Postgres;
- **segredo** — no mínimo 32 bytes de `:crypto.strong_rand_bytes/1` (FR-002),
  codificado em Base64 URL-safe sem padding, para caber num cabeçalho sem escape.

**Alternativa considerada:** parte única, buscando por hash. Recusada por Q1 — a
comparação sairia do nosso controle de tempo.

---

## R6 — os limiares na base de conhecimento

**Decisão: `priv/knowledge_base/rules/api_access_thresholds.yaml`, id
`api.access.thresholds`.** Vem de Q8 e FR-069.

| Limiar | Nome | Valor |
|---|---|---|
| validade máxima | `api.access.token_lifetime` | 90 dias |
| expiração por desuso | `api.access.token_idle_expiry` | 30 dias sem uso |

Nesta fatia o arquivo é criado e **o primeiro é aplicado**; o segundo é declarado e
**não aplicado**, porque aplicar exige o carimbo de uso maduro. A diferença fica
escrita na regra, e não só aqui — limiar declarado e não aplicado é pior que limiar
ausente se ninguém disser qual é qual.

---

## R7 — o que já existe e não se refaz

| Existe | Onde | Como esta fatia usa |
|---|---|---|
| pipeline `:api`, declarada e virgem | `router.ex:44-46` | é a primeira a passar rota por ela |
| `require_admin` da área administrativa | `router.ex:141` | a tela de tokens entra nela, FR-045 |
| precedente de rota fora do LiveView | `lib/the_band_web/controllers/version_controller.ex` | a doutrina dele — *"a forma existe para ser comparada, não para crescer"* — vale igual aqui |
| CSP restritiva `script-src 'self'` | `router.ex:31` | não se afrouxa. Vale para o Swagger da US4, que está fora |
| `Access` como veredito único | `lib/the_band/tenants/access.ex` | chamado na forma em lote, nunca por item |
