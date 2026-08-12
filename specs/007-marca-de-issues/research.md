# Pesquisa — Feature 007: a marca de trabalho no repositório

Quatro questões. Nenhuma delas é sobre desenho novo — três são sobre **não** introduzir desenho,
e a quarta é a única coisa que a plataforma ainda não sabe.

---

## R1 — A marca é componente novo, ou markup na célula?

**Decisão**: **markup na célula**, com um helper privado para o texto. **Nenhum componente
novo.**

**Razão**: há **um** ponto de uso. A tabela e o cartão do telefone são o **mesmo** HTML — o
`stacked` do design system converte a tabela em cartões por CSS, com `data-label`, e não por um
segundo caminho de renderização. Um componente para um único chamador é generalidade
especulativa, e o antipadrão está nomeado no `AGENTS.md` §7.7.

**O que o componente daria, e não é preciso**: reuso — que não existe; e testabilidade — que o
teste de LiveView já cobre pela tela.

**Quando isto vira componente**: no segundo chamador. Se a marca precisar aparecer na tela do
repositório ou em outra lista, aí ela tem o problema que justifica o componente — e o critério de
reversão é este parágrafo.

**Recusado**: reusar `<.evidence>`. Ela responde *"de onde veio este conceito"* — proveniência de
uma decisão semântica. A marca responde *"há trabalho aqui"*. Emprestar o componente faria a
mesma forma significar duas coisas, e a gramática da evidência perderia precisão exatamente onde
ela é o produto.

**Recusado**: reusar `<.absent>` para o caso vazio. Ela nomeia **valor** ausente num campo. Aqui a
ausência é de trabalho num repositório, e o texto precisa dizer se a coleta ocorreu — o que
`<.absent>` não tem como saber.

---

## R2 — De onde vem a contagem, sem aumentar consulta

**Decisão**: uma consulta **agrupada** — `count_collected_by_repository/2` — devolvendo mapa de
`observed_repository_id` para contagem. A coluna e a marca leem o **mesmo** mapa.

**Razão**: hoje `por_repositorio/2` chama `count_collected/2` **uma vez por repositório**: 135
consultas para desenhar a tela. A marca precisa do mesmo número, e ler de novo faria 270.

A troca não é otimização especulativa: FR-011 proíbe aumentar, FR-010 exige um número só, e o
caminho que atende aos dois é o mesmo — agrupar.

**Não é padrão novo.** É a forma que o projeto já usa duas vezes, pelo mesmo motivo:
`EO.organizations_by_person/2` e `WorkItems.current_promotions/2` existem porque uma consulta por
linha cresce com a coleta. Usar aqui é aplicar o padrão dentro do problema que o motivou.

**Ganho medido, e é bônus**: 135 consultas viram 1. A feature **reduz** o custo da tela em vez de
aumentar.

**Recusado**: guardar a contagem numa coluna de `observed_repositories`. Seria situação
materializada — a ADR 0004 D7 — e ficaria errada no instante em que uma issue fosse coletada,
sem nada dizendo que envelheceu.

**Recusado**: contar no LiveView a partir da lista de issues já carregada. A tela pagina as
issues (50 por página), então a lista em memória **não** é o conjunto: contar ali daria a
contagem da página.

---

## R3 — A marca resume issues vigentes, e o que fazer com as não vigentes

**Decisão**: a contagem é de issues **vigentes** — `no_longer_observed_at` nulo. Repositório que
só tem issues marcadas como ausentes aparece com marca vazia e o texto **"no current work"**, e
não "no issues".

**Razão**: são fatos diferentes, e o design system exige nomear a diferença. "Sem issues" afirma
que nunca houve trabalho; "sem trabalho vigente" afirma que houve e não está presente. A segunda
é a que interessa a quem procura o que fazer agora.

**Consequência declarada**: a coluna de contagem hoje conta **todas**, vigentes e não vigentes.
Com esta decisão, coluna e marca passariam a discordar — e é isso que FR-010 proíbe. Então **a
coluna passa a contar vigentes também**, e a mudança é declarada como parte da feature.

No dado real, nenhuma issue está marcada como não mais observada, então o número exibido hoje não
muda — mas o significado muda, e a mudança é registrada.

**Recusado**: duas contagens, vigente e histórica, lado a lado. Duplica a coluna para resolver um
caso que hoje tem zero ocorrências, e a tela do repositório já mostra as não vigentes com a marca
própria.

---

## R4 — Como distinguir "coletado e vazio" de "nunca coletado"

**Decisão**: **uma coluna nova** — `observed_repositories.issues_collected_at` —, gravada quando
a fase de issues termina para aquele repositório. `nil` significa "nunca passou por coleta de
issues", e é a única coisa que a plataforma hoje não sabe.

**Por que não é derivável do que existe**, e eu conferi:

| candidato | por que não serve |
|---|---|
| `sync_checkpoints` | a chave é `github.issue`, uma por execução — não por repositório |
| `raw_payloads` | tem payload de issue, então prova que **houve** issue; não prova coleta que achou zero |
| `collected_issues` | ausência de linha é justamente a ambiguidade que se quer resolver |
| `observed_repositories.inserted_at` | diz quando o repositório passou a ser observado, não quando as issues dele foram buscadas |

**As três perguntas do princípio VIII**

**Qual problema concreto resolve?** Distinguir 61 repositórios coletados e vazios de repositórios
recém-observados que nunca foram consultados. Hoje os dois grupos são indistinguíveis, e a tela
mostraria `0` para ambos — que é ausência desenhada como quantidade, o que o design system
proíbe.

**O problema existe agora?** **Sim, e é a maioria.** 61 dos 135 repositórios têm zero issues, e
não há como dizer quais nunca foram consultados. Toda ferramenta nova conectada cria mais.

**O que fica pior?** Um lugar a mais para esquecer de escrever. Se a fase de issues gravar a data
para uns e não para outros, a marca passa a mentir sobre coleta — e mentir sobre coleta é pior
que não saber. A mitigação é a gravação ficar no **mesmo** ponto que já grava o checkpoint da
fase, e o teste exigir que os dois andem juntos.

**É evento, não situação.** `issues_collected_at` registra que algo **aconteceu** — a ADR 0004 D7
proíbe materializar situação derivada, e não proíbe registrar fato de coleta. É a mesma natureza
de `collected_at` e `last_observed_at`, que já existem.

**Recusado**: tratar "sem issues" como sempre desconhecido. Seria honesto e inútil: 61
repositórios diriam "não se sabe" quando a plataforma sabe muito bem que olhou e não achou nada.

**Recusado**: inferir da existência de qualquer sincronização concluída para a ferramenta. Um
repositório excluído ou inacessível **não** foi consultado naquela execução, e a inferência o
marcaria como coletado.

---

## R5 — O nome da branch

**Decisão**: a branch desta feature é **`008-marca-de-issues`**, e o diretório da spec continua
`specs/007-marca-de-issues`.

**Razão**: a numeração do diretório é sequencial sobre `specs/`, e ali o próximo livre era 007. A
branch em andamento — `007-interface-em-ingles` — não tem diretório de spec, porque aquela
mudança começou fora do ciclo, o que está declarado como dívida.

Reusar `007` na branch faria duas branches diferentes com o mesmo número, e o `git branch` não
diria qual é qual. Renumerar o diretório para 008 faria a spec mentir sobre a ordem em que foi
escrita.

**A dependência é real, e é o motivo de a ordem importar**: esta feature usa o design system e o
`stacked`, que vivem na branch 007. O plano assume que ela foi incorporada — se não tiver sido, a
marca não terá a gramática para aplicar.
