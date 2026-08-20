# Verificação contínua — do GitHub para a rede de ontologias

Como uma execução do GitHub Actions vira conceito, e por que o estado da verificação
mora em três lugares diferentes.

Esta página é escrita à mão. As tabelas de mapeamento em
[mappings.md](mappings.md) são geradas da base — aqui está o **porquê** que a tabela não
carrega.

---

## Os dois eixos, e por que separá-los

Um painel de CI responde "passou ou quebrou". Isso não precisa de ontologia. A pergunta
que precisa é **o que** passou ou quebrou — porque teste vermelho tem resposta diferente
de inspeção vermelha: um é código, o outro é convenção.

Por isso a modelagem tem dois eixos independentes, e um terceiro que é de outra API:

| Eixo | Pergunta | Vem de |
|---|---|---|
| **tipo** | que processo esta execução materializa | os **jobs**, derivado |
| **fase** | como esse processo terminou | `status` + `conclusion` da execução |
| **gatilho** | o que a disparou | `event` da execução |

Cruzá-los é o que produz medida. Colapsá-los produz um número que parece confiável e não
é.

---

## Eixo 1 — o tipo é derivado dos jobs, nunca afirmado pela execução

A versão 1 do mapeamento afirmava que toda execução de workflow é uma ocorrência de
processo de integração contínua. **O dado desmentiu.** Das 1.051 execuções coletadas em
2026-08-18, **399 não são nem verificação nem implantação**: `Sync to GitLab`,
`Sprint Rollover`, `Card de promoção`.

A regra que decide está em
[`priv/knowledge_base/rules/github_ci_job_routing.yaml`](../../priv/knowledge_base/rules/github_ci_job_routing.yaml),
com `confidence: low` **declarada**, e a razão da confiança baixa está escrita nela: o
GitHub não declara qual processo componente um job executa, e o nome é convenção de quem
escreveu o workflow.

| nome ou etapa casa | conceito | ontologia |
|---|---|---|
| `build` `compile` `assets` `docker` `image` | `ciro.continuous_build_process` | CIRO |
| `test` `spec` `coverage` `e2e` `pytest` `jest` | `ciro.continuous_test_process` | CIRO |
| `lint` `credo` `sobelow` `dialyzer` `gates` `sast` | `ciro.continuous_inspection_process` | CIRO |
| `deploy` `rollout` `helm` `kubectl` `argocd` | `cdro.deployment_activity` | **CDRO** |
| `release` `publish` `delivery` | `cdro.delivery_activity` | **CDRO** |

Três decisões nessa tabela, e nenhuma é detalhe.

### Devolve todos os que casam, não o primeiro

Job que testa e inspeciona materializa **dois** componentes. Escolher um e descartar os
outros faria a plataforma afirmar que o job só testa quando ele também inspeciona.

Quando mais de um casa, o job é reportado como `ci.ap01.monolithic_job` — e o
agrupamento é fato sobre o **script**, não sobre a execução. Por isso a tela nomeia o
arquivo, não o nome do job: dois repositórios com um job chamado `build` não são a mesma
linha. O antipadrão mais frequente na instalação é o deste próprio projeto —
`.github/workflows/ci.yml`, job `quality-gates`, 352 execuções.

O custo do agrupamento é exatamente a pergunta desta página não ter resposta: a
plataforma não sabe o que quebrou.

### Deploy sai da CIRO

`deploy` não é componente de integração contínua. É CDRO. Manter os dois na mesma
ontologia faria a medida de integração incluir implantação, e implantação tem outro
ciclo, outro responsável e outro risco.

### Sem componente reconhecido, a execução fica sem tipo

A rede não tem conceito para automação de quadro. Forçar `Card de promoção` num conceito
de verificação produziria medida errada; deixá-la **sem tipo** é ausência nomeada, e a
tela nunca escreve as duas situações com a mesma frase.

### Os padrões são estreitos de propósito

`artifact` casava com `Upload Pages artifact` e produziu **238 entregas falsas**.
`package` casava com `Install npm packages`. Os dois foram removidos.

A assimetria é a razão: o padrão não reconhecido alguém corrige — aparece na tela como
lacuna e vira issue. O padrão reconhecido errado **vira medida**, e ninguém procura o
erro num número que já parece resposta.

---

## Eixo 2 — a fase vem de `status` mais `conclusion`

Implementada em
[`classification.ex`](../../lib/the_band/verification/classification.ex).

| GitHub | conceito CIRO |
|---|---|
| `status` em `queued` `in_progress` `waiting` `pending` | em andamento — **sem fase** |
| `conclusion: success` | `ciro.successful_continuous_integration_process` |
| `conclusion: failure` | `ciro.unsuccessful_continuous_integration_process` |
| `conclusion: cancelled` | `ciro.interrupted_continuous_integration_process` |
| `conclusion: skipped` | `ciro.unperformed_continuous_integration_process` |
| `conclusion: timed_out` | `ciro.expired_continuous_integration_process` |

**`cancelled` e `skipped` não são insucesso.** A versão 1 do mapeamento dizia que eram, e
as cinco fases distintas foram o conserto. Uma execução cancelada não diz nada sobre o
código; contá-la como falha faz a taxa de insucesso medir a interrupção humana.

O modelo foi validado em escala, e a escala mudou o que ele mostra: no primeiro
repositório havia 55 falhas e 54 cancelamentos, e `unperformed` era **zero**. Nas 15.375
execuções são 2.633 falhas, 248 cancelamentos — e `unperformed` só existe no volume.

Execução em andamento não recebe fase, e não recebe **sucesso**. Ausência de erro não é
resultado.

---

## Eixo 3 — o estado de quem entrou vem de outra API

`workflow_run` cobre uma camada de verificação. O GitHub tem três:

| camada | API | quem publica |
|---|---|---|
| `workflow_run` | Actions | o próprio Actions, por execução de workflow |
| `check_run` | Checks | o Actions por **job**, e apps de terceiros |
| `status` | Statuses (antiga) | serviço externo |

Coletar só a primeira deixa duas invisíveis. E a pergunta que a máxima `ci.ap03` faz —
*quem integrou código com verificação vermelha* — é sobre a **ponta no momento do merge**,
não sobre uma execução qualquer do ramo.

### Por que o casamento por `head_sha` não serve

O `head_sha` de uma execução é a ponta do ramo **naquele instante**. Isso produz erro nas
duas direções, e a direção que importa não é a que parece.

**Ele deixa passar**: ramo que recebeu mais commits depois tem execuções apontando para
SHAs que já não são a ponta, e o casamento não acha execução para a ponta.

**E ele superconta, que é o pior.** Qualquer execução vermelha em *qualquer* commit do PR
faz o casamento marcar a solicitação como integrada vermelha — inclusive a vermelha que
foi consertada antes do merge, que é o processo funcionando.

### `statusCheckRollup` é campo do commit, e agrega as três camadas

A consulta pede `commits(last: 1)` do pull request — a ponta no merge. É ela que
interessa, porque a máxima `ci.ap03` fala de **integrado** com vermelho, e o que foi
integrado é a ponta.

Medido em 2026-08-20 sobre as **4.878 solicitações integradas, todas medidas** — nenhuma
pendente, o que importa porque a versão anterior desta página comparava com 763 ainda por
medir:

| | vermelhas |
|---|---|
| casamento por `head_sha` | 323 |
| `statusCheckRollup` da ponta | 261 |
| **nos dois** | **115** |
| união | 469 |

A sobreposição de 115 em 469 é o número que diz tudo: **não são duas medidas do mesmo
fenômeno com precisões diferentes — são dois fenômenos.**

Das 208 que só o casamento acha, **198 estão verdes na ponta**. Conferido no `#13`: 33
commits, três execuções vermelhas no meio, ponta verde com 2 contextos. O casamento
chamava isso de integração vermelha.

Outras 10 dessas 208 **não tiveram check nenhum** na ponta. O casamento achava vermelho no
meio e a ponta entrou sem verificação — as duas coisas são verdade, e só a segunda descreve
o que foi integrado.

Das 146 que só o rollup acha, a causa é a camada: `check_run` e `status` não aparecem em
`workflow_run`.

### Duas colunas, porque nulo não é desconhecimento

Declaradas em
[`20260819070000_add_merged_check_state.exs`](../../priv/repo/migrations/20260819070000_add_merged_check_state.exs):

```text
merged_check_state = nil  E  merged_check_contexts = 0    →  nenhum check rodou
merged_check_contexts = nil                              →  não medimos ainda
```

Com uma coluna só, *"não coletamos"* e *"não havia o que coletar"* ficariam com o mesmo
nulo — que é exatamente a confusão que esta casa mais combate.

E a distinção não é acadêmica: **2.024** das 4.878 solicitações integradas entraram sem check
nenhum — 41%. Pelo caminho antigo apareciam como "não dá para saber". São a coisa oposta —
**achado sobre o processo**, não lacuna nossa. A organização apareceria medida onde não é
verificada, que é pior do que não ter o número, porque ninguém procuraria o problema.

Os valores ficam **crus**: `SUCCESS`, `FAILURE`, `PENDING`, `ERROR`, `EXPECTED`. A
tradução para fase da CIRO acontece na leitura, nunca no lugar do que a origem disse.

---

## O que a tela faz com isso

| Tela | O que responde |
|---|---|
| `/work/verifications` | fases, componentes, cobertura pela ponta, jobs monolíticos por arquivo |
| `/work/verifications/:id` | uma execução, seus jobs e os conceitos de cada um |
| `/work/verifications/people` | quem propôs e quem integrou vermelho, por participação |

### Vermelho no ramo de proposta não conta

É o processo **funcionando**: a verificação pegou o problema antes de integrar, que é para
isso que ela existe. Contá-lo produziria a medida ao contrário — quem empurra cedo e usa
o CI como rede acumularia vermelhos, e quem desenvolve local e empurra uma vez apareceria
impecável.

### As duas participações não se somam

Submeter (`cmpo.stakeholder_submitted_change_request`) e integrar
(`cmpo.stakeholder_performed_checkin`) são atos distintos, e a tela obriga a escolher um.
Quem propôs pode ter aberto a solicitação vermelha de propósito, para pedir ajuda. **Quem
integrou decidiu que entrava assim** — e a definição de `cmpo.change_request` já dizia que
o PR "não é o merge, nem a decisão de aprovação".

### Base pequena não recebe taxa

Abaixo de dez solicitações verificáveis a tela mostra a contagem e **não** a porcentagem.
Três de quatro é 75% e não significa nada — e o corte vai **declarado na tela**, porque
corte escondido faz quem lê achar que é propriedade do dado.

---

## Limitações abertas

- **A confiança do tipo é baixa, e permanece baixa.** Depende do nome que alguém deu ao
  job. Não há como elevá-la sem o GitHub declarar o processo — e declarar confiança alta
  onde ela não existe seria pior que a lacuna.
- **CIRO não declara relação** entre `ciro.continuous_integration_process` e
  `cmpo.source_repository`. A execução aponta para o repositório e nada materializa o
  vínculo na rede.
- **`updated_at` aproxima o término**, mas não é o instante exato de fim.
- **Implantação real ainda não é observada.** `cdro.deployment_activity` é derivado do
  nome do job, e o processo de implantação vive no ArgoCD — que não é coletado (issue
  #442).
- **Coautoria não tem atribuição única.** 1.203 de 16.416 commits têm mais de um autor
  pelo trailer `Co-Authored-By`, e a rede declara uma participação para cada.

Números conferidos na instalação de três organizações em 2026-08-19.
