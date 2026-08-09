# Extensões à estratégia `one table per kind` para redes de ontologias

**Documento de trabalho** — registro das decisões que se afastam de Guidoni,
Almeida & Guizzardi (2020), com vistas a uma possível publicação.

**Status**: rascunho. As extensões estão implementadas e validadas sobre três das
doze ontologias da rede; a avaliação sistemática não foi feita.

---

## 1. Contexto

O The Band integra semanticamente dados de ferramentas de Engenharia de Software
contra uma rede de ontologias — UFO na camada fundacional, SEON no núcleo e
domínio, e Continuum como subrede de Continuous Software Engineering. São 220
conceitos em 12 ontologias, com altura máxima de hierarquia 5 e 148 classes
folha.

Gerar o esquema relacional a partir dessa rede exigiu adotar uma estratégia de
transformação. Escolhemos `one table per kind` por ser a única, entre as
avaliadas, que suporta simultaneamente generalizações sobrepostas e incompletas,
classificação dinâmica, herança múltipla e hierarquias ortogonais — todas
presentes no nosso modelo.

Ao aplicá-la, encontramos quatro pontos em que o método não decide, por tratar de
um recorte diferente do nosso. Este documento registra o que fizemos em cada um.

## 2. O que o método original estabelece

Guidoni et al. propõem três passos, guiados pelas meta-propriedades de
sortalidade e rigidez:

1. **Flattening** — não-sortais são achatados em direção às subclasses sortais.
2. **Lifting** — sortais que não são kinds sobem recursivamente até seus kinds,
   com atributos obrigatórios propagados como opcionais.
3. **Geração** — uma tabela por classe remanescente, com chaves estrangeiras de
   dependência.

O resultado do lifting depende do generalization set: disjunto produz
discriminador enumerado; sobreposto produz tabela discriminadora de
*qua-entities*; ausência de generalization set produz booleano.

## 3. Lacunas encontradas

| # | Lacuna | Por que aparece no nosso caso |
|---|---|---|
| L1 | O método transforma **um** modelo conceitual isolado | Nossa fonte é uma rede estratificada, com dependência entre ontologias |
| L2 | O método trata de **endurantes** | Nossos maiores agrupamentos são processos e atividades — perdurantes |
| L3 | O método não define **como reconhecer** o estereótipo | Conceitos vindos de ontologias de referência não trazem estereótipo OntoUML |
| L4 | A transformação **esconde o vocabulário** do domínio | Nossas 64 perguntas de competência estão escritas em conceitos, não em tabelas |

L1 e L2 são consequência do recorte do paper, não falhas dele. L3 e L4 são
efeitos colaterais que só aparecem em uso continuado.

## 4. Extensões propostas

### E1 — Redes de ontologias por referência

**Problema.** Um conceito de uma ontologia de domínio especializa um kind que
mora numa ontologia de núcleo. O método não diz onde a tabela deve ficar.

**Alternativa existente.** A tese que fundamenta o projeto resolve por
replicação: o mesmo conceito aparece em vários repositórios baseados em
ontologia, reconciliados por um identificador interno e sincronizados por
message broker. Faz sentido para serviços autônomos.

**Nossa decisão.** O kind mora na ontologia que o define; as demais referenciam.
Três regras:

- o kind é materializado uma vez, na ontologia que o introduz;
- o subtipo externo contribui um valor ao discriminador do kind;
- atributos próprios do subtipo viram tabela de extensão na ontologia dona,
  ligada por chave estrangeira.

**Justificativa.** Extensibilidade, sobretudo: uma ontologia nova aponta para os
kinds existentes e adiciona os seus, sem alterar nada do que já existe. Com
replicação, cada ontologia nova cria mais um lugar que precisa concordar com os
demais.

**Evidência.** CMPO, com 26 conceitos, produz 5 tabelas próprias e 1 tabela de
extensão, contribuindo 13 valores ao discriminador de SPO **sem alterar SPO**.

**Efeito colateral favorável.** A tabela do kind não acumula colunas nulas de
subtipos sem relação entre si. `sha`, `message`, `additions` e `deletions` vivem
na extensão do commit, não numa tabela que também guarda cerimônias de Scrum.

### E2 — Perdurantes tratados pelo mesmo teste, com critério de identidade declarado

**Problema.** Sortalidade e rigidez são definidas para endurantes. Processos e
atividades executadas são perdurantes, e concentram 45 e 28 subtipos na nossa
rede.

**Nossa decisão.** Não criar regra separada. Aplicar aos perdurantes o mesmo
teste que decide tudo: *os descendentes compartilham princípio de identidade?*
E tornar o teste operacional exigindo que o critério seja **declarado**:

```yaml
identity_criterion:
  form: composite_hash
  components: [tenant_id, organization_id, project_id, activity_type,
               performer_id, occurred_at, source_external_id]
  nullable_components: [performer_id, source_external_id]
  inherited_by_subtypes: true
```

**Consequência prática.** O teste vira uma pergunta respondível: *qual a chave
natural?* Se ela difere entre os descendentes, o conceito não é kind, é
`category`, e é achatado.

**Evidência do impacto.** Antes de aplicar o teste, tratávamos os conceitos
guarda-chuva como kinds, e o esquema resultava em 27 tabelas com o maior
agrupamento concentrando 45 subtipos. Aplicando o teste, `spo.artifact` e
`spo.performed_project_activity` revelam-se candidatos a `category`, e o esquema
passa a 82 tabelas com maior agrupamento de 13.

**Restrição descoberta.** O hash precisa cobrir apenas componentes
identificadores. Incluir atributo descritivo mutável — `end_date`, nulo enquanto
a atividade corre e preenchido ao terminar — faria o identificador mudar no
encerramento, orfanando toda referência. Componentes ausentes precisam de
representação canônica para que o hash permaneça determinístico: atividades
automatizadas não têm executor humano.

### E3 — Distinção entre `role` e `phase` na materialização

**Problema.** O método distingue os casos pela estrutura do generalization set.
Para roles sem generalization set, prescreve atributo booleano.

**Nossa observação.** O booleano registra a classificação e descarta o que a
sustenta. Um `role` é relacionalmente dependente: `is_under_integration = true`
não diz em qual processo, desde quando, nem admite dois simultâneos. Uma `phase`
é mudança intrínseca, e aí o discriminador basta — um processo de integração
contínua é bem-sucedido pelo próprio resultado.

**Nossa decisão.** Refinar a regra pela natureza do estereótipo:

| Estereótipo | Natureza | Materialização |
|---|---|---|
| `subkind` | rígida | discriminador enumerado |
| `phase` | intrínseca | discriminador enumerado ou booleano |
| `role` | **relacional** | relator; discriminador apenas como desnormalização |

**Ressalva importante.** O método original não está errado: ele pressupõe o
relator modelado ao lado, e nesse caso o discriminador é derivável e serve de
otimização de consulta. A pressuposição não vale em nossa base — 41 dos 44 roles
não têm relator declarado, o que é lacuna nossa e não do método. A extensão pode
ser lida como: *quando o relator não existe, o booleano não é desnormalização, é
perda de informação.*

### E4 — Reificação do papel como catálogo com vigência

**Problema.** Papéis fixados como valores de enum exigem migração para cada papel
novo, não têm temporalidade e não admitem acúmulo.

**Nossa decisão.** O papel é uma **linha** em tabela de catálogo, e o kind o
instancia por um período através do relator:

```text
organizational_roles     catálogo — uma linha por papel
people                   o kind que assume o papel
team_memberships         o relator: pessoa + equipe + papel + período
```

**Ganhos.** Papel novo é `INSERT`; começo e fim vivem no relator, e o histórico
sobrevive à saída da pessoa; papéis simultâneos são múltiplas linhas, sem
construção adicional; num sistema multitenant, cada organização define os seus.

**Custo.** Um join a mais para a pergunta "qual o papel desta pessoa" — aceitável
porque a pergunta útil quase nunca é essa, e sim "qual o papel desta pessoa
*nesta equipe*, *neste período*", que exigiria o join de todo modo.

### E5 — Views derivadas que restauram o vocabulário

**Problema.** Depois da transformação, `sprint`, `commit` e `developer` deixam de
ser tabelas: viram valor de discriminador, linha de relator ou junção com
extensão. Quem consulta precisa conhecer o modelo de informação, não o domínio.
Em nosso caso as 64 perguntas de competência estão escritas em conceitos.

**Nossa decisão.** Cada conceito absorvido reaparece como view, derivada junto
com o esquema pela mesma transformação:

| Forma de absorção | View |
|---|---|
| elevado com discriminador | filtra o discriminador, junta a extensão se houver |
| materializado por relator | junta kind, relator e catálogo, expondo vigência |
| elevado como fase | filtra o estado |

**Justificativa.** Custo zero de armazenamento, e o planner resolve o filtro como
se estivesse escrito na consulta. O esquema otimiza escrita e integridade; a
camada de views preserva a leitura pelo vocabulário do domínio.

**Ponto de método.** As views são derivadas, nunca escritas à mão — caso
contrário reintroduzem a divergência que a derivação existe para evitar.

## 5. Resumo das contribuições

| # | Contribuição | Natureza |
|---|---|---|
| E1 | Rede de ontologias por referência, com contribuição de discriminador e tabelas de extensão | extensão do método |
| E2 | Perdurantes pelo mesmo teste, com critério de identidade declarado | extensão do escopo |
| E3 | Materialização distinta para `role` e `phase` | refinamento |
| E4 | Papel reificado como catálogo com vigência | padrão de modelagem |
| E5 | Views derivadas que restauram o vocabulário do domínio | extensão do método |

E3 é refinamento condicional, não correção. E4 é padrão conhecido em modelagem
temporal, aqui derivado sistematicamente a partir do estereótipo em vez de
escolhido caso a caso.

## 6. Limitações

**Sem avaliação empírica.** Não há medição de desempenho sobre dados reais. As
comparações de tamanho de esquema são contagens estáticas, não benchmarks. O
argumento de que a tabela de extensão evita esparsidade é estrutural, não medido.

**Cobertura parcial.** Três das doze ontologias foram classificadas com
estereótipo OntoUML e derivadas: EO (10 conceitos → 6 tabelas), SPO (21 → 6) e
CMPO (26 → 5 + 1 extensão). As demais 163 concepções seguem sem classificação.

**Generalization sets não declarados.** A base não declara disjunção nem
completude, o que impede exercitar o caso de conjunto sobreposto — justamente
onde o método original propõe a tabela de *qua-entities*. As extensões aqui não
tocam nesse ponto.

**Uma única rede.** Todas as observações vêm de UFO + SEON + Continuum. Se as
extensões generalizam para outras redes é hipótese, não resultado. Os dez modelos
OntoUML usados na avaliação do paper original seriam a suíte natural para
testar.

**Classificação como fonte de erro.** A descoberta mais consequente deste
trabalho — que a god table era efeito de classificar um não-sortal como kind — é
também um alerta: os resultados dependem inteiramente da qualidade da
classificação, que é atividade humana e não verificável automaticamente.

## 7. Trabalhos relacionados a consultar

- Guidoni, Almeida & Guizzardi. *Forward Engineering Relational Schemas and
  High-Level Data Access from Conceptual Models.* ER 2021 — pode já cobrir parte
  do que tratamos como extensão.
- Trabalho do grupo sobre *multi-level modeling*, relevante para E4: o catálogo
  de papéis é reificação de tipo, que é matéria de modelagem multinível.
- Literatura de UFO-B sobre eventos, relevante para E2.

Verificar essas três frentes antes de tratar qualquer item da Seção 5 como
contribuição original.

## 8. Implementação

Regras declaradas em
[`priv/knowledge_base/transformations/ontology_to_information_model.yaml`](../../priv/knowledge_base/transformations/ontology_to_information_model.yaml)
— 19 regras em 5 passos, 9 delas marcadas como extensão deste projeto.

Derivação em [`scripts/derive_information_model.py`](../../scripts/derive_information_model.py).
Decisões e justificativas em [ADR 0004](../adr/0004-modelo-de-informacao-one-table-per-kind.md).
Questões abertas em [RFC 0001](../rfc/0001-derivacao-do-modelo-de-informacao.md).

## Referências

- Guidoni, G. L.; Almeida, J. P. A.; Guizzardi, G. **Transformation of
  ontology-based conceptual models into relational schemas.** ER 2020, Viena,
  Springer, p. 315–330.
- Carraretto, R. **Separating Ontological and Informational Concerns: A
  Model-driven Approach for Conceptual Modeling.** Dissertação de mestrado,
  UFES, 2012.
- Santos Júnior, P. S. **From Continuous Software Engineering Reference
  Ontologies to the Integration of Data for Data-Driven Software Development.**
  Tese de doutorado, UFES, 2023.
- Guizzardi, G. **Ontological foundations for structural conceptual models.**
  Tese de doutorado, University of Twente, 2005.
