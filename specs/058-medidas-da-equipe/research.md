# Research — Feature 058

A pergunta que a spec deixou aberta tem resposta, e ela **muda o plano**: não há
um caminho, há **dois**, e eles afirmam coisas diferentes.

---

## R1 — O caminho da verificação até a equipe: existem dois *(resolve a US3)*

A spec previa que a entrega da US3 pudesse ser **a recusa declarada**. Não é: os
dois caminhos existem no esquema, e o problema deixa de ser *"dá para calcular?"*
para ser *"qual pergunta se está respondendo?"*.

### Caminho A — por quem disparou

```text
collected_verifications.actor_person_id → eo_team_memberships → equipe
```

`actor_person_id` existe e é preenchido na ingestão, do login do ator do
workflow casado contra as pessoas conhecidas.

**O que a taxa afirmaria**: *as verificações **disparadas por** quem pertencia a
esta equipe*.

**Por que isso não é a saúde do pipeline da equipe**: o ator de uma execução é
**quem a disparou**, não quem escreveu o código. Execução agendada tem por ator
quem configurou o agendamento, ou um robô; execução de `push` tem quem empurrou;
de `pull_request`, quem abriu. Uma equipe cujo CI roda por agendamento
apareceria quase vazia, e uma pessoa que empurra muito carregaria a taxa da
equipe inteira.

### Caminho B — por onde o código mora

```text
collected_verifications.observed_repository_id
  → spo_project_repositories  (linked_at, unlinked_at)
  → spo_project_teams         (linked_at, unlinked_at)
  → equipe
```

`spo_project_repositories` existe, com **as mesmas colunas de período** de
`spo_project_teams`.

**O que a taxa afirmaria**: *as verificações dos repositórios dos projetos em que
esta equipe trabalhava*.

**É a pergunta que quem gerencia faz.** E, mais importante, é a mesma estrutura
de interseção de períodos que a **US2 já constrói** — o caminho B não acrescenta
mecanismo, reusa o da história anterior.

### Decisão

**Caminho B**, e o A **não entra** — nem como alternativa, nem como
complemento.

**Razão**: dois números com o mesmo rótulo e denominadores diferentes é
exatamente o defeito que a L67 registra (*duas medidas do mesmo nome: comparar os
totais esconde que são fenômenos diferentes*). Oferecer os dois obrigaria quem lê
a saber qual está olhando, e a tela não tem como garantir isso.

**O que piora**: equipe **sem projeto declarado** fica sem a taxa, mesmo tendo CI
rodando. Isso é ausência nomeada e correta — a plataforma não sabe de quais
repositórios aquela equipe cuida, e inventar o elo pelo ator seria adivinhar.

**Alternativas descartadas**:

- *Caminho A* — responde outra pergunta, e o nome enganaria;
- *A união dos dois* — inflaria o denominador com execuções contadas duas vezes;
- *A recusa* — que a spec admitia, e que a pesquisa tornou desnecessária.

**Efeito na spec**: `FR-013` continua valendo com o ramo do "existe"; o ramo da
recusa passa a valer **por equipe sem projeto**, e não pela medida inteira.

---

## R2a — Correção: `linked_at` é NOT NULL, e eu afirmei o contrário

**Conferido em 2026-09-02**, depois de o teste falhar com
`null value in column "linked_at" violates not-null constraint`.

R2 e a spec diziam que `spo_project_teams.linked_at` era anulável. **É `null:
false`** — e `spo_project_repositories.linked_at` também. Afirmei sobre o esquema
sem conferir a migração, que é a **L51**.

| coluna | anulável? |
|---|---|
| `eo_team_memberships.started_at` | **sim** |
| `eo_team_memberships.ended_at` | sim |
| `spo_project_teams.linked_at` | **não** |
| `spo_project_teams.unlinked_at` | sim |
| `spo_project_repositories.linked_at` | **não** |
| `spo_project_repositories.unlinked_at` | sim |

**O que muda, e o que não muda.**

O terceiro estado `{:parcial, _}` **continua necessário** — `started_at` do
vínculo de pessoa é anulável de propósito, e é o caso que a feature 057 já
tratou. O que muda é a **origem** da dúvida: ela vem de quem entrou na equipe sem
data conhecida, e **nunca** do vínculo com projeto ou repositório.

**`fim` nulo não é dúvida**: `unlinked_at` nulo significa **vigente**, e não
desconhecido. Foi aqui que a redação original errou por generalizar — tratar
todo nulo como desconhecido inverteria o significado do fim.

`TheBand.Periodos` não muda: ele recebe períodos e não sabe de onde vêm. Quem
monta o período é que precisa distinguir *fim aberto* de *início desconhecido*.

---

## R2 — A interseção de três períodos, e o que fazer com o nulo

A US2 pede a interseção de **pessoa ↔ equipe**, **equipe ↔ projeto** e a janela
perguntada. Com o caminho B, a US3 acrescenta **projeto ↔ repositório** — quatro
períodos, mesma regra.

**Decisão**: uma única função de interseção, com a borda `[início, fim)` da
feature 057, e **três estados** em vez de dois:

| estado | quando |
|---|---|
| `:intersecta` | os períodos se sobrepõem, e todas as bordas são conhecidas |
| `:nao_intersecta` | não se sobrepõem |
| `{:parcial, quais}` | há sobreposição, e ao menos uma borda é **desconhecida** |

**Por que o terceiro estado**: `linked_at` e `started_at` são anuláveis. Tratar
nulo como "aberto desde sempre" é o **mesmo fallback silencioso** que a feature
057 corrigiu no vínculo — e repeti-lo aqui, com a lição escrita, seria
reincidência.

**O que piora**: quem consome precisa tratar três casos, e não dois. É o custo de
não mentir sobre o que se sabe.

---

## R3 — O recorte da primeira revisão é pela ABERTURA, não pela revisão

`TheBand.Quality.time_to_first_review/2` devolve as últimas 50 solicitações do
tenant, sem recorte.

**Decisão**: a solicitação conta para a equipe quando quem a **abriu** pertencia a
ela **na data de abertura**.

**A alternativa considerada** — recortar pela data da *revisão* — foi descartada:
mediria a equipe de quem revisa, e a medida se chama *tempo até a primeira
revisão*, que é uma espera **de quem abriu**.

**O que piora**: solicitação aberta por quem nunca teve vínculo declarado não
conta para equipe nenhuma. Vai para a contagem do que ficou de fora, nomeada — e
não some.

---

## R4 — Robô não encerra a contagem, e isso já está resolvido

`TheBand.Quality` já filtra `author_type == @humano` nas avaliações.

**Decisão**: consumir, não redefinir. A tela declara que a revisão de robô é
descartada — o que **muda** é que hoje ninguém vê essa declaração, porque a
medida não chega à tela da equipe.

---

## R5 — Espera em curso não é tempo zero

Solicitação ainda sem revisão humana tem `first_review_at` nulo.

**Decisão**: relator próprio — `{:aguardando, ha_dias}` —, e **nunca** ausência da
lista nem tempo zero.

**Por que isso importa mais aqui do que parece**: as solicitações que mais
interessam são justamente as que ninguém revisou. Omiti-las faria a mediana
melhorar quanto **pior** a equipe estivesse — a medida andaria para o lado errado
sem ninguém notar.

**O que piora**: a mediana passa a ter duas populações, e a tela precisa
apresentar as duas. É o preço de a medida não mentir.

---

## R6 — O que NÃO consegui medir, e por quê

**Não sei quantas verificações têm `actor_person_id` preenchido, nem quantos
vínculos equipe ↔ projeto existem com dado real.**

Tentei medir contra o banco de desenvolvimento e a aplicação não sobe:
`:missing_master_key`. A chave mestra não está neste ambiente, e obtê-la não é
passo de pesquisa.

**Consequência para o plano**: a decisão de R1 é sobre **semântica**, não sobre
volume — o caminho B é o certo mesmo que o A tivesse mais linhas preenchidas. Mas
o **tamanho da amostra** é desconhecido, e por isso:

- a tela **não** apresenta a taxa sem dizer sobre quantas execuções ela é;
- o `quickstart.md` mede as três coberturas **antes** de aceitar a feature, e a
  aceitação inclui esse número.

**Isto é limitação declarada, e não pendência.** A L30 diz para conferir contra a
origem; aqui a origem está inacessível, e dizer isso é melhor do que estimar.

---

## R7 — Onde estas medidas moram

`Quality` já existe e é o lugar do tempo de revisão. `SPO` é o lugar dos
vínculos com projeto. `Verification` é o lugar das verificações.

**Decisão**: **nenhum módulo novo.** Cada medida ganha função na fachada que já
possui o conceito, e a interseção de períodos — a única coisa que atravessa três
módulos — vira função **pura** em `TheBand.Periodos`, sem consulta.

**Por que uma função pura e não um módulo de consulta**: a interseção é
aritmética sobre datas. Consultar é de quem tem o conceito; intersectar não
pertence a ontologia nenhuma, e pô-la dentro de uma delas obrigaria as outras a
alcançá-la.

**O que piora**: mais um módulo na raiz de `lib/the_band/`. Aceito — é pequeno,
puro, e a alternativa é a mesma regra escrita três vezes.
