# Implementation Plan: segredo em repouso

**Branch**: `064-plan-segredo-em-repouso` · **Spec**: [spec.md](spec.md) · **Data**: 2026-09-13

**Research**: [research.md](research.md) · **Modelo**: [data-model.md](data-model.md) · **Validação**: [quickstart.md](quickstart.md)

---

## Summary

A spec pediu que nenhum segredo fique em claro no banco. Parte já foi entregue no **PR #864** e
não se replaneja: `TheBand.Segredo` (FR-006 no caminho do GitHub) e a redação de
`oban_jobs` #697.

Este plano cobre o que sobrou, e a decisão central é a **FR-004**. Ela mudou depois de eu ler o
código: o `session_token` **não é credencial ao portador sozinho**, como a spec afirmava — é
metade de uma credencial de duas partes, e a outra metade é o `SECRET_KEY_BASE`, que não está
no banco. A correção está em [R1](research.md#r1--o-que-o-session_token-é-de-fato), rebaixa a
severidade e **não** dispensa a correção.

O desenho: separar o que hoje é **um campo com dois trabalhos** em **dois campos com um
trabalho cada** — token por sessão (resumido no banco) e época de senha (não secreta).

## Technical Context

| | |
|---|---|
| **Linguagem** | Elixir ~> 1.17 · Phoenix 1.8.9 · LiveView |
| **Persistência** | PostgreSQL 16, multitenant — toda consulta recebe `%Tenant{}` (princípio V) |
| **Resumo** | `:crypto.hash(:sha256, ...)`, comparação por `Plug.Crypto.secure_compare/2` |
| **Executor de tarefas** | Oban 2.23.1 — `oban_jobs` é tabela **da dependência** |
| **O que verifica** | `mix gates` — 16 gates, e o veredito é o código de saída |
| **Escala** | 3 usuários, 2 com sessão. Um `pg_dump` de 220 MB leva ~40 s; a restauração, ~2 min |

**Nenhum NEEDS CLARIFICATION.** As três perguntas que a spec deixou abertas foram respondidas
por leitura de código, não por suposição: o que o token é (R1), o que a migração faz com as
sessões vivas (R3), e de onde vieram os registros sem data (R6 — **incógnita declarada**, e a
mitigação não depende de resolvê-la).

## Constitution Check

| princípio | como este plano o satisfaz |
|---|---|
| **V — multitenant** | as sessões pertencem a um usuário, que pertence a um tenant; a consulta de sessão parte do usuário já resolvido, e nenhuma consulta nova cruza tenants |
| **VIII — desenho que o problema justifica** | ver o registro abaixo, um a um |
| **X — responsabilidade única** | é o coração do plano: o campo de hoje faz **duas** coisas, e a separação é a correção, não um efeito colateral dela |
| **XI — estado conferido antes, sinal nunca silenciado** | a varredura **falha** se o controle positivo não achar o valor plantado; um verificador **falha** se houver registro terminado sem data |

### Registro das decisões de desenho (princípio VIII)

**1. Tabela de sessões, uma linha por sessão**

- *Que problema resolve*: o token de hoje é por **usuário** e estável entre dispositivos, o
  que impede resumi-lo — um login novo precisa do valor bruto, e o banco teria só o resumo.
- *Existe agora?* **Sim, medido**: [auth.ex:190-192](../../lib/the_band/tenants/auth.ex#L190-L192)
  diz por escrito que o token não gira no login, e a coluna está em claro num dump.
- *O que piora*: uma tabela a mais, uma consulta a mais por requisição, e um caminho de
  limpeza que não existia (sessão expirada não sai sozinha). Passa a existir estado que
  cresce.

**2. Época de senha como coluna separada, não secreta**

- *Que problema resolve*: invalidar todas as sessões na troca de senha, que hoje é o
  **segundo** trabalho do mesmo campo.
- *Existe agora?* **Sim** — é comportamento em produção, e some se a separação não o preservar.
- *O que piora*: mais uma coluna e mais uma comparação por requisição. E uma armadilha: alguém
  pode achar que ela é segredo e tentar protegê-la. O nome e o comentário precisam dizer que
  **não é**, e por quê.

**3. `mix the_band.varre_segredos` com controle positivo embutido**

- *Que problema resolve*: a FR-010 exige varredura repetível antes de cada cópia nova; o script
  solto de 2026-09-12 não sobrevive a três meses.
- *Existe agora?* **Sim** — a decisão de mandar o backup para um segundo host é de 2026-09-12,
  e cada destino novo pede a varredura de novo.
- *O que piora*: mais uma tarefa para manter, e a lista de padrões passa a ser algo que se
  esquece de atualizar. Mitigado pela FR-014, que exige declarar o tipo antes de a coluna
  existir.

**4. Verificador de registro terminado sem data**

- *Que problema resolve*: quatro registros permanentes, **medidos**, que a poda nunca alcança.
- *Existe agora?* **Sim, e um deles carregava o segredo.**
- *O que piora*: mais um gate, e um gate que falha por dado e não por código — o tipo que
  incomoda quem só quer mergear. É o ponto: sem ele, a correção é um `UPDATE` que ninguém
  repete.

**Nenhum padrão novo.** `TheBand.Segredo` já existe e vem do PR #864; aplicá-lo ao caminho do
provedor de modelos é usá-lo **dentro do problema que o motivou**, e a §7.7 do `AGENTS.md`
dispensa rejustificar.

## Project Structure

### Documentation (this feature)

```
specs/064-segredo-em-repouso/
├── spec.md                  ← 15 FR, 8 SC (mergeado no #864)
├── plan.md                  ← este documento
├── research.md              ← R1..R7, as decisões e o que foi descartado
├── data-model.md            ← a sessão, a época, e a migração sem queda
├── quickstart.md            ← como provar que funciona, inclusive o que deve FALHAR
├── contracts/
│   └── varre-segredos.md    ← o contrato da tarefa Mix
└── checklists/requirements.md
```

### Source Code

```
lib/the_band/
├── segredo.ex                        ← JÁ EXISTE (#864), sem mudança
├── tenants/
│   ├── user.ex                       ← sai `session_token`, entra `password_epoch`
│   ├── user_session.ex               ← NOVO: a sessão, com o resumo
│   ├── auth.ex                       ← abre sessão em vez de garantir token
│   └── sessions.ex                   ← NOVO: abrir, conferir, encerrar, girar todas
├── integrations/llm/http/req.ex      ← aplica `TheBand.Segredo` (linhas 41 e 93)
└── mix/tasks/the_band.varre_segredos.ex   ← NOVO

lib/the_band_web/
├── plugs/current_scope.ex            ← confere resumo + época
├── live/hooks.ex                     ← idem
└── controllers/session_controller.ex ← põe o BRUTO no cookie, guarda o resumo

priv/repo/migrations/
├── *_cria_user_sessions.exs          ← tabela + migração SEM queda de sessão
└── *_preenche_datas_de_encerramento.exs

docs/producao/runbook.md              ← FR-013 e o procedimento "girar todas as sessões"
```

## Ordem de execução, e por que ela é esta

A ordem **não** é por tamanho nem por dependência técnica. É por **irreversibilidade**.

| # | o quê | FR | por que nesta posição |
|---|---|---|---|
| **1** | `mix the_band.varre_segredos`, com controle positivo | 008, 009, 010 | **É o único item que o tempo torna impossível de cumprir depois.** O que passa para uma cópia não se desfaz, e a decisão de mandar o backup para um segundo host já foi tomada. Tudo o mais pode ser feito com a plataforma no ar |
| **2** | `TheBand.Segredo` no caminho do provedor de modelos | 006 | barato, sem migração, e fecha a **mesma** classe de defeito já medida no outro caminho |
| **3** | datas de encerramento: preencher + verificador | 015 | remove a via pela qual um registro com segredo se torna permanente |
| **4** | sessão por token resumido + época de senha | 004 | o maior, e o único com migração de dado em uso. Vem por último porque os três acima reduzem risco **enquanto** ele é construído |
| **5** | runbook: FR-013 e o giro de todas as sessões | 013 | depende do desenho do item 4 estar fechado |

## Complexity Tracking

| o que se acrescenta | custo assumido | por que se aceita |
|---|---|---|
| tabela `user_sessions` | uma consulta a mais por requisição; estado que cresce e precisa de limpeza | é o que permite resumir o token sem derrubar login em dispositivo novo — sem ela, a FR-004 só se cumpre quebrando a FR-002 |
| coluna `password_epoch` | mais uma comparação por requisição | preserva a invalidação em massa que hoje é efeito colateral do giro do token |
| tarefa Mix da varredura | mais uma tarefa; a lista de padrões pode envelhecer | a FR-010 pede ato repetível, e ato repetível precisa de nome |
| verificador nos gates | um gate que falha por **dado**, não por código | sem ele a correção da FR-015 não se repete |

**O que foi recusado por não ter problema que o justifique**: um comportamento (behaviour) para
"armazenamento de sessão" com uma implementação só; uma abstração de "tipo de segredo" sobre os
três que existem; e trocar a regra de poda do Oban, que é tabela de dependência.

## O que este plano NÃO resolve

- **A rotação do token do GitHub** — adiada pela pessoa mantenedora para 2026-10-12. Ato
  operacional, não código.
- **A varredura da produção** — a tarefa do item 1 a torna possível; **rodá-la** é ato de quem
  opera, e a FR-010 exige que aconteça antes da primeira cópia para o destino novo.
- **O caminho até o MinIO** — `pg_dump → varredura → restauração` foi exercitado em
  2026-09-12; `→ destino remoto →` não.
- **De onde vieram os quatro registros cancelados sem data** — incógnita declarada em R6. A
  mitigação não depende da resposta, e a resposta não é pré-requisito de nada aqui.
