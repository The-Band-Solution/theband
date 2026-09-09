# O inventário do H2 — o que cada rota mostra de pessoa nomeada

**Medido em 2026-09-09.** O achado H2 declarou que o levantamento anterior era **piso,
não total**: oito dos 26 LiveViews tinham sido examinados. Este documento fecha o
inventário, porque o próprio H2 diz que *"o inventário é parte da decisão — para que ela
seja tomada sobre o que existe e não sobre a ideia geral"*.

---

## Primeiro, o recorte: só `:autenticado` é superfície do H2

O roteador tem três `live_session`, e **duas já são gateadas por outra coisa**:

| `live_session` | rotas | quem alcança |
|---|---:|---|
| **`:autenticado`** | **20** | **qualquer conta autenticada do tenant** ← a superfície do H2 |
| `:operacao` | 4 | administração **ou** escopo `organization` vigente (FR-023) |
| `:admin` | 3 | administração do tenant |

Isso tira da conta `/accounts` (que mostra **e-mail** de todas as contas),
`/access-scopes` e `/roles` — as três são `:admin`, e o e-mail nunca esteve exposto a
conta comum.

---

## Segundo: seis das onze suspeitas eram FALSO POSITIVO

A primeira medida buscou `login` nas 20 rotas de `:autenticado` e achou onze sem
veredito. **Seis mostram o `login` da organização no GitHub**, e não de pessoa:

`teams_live/index.ex` · `projects_live/index.ex` · `work_item_live/index.ex` ·
`verification_live/index.ex` · `repository_live/show.ex` · `organization_live/index.ex`

Em `organization_live/index.ex` as onze aparições são **comentários** sobre a cadeia
`connected_tools.organization_login → organizations.login`.

> **Um inventário com falso positivo manda a decisão para o lado errado**, e este teria
> mandado: onze rotas "vazando pessoa" contra cinco é a diferença entre *"a plataforma
> está aberta"* e *"cinco telas precisam de decisão"*.

---

## O inventário real: cinco rotas, e TRÊS naturezas diferentes

A decisão que o H2 pede não é uma — é uma por natureza.

### (a) Agregado por pessoa nomeada — **decidido, e consertado**

| rota | o que mostra |
|---|---|
| `/work/verifications/people` | ranking de quem integrou com a verificação **vermelha**, por login |
| `/process` | tabela de pessoas com **contagem de eventos** e atividade mês a mês, ordenada por total decrescente |

É leitura de **desempenho**, e a decisão da pessoa mantenedora de 2026-09-09 já a
cobre — *"quem tem o escopo de team, organization e admin podem ver; e a pessoa vê o
seu"*. As duas passaram a **filtrar pelo alcance**, e há teste de paridade que enumera
as rotas desta lista e exige que todas respondam igual.

### (b) Atribuição no item — **decidido em 2026-09-09: NÃO segue o veredito**

| rota | o que mostra |
|---|---|
| `/work/issues/:id` | o **autor** da issue |
| `/work/changes/:id` | o **autor** e os **revisores** da solicitação |
| `/work/files` | quem **tocou** o arquivo |

**Não é ranking**: é a proveniência do próprio item. E é aqui que a decisão fica difícil,
porque **esconder o autor torna o item ilegível** — uma issue sem quem a abriu não se
lê, e uma solicitação sem revisor não se avalia.

**Decisão da pessoa mantenedora, 2026-09-09: fica visível.** Escrita como
[FR-024 da spec 045](../../specs/045-autenticacao-e-acesso/spec.md).

A autoria é parte do trabalho, e não uma medida sobre a pessoa — issue sem quem a abriu
não se lê, e solicitação sem revisor não se avalia. Quem alcança o item já vê o trabalho.

**O risco de agregação fica aceito e declarado**, não mitigado: com acesso a muitos
itens, alguém reconstrói por acumulação o agregado que o veredito recusa direto. Esconder
a atribuição não o fecha — quem quer acumular acumula devagar. O caminho é o **H4**
(registro de acesso) e limite de taxa, e enquanto o H4 não existir **não se sabe se algo
já aconteceu**.

### (c) O diretório de pessoas — **decidido em 2026-09-09: NÃO segue o veredito**

| rota | o que mostra |
|---|---|
| `/people` | **nome e `@login` de todas as pessoas do tenant** |

**Decisão da pessoa mantenedora, 2026-09-09: fica visível.** Um tenant é uma
organização, e quem está dentro saber quem mais está é o que uma lista de ramais faz. O
diretório afirma que a pessoa **existe**; as medidas sobre ela seguem o veredito.

---

## O que fecha o H2, e o que já foi feito

| item | estado |
|---|---|
| 1. decisão registrada da pessoa mantenedora, como **FR nova numerada** | **feito** — [FR-024 da spec 045](../../specs/045-autenticacao-e-acesso/spec.md), as três naturezas decididas |
| 2. o inventário, para a decisão ser tomada sobre o que existe | **este documento** |
| 3. teste de paridade que impede a próxima tela de herdar a omissão | **feito** — `h2_paridade_das_rotas_test.exs` |

O item 3 é o que muda o futuro: o H2 **não foi uma tela esquecida**, foi um regime
herdado por omissão — a spec 023 registra que *"toda pessoa autenticada vê qualquer
outra"* vigorava **por omissão**, e cada seção nova o herdou. Consertar as rotas de hoje
não impede a de amanhã; o teste que **enumera** impede.

---

## Como o inventário foi medido, para poder ser repetido

```bash
# 1. as rotas de cada live_session
grep -n "live_session\|live \"" lib/the_band_web/router.ex

# 2. quais mostram `login` e quais consultam veredito
#    (`pode_ver`, `pode_ver_equipe`, `pessoas_alcancadas`)

# 3. e o passo que evita o falso positivo — LER as ocorrências:
grep -n "login" lib/the_band_web/live/<tela>.ex
```

**O passo 3 é o que separou cinco de onze.** Contar ocorrências é medida; ler o que elas
são é o inventário.

## Referências

- `docs/seguranca/2026-09-09-o-que-consertar-agora.md` — o achado H2 e o cenário do QA;
- `specs/023-painel-da-pessoa/spec.md` — a FR-012 e o regime que vigorava por omissão;
- `specs/045-autenticacao-e-acesso/spec.md` — a FR-022, emendada em 2026-09-09, e a
  FR-023 que continua de pé;
- `test/the_band_web/live/h2_paridade_das_rotas_test.exs` — a lista declarada e a cobrança.
