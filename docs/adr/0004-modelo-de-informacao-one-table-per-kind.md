# ADR 0004 — Modelo de informação derivado da ontologia por `one table per kind`

## Status

Aceita — 2026-08-09

Depende de: [ADR 0002](0002-yaml-como-base-de-conhecimento.md), [ADR 0003](0003-organizacao-por-ontologias.md)
Questões em aberto que esta ADR não resolve: [RFC 0001](../rfc/0001-derivacao-do-modelo-de-informacao.md)

## Contexto

A base de conhecimento declara 219 conceitos em 12 ontologias. Gerar o banco a
partir dela exige uma decisão que estava implícita e não registrada: **o modelo
ontológico não é o modelo do banco**.

A tese que fundamenta o projeto nomeia essa distinção. Citando Carraretto (2012),
Seção 5.3:

> An information model concerns what kind of information may be stored and
> exchanged considering demands of specific agents (the "recorded world"), while
> an ontology model concerns metaphysical aspects of a domain (i.e., it concerns
> what is considered to exist in the "real world").

E define o papel do resultado:

> the information model represents the canonical/common data model to be used to
> share and exchange data between OBSs

Sem essa camada intermediária, cada distinção metafísica viraria uma tabela. Uma
primeira derivação manual, feita antes desta decisão, produziu 94 entidades a
partir dos 219 conceitos — mas por curadoria, sem método declarado e sem
possibilidade de auditoria ou regeneração.

O problema, então, não era *se* reduzir, e sim **por qual método**, e como manter
esse método explícito e verificável.

## Decisão

Adotar a estratégia **`one table per kind`** de Guidoni, Almeida & Guizzardi
(2020), aplicada sobre a base de conhecimento e declarada como artefato
versionado em `priv/knowledge_base/transformations/`.

O modelo de informação é **derivado**, nunca escrito à mão. Editá-lo diretamente
o faria divergir da ontologia — o mesmo erro que a [ADR 0002](0002-yaml-como-base-de-conhecimento.md)
evita para a documentação.

### Resumo das decisões

| # | Decisão | Origem | Explicação |
|---|---|---|---|
| D1 | Adotar `one table per kind` | Guidoni et al. (2020) | A tabela pousa no **Kind**, que é o tipo que fornece o princípio de identidade — aquilo que permite dizer se dois registros são o mesmo indivíduo. Tipos que não fornecem identidade própria (`subkind`, `role`, `phase`) não ganham tabela: são absorvidos no kind. Isso resolve por construção as quatro lacunas que o paper aponta nas estratégias dominantes — generalização sobreposta, generalização incompleta, herança múltipla e hierarquias ortogonais — porque a chave primária mora num único lugar e nunca se move. As alternativas falham justamente nas transições mais comuns do nosso domínio: em `one table per class` e `per leaf class`, reclassificar um entregável de não aceito para aceito exigiria `DELETE` mais `INSERT`, quebrando toda referência existente. |
| D2 | Suprimir a camada fundacional; manter core e domínio | Tese, §5.3 | A UFO existe para **categorizar** os conceitos das outras camadas, não para descrever o domínio da aplicação. `ufo.object` e `ufo.event` não são coisas sobre as quais o The Band tem dados — são a gramática usada para classificar as coisas sobre as quais ele tem dados. Replicá-las como tabelas criaria linhas sem referente no mundo. A classificação permanece na base de conhecimento como metadado, onde continua servindo para validação e para guiar esta própria transformação. |
| D3 | Preservar associações herdadas de categoria suprimida | Tese, §5.3 | Suprimir a categoria não pode suprimir o que ela fundamenta. `caused by`, entre processo pretendido e executado, é definida em nível fundacional; se sumisse junto com a categoria, não haveria como ligar o que foi planejado ao que foi executado — e toda análise de aderência entre plano e realidade, que é uma das razões de o sistema existir, deixaria de ser possível. |
| D4 | Modelo de informação derivado, nunca escrito à mão | Coerência com ADR 0002 | Se o esquema pudesse ser editado diretamente, ele divergiria da ontologia em semanas, e passaria a haver duas verdades sobre o mesmo domínio — sem que ninguém soubesse qual está certa. Derivando, uma correção conceitual se propaga ao banco por regeneração, e qualquer divergência entre os dois vira falha de build em vez de descoberta tardia. É a mesma razão pela qual `docs/ontology/` é gerado. |
| D5 | `role` materializa por relator; `phase` e `subkind`, por discriminador | Refinamento nosso sobre o paper | A distinção é entre dependência **relacional** e mudança **intrínseca**. Um `role` só existe em relação a outra coisa: ninguém é "membro de equipe" no vácuo, é membro *daquela* equipe, *naquele* período. Uma coluna booleana registra a classificação e descarta exatamente isso — o contexto, a temporalidade e a possibilidade de acúmulo. Já uma `phase` é estado do próprio indivíduo: um processo de CI é bem-sucedido ou malsucedido por conta do próprio resultado, sem referência a terceiros, e aí o discriminador basta. O paper admite booleano para roles porque pressupõe o relator modelado ao lado; como 41 dos nossos 44 roles não têm relator, essa pressuposição não vale aqui. |
| D6 | `role` reificado como catálogo, instanciado por período via relator | Decisão própria, validada na EO | Papel vira **linha**, não valor de enum. Isso torna a extensão barata — um papel novo é um `INSERT`, não uma migração —, coloca começo e fim no relator, permite acúmulo simultâneo sem construção adicional, e deixa cada organização definir seus próprios papéis num sistema multitenant. O custo é um join a mais para perguntar "qual o papel desta pessoa", aceitável porque a pergunta útil quase nunca é essa, e sim "qual o papel desta pessoa **nesta equipe**, **neste período**" — que exigiria o join de todo modo. |
| D7 | Eventos são `append-only`; situações não são materializadas | Extensão nossa | O paper trata de **endurantes** e não cobre nenhum dos dois casos. Evento registra algo que ocorreu: atualizar uma falha para dizer que ela não ocorreu reescreveria o passado, então correções entram como novos registros. Situação é a realidade antes e depois de um evento, integralmente derivável dos instantes dele; persistir em separado criaria três lugares para discordarem sobre o mesmo fato. |

### Política de camadas — da tese, Seção 5.3

| Camada | Tratamento | Explicação |
|---|---|---|
| Fundacional (UFO) | suprimida | Categoriza as demais camadas e não contém conceitos do domínio da aplicação. Não há dado a guardar sobre `ufo.object` — ele é a régua, não o medido. |
| Core (EO, SPO, SysSwO) | mantida | Contém os conceitos que dão identidade a quase tudo: pessoa, organização, projeto, artefato, item de software. É onde a maioria das tabelas pousa. |
| Domínio | mantida | Contém as especializações que o usuário reconhece pelo nome — sprint, pull request, pipeline. A tese exige mantê-las para que cada ontologia possa sustentar seu serviço e seu repositório. |
| Associações herdadas de categoria suprimida | **mantidas** | Ver D3: a relação sobrevive à supressão da categoria que a definiu, senão perde-se o vínculo entre planejado e executado. |

### Estratégia de transformação — do paper, três passos

1. **Flattening** — não-sortais (`category`, `role_mixin`, `mixin`) são achatados
   em direção às subclasses sortais, com replicação de atributos. Não-sortal
   classifica indivíduos de kinds diferentes; não há tabela possível para ele sem
   misturar princípios de identidade.
2. **Lifting** — sortais que não são kinds (`subkind`, `role`, `phase`) são
   elevados recursivamente das folhas até seus kinds, com atributos obrigatórios
   propagados como opcionais.
3. **Geração** — uma tabela por classe remanescente; entidades existencialmente
   dependentes recebem chave estrangeira obrigatória para aquilo de que dependem.

### O que o lifting produz — refinado além do paper

O paper distingue os casos pela estrutura do generalization set. Adotamos essa
regra **e a refinamos pela natureza do estereótipo**, porque a distinção entre
papel e fase importa aqui:

| Estereótipo | Natureza | Materialização | Explicação |
|---|---|---|---|
| `subkind` | rígida | discriminador enumerado | O indivíduo é daquele subtipo por toda a sua existência e nunca deixa de ser. A distinção é permanente e exclusiva, então cabe num único valor. `eo.project_team` e `eo.organizational_team` viram `eo_teams.type`. |
| `phase` | **intrínseca** | discriminador enumerado; booleano se não houver generalization set | O indivíduo muda de fase ao longo da vida, mas por conta de **propriedade própria**, sem depender de vínculo com terceiros. Um processo de CI é bem-sucedido pelo próprio resultado. Como a mudança é intrínseca, ela cabe numa coluna que se atualiza — e a reclassificação vira `UPDATE`, sem mover a linha. |
| `role` | **relacional** | **relator / tabela de qua-entity**; discriminador apenas como desnormalização opcional | O papel só existe em relação a algo, e a coluna perderia justamente essa relação. `codes.is_under_integration = true` não diz em qual processo, desde quando, nem admite dois processos simultâneos. O relator guarda as três coisas e ainda permite acúmulo por múltiplas linhas. |
| generalization set sobreposto | — | tabela discriminadora de qua-entities | Quando o indivíduo pode estar em vários subtipos ao mesmo tempo, nenhum valor único serve. O paper introduz uma tabela cujas linhas são qua-entities, cada uma ligando o portador a um dos subtipos que ele assume — é assim que uma pessoa com dupla nacionalidade é representada sem duplicar a pessoa. |

O refinamento existe porque um `role` é relacionalmente dependente: ele só existe
em relação a algo. Um booleano `is_under_integration` no código registra a
classificação e perde o que importa — em qual processo, desde quando, e se há
mais de um simultaneamente. Para `phase`, que é mudança intrínseca, o
discriminador basta.

O paper pode usar booleano para roles porque no OntoUML bem modelado o relator já
existe ao lado, e o discriminador é derivável dele. Nossa base ainda não está
nessa condição — ver [RFC 0001](../rfc/0001-derivacao-do-modelo-de-informacao.md), Q6.

### Role reificado: catálogo mais relator com período

Decorre do anterior e é decisão própria: o `role` vira **tabela de catálogo**, e
o kind o instancia **por um período**, através do relator.

```text
eo_organizational_roles      catálogo — uma linha por papel
eo_people                    o kind que assume o papel
eo_team_memberships          o relator: pessoa + equipe + papel + período
```

O que isso compra, comparado a um discriminador na tabela do kind:

- **Extensibilidade** — papel novo é uma linha, não uma migração de enum.
- **Temporalidade** — começo e fim vivem no relator, e o histórico sobrevive à
  saída da pessoa.
- **Acúmulo** — várias linhas de relator expressam papéis simultâneos sem
  qualquer construção adicional.
- **Multitenancy** — cada organização define seus próprios papéis.

O custo é um join a mais para responder "qual o papel desta pessoa", o que é
aceitável dado que a pergunta correta quase nunca é essa, e sim "qual o papel
desta pessoa **nesta equipe**, **neste período**" — que exigiria o join de
qualquer forma.

Validado por derivação sobre a EO: 9 conceitos produzem 5 tabelas, e
`eo.team_member` é absorvido em `eo.person` sem virar coluna.

### Extensões próprias, fora do escopo do paper

O paper trata de **endurantes**. Duas regras são nossas e estão marcadas como
`source_of_rule: proposed`:

- **Eventos são append-only.** Registram algo que ocorreu; corrigir por
  atualização reescreveria o passado.
- **Situações não são materializadas.** São deriváveis dos instantes do evento;
  persistir criaria três lugares para discordarem entre si.

## Alternativas consideradas

**One table per class** (uma tabela por classe, joins na hierarquia). Com `h=5`
no nosso modelo, custa até 5 joins para ler uma entidade, e a reclassificação
exige `DELETE` mais `INSERT` — quebrando integridade referencial exatamente nas
transições mais comuns do domínio: entregável que passa a ser aceito, pipeline
reexecutado com sucesso, defeito que se manifesta como fault.

**One table per leaf class.** Produziria 148 tabelas, e uma consulta polimórfica
exigiria união de 148. Pior: não representa generalização sobreposta — alguém que
assume dois papéis ao mesmo tempo precisaria existir em duas tabelas com duas
chaves primárias — nem incompleta, já que quem não assume papel nenhum não teria
onde existir. Ambos os casos são cotidianos aqui.

**One table per hierarchy.** Daria 26 tabelas e bom desempenho em consulta
polimórfica, mas não suporta herança múltipla, e concentraria 46 subtipos numa
única tabela de atividades executadas.

**Curadoria manual, sem método.** Foi o ponto de partida e produziu um resultado
plausível, mas não auditável, não regenerável, e sem critério para resolver
divergências.

## Consequências

**Positivas**

- A redução deixa de ser opinião e passa a ser derivação auditável.
- Reclassificação vira `UPDATE` de discriminador: a linha não se move, a chave
  não muda, nada aponta para o vazio.
- Generalizações sobrepostas, incompletas, herança múltipla e hierarquias
  ortogonais passam a ser representáveis — as quatro lacunas que o paper aponta
  nas estratégias dominantes.
- A chave primária mora na tabela do kind, então o indivíduo existe
  independentemente dos papéis que assume.
- Uma correção conceitual na ontologia se propaga ao esquema por regeneração.

**Negativas**

- Consulta polimórfica pode exigir até `nk` uniões quando o atributo está num
  não-sortal que classifica todos os kinds.
- A transformação depende de metadados que a base **ainda não declara**: o
  estereótipo OntoUML de 142 dos 207 conceitos, e os generalization sets. Sem
  eles, o método não roda de fato.
- Reificar os relatores dos roles aumenta o número de tabelas, ainda que sejam
  tabelas estreitas.

**Riscos aceitos**

- O método não cobre perdurantes, e processos e atividades executadas são
  perdurantes. Tratá-los por analogia é decisão nossa, registrada como questão
  aberta.
- A escolha da fronteira de aplicação — rede inteira, ontologia ou módulo — muda
  o resultado de 26 para 94 tabelas e permanece em aberto.

## Verificação

`scripts/validate_knowledge_base.py` valida a base contra os schemas, incluindo
`transformation.schema.yaml`. A derivação do modelo de informação, quando
implementada, deve ser reprodutível: mesma base e mesmas regras produzem o mesmo
modelo, e qualquer divergência é falha de build.

## Referências

- Guidoni, G. L.; Almeida, J. P. A.; Guizzardi, G. **Transformation of
  ontology-based conceptual models into relational schemas.** ER 2020, Viena,
  Springer, p. 315–330. Implementação de referência:
  [nemo-ufes/ontouml2db](https://github.com/nemo-ufes/ontouml2db)
- Carraretto, R. **Separating Ontological and Informational Concerns: A
  Model-driven Approach for Conceptual Modeling.** Dissertação de mestrado,
  UFES, 2012.
- Santos Júnior, P. S. **From Continuous Software Engineering Reference
  Ontologies to the Integration of Data for Data-Driven Software Development.**
  Tese de doutorado, UFES, 2023 — Seção 5.3.
