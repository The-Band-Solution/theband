# Pesquisa — Feature 005: regras de mapeamento por organização

Seis questões que a spec deixou para o plano. Cada uma com decisão, razão e o que foi
recusado.

---

## R1 — Onde a regra vive: YAML ou banco?

**Decisão**: **as duas coisas, com papéis distintos.** O catálogo em YAML versionado; a
regra da organização no banco.

| | Catálogo | Regra da organização |
|---|---|---|
| Onde | `priv/knowledge_base/rules/github_issue_pattern_catalog.yaml` | tabela `issue_mapping_rules` |
| Quem escreve | commit revisável | a tela |
| Quando é lido | **uma vez, no boot**, para ETS | por consulta, a cada uso |
| Efeito de mudar | exige reiniciar | **vale imediatamente** |

**Razão**: é a distinção central do desenho, e ela decorre de um fato do sistema. A base de
conhecimento é carregada no boot — `TheBand.Ontology.KnowledgeBase` popula ETS quando a
aplicação sobe. Uma regra gravada pela tela que vivesse no YAML **não valeria sem restart**,
e isso já mordeu nesta sessão: a regra do tenant criada depois do boot não valia, e a tela
mostrou três divergências que um restart resolveria.

Pedir restart depois de cadastrar regra é inaceitável numa tela de configuração.

**O que o YAML continua sendo**: o **padrão** do qual a organização parte, e o lugar onde a
semântica revisável vive (princípio IV). O catálogo não é configuração da aplicação — é
conhecimento sobre convenções de escrita de issue, e conhecimento passa por revisão de
código.

**Recusado**: só banco. A semântica sairia do YAML versionado, contra o princípio IV, e o
catálogo deixaria de ter revisão.

**Recusado**: só YAML. Cadastrar regra exigiria commit e restart — a tela pedida não
existiria.

---

## R2 — Como o catálogo se materializa por organização

**Decisão**: o catálogo **não é copiado** para o banco na conexão. A tela **compõe** as duas
fontes em leitura: para cada entrada do catálogo, procura a regra da organização com a mesma
chave; havendo, mostra a da organização e marca como **editada**; não havendo, mostra a do
catálogo como **proposta**.

**Razão**: copiar na conexão criaria 18 linhas por organização no instante do `connect`, e
todas com autor "sistema" — que é exatamente o que FR-041 proíbe. Pior: uma atualização do
catálogo não teria como alcançar as cópias sem sobrescrever edição, e FR-043 proíbe
sobrescrever.

Compor em leitura resolve os dois: a organização só tem linha quando alguém **decidiu**, e a
ausência de linha significa "nunca decidido" em vez de "cópia intocada".

**A chave que liga catálogo e banco** é `(where, how, text)` normalizado — onde procura, como
compara, e o texto. Não é o índice da lista: reordenar o catálogo não pode desligar as
decisões já tomadas.

**Recusado**: copiar na conexão. Ver acima.

**Recusado**: gravar apenas o que difere do catálogo. Seria a mesma coisa que compor, com o
custo de a linha "ativada sem alteração" ser indistinguível de "não decidida".

---

## R3 — Onde a regex é validada, e o que é recusado

**Decisão**: validação no comando, antes de qualquer escrita, com três recusas — e a mesma
função valida na prévia.

| Recusa | Como é detectada | Mensagem |
|---|---|---|
| não compila | `Regex.compile/2` devolve `{:error, {razão, posição}}` | a razão e a posição |
| casa string vazia | `Regex.match?(regex, "")` | "casaria todas as issues" |
| lenta demais | avaliação numa amostra com limite de tempo | o limite, em ms |

**Razão**: `Regex.compile/2` é a única forma de saber se compila, e ela devolve a posição do
erro — que é o que a pessoa precisa para corrigir. E `Regex.match?(regex, "")` é o teste mais
direto para o caso perigoso: uma expressão que casa vazio grava sem erro e reclassifica tudo.

**Sobre o limite de tempo**: Erlang usa PCRE via `:re`, e a maioria das expressões
patológicas não trava o escalonador — mas `:re` **não** tem limite de passos, e uma expressão
com aninhamento de quantificadores sobre título longo pode custar segundos. A avaliação numa
**amostra** com `Task.await/2` e limite dá a resposta sem prender o processo da tela.

**A amostra é de títulos reais da organização**, não de string sintética: uma expressão que
é rápida em `"abc"` pode ser lenta no título de 200 caracteres que o time escreve.

**Recusado**: validar só na gravação. A prévia usaria caminho diferente, e a diferença entre
prévia e efeito é o que SC-007 proíbe.

**Recusado**: `Regex.compile!/2`. Levantaria exceção onde o erro é previsto — e o princípio
VIII manda erro previsto ser retorno.

---

## R4 — Síncrono ou assíncrono, e o limite

**Decisão**: **assíncrono sempre**, na fila `transformation`, com o progresso visível na
tela. Sem limite condicional.

**Razão**: o recálculo afeta até 3440 issues numa organização, e este número **vai crescer**.
Um limite condicional — "síncrono até N, assíncrono acima" — cria dois caminhos, e o caminho
raro é o que quebra: seria testado com 10 issues e usado com 3440.

Um caminho só, sempre assíncrono, é mais simples de entender e de verificar. O custo é que
gravar regra não devolve o resultado na mesma requisição — e a tela resolve isso mostrando o
progresso, que ela precisa mostrar de todo modo.

**A fila é `transformation`, que já existe.** Declarar fila nova sem configurá-la faz o job
ficar `available` para sempre — aconteceu nesta sessão com uma fila `:sync` inexistente, e o
sintoma foi uma coleta que "completou" sem coletar nada. E `transformation` é semanticamente
certa: recalcular promoção é transformar o que já foi coletado, não coletar.

**Idempotência** (FR-027): o recálculo compara a decisão nova com a **vigente** e só grava
quando diferem. Executar duas vezes sobre o mesmo estado não produz linha nova.

**Recusado**: síncrono com limite. Dois caminhos, e o raro é o que importa.

**Recusado**: fila nova. Sem problema que a justifique, e com o risco já observado.

---

## R5 — Onde entra a correspondência por título, no código que já existe

**Decisão**: `TheBand.WorkItems.Routing.decide/2` ganha uma **segunda etapa**, e a ordem é a
regra:

```
1. tipo declarado           → regra da organização, depois tenant, depois global
2. título, SE não houver    → regra da organização apenas
   conceito da etapa 1
```

**Razão**: FR-008 diz que tipo declarado vence regra de título, e a única forma de garantir
isso é **não chegar** à etapa 2 quando a etapa 1 decidiu. Uma implementação que avaliasse as
duas e escolhesse depois deixaria a precedência dependente da ordem de comparação.

**Regra de título não existe em YAML global.** O catálogo propõe padrões de título, mas eles
só valem depois de ativados por organização — e ativados, vivem no banco. Isso mantém a
inferência sobre texto livre sempre como **decisão declarada de alguém**, nunca como padrão
da plataforma.

**A confiança sai daqui** (FR-013): etapa 1 grava confiança `high`; etapa 2 grava `medium`. É
o mesmo vocabulário de níveis que a base de conhecimento já usa, e não um número inventado.

**Recusado**: uma etapa só, com prioridade por atributo. Faria a precedência dado em vez de
estrutura, e um dado errado inverteria a regra em silêncio.

---

## R6 — O que acontece com `tool_concept_mappings`

**Decisão**: **não é implementada.** FR-036 declara a substituição, e as tarefas T043 a T046
da feature 004 são fechadas como substituídas — não como concluídas.

**Razão**: um mapeamento por igualdade de nome é o caso particular de `how: equals` desta
feature. Duas tabelas para a mesma decisão divergiriam, e a divergência seria silenciosa:
qual delas a promoção consulta?

**O que se perde, e é pouco**: a 004 previa mapear **campo de quadro → atributo da
ontologia** na mesma tabela. Isso fica fora desta feature (FR-037) e continua no product
backlog, porque campo configurável não é tipo de issue e a correspondência por texto não se
aplica a ele.

**O que a 004 já entregou e permanece**: a regra do tenant em
`rules/tenants/the_band_solution.yaml`, com os tipos e os identificadores. Ela continua sendo
o segundo nível de precedência.

**Recusado**: implementar as duas e escolher depois. É a definição de divergência silenciosa.
