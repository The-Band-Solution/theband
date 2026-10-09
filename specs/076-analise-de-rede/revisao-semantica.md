# Revisão semântica — 076, análise de rede

**Papel**: Ontology & Semantic Integration (AGENTS.md §13), que pode bloquear. **Data**: 2026-10-03.
**Issue**: #1309. **Objeto**: a aresta de designação pedida pela pessoa mantenedora (*"a da
referência (autor da issue → responsável)"*), as medidas da análise de rede e o papel de pessoa,
na forma de [`proposta-base/`](proposta-base/).

**Réguas**: AGENTS.md §6, §8 e §11; a constituição, princípios I, IV e VIII; os YAMLs de SRO, EO,
SPO, CMPO, QAPO e OSDEF em `priv/knowledge_base/ontology/`; os mapeamentos de issue em
`priv/knowledge_base/mappings/github/sro/` e `osdef/`; a coleta em `lib/the_band/work_items/` e
`lib/the_band/ingestion/github_work_items.ex`; o código da referência
(`dashboard_team_graph.py`); e o precedente da 073 (`specs/073-rede-de-revisao/revisao-semantica.md`).

**Declaração de independência**: este parecer foi escrito pelo mesmo agente que escreveu a spec e
a proposta da base. A independência que o princípio VII pede **não** está cumprida neste papel; a
avaliação de segurança é de outro agente, e a revisão semântica precisa de um segundo par de olhos
antes do plano (decisão D6).

---

## Veredito: **aprova com emendas, e com três decisões que bloqueiam o plano**

As emendas já estão na proposta. O núcleo se sustenta: a aresta pedida tem semântica que se pode
declarar, desde que **não** se chame colaboração nem delegação, e toda medida da referência pode
ser trazida com o defeito corrigido. O que bloqueia não é semântica errada, é escolha que não é
deste papel: D1 (qual aresta), D2 (os rótulos do papel) e D3 (como a conta da organização é
reconhecida). Sem as três, o plano não sabe o que calcular nem o que escrever na tela.

---

## 1. Achados

### S1 — Alto: a aresta da referência não é delegação; é designação sobre um item que outra pessoa abriu

O pedido chama a aresta de **delegação**, e ela é melhor que "colaboração", que é o nome da
referência. Mas o dado não sustenta nem delegação:

- **O autor não é quem designou.** `collected_issues.author_person_id` é quem abriu a issue;
  `issue_assignees.person_id` é quem está designado agora. Quem fez a designação é outro fato, e
  **a plataforma o coleta**: `AssignedEvent { actor { login } assignee { … } createdAt }`
  (`priv/connectors/github/queries/issues.graphql:86`), gravado como
  `spo.performed_project_activity` com o ator em `performer_id`
  (`lib/the_band/ingestion/github_work_items.ex:753-770`;
  `rules/github_timeline_event_vocabulary.yaml:53`). Quem se designa na issue de outra pessoa gera
  uma aresta autor → responsável sem ato nenhum do autor.
- **A designação não tem data.** `issue_assignees` não guarda quando a designação aconteceu
  (`lib/the_band/work_items/person_work.ex:112`; decisão de 2026-08-27).
- **O responsável não é quem executou.** O mapeamento de tarefa já o diz:
  *"Assignee indica quem foi designado, não necessariamente quem executou"*
  (`mappings/github/sro/issue_task.yaml:55`).

**Emenda aplicada**: a aresta chama-se **designação** (`assignment.network.edge`), com
`equivalence: partial` e a justificativa acima, e a primeira limitação diz que **não é delegação no
sentido estrito**. A tela (US2, cenário 5) diz, em uma frase, o que a aresta liga e o que não diz.

### S2 — Alto: a rede de ontologias não tem a relação, e as que parecem tê-la são de execução

Conferido nos ids:

| candidato | o que é | por que não serve |
|---|---|---|
| `spo.is_in_charge_of` (`seon/spo/modules/processes_and_activities.yaml:240`) | `spo.project_stakeholder` → `spo.performed_project_activity` | alvo é atividade **executada**; designação é sobre o item planejado |
| `sro.developer_in_charge_of_development_task` (`continuum/sro/modules/scrum_stakeholder_participation.yaml:55`) | `sro.developer` → `sro.performed_scrum_development_task` | idem, e exige o papel Scrum de desenvolvedor, que a designação não estabelece |
| `spo.participates_in` (`processes_and_activities.yaml:250`) | stakeholder → atividade executada | idem |
| relação `assignee` do mapeamento de tarefa (`mappings/github/sro/issue_task.yaml:47-50`) | issue → `eo.person` | é relação de **mapeamento**, sem id na ontologia; é a fonte usada |
| relação `author` / `reporter` (`issue_user_story.yaml:41-44`, `osdef/issue_bug.yaml:41`) | issue → `eo.person` | idem, do lado do autor |

Os conceitos do item existem — `sro.user_story`, `sro.intended_scrum_development_task`,
`sro.epic` e `osdef.defect` —, e `eo.person` e `spo.project_person_stakeholder` também. **A
relação "está designado como responsável pela tarefa pretendida" não existe na SRO.**

**Decisão deste papel**: a aresta é **regra derivada** sobre o que a coleta já integrou, como a
`review.network.edge` da 073 (A1 daquela revisão), e não relação nova. Usar `spo.is_in_charge_of`
faria designação parecer execução, que é a distinção planejado × executado do AGENTS.md §6.

**Recomendação fora desta feature**: abrir issue para a SRO declarar a designação sobre a tarefa
pretendida (provavelmente `sro.developer` → `sro.intended_scrum_development_task`, *"was assigned
to"*). Mudança de ontologia não entra numa feature de análise.

### S3 — Médio: a categoria UFO

**Relação derivada, sem relator, e não conceito da rede.** Os fundamentos são o ato de registrar
a issue (evento) e a designação vigente. Se há relator ali, é o **compromisso social** entre quem
designou (ou a organização) e o responsável — e o autor da issue **não participa dele**. Por isso a
aresta autor → responsável não pode ser lida como relator entre as duas pessoas. Consequências,
escritas em `assignment_network_edge.yaml` (`ufo_category`): sem id de conceito, sem módulo, sem
tabela de domínio com `internal_id`; a aresta vive só na leitura derivada.

### S4 — Médio: a intermediação passa a ser sem direção

A referência calcula sobre o grafo dirigido (`dashboard_team_graph.py:90`) e a lê como "ponte
entre grupos" (`:304`). Ponte entre grupos é pergunta sem direção. **Emenda aplicada**:
`network.analysis.parameters.betweenness` usa a projeção sem direção, com a razão escrita, e a
medida declara a mudança. Se a pessoa mantenedora quiser o número dirigido da referência, é
pergunta para o plano, e não muda a semântica do resto.

### S5 — Médio: o clustering da referência transforma ausência em zero

O networkx conta 0 para quem tem menos de 2 vizinhos. Na rede de designação, onde muita gente tem
um vizinho só, isso puxa a média para baixo e entra no σ. **Emenda aplicada**: o clustering local
de quem tem menos de 2 vizinhos é **indefinido**, fica fora da média, e o número é dito; a mesma
regra vale para os aleatórios, e a razão C/C_rand continua comparável.

### S6 — Alto: os rótulos do papel julgam a pessoa

*"Coordenador central"*, *"Hub de colaboração"*, *"Ponte entre equipes"* e *"Colaborador
especializado com foco limitado"* (`:497-507`) afirmam função, mérito ou juízo, e dois falam de
colaboração e de equipe, que nenhuma das duas arestas sustenta. A classificação em si — o quadrante
de dois percentis — é medida e pode ser declarada. **Emenda aplicada**: `network.position_role`
usa rótulos **posicionais** (*"Central position"*, *"Many direct links"*, *"On many paths"*,
*"Above the median in both"*, *"Few links, few paths"*, *"Mixed position"*), sempre com os dois
percentis e o corte ao lado; os da referência ficam em `reference_labels`. **Decisão D2.**

### S7 — Médio: o percentil da referência empurra grupos empatados para cima, e o corte de 30 não tem razão

- `:486-487` conta "menor ou igual". Com 40% da rede em intermediação zero, todos ficam no
  percentil 40, acima do corte de 30, e ninguém é "periférico". **Emenda aplicada**: posto médio.
- 80 é quintil e 50 é mediana; 30 não é quintil, tercil nem decil. **Emenda aplicada**: 20,
  simétrico ao 80, com a razão; o 30 da referência é a alternativa da **decisão D2**.
- Abaixo de 10 pessoas, o quinto superior tem uma pessoa por construção. **Emenda aplicada**:
  ninguém é classificado com menos de 10.

### S8 — Médio: a conta da organização não é inferível

O caso `LEDS` da referência é uma conta de usuário usada pela organização. Para a plataforma, ela
chega como `User`: `Mapper.account_type/1` devolve `person` para qualquer `__typename` que não seja
`Bot` ou `App`, e para login sem `[bot]` (`lib/the_band/semantic_integration/mapper.ex:94-101`), e
`eo_people.account_type` só admite `person`, `bot` e `app` (migração
`20260809120200_create_eo_information_model.exs:82-83`). Inferir pelo nome seria o "padrão largo
inventa mais". **Emenda aplicada**: o motivo de exclusão `organization_account` existe, e o
reconhecimento é por **declaração**. **Decisão D3**: quem declara, e onde.

### S9 — Médio: dois números de "grupos" na mesma área

A 073 declara `review.network.unconnected_groups.count` sobre o recorte do alcance (Q4). A 076
calcula as medidas estruturais sobre a rede inteira (FR-011), e por isso declara
`network.components.count`. Na página da rede de revisão, os dois podem aparecer, com valores
diferentes, para a mesma conta. É o caso do princípio X (*"um número que respondia outra
pergunta"*). **Emenda aplicada**: a limitação está nas duas direções, e a medida nova diz que a
tela não os põe lado a lado sem dizer qual é qual. A forma final é do protótipo, com a avaliação de
segurança.

### S10 — Baixo: faixas da modularidade

0,3 e 0,7 têm fonte na literatura (Clauset, Newman e Moore, 2004; Newman e Girvan, 2004), ao
contrário das outras faixas da referência. Mas grafos aleatórios pequenos e esparsos atingem Q de
0,3 por flutuação (Guimerà, Sales-Pardo e Amaral, 2004), que é o tamanho destas redes. **Emenda
aplicada**: Q aparece com Q_rand, e as faixas aparecem como **citação com a fonte**, nunca como
adjetivo da plataforma.

### S11 — Baixo: o σ, item por item

Os cinco defeitos da referência estão corrigidos em `network.analysis.parameters.small_world`:
todos os aleatórios entram; a média divide pelo número que entrou; a distância do aleatório segue
a regra da real; semente fixa (42) e 100 amostras; ausência no lugar de 0. Além disso: G(n, m) em
vez de G(n, p), para comparar com a mesma densidade; mínimo de 10 pessoas; leitura *"meets the
σ > 1 criterion"*, com a limitação de Telesford et al. (2011).

### S12 — Baixo: a janela e os responsáveis

Janela pela abertura da issue e só responsáveis vigentes: as duas são o que a referência faz, e as
duas estão nas limitações da aresta e da medida de issues. A alternativa com data é a da D1.

---

## 2. O que foi conferido e está certo

| conferência | resultado |
|---|---|
| ids citados na proposta | existem: `eo.person` (`seon/eo/modules/…`), `spo.project_person_stakeholder`, `sro.user_story` (`continuum/sro/modules/product_and_sprint_backlog.yaml:26`), `sro.intended_scrum_development_task`, `sro.epic`, `osdef.defect` (`seon/osdef/modules/defects_and_failures.yaml:24`), `qapo.artifact_evaluation`, `qapo.stakeholder_performed_artifact_evaluation`, `qapo.artifact_evaluation_evaluates`, `cmpo.change_request`, `cmpo.change_request_submission`, `cmpo.stakeholder_submitted_change_request`, `cmpo.submission_produced_change_request` |
| dependência entre ontologias | a proposta não cria relação nem conceito; as regras são globais; `mix knowledge.graph` na cópia dá `EXIT=0` |
| PR ≠ merge | a rede de revisão é a da 073, sem mudança |
| pessoa ≠ membro de equipe | nó é `eo.person` com `account_type = 'person'`; equipe não entra |
| comunidade ≠ equipe | dito em `network.communities.count`, na spec (FR-030) e na necessidade |
| planejado ≠ executado | a designação é sobre o item planejado, e a proposta recusa as relações de execução (S2) |
| nunca por semelhança de nome | a aresta é justificada pela estrutura (autor e responsável da mesma issue), e o nome "delegação" foi recusado por isso |
| §11, cada medida | as 20 têm necessidade, fórmula com `inputs`, unidade, `levels`, `filters`, `period`, `limitations`, `misinterpretations` e proveniência; as de algoritmo citam a literatura |
| ausência nunca zero | toda medida nomeia o motivo; o único zero de definição (eficiência de par sem caminho) está escrito como definição |

---

## 3. Decisões que ficam com a pessoa mantenedora

| # | pergunta | opções | recomendação |
|---|---|---|---|
| **D1** | qual aresta é a "da referência"? | (a) autor da issue → responsável vigente, janela pela abertura — **igual à referência**; (b) quem designou → designado, pelo `AssignedEvent`, com a data do evento — é delegação de verdade, mas não é o que a referência desenha | **(a)**, como foi pedido, com o nome "designação" (S1). (b) fica como rede futura, se a pergunta for "quem distribui trabalho" |
| **D2** | os rótulos do papel e o corte baixo | (a) rótulos posicionais e corte 20 (a proposta); (b) rótulos da referência e corte 30 | **(a)**. Os rótulos da referência dizem colaboração e equipe, que a aresta não sustenta, e o 30 não tem razão |
| **D3** | como a conta da organização é reconhecida | (a) quem administra marca a conta como "da organização" na tela de pessoas, com registro de quem marcou; (b) lista de logins na base de conhecimento, por tenant; (c) não reconhecer, e declarar a limitação | **(a)**. (b) põe dado de tenant na base global, que o AGENTS.md §7.4 proíbe sem feature; (c) repete o defeito da referência |
| **D4** | intermediação sem direção (S4) ou dirigida como a referência | (a) sem direção; (b) dirigida | **(a)**, pela pergunta que a tela faz |
| **D5** | o clustering exclui quem tem menos de 2 vizinhos (S5) | (a) excluir e dizer quantos; (b) contar 0, como o networkx | **(a)**: ausência não é zero |
| **D6** | a independência desta revisão | (a) um segundo revisor do papel semântico antes do plano; (b) aceitar com a lacuna declarada | **(a)** |

---

## 4. Validação, com o código de saída

Cópia de `priv/knowledge_base/` num diretório único do scratchpad
(`…/scratchpad/kb-076-a7-1791078648`), com os 24 YAMLs de [`proposta-base/`](proposta-base/)
sobrepostos e a `review_network_parameters.yaml` emendada no lugar da original. Saída redirecionada
para arquivo, código lido direto do `mix`.

| comando | EXIT | resultado |
|---|---|---|
| `mix knowledge.validate priv/knowledge_base` (base, sem a proposta) | 0 | 148 artefatos: 17 medidas, 9 necessidades, 27 regras |
| `mix knowledge.validate <cópia>` | 0 | 172 artefatos: 37 medidas, 10 necessidades, 30 regras (+20, +1, +3) |
| `mix knowledge.graph <cópia>` | 0 | 33 módulos, dependências íntegras |
| vista reprovando: `network.small_world_sigma.score` respondendo a `network.estrutura_inexistente`, com `campo_inventado` | **1** | *"network.small_world_sigma.score responde a network.estrutura_inexistente, que não existe"* e *"campo campo_inventado não está declarado no schema"* |
| a mesma medida restaurada, conferida com `cmp` contra a proposta | — | idêntica |
| `scripts/validate_knowledge_base.py --kb <cópia>` | 1 | 172 arquivos, 37 medidas; o único problema é `jsonschema` não instalado — o mesmo da 073 |

## 5. O que não verifiquei

- **As regras**: `derivation_rule` não tem schema em `schemas/` (lacuna da 073, research R11), e as
  três regras novas foram conferidas só pela forma das existentes.
- **Os números**: nenhuma medida foi calculada contra o banco; o volume da maior organização em 180
  dias é o #1190.
- **Quantas issues têm autor ≠ quem designou**: a medida que diria quanto a aresta (a) se afasta de
  (b) na D1 exige consulta ao banco de produção, que este papel não fez.
- **Perguntas de competência**: não foram escritas. Cabem no plano, depois da D1, porque mudam com
  a aresta escolhida.
