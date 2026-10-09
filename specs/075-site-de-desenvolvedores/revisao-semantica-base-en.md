# Revisão semântica: o `en` da base de conhecimento

Issue #1312, filha do #1267. Papel: Ontology & Semantic Integration (AGENTS.md §13). Data: 2026-10-04.

**O que se confere.** O `en` não pode dizer algo diferente do `pt-BR`. A pergunta é de
**sentido**, e não de estilo: um `en` mais forte, mais fraco ou mais específico que o original
reprova, por melhor que seja o inglês. Tradução que acrescenta conceito é o mesmo erro que
mapear por semelhança de nome. A medida passa a mentir na página inglesa, e quem lê só o
inglês não tem como perceber.

**Quem traduziu e quem revisou.** A tradução foi feita em lotes por cinco agentes, com as
regras e o glossário de L01, L02 e L03 mais os rótulos `en` dos 240 conceitos. A revisão é
do agente que coordenou o trabalho e não traduziu nenhum lote. Ela **não** é revisão
independente no sentido do princípio VII: a revisão humana do PR continua pendente.

## O que ganhou `en`

| tipo | campo | com `en` antes | ganharam `en` | total |
|---|---|---:|---:|---:|
| definição de conceito | `concepts[].definition` | 0 | 240 | 240 |
| descrição de módulo | `module.description` | 3 | 30 | 33 |
| pergunta de competência | `competency_questions[].question` | 19 | 62 | 81 |
| justificativa de mapeamento | `semantics.justification` | 0 | 22 | 22 |
| limitação de mapeamento | `limitations[]` | 0 | 124 | 124 |
| **total** | | | **478** | |

Nenhum `pt-BR` mudou, e isso foi **conferido por máquina**, não por leitura. O aplicador
relê cada arquivo depois de escrever e reprova se o documento, sem os `en`, diferir do
original. As páginas em português geradas por `scripts/generate_docs.py` saem idênticas byte a
byte às de `origin/development` (`diff -r`, saída 0).

## A amostra

São 10% de cada tipo, arredondados para cima, sorteados com semente fixa (`random.Random(1312)`)
sobre a lista ordenada por id. Quem quiser refazer o sorteio chega à mesma amostra.

| tipo | amostra | de | divergências |
|---|---:|---:|---:|
| definição de conceito | 24 | 240 | 2 |
| descrição de módulo | 3 | 30 | 0 |
| pergunta de competência | 7 | 62 | 0 |
| justificativa de mapeamento | 3 | 22 | 0 |
| limitação de mapeamento | 13 | 124 | 0 |
| **total** | **50** | **478** | **2** |

### As duas divergências, e o que foi feito

1. **`sro.product_owner_membership`**: o `pt-BR` diz *"Alocação que faz um membro do time
   desempenhar o Papel de Product Owner…"*, e o `en` dizia *"Membership that makes…"*. O nome do
   conceito é *Membership*, mas a definição diz **alocação**. Trocar a palavra da definição pela
   do nome a tornaria circular, e o `en` passaria a dizer menos que o `pt-BR`. Corrigido para
   *"Allocation that makes…"*. Os dois irmãos, fora da amostra e com a mesma frase, foram
   corrigidos junto: `sro.scrum_master_membership` e `sro.developer_membership`.
2. **`eo.role_visibility_grant`**: o `pt-BR` diz *"com vínculo vigente"*, e o `en` dizia *"with a
   team membership in force"*. O glossário traduz *vínculo (de equipe)* como *team membership*,
   mas aqui a frase não diz de que vínculo se trata. A nota do módulo fala do *"vínculo vigente com
   esse papel"*. Escrever *team membership* acrescentaria uma especificidade que o original não
   tem. Corrigido para *"with a link in force"*, literal como o `pt-BR`. O irmão fora da amostra,
   `eo.role_structure_management_grant`, tem a mesma frase e foi corrigido junto.

### O que a amostra confirmou

- **Distinções que a base existe para preservar**: *intended* e *performed* (SPO, SRO),
  *defect*, *fault* e *failure* (OSDEF), caso de teste e execução (ROoST), artefato de requisito
  e requisito (RSRO). Nenhum `en` da amostra os confunde. Onde o `pt-BR` diz *"insucesso"* (CIRO),
  o `en` diz *unsuccessful*, e não *failure*. Seria o conceito de OSDEF, e o original não o diz.
- **Modalidade**: *"pode"*, *"nunca"* e *"NÃO"* em caixa alta saem como *may*, *never* e *NOT*.
  Nenhuma ressalva foi suavizada ou reforçada.
- **Identificadores**: todo texto entre crases saiu igual, e o script `conferir.py` confere isso
  item a item. Os ids sem crase (`eo.person`, `ciro.unperformed_continuous_integration_process`)
  também foram mantidos.
- **Números e datas**: *2.461* virou *2,461*. É a convenção do inglês para o mesmo número. As
  datas ficam no formato AAAA-MM-DD.

### Escolhas de tradução declaradas pelos tradutores, e aceitas

Nenhuma destas muda o sentido. Elas ficam registradas porque são o primeiro lugar a olhar se um
leitor achar o inglês estranho:

- a citação da pessoa mantenedora, *"interações futuras são plannings que não foram feitas"*
  (dois mapeamentos de iteração), saiu como *"future iterations are plannings…"*, com o original
  entre parênteses. *"interações"* é lapso evidente por *"iterações"*. O `pt-BR` **não** foi
  corrigido: é citação, e corrigir citação é editar a decisão de outra pessoa;
- *"atende"* (a tarefa atende a user story; o PR atende a issue) saiu como *serves* ou *fulfills*,
  conforme o contexto;
- *"vínculo"* saiu como *team membership* quando é entre pessoa e equipe, como manda o glossário,
  e como *link* nos demais casos (issue, projeto, organização, composição);
- as tabelas em ASCII dentro de duas justificativas foram traduzidas e realinhadas. Elas ficam em
  bloco literal (`|`) no YAML, para o recuo não ser refluído.

## O que esta revisão não cobre

- **Os 90% fora da amostra.** A amostra mede uma taxa: 2 divergências em 50, das quais uma tem
  irmãos que foram corrigidos junto. Ela não prova que os outros 428 estão certos. Quem revisar o
  PR e ler o inglês das páginas geradas é a segunda verificação;
- **Os textos fora do escopo da #1312**, que continuam só em português e saem marcados `pt-BR` na
  página inglesa: a semântica das relações, o `rationale` das perguntas de competência, as notas e
  referências de proveniência, os exemplos, a descrição das ontologias, e as necessidades de
  informação e medidas.
