# Retomar

**Última sessão**: 2026-08-26, noite/madrugada.

A sessão inteira foi sobre **uma decisão aplicada quatro vezes**: a organização declara, e
a plataforma não escolhe pelo nome. Quatro issues, quatro mecanismos, a mesma forma.

---

## Conferir primeiro

| PR | issue | estado quando parei |
|---|---|---|
| [#523](https://github.com/The-Band-Solution/theband/pull/523) | #514 | **mergeado** ✅ |
| [#524](https://github.com/The-Band-Solution/theband/pull/524) | #368 | **aberto**, `quality-gates` verde, `cobertura` ainda rodando |

**Confere se a #524 mergeou.** Se reprovou, o motivo está nos checks.

A branch `feat/369-quem-ve-o-painel-de-quem` está **commitada e enviada** (`9c38af0`,
13/13 gates), mas **sem PR** — ela está empilhada sobre `feat/368-de-onde-vem-o-prazo`, e
`Closes` em PR empilhado não fecha issue nenhuma. Rebasear na `main` depois que a #524
mergear, e só então abrir o PR.

---

## O que ficou pronto

### #514 — o trimestre deixa de ser lido como sprint ✅ fechada

`sro_sprints` promovia **todo** campo de iteração a `sro.sprint`. Medido: `Quarter` tem 27
iterações de 61 a 92 dias contra `Sprint` com 171 de 3 a 26. **669 dos 2.685 vínculos de
issue — 25% — eram trimestre lido como sprint.**

A organização declara o papel do par (quadro, campo). Resolve **na leitura, nunca
materializa**: as 27 iterações já coletadas mudam de leitura no instante da declaração,
sem recoleta e sem migração.

### #368 — de onde vem o prazo (PR #524)

O GitHub **não tem campo de prazo na issue**. 33 pares (quadro, campo) de data, 13 nomes,
duas línguas. Decisão tua: além do campo do quadro, o prazo pode vir do **sprint** ou do
**marco** — e *"se uma task está dentro do sprint, o prazo dela é do sprint E do
milestone"*.

**As três origens se somam.** A resolução devolve **lista com proveniência**, nunca um
valor. Medido sobre 5.216 issues: 304 têm marco e caixa ao mesmo tempo, 640 estão em mais
de uma caixa, 2.251 (43%) não alcançam origem alguma.

A #514 aparece dentro dela — verificado no quadro DevOps, 400 issues:

```
SEM papel declarado ..... %{sprint: 546}
COM Quarter = horizonte .. %{planning_horizon: 175, sprint: 371}
```

**175 de 546 — 32% — eram trimestre lido como sprint.**

⚠️ **A próxima sincronização repagina as issues uma vez por repositório.** É intencional:
`milestone { dueOn }` passou a ser coletado, e sem reabrir o corte as 5.216 issues ficariam
com `milestone_due_on` nulo para sempre — o corte pula o repositório *inteiro* quando não
houve push novo, e "sem push" é o estado normal da maioria. O teste de impressão digital da
#452 pegou isso e obrigou a decidir.

### #367 — a evidência para escolher o quadro (no PR #524, não fecha a issue)

O picker de quadro agora mostra volume, abertas e período:

```
#43 Conecta Fapes                938 itens · 785 abertas · Dec/2025 a Aug/2026
#19 Conecta Fapes - Delivery     730 itens · 565 abertas · Jun/2025 a Jun/2026
#7  [DEPRECATED] ConectaFapes    196 itens ·  49 abertas · Feb/2025 a Jul/2025
```

**Tu já vinculou 4 quadros ao projeto "Conecta Fapes 042".** O `#7 [DEPRECATED]` — que
carrega o período **mais antigo** — segue fora. Agora a tela te mostra o que ele carrega, e
o vínculo é gesto teu.

### #506 — as duas decisões viraram declaração (no PR #524, não fecha a issue)

`flow.wip.count` → `period: weekly`.

`rework.not_accepted_deliverable_ratio` ganhou **`proxies`**, campo novo no schema de
medida, com as origens que tu nomeou:

| aproximação | medido |
|---|---:|
| PR fechado sem integrar | 668 |
| verificação que quebrou | 2.987 de 15.671 (19%) |
| PR integrado com check quebrado | 261 |

Cada uma é **obrigada** a declarar o que NÃO diz. E a limitação que o denominador exige:
**2.024 das integradas (41%) não têm estado de verificação registrado.**

---

## Onde parei: #369 — quem vê o painel de quem

**Branch `feat/369-quem-ve-o-painel-de-quem` enviada, 13/13 gates, sem PR ainda.**

Tua decisão: **a própria pessoa, o líder da equipe dela, e o responsável da organização.**
E depois: os papéis de liderança são `Tech Leader` e `Team Leader`.

### O bloqueio que a issue não previa

Ao implementar, medi: **`eo_people` tem 88 pessoas e NENHUMA com e-mail** — o GitHub não
entrega, por privacidade —, e `users` não tinha coluna alguma que apontasse para pessoa
observada. **Nem "cada pessoa vê a si" nem "o líder vê o time" eram computáveis.**

Tua decisão: **usar o id do GitHub.** E o número mostra por quê — medido sobre as 88:

| campo | preenchido |
|---|---:|
| `external_id` (o id do GitHub) | **88** |
| `login` | **88** |
| `email` | **0** |

Com e-mail, os **dois** lados do elo teriam que ser digitados. Com o id, o lado observado já
vem pronto — e na tela a escolha virou uma **lista de contas**, não um `U_kgDOABFnGA` para
transcrever.

### O que está feito nessa branch (commit `9c38af0`, 13/13 gates)

- migração `20260827050000_qual_pessoa_observada_e_a_conta.exs` — `users.person_id` aponta
  para `eo_people`, com autor, data e revogação; índice parcial único entre os vigentes
- `Tenants.declare_person/4`, `revoke_person/3`, `user_for_person/2`, `person_of_user/1`,
  `elo_coverage/1`; `User.elo_vigente?/1`
- seção na tela da pessoa com **lista de contas para escolher**, e **só admin declara**
- 11 testes de lógica + 7 de tela, **10 injeções, 10 pegas**
- spec: FR-012c a FR-012g

Dois defeitos meus que as injeções revelaram na primeira versão (a do e-mail), e que a
versão por id já nasceu sem:

1. **revogar zerava o identificador** — perdia *quem* a conta era, sobrava só *desde
   quando*. O índice parcial já exclui a linha revogada; zerar era desnecessário.
2. **struct velha entre revogar e declarar** — `update_all` não atualiza a struct em
   memória, e um campo cujo valor novo é igual ao da struct velha **não entra nas mudanças**
   do changeset. `person_declared_by_user_id` ficaria nulo com `person_id` preenchido,
   violando a CHECK. Resolvido recarregando entre as duas.

### O que FALTA na #369

1. **Rebasear na `main`** depois que a #524 mergear, e abrir o PR
2. **A concessão de visibilidade**: tabela `eo_role_visibility_grants` ligando papel a
   escopo (`team` / `organization`), revogável, com autor — relator e nunca booleano, pelo
   motivo de sempre: um `is_leader` perde quem concedeu e quando, e numa decisão de
   visibilidade essa é a pergunta que mais se faz depois
3. **Criar os papéis** `Tech Leader` e `Team Leader` na tela `/roles` e marcá-los escopo
   `team` — hoje só existem **2 papéis, ambos `Developer Role`**
4. **A regra de visibilidade em si** na rota `/people/:id` — hoje é `require_user` + tenant,
   ou seja, toda pessoa autenticada vê qualquer outra
5. **Quem é o responsável da organização** — tu não nomeou o papel; escopo `organization`
   fica sem ninguém até nomear

**A plataforma não deve casar `"Tech Leader"` por string.** Papel é renomeável, e conceder
visibilidade por padrão de nome erra para o lado que ninguém reclama — o excesso concedido.
A concessão é ato declarado, com autor. Está escrito como FR-012a na spec.

---

## Decisões tuas que continuam esperando

| issue | o que falta |
|---|---|
| **#506** | **as perguntas do painel da equipe**, com *quem decide o quê* em cada uma. É o que impede o painel; duas das cinco medidas já calculam |
| **#367** | vincular (ou não) o `[DEPRECATED] ConectaFapes`; coletar a timeline do `conectafapes-project`; e quais colunas de cada quadro significam "concluído" |
| **#442** | quatro escolhas técnicas do conector ArgoCD — qual API, como a ferramenta entra em `connected_tools`, onde o ambiente encontra o repositório, e se `drift` vira conceito |
| **#397, #363, #356** | sem trabalho iniciado |
| **#504, #507** | bloqueadas pela #506 |

---

## Achados que valem lembrar

**A #367 tem premissa vencida.** Ela diz que a plataforma não lê campo de quadro. **Lê** —
a #181 entregou. Medi 3.601 itens com coluna e issue por trás: **409 marcados concluídos na
coluna seguem abertos**, 87 fechados nunca saíram de coluna de início — 496 em 2.945
comparáveis, **16,8%**. A issue estimava 11% sobre 25 itens.

⚠️ **Ressalva**: classifiquei "coluna de início" **pelo nome**, que é exatamente o erro que
estas quatro features existem para não cometer. Há 33 nomes de coluna em duas línguas. É
primeira medida, **não resposta** — quais colunas significam concluído é declaração que
ainda não foi feita.

**Defesa em profundidade que parece redundância.** Os dois filtros de tenant da resolução de
prazo se cobrem: remover um sozinho não quebra teste nenhum, remover os dois quebra. Está
registrado no moduledoc do teste para ninguém "simplificar" um deles.

**Duas injeções passaram na primeira tentativa nesta sessão, e nenhuma era defeito ausente
no código** — as duas eram cenário fino demais no teste. O padrão: um campo declarado
*em branco* passa por qualquer defeito de join, porque não há linha para o join achar. O
caso que prova é o campo declarado **explicitamente com o outro valor**.

---

## Comandos

```bash
mix gates > /tmp/gates.log 2>&1; echo "CODIGO_DE_SAIDA_DO_GATE=$?" >> /tmp/gates.log
grep CODIGO_DE_SAIDA_DO_GATE /tmp/gates.log     # o veredito é o número, lido num comando separado

set -a; . ./.env; set +a                        # a chave mestra vem do .env
MIX_ENV=dev mix run script.exs                  # medir contra o banco de desenvolvimento
```
