# Plano de implementação: o detalhe da pessoa

**Feature**: `specs/010-detalhe-da-pessoa/` · **Branch**: `014-detalhe-da-pessoa`
**Spec**: [spec.md](spec.md) · **Pesquisa**: [research.md](research.md)
**Constituição**: v1.4.0, dez princípios · **Origem**: issue #211

---

## Summary

Uma página por pessoa, dizendo o que a plataforma sabe: identidade e proveniência, as equipes que a
origem declara, e o trabalho — issues designadas e issues abertas, **separadas**, mais os
repositórios derivados delas.

Medido: **75 pessoas, 88 evidências de equipe, zero vínculos, zero papéis**, 4 232 designações e
4 241 autorias.

## O que este plano decide antes de tudo

**A tela mostra três coisas onde uma tela comum mostraria uma.** O que a origem declarou, que a
plataforma **não** promoveu, e **por quê** — e o "por quê" vem do dado, não de texto fixo.

| se a tela | resultado |
|---|---|
| escondesse a evidência | 75 pessoas sem equipe nenhuma, o que é falso |
| escondesse a não promoção | afirmaria um vínculo que a plataforma recusou |
| fixasse o motivo no texto | mentiria no dia em que alguém cadastrar papel |

## Technical Context

| | |
|---|---|
| Linguagem | Elixir 1.20.2 / OTP 29 |
| Framework | Phoenix 1.8.9 + LiveView |
| Persistência | Ecto + PostgreSQL 17 |
| Escala | 75 pessoas, 12 equipes, 4 521 issues, 4 232 designações |
| Fronteiras cruzadas | **EO** (pessoa, equipe), **WorkItems** (issue, designação) e **CMPO** (nome do repositório) |

---

## Constitution Check

### I. Domínio organizado pelas ontologias — **conforme**

Nenhum conceito novo. Pessoa e equipe são EO; issue e designação são WorkItems. O que a feature
acrescenta é **leitura** e **exibição** — e a distinção que ela exibe é a que a rede já modela.

### II. Fonte externa não é domínio — **conforme, e é o assunto da tela**

`platform_access_level` é dado **da ferramenta** — `MEMBER`, `MAINTAINER` —, e a tela o mostra como
tal. **Nada deriva papel dele** (FR-004): papel é conceito da SRO, e mapear permissão em papel seria
mapear por semelhança de nome, que o `AGENTS.md` §7.7 nomeia como antipadrão.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL) — **conforme**

A página **exibe** proveniência: origem, identificador, `observed_at`, `last_observed_at`,
`no_longer_observed_at`. Nada é gravado, então não há idempotência a garantir — e é o desenho certo:
o conteúdo é derivado na leitura, como a classificação épico/atômica.

### IV. Semântica declarada em YAML versionado — **não se aplica**

Nenhum conceito, regra ou mapeamento novo.

### V. Monólito modular multitenant — **conforme**

Toda consulta recebe `%Tenant{}`. Pessoa de outro tenant responde **não encontrado**.

### VI. Spec Kit e sprint backlog antes do código — **conforme**

Spec, checklist, pesquisa, este plano, data-model, contrato e quickstart antes da primeira linha. É a
quinta feature seguida na ordem.

### VII. Quality gates e revisão independente — **conforme por construção**

Dez gates por `mix gates`, agora com **veredito pelo código de saída**. O contrato vem antes da
primeira função pública, em [contracts/](contracts/person-detail.md).

### VIII. Desenho que o problema justifica — **conforme, dois padrões e cinco recusas**

Ver abaixo. **Nenhum módulo novo**, e a composição segue precedente já em uso.

### IX. Ontologias modulares e autônomas — **conforme, e é o princípio que mais decidiu**

A página cruza **três** fronteiras: **EO** (pessoa, equipe), **WorkItems** (issue, designação) e
**CMPO** (o nome do repositório e de qual organização ele é).

**A terceira só apareceu na análise**, e a versão anterior deste plano dizia "duas". O motivo é
concreto: `repositories_of_person/2` devolve identificador e contagens, e nada nessa resposta diz o
**nome** do repositório — a tela precisa dele, e `WorkItems` **não pode** juntar
`cmpo_source_repositories`, porque a fronteira é o que este princípio protege.

**Nenhuma das três lê a tabela da outra.** Cada uma responde pela sua, e a composição acontece na
borda de apresentação — que é o precedente de `repository_live/show.ex`, onde três fronteiras já são
compostas.

**E o nome vem de uma consulta só**: `CMPO.list_observed/1` uma vez, virando mapa de identificador
para nome e organização — exatamente o `onde/2` da feature 007. Consultar por repositório aqui
violaria FR-016.

**A alternativa que o princípio recusa**: um módulo que devolvesse a página montada. Ele conheceria as
duas ontologias e seria o lugar onde a fronteira se dissolve.

### X. Responsabilidade única, em módulo e em tela — **conforme**

A página responde **uma** pergunta: *o que a plataforma sabe sobre esta pessoa?* As três seções —
identidade, equipes, trabalho — são partes dessa resposta, não perguntas novas.

---

## Registro dos padrões introduzidos (princípio VIII)

### P1 — Filtro por pessoa em `escopo/2`, com **duas** opções distintas

**Qual problema concreto resolve?** Listar as issues de uma pessoa, sem misturar designação com
autoria. `escopo/2` filtra por repositório e não conhece pessoa.

**O problema existe agora?** Sim: 4 232 designações e 4 241 autorias, e a spec proíbe a soma.

**O que fica pior?** `escopo/2` passa a ter três dimensões. Mitigação: as opções se chamam
`assigned_to:` e `authored_by:` — o nome carrega a distinção, e uma opção `person_id:` obrigaria quem
lê a descobrir o sentido. É a L34 aplicada antes de doer.

### P2 — Um componente privado para a origem da relação

**Qual problema concreto resolve?** **Dois** lugares da mesma tela precisam dizer se a relação é
observada, derivada ou ausente: a lista de **equipes** e a lista de **repositórios**.

**A análise corrigiu a contagem**: a versão anterior dizia três, somando "vínculo ausente" como uso
próprio. Ele **não é**: equipe e vínculo ausente são a **mesma lista**, e a linha muda de forma
conforme `no_longer_observed_at`.

**O problema existe agora?** Sim, **dois** usos — que é exatamente o limiar do projeto. A feature 007
recusou componente para **um** chamador.

**Fica no limiar, e isso está declarado**: se uma das duas listas sair da tela, o componente sai com
ela e volta a ser markup no lugar de uso.

**O que fica pior?** Um componente a mais para manter, e a tentação de promovê-lo cedo a
`TheBandWeb.UI`. Mitigação: ele é **privado do LiveView**, e o critério de promoção está escrito em R5
— o segundo consumidor **fora** desta tela.

### Padrões **recusados**, e por quê

| Recusado | Por quê |
|---|---|
| módulo `PersonProfile` que monta a página | conheceria duas ontologias e dissolveria a fronteira — princípio IX, ADR 0003 |
| `EO` consultando `issue_assignees` | designação é de WorkItems; a fronteira quebrada por conveniência |
| reusar `<.evidence>` | ela responde "de onde veio o conceito"; aqui a pergunta é "de onde veio a relação" — R5 |
| uma consulta que devolva "as issues da pessoa" | são três conjuntos, e a união é o que não corresponde a nada |
| texto fixo explicando a não promoção | passaria a mentir quando alguém cadastrar papel — R4 |

---

## Project Structure

```text
specs/010-detalhe-da-pessoa/
├── spec.md          17 FR, 12 SC, 3 user stories, 6 casos de borda
├── research.md      R1 a R6 — R1 por precedente, R4 pela forma do dado
├── plan.md          este documento
├── data-model.md    nenhuma coluna nova
├── contracts/person-detail.md
├── quickstart.md    V1 a V9
└── checklists/requirements.md
```

```text
lib/the_band/ontology/seon/eo/queries.ex        + equipes da pessoa, + contagem de papéis
lib/the_band/ontology/seon/eo.ex               + os defdelegates
lib/the_band/work_items/queries.ex             + contagens e repositórios por pessoa
lib/the_band/work_items.ex                     + os defdelegates
lib/the_band_web/live/people_live/show.ex      a página
lib/the_band_web/live/people_live/index.ex     o nome vira link
lib/the_band_web/router.ex                     + /people/:id
```

**Nenhuma migração.** A feature só lê.

---

## Fases, e por que esta ordem

### F1 — O que a origem declara sobre a pessoa

As equipes com nível de acesso e período, e a contagem de papéis que sustenta a explicação da não
promoção.

**Primeiro porque é o achado da feature**: 88 evidências e zero vínculos. Sem esta fase a tela
mostraria trabalho e esconderia a distinção que o produto existe para fazer.

### F2 — O trabalho derivado

Contagens separadas de designação e autoria, os repositórios agrupados com a evidência, e a lista
paginada.

### F3 — A página

A rota, o link em `/people`, o componente da origem da relação, e as três ausências nomeadas.

**Por último**, e as duas primeiras não são entregáveis sozinhas: função sem consumidor visível não é
funcionalidade entregue — é a L21, e por isso as três fases estão no mesmo sprint.

---

## Riscos

| Risco | Mitigação |
|---|---|
| **exibir a soma de designação com autoria** | FR-009; o teste procura o número proibido, como o `refute html =~ ">39<"` da feature 006 |
| a explicação da não promoção envelhecer | o motivo vem do dado, com o caso "há papéis e ainda não promoveu" previsto — R4 |
| ler nível de acesso como papel Scrum | FR-004; nenhum texto da tela usa a palavra papel para `MAINTAINER` |
| consultar por linha | **oito** consultas, todas agrupadas ou paginadas, e o número é **asserido** no teste — FR-016 |
| vínculo ausente desaparecer da tela | FR-006 exige com data; o teste marca a evidência como não mais observada e exige que apareça |
| a tela crescer para pessoa com centenas de issues | lista paginada, com o total no cabeçalho |

---

## Complexity Tracking

| Item | Custo | Aceito porque |
|---|---|---|
| duas opções novas em `escopo/2` | a função cresce | os nomes carregam a distinção que a spec exige |
| um componente privado | mais um lugar para olhar | três usos na mesma tela |
| **oito** consultas próprias por render | oito em vez de uma | juntá-las produziria o número proibido, e o nome do repositório exige a terceira fronteira. Medido: 24 na página contra 16 na lista |
| uma consulta de contagem de papéis | uma a mais, barata | é o que impede a explicação de envelhecer |

---

## Reavaliação da constituição, pós-desenho

Dez princípios: nove conformes, um não aplicável (IV). Dois padrões introduzidos, cinco recusados.

**O princípio IX foi o que mais decidiu**, e decidiu contra criar o módulo que parecia natural: a
composição fica na borda de apresentação, onde ela já acontece em `repository_live/show.ex`.

E o princípio II sustenta o requisito mais fácil de violar: `MAINTAINER` é permissão da ferramenta, não
papel do processo — e a tela precisa dizer isso com palavras, não só evitar a palavra.
