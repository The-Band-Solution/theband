# ADR 0002 — YAML versionado como base de conhecimento declarativa

## Status

Aceita — 2026-08-08

## Contexto

O modelo conceitual do The Band — 12 ontologias, 219 conceitos, 141 relações, 64
perguntas de competência — é o ativo central do sistema. É ele que distingue a
plataforma de um data lake com dashboards.

Esse modelo precisa de propriedades que código Elixir sozinho não oferece bem:

- **ser revisável por quem entende do domínio**, incluindo quem não lê Elixir;
- **ser versionado semanticamente**, com diff que mostre a mudança conceitual;
- **carregar proveniência**, apontando para a seção da tese que originou cada conceito;
- **ser validável mecanicamente** — referências, ciclos, cardinalidades, campos
  obrigatórios;
- **ser a mesma fonte** para o código, a documentação e os testes conceituais.

Se conceitos vivessem apenas em módulos e schemas Ecto, uma mudança conceitual
apareceria espalhada por schema, migração, changeset e documentação — e a documentação
divergiria do modelo real em semanas.

## Decisão

O modelo conceitual vive em **`priv/knowledge_base/`, como YAML versionado, validado e
revisado**. O código Elixir carrega esse modelo; não o duplica.

A base cobre: ontologias e seus metadados, conceitos, relações, cardinalidades,
restrições, perguntas de competência, mapeamentos entre fontes e ontologias,
necessidades de informação, medidas, glossário, regras e exemplos.

Regras que acompanham a decisão:

- todo YAML tem schema em `schemas/`, versão, identificador estável, dependências
  declaradas e proveniência;
- campos desconhecidos são rejeitados quando o schema é estrito;
- validação roda no CI e falha o build;
- mudança que altere semântica, contrato ou comportamento exige teste e revisão
  semântica;
- nenhum YAML contém token, senha ou credencial;
- carregamento acontece em compile time, boot ou cache controlado — **nunca** leitura
  de disco por requisição;
- a documentação em `docs/ontology/` é **gerada** da base, e não editada à mão.

Granularidade: **um arquivo por módulo/subontologia**, não por conceito. Um conceito por
arquivo geraria ~200 arquivos e faria conceito e relações aparecerem em diffs separados,
tornando ilegível a revisão de uma mudança semântica. O módulo é a mesma granularidade
dos módulos Elixir correspondentes.

## Alternativas consideradas

**Conceitos como módulos Elixir, direto no código.** Elimina a etapa de carga e dá
verificação de tipo, mas perde a revisibilidade por não-programadores, dilui a
proveniência em comentários e faz a documentação divergir. A mudança conceitual deixa
de ser um diff conceitual.

**OWL/RDF com um triplestore.** É o formato nativo de ontologias e traria raciocínio
automático de graça. Custa uma dependência de infraestrutura pesada, uma linguagem que
a equipe não domina, e ferramental distante do fluxo de revisão em Pull Request. O
ganho de raciocínio não é necessário para o caso atual: as verificações que importam —
referências, ciclos, cardinalidades — são obtidas com validação de schema.

**Tabelas no banco, editáveis por interface.** Facilitaria edição por usuários finais,
mas tira o modelo do controle de versão. Uma mudança conceitual passaria a ser um
`UPDATE` sem revisão, sem histórico legível e sem vínculo com o código que depende dela.

**JSON Schema com arquivos JSON.** Equivalente em capacidade, mas sem comentários e com
sintaxe mais ruidosa para texto multilinha — e as definições dos conceitos são textos
longos, em dois idiomas.

## Consequências

**Positivas**

- A mudança conceitual é um diff legível, revisável por quem entende de ontologia.
- Proveniência fica junto do conceito, apontando para a seção da tese.
- Validação mecânica pega referência quebrada, ciclo de dependência e conceito órfão
  antes do merge.
- Documentação gerada não diverge do modelo, porque é derivada dele.
- Teste conceitual e perguntas de competência leem a mesma fonte que o código.

**Negativas**

- Existe uma camada de carga e cache a construir e manter.
- YAML não dá verificação de tipo em tempo de compilação; a rede de segurança é a
  validação de schema.
- Há risco de divergência entre a base e os schemas Ecto se não houver teste que amarre
  os dois.

**Mitigações**

- `mix knowledge.validate`, `knowledge.graph`, `knowledge.compile`, `knowledge.test` e
  `knowledge.diff` como portas obrigatórias no CI.
- Testes conceituais por ontologia verificando que schemas Ecto refletem os conceitos
  declarados.
- Nenhuma leitura de disco em tempo de requisição — carga controlada e cacheada.
