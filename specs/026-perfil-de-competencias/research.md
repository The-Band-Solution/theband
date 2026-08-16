# Research — Perfil de competências e evolução

**Data**: 2026-08-15 · **Fase 0 exercitada contra o banco real e contra a API do provedor.**

Este documento registra o que foi **medido e testado antes do plano**, e não o que se
espera que funcione. O pipeline inteiro foi rodado ponta a ponta com `AndreCoelhoS` — 97
tarefas concluídas, 5 abertas, 24 mil tokens de entrada — e três defeitos observados nessa
rodada viraram requisito da spec.

---

## R1 — O perfil **não** é um conceito novo na rede de ontologias

**Decisão**: nenhum conceito de competência entra em EO, SRO ou módulo novo. O perfil é
gravado como **documento sobre uma pessoa**, com proveniência, referenciando `eo.person`.

**Rationale**: a rede descreve o mundo — pessoa, papel, equipe, alocação, tarefa, sprint.
Um texto que um modelo escreveu **não é uma coisa do mundo observado**: é artefato que a
plataforma produziu ao interpretar o que observou.

Criar `eo.competence` faria a plataforma **afirmar que a pessoa tem a competência**, e isso
é exatamente o que a spec recusa: `FR-005` diz que lacuna é do registro, não da pessoa, e
`FR-007` proíbe afirmar nível. Um conceito de competência licenciaria a consulta *"quem tem
competência X"* — pergunta que a evidência não sustenta, e que a existência do conceito
convidaria a fazer.

Há precedente na própria casa: a promoção de issue a user story grava **proveniência e
confiança** em vez de afirmar o tipo como fato, e a tela mostra a evidência ao lado. Mesma
postura aqui, um nível acima.

**Alternativas consideradas**:

| alternativa | por que não |
|---|---|
| `eo.competence` como novo conceito em EO | EO é ontologia de referência com fonte; acrescentar conceito sem `reference_ontology` que o sustente viola o princípio I, e a única fonte real seria decisão nossa |
| módulo `competency` novo, com `project_decision` | resolve a proveniência e não resolve o problema: continua afirmando competência a partir de texto de terceiro em 44% dos casos |
| reaproveitar `sro.developer_role` | papel não é habilidade. Alocar alguém como pessoa desenvolvedora não diz em que ela é boa |

**Consequência a aceitar**: não haverá consulta "quem sabe Kubernetes" derivada do modelo.
Quem quiser isso vai ter de ler perfis, ou declarar habilidade à mão numa feature futura —
e declarar é honesto de um jeito que inferir não é.

---

## R2 — A tabela é **somente-acréscimo**, e o recorte de entrada é coluna

**Decisão**: `eo_person_profiles`, uma linha por geração. Nunca `UPDATE`. O perfil vigente é
o mais recente por `generated_at`.

**Rationale**: `FR-015` exige que uma geração nova não apague a anterior, e `US4` diz por
quê — comparar agosto com dezembro é parte do valor. Sobrescrever destruiria a única série
que a feature produz ao longo do tempo.

O recorte de entrada vira **coluna, e não JSON solto**: quantas concluídas, quantas abertas,
o intervalo de meses, quantas escritas por terceiro, quantas compartilhadas. É o que permite,
meses depois, dizer sobre o que aquele texto falava — e é consultável para `FR-016`, que
compara o recorte com o que existe hoje.

**Alternativa considerada**: uma linha por pessoa, com `updated_at`. Descartada por `FR-015`.

---

## R3 — A chamada ao provedor é **porta e adaptador**, espelhando o GitHub

**Decisão**: `TheBand.Integrations.LLM.HTTP` como behaviour, `…HTTP.Req` como implementação,
Mox no teste. Idêntico em forma a `TheBand.Integrations.GitHub.HTTP`.

**Rationale**: o padrão já está justificado em `AGENTS.md` §7.7 para a borda HTTP, e o motivo
é o mesmo aqui — é o único ponto que o teste substitui, e mockar qualquer coisa abaixo dele
esconderia erro em vez de revelá-lo. Não é padrão novo: é o padrão da casa aplicado à segunda
borda de I/O que a plataforma ganha.

**O que fica pior**: mais um `Application.get_env` para configurar, e mais um salto de leitura
entre quem pede o perfil e quem faz o HTTP. Aceito, porque sem isso o teste da geração
dependeria de rede e de crédito.

---

## R4 — A geração é **trabalho de fundo**, não chamada síncrona na tela

**Decisão**: um job Oban por geração. A tela pede, recebe confirmação imediata, e o perfil
aparece quando o job termina.

**Rationale**: medido na validação — a chamada levou **entre 25 e 60 segundos** com
`gpt-5.4-mini` e 24 mil tokens de entrada. Segurar o processo do LiveView por um minuto
prenderia a aba inteira, e um `timeout` de rede derrubaria a tela em vez de reportar falha.

O projeto já usa Oban para toda coleta, então não é tecnologia nova.

**O que fica pior**: a tela ganha um estado a mais — *pedido, ainda não pronto* — e ele
precisa ser distinguível de *nunca gerado* e de *falhou*. Três estados diferentes com três
frases diferentes, e é `FR-022` que impede que virem um só.

---

## R5 — A linha de base é **uma consulta, uma vez**, e não por pessoa

**Decisão**: uma consulta agrupada por mês sobre `collected_issues` do tenant, calculada uma
vez por geração e reaproveitada nos três períodos.

**Rationale**: a linha de base é a mesma para todo mundo — é o tenant, não a pessoa. Calcular
dentro do laço dos períodos seria N+1 por definição, e calcular por pessoa multiplicaria por
25 uma consulta que tem uma resposta só.

**Medido**: 20 meses de dados, uma consulta, sem índice novo.

---

## R6 — O veredito da comparação é **calculado**, não pedido ao modelo

**Decisão**: a plataforma calcula a razão de crescimento da pessoa e a do projeto, compara as
duas, e entrega ao modelo a **frase pronta**: *"a pessoa ACOMPANHOU o projeto: a mudança é da
convenção do time, e NÃO dela"*.

**Rationale**: isto não é preferência de estilo — é defeito observado. Na validação, o modelo
recebeu `415, 428, 814` e escreveu que o projeto *"ficou perto de estável"*. É o dobro. E é
justamente a conta que decide se `FR-010` foi cumprido ou violado.

**A regra geral que sai daqui**: conta que decide requisito não se delega a quem só lê texto.
O modelo escreve; a plataforma calcula.

**Limiar**: abaixo de 1,3× de diferença entre as duas razões, a mudança é do time. Escolhido
na validação — a diferença real do `AndreCoelhoS` foi 1,8× contra 2,0×, ou seja 0,9×, bem
dentro da faixa de "acompanhou".

---

## R7 — Os três defeitos do modelo, e o que cada um exigiu

Observados rodando o pipeline de verdade, e não previstos no papel:

| defeito observado | forma que apareceu | contenção |
|---|---|---|
| **referência inventada** | `(#P1, #P2)`, `(#linha de base P1/P2/P3)`, `(#2025-05)` — rótulos com cerquilha que parecem issue e não são | regra explícita no prompt de que só existe `#<número>` de tarefa presente no material; verificado por contagem |
| **gênero deduzido do nome** | o texto tratou `AndreCoelhoS` por "ela" do começo ao fim | proibição explícita, e instrução de escrever pelo login ou em construção neutra — `FR-008` |
| **citação onde não cabe** | despejo de 17 números num parágrafo do resumo, mesmo com teto de três pedido quatro vezes | **limpeza no código**, e não pedido ao modelo: o resumo é definido como a parte sem citação, então a plataforma remove — e registra quantas removeu |

O terceiro é o mais instrutivo: **quando a regra é verificável mecanicamente, aplicá-la é
melhor que pedi-la.** Pedir e não conferir produz um relatório que viola a própria regra e
parece cumpri-la.

---

## R8 — A necessidade de informação existe, e é declarada

`AGENTS.md` §17 proíbe criar tela sem necessidade de informação. Esta feature declara
`people.demonstrated_domains` em `priv/knowledge_base/information_needs/`, com a pergunta que
ela responde, quem decide com ela, e — o que importa aqui — **o que ela explicitamente não
responde**.

---

## O que ficou de fora, e por quê

- **Commits, revisões e comentários** como material. A designação é o vínculo que a plataforma
  observa com proveniência; commit exigiria mapear autoria de git para pessoa, que é outra
  feature.
- **Habilidade declarada à mão pela pessoa.** É o complemento honesto do perfil derivado, e é
  feature própria — misturar declarado e derivado na mesma tela sem separá-los seria
  exatamente o que o design system proíbe.
- **Comparar duas gerações lado a lado.** `FR-015` guarda o histórico para que isso seja
  possível; exibi-lo é escopo de outra vez.
