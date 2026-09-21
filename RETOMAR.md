# Retomar — estado em 2026-09-18, a API com token pela metade e a release bloqueada por um comando

**Este é o único documento de estado.** `docs/sprints/RETOMAR.md` aponta para cá (AGENTS.md §5).

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

---

## Onde parei, em uma frase

**A API pública está em 12 de 24 tarefas** — o token existe, é gerável na tela e revogável,
mas **nenhuma rota responde ainda**. Dois branches estão empurrados **sem PR aberto**. E a
release da v0.8.0 está preparada há quatro dias, bloqueada por **um comando** que só a pessoa
mantenedora pode dar.

## O primeiro comando

```bash
git fetch origin --prune && git status --short     # 1. NADA fora de commit — antes de tudo
git checkout development && git pull
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"    # o veredito é o CÓDIGO DE SAÍDA, colado
```

`mix gates` deu **0** em `061-api-tela` em 2026-09-18, com 16 gates. A suíte inteira é inviável
com o servidor dev de pé — se estiver: `pgrep -fl phx.server`.

> **O servidor local foi reiniciado em 2026-09-18.** O anterior subira em 15/09, antes de
> `api.access.thresholds` existir, e a base de conhecimento só carrega no boot — a tela de
> tokens dava 500 por isso. Se acrescentar regra à base, **reinicie o servidor** ou ela não
> existe para quem está rodando.

---

## ⛔ O bloqueio, e ele é de uma linha

**O secret `PRODUCAO_URL` não existe no repositório.** Só há `DOKPLOY_WEBHOOK_URL` e
`SONAR_TOKEN`.

```bash
gh secret set PRODUCAO_URL --body "https://app.theband.dev"
```

O passo do CD que confirma a versão (`cd.yml:117`) falha explicitamente sem ele — e falha
**depois de o deploy já ter acontecido**, deixando a versão no ar e o pipeline vermelho, sem
distinguir deploy quebrado de verificação impossível.

Conferido em 2026-09-18: `https://app.theband.dev` responde `302` para `/sign-in`, servindo a
aplicação. A rota `/version` devolve **texto puro** (`0.8.0`), que é exatamente o que o CD
compara — a engrenagem está certa, falta só o endereço.

**Esta é a primeira release em que aquele passo pode funcionar**: a rota entrou no #859, depois
da v0.7.0, e por isso produção devolve 404 nela hoje.

---

## O que está no ar

A **v0.7.0** (`dd4272f`, 2026-09-10). São **92 commits** não publicados e **oito dias** de
defasagem — nada desta semana está em produção.

A avaliação e a reavaliação estão em `docs/releases/v0.8.0.md`. A versão **continua 0.8.0,
MINOR**, e a reavaliação de 18/09 cobre os 34 commits que entraram depois da avaliação
original.

> **O agente de Product Owner travou duas vezes**, aos 600 segundos, sem escrever nada —
> 13/09 e 18/09. A skill `/release` prevê isso, e as duas avaliações foram feitas por medição
> direta, com o fato declarado no documento. **Não insista nele sem prever o mesmo.**

### Os três riscos, medidos

| Risco | Veredito |
|---|---|
| seis migrações novas | **nenhuma destrutiva ao subir** — todo `drop`/`remove`/`modify` está no bloco `down` |
| oito variáveis novas | **nenhuma obrigatória** — o `compose.yaml` não exige nenhuma sem padrão |
| comportamento visível | três: valores nos gráficos, aba da equipe que voltou a abrir, quatro declarações no quadro |

**E um risco novo**: a fase `issues` da coleta foi à **versão 5**, o que reabre o corte
incremental em **todos** os repositórios na primeira coleta depois do deploy. É intencional —
torna retroativo o conserto do identificador do evento e do quadro —, mas custa cota: a
recoleta completa de 33 repositórios custou **858 pontos**. Quem acompanhar em `/syncs` precisa
saber antes de achar que travou.

**Não medido**: o volume de produção. O documento não promete tempo de migração.

---

## O que fazer, em ordem

### 1. Abrir os dois PRs que ficaram sem PR

Empurrados em 2026-09-18, verdes, **sem PR**:

| branch | commits | o que traz |
|---|---|---|
| `061-api-fundacao` | 1 | a regra na base, a ADR 0010, a tabela, o schema, o formato do token |
| `061-api-tela` | 2 | contém o anterior, mais a tela `/api-tokens` |

**Um PR só resolve os dois** — `061-api-tela` contém `061-api-fundacao`. Base: `development`.

E `fix/divergencias-do-esquema` **já foi mergeado** (#929) — o branch pode ser apagado.

### 2. Terminar a API — faltam 11 tarefas

`specs/061-api-publica/tasks.md`. **T001 está feita e não marcada**: o protótipo existe e foi
aprovado em 18/09.

| Tarefa | O que falta |
|---|---|
| T014 | a autenticação na fronteira **já existe em código** (`ApiTokens.autenticar/1`) — falta marcar e cobrir o caso da conta desativada |
| T015 | o plug da recusa uniforme, em `lib/the_band_web/plugs/api_auth.ex` |
| T016 | o formato único de erro — o contrato está em `contracts/erro.md` |
| T017 | `GET /api/v1/teams` — a pipeline `:api` está declarada e **nunca teve rota** |
| T018 | o serializador com a marca `origin` (`observed` / `declared`) |
| T019 | paginação por cursor, **sem total**, com a nota dizendo por quê |
| T020–T023 | os quatro transversais: teto de consultas, nenhum método de escrita, o valor que não existe, os dois tenants |
| T024 | gates |

**O que já funciona**, conferido em 18/09: gerar token na tela, ver o valor uma vez, a linha
mascarada, o alcance vigente da conta dona antes de criar, e revogar com o rótulo nomeado.
Dezesseis itens da régua do QA conferidos contra o HTML servido; zero ocorrências de token na
página em repouso.

### 3. As três decisões que são da pessoa mantenedora

**A 066 está entregue ou pela metade?** Ela entregou a **declaração** — a tela onde a
organização diz o que cada coluna significa. As medidas **ainda não a consomem**: o gráfico por
mês conta `external_closed_at`, o fechamento da issue na origem, e não a coluna do quadro. As
**três tabelas de declaração estão zeradas** — ninguém declarou nada —, e as **377 entregas** do
quadro 43 continuam fora do gráfico do Harian.

**O Swagger entra agora ou com as oito rotas?** É US4, P2, e o pedido original é literal: *"A
API precisa de ter Swagger"*. Traz a **única dependência nova** da feature (`open_api_spex`), e
a CSP (`script-src 'self'`) obriga a servir o ativo do próprio domínio. Com **uma** rota ele é
quase só esqueleto; com as oito vale muito mais.

**As seis perguntas abertas do protótipo**, em
`specs/061-api-publica/prototipo/README.md`. A mais concreta: **a revogação registra razão?** É
campo novo, e *suspeita de vazamento* é o único caso em que o ato seguinte muda.

---

## O que esta semana descobriu, e que não se deve redescobrir

### A cadeia da timeline truncada — quatro defeitos, um dentro do outro

1. **o GitHub cortava a timeline** dentro de `issues(first: 50)` e **declarava `totalCount`
   igual ao que cortou**, com `hasNextPage: false`. A guarda existente olhava a bandeira errada
   e nunca disparou;
2. **o critério de identidade da atividade não tinha o sujeito**, e colava ocorrências
   distintas — a issue #2539 tinha 12 eventos na origem e 7 no banco;
3. **um comentário afirmava que a timeline não identifica seus eventos.** Medido: é falso, e a
   afirmação já tinha virado fundamento numa emenda de ontologia;
4. **o evento não dizia de que quadro veio**, o que fazia creditar conclusão a quem não a teve
   — 25 dos 46 cartões fora de `Done` no quadro 43 eram crédito falso.

A base inteira foi recolhida: 33 repositórios, veredito `completa` em todos, 858 pontos. As
chegadas a `Done` foram de **1 794 para 3 294**.

### Três coisas no backlog que são decisão, não código

- **`Done` é alegação, não aceite** — cartão sai de `Done` **193 vezes, em 185 issues**, e em
  58% quem devolve é outra pessoa. Das 185, **69 não voltaram**;
- **o evento não diz o quadro** — a origem oferece o campo `project` e a consulta nunca o
  pediu. Conserto barato, recoleta cara;
- **o booleano `active`** em duas tabelas, onde nove guardam data e autor.

### Duas armadilhas que me pegaram, e pegam de novo

**Guarda que lê o próprio código reprova a prosa.** Duas vezes: um teste procurou
`token_hash ==` e achou no `@moduledoc` que explica por que não se faz isso; outro procurou a
palavra `reactivate` e achou na frase que diz que não existe reativar. **Teste o controle, não
a palavra** — e ao ler fonte, tire comentário e documentação antes.

**Medir o que a casa faz antes de escolher.** Escrevi `SET NULL` em três chaves estrangeiras
novas; nas duas de `tenant_id` teria falhado ao apagar um tenant, com violação de nulo, porque
a coluna é `NOT NULL`. **61 das 65 chaves usam `RESTRICT`** — só apareceu porque fui contar.

---

## O que NÃO foi feito, e é honesto dizer

- **as 12 tarefas da API** acima;
- **a v0.8.0 não foi publicada**, e o bloqueio é o secret;
- **a 066 não tem `plan.md` nem `tasks.md`** — foi implementada direto do protótipo aprovado,
  pulando duas etapas do ciclo. Dívida declarada no #928;
- **as três declarações da 066 não têm teste de comando** — só teste de tela, enquanto as seis
  irmãs mais antigas têm os dois. Material para QA;
- **o diâmetro do grafo da rede não foi medido** — é a única medida que reabriria a decisão de
  REST contra GraphQL com rigor;
- **o volume de produção não foi medido**, e por isso nenhum tempo de migração foi prometido.
