# Pesquisa — Feature 004: issues e projetos

Seis questões que a spec deixou para o plano resolver. Cada uma com decisão,
razão e o que foi considerado e recusado.

---

## R1 — Repositório vira tabela, ou fica dentro do payload?

**Decisão**: tabela própria, `cmpo_source_repositories`, derivada de
`cmpo.source_repository`.

**Razão**: o repositório é o **escopo da marca de ausência** (FR-010). Um escopo
que vive dentro de um payload JSON não pode ser o lado de um `subquery`, e a
consulta de ausência precisa exatamente disso — foi o que a L19 mostrou custar.
Além disso, o tenant precisa excluir um repositório da observação (FR-004), e
exclusão é estado de um registro, não campo de payload.

O conceito **já existe na base** e não precisa ser criado:

```yaml
- id: cmpo.source_repository
  classification: { ufo_category: disposition, ontouml_stereotype: subkind,
                    parent: sys_swo.loaded_software_system_copy }
```

**Consequência que o plano tem de tratar**: sendo `subkind` de um kind da
SYS_SWO, o derivador o **eleva** — ele contribui um valor de discriminador na
tabela de `sys_swo.loaded_software_system_copy`, que **não existe**, porque
SYS_SWO tem 11 conceitos sem `ontouml_stereotype`.

**Duas saídas, e a escolha**:

| Saída | Custo |
|---|---|
| anotar os 11 conceitos da SYS_SWO e derivar a tabela base | trabalho de ontologia numa terceira ontologia, dentro desta feature |
| **declarar `cmpo.source_repository` como `kind`** | contradiz o `parent` declarado, exatamente a decisão que a SRO tomou no sprint 003 |

**Escolhido**: anotar a SYS_SWO. A razão é diferente da que valeu para a SRO. Lá,
`user_story` como `kind` deixava a SRO fechada e autossuficiente. Aqui,
`source_repository` **não é o conceito central da feature** — issue é —, e forçá-lo
a `kind` faria a plataforma afirmar que um repositório tem princípio de identidade
próprio, quando ele é uma cópia carregada de sistema de software. São 11 conceitos,
e o repositório é o primeiro de vários que virão da SYS_SWO.

**Recusado**: guardar repositório apenas como `raw_payload`. Impediria FR-004 e
FR-010, que são o núcleo da feature.

---

## R2 — Onde mora a promoção de uma issue a um conceito?

**Decisão**: tabela própria de promoção — `issue_promotions` — na camada de
plataforma, ligando a issue coletada ao conceito de destino, com a regra e a
versão que decidiram.

**Razão**: a promoção **não é um conceito ontológico**. Não existe em SRO um
conceito "promoção de issue"; ela é o registro de uma decisão da plataforma sobre
como interpretar um dado externo. Colocá-la no domínio faria a rede ontológica
carregar um artefato do integrador — o oposto do princípio II.

E ela precisa ser uma tabela, não um campo:

| Precisa guardar | Por quê |
|---|---|
| conceito declarado e conceito derivado | FR-013 exige registrar a divergência, não só o resultado |
| regra e versão | FR-012; a regra tem `status: proposed` e vai mudar |
| motivo, quando não promove | FR-014; a lacuna é contada por motivo |

**Recusado**: coluna `promoted_to` na issue coletada. Guardaria o resultado e
perderia a divergência, que é o dado mais interessante para quem administra o
processo — e é o que FR-035 manda mostrar na tela.

**Recusado**: derivar a promoção em consulta, sem persistir. A regra é versionada
e muda; uma consulta responderia sempre com a regra de hoje, e a resposta para
"por que esta issue foi classificada assim em março" desapareceria.

---

## R3 — Épico contra atômica: onde a classificação vive?

**Decisão**: **não vive em lugar nenhum como valor gravado.** É derivada da
existência de partes, em consulta, exatamente como `observation_ended?/1` deriva
o estado da observação do último evento.

**Razão**: ADR 0004 D7 e FR-015. A derivação da SRO já produz a forma:

```
sro_user_stories.status  {atomic_user_story, epic}
```

O `status` é **discriminador de `phase`**, e phase é mudança intrínseca de
situação — uma user story vira épico ao ser decomposta e deixa de ser ao perder
as partes. Gravar o valor reintroduziria situação materializada, que é a dívida do
`connected_tools.status` ainda em aberto. Não se abre uma segunda.

**O que é persistido**: os **vínculos de decomposição**, que são fatos observados.
A classificação sai deles.

**Consequência de desenho**: a coluna `status` que o derivador imprime existe na
saída da derivação e **não será materializada nesta feature**. Isso precisa ficar
escrito na migração, ou a próxima pessoa a acrescenta achando que faltava.

---

## R4 — Sub-issues: uma tabela de vínculos, e o ciclo

**Decisão**: tabela de vínculos de decomposição com o par (pai, parte), mais uma
tabela de vínculos **recusados** com o motivo.

**Razão**: `sro.rule04` exige hierarquia acíclica, e o próprio axioma diz como
verificar:

> Verificar no comando de registro, antes de persistir. Uma constraint de banco
> sozinha não pega ciclo transitivo em auto-relacionamento; é preciso checar o
> caminho até a raiz.

Logo: a verificação é no comando, não no banco. E o vínculo recusado precisa
sobreviver — FR-017 manda nomear o caminho que fecha o ciclo, e um vínculo
descartado em memória não tem como ser nomeado depois.

**Recusado**: recusar a **issue** quando o vínculo fecha ciclo. A issue existe no
GitHub; recusá-la faria a plataforma esconder dado observado por causa de uma
relação inválida. Recusa-se o vínculo, e as duas issues permanecem coletadas.

**Recusado**: `check_constraint` no banco. Não pega ciclo transitivo, como o
axioma já registra.

---

## R5 — Campos configuráveis de Projects v2

**Decisão**: três tabelas — definição de campo, valor de campo por item, e um
mapeamento **declarado por tenant** na base de conhecimento ligando campo a
atributo da ontologia.

**Razão**: o campo é configurável por projeto, e o mapeamento é **semântica**, que
o princípio IV manda declarar em YAML versionado. Já existe a convenção:
`rules/tenants/<tenant>.yaml`, prevista pela regra de roteamento de issues.

**A identidade do campo é o identificador, não o nome** (FR-027). Renomear
"Priority" para "Prioridade" não pode criar um campo novo, e não pode invalidar o
mapeamento.

**Valor sem mapeamento é guardado e marcado como não interpretado** (FR-025). É a
aplicação direta de um antipandrão declarado no `AGENTS.md` §7.7 — *mapeamento por
semelhança de nome*. Um campo chamado "Priority" **não** é `importance`: importance
é decimal com escala declarada, e Priority é seleção única cujos valores o tenant
inventou.

**Recusado**: inferir o mapeamento do nome do campo. É o antipadrão nomeado.

**Recusado**: guardar valores num `jsonb` na linha do item. Impediria a consulta
"quais itens têm valor neste campo" sem varrer todos os itens, e FR-023 pede o
valor de cada campo em cada item.

---

## R6 — Iteração e sprint

**Decisão**: a iteração é coletada como **configuração do projeto** e promovida a
`sro.sprint` apenas quando a data de início já passou. Proveniência de derivação,
declarando que a origem é configuração de projeto e não observação de processo.

**Razão**: `sro.sprint` é `complex_action` — algo que **ocorreu**. Uma iteração
configurada para começar em duas semanas não ocorreu. Promovê-la afirmaria um
sprint que não existe, e toda medida de vazão passaria a incluir sprints futuros
com zero entregas.

**O que fica torto, declarado**: a data de início da iteração é **planejamento**,
não observação. Um sprint que começou atrasado terá, na plataforma, a data que o
projeto dizia — e não a que ocorreu. Isso já aconteceu neste próprio repositório
duas vezes, e está registrado nas reviews dos sprints 002 e 003. A feature não
resolve, e não deve fingir que resolve: a data observada exigiria o histórico de
itens, que está fora de escopo por custo.

**Recusado**: promover toda iteração. Afirmaria sprints futuros.

**Recusado**: não promover nenhuma. Deixaria `sro.sprint` vazio, e com ele todo o
`sro.rule01` — que liga tarefa executada a user story do sprint backlog — sem dado
para verificar.

---

## O que não precisou de pesquisa

| Questão | Já estava decidido, e onde |
|---|---|
| tipo de issue desconhecido | `github.issue_type_routing`, `fallback: skip` |
| estrutura contra rótulo | mesma regra, `precedence: structure_over_declaration` |
| tarefa não compõe user story | `precedence_rationale` da mesma regra, com o caso escrito |
| paginação, cursor, retomada | runtime declarativo do conector, feature 001 |
| limite de consumo | `rate_limit` na definição do conector, com `pause_when` |
| payload preservado | `raw_payloads` com `mapping_id` e `mapping_version` |
| ferramenta com observação encerrada | `list_observed_tools/1`, feature 003 |

---

## R7 — Auditoria dos conceitos: o que existe de fato na base

Feita a pedido da pessoa mantenedora, antes de fixar o plano. **Dois dos meus
requisitos contrariavam a matriz de cobertura que já existia**, e foram corrigidos.

### Repositório

Não existe `code_repository` nem nada parecido. Existe **um** conceito:

```yaml
- id: cmpo.source_repository
  definition:
    pt-BR: >
      Cópia carregada de sistema de software cujo propósito é tratar as mudanças
      de cópias de artefato.
  classification: { ufo_category: disposition, ontouml_stereotype: subkind,
                    parent: sys_swo.loaded_software_system_copy }
```

A definição importa para o desenho: repositório é **cópia carregada**, não
empreendimento nem documento. É por isso que ele é `subkind` de algo da SYS_SWO, e
é o que torna a decisão de R1 — anotar a SYS_SWO em vez de forçá-lo a `kind` — a
correta.

### Issue

**Zero conceitos.** Nenhuma ontologia da rede define "issue", e isso está certo:
issue é artefato de uma ferramenta, e o princípio II diz que fonte externa não é
domínio. Uma issue **é promovida a** `sro.epic`, `sro.atomic_user_story`,
`sro.intended_scrum_development_task` ou `osdef.defect`, conforme o tipo e a
estrutura.

Confirma a decisão de R2: a promoção mora na camada de plataforma, porque ela é
registro de uma interpretação, não um conceito da rede.

### Projeto

Existem três, em cadeia, e **nenhum deles é um GitHub Project v2**:

| Conceito | Definição |
|---|---|
| `spo.project` | empreendimento temporário com objetivo definido, executado por uma organização |
| `spo.software_project` | projeto relacionado a desenvolvimento ou manutenção de software |
| `sro.scrum_project` | projeto de software que adota Scrum |

Um Project v2 é um **quadro de planejamento**. Uma organização mantém vários
quadros para o mesmo empreendimento, e um quadro pode conter itens de
empreendimentos diferentes. Tratar quadro como projeto faria a plataforma contar
três projetos onde existe um.

A matriz de cobertura em `docs/backlog/github-to-sro.md` já dizia isso, e eu não a
tinha lido com atenção suficiente ao escrever a spec:

| Conceito SRO | Origem | Confiança |
|---|---|---|
| `sro.scrum_project` | repositório ou Project v2 **declarado como projeto Scrum pelo tenant** | média |
| `sro.sprint` | `ProjectV2IterationField` | alta |
| `sro.sprint_backlog` | itens do Project atribuídos a uma iteration | alta |
| `sro.product_backlog` | itens do Project **sem** iteration atribuída | média |

**As duas correções que isso obrigou na spec:**

**FR-020a, novo** — a promoção de um projeto observado a projeto Scrum exige
declaração do tenant, e nunca ocorre automaticamente. Antes a spec dizia que o
projeto "aparece com nome, número e organização", o que deixava implícito que ele
era um projeto. Agora ele é artefato de fonte até que alguém declare.

**FR-032a e FR-032b, novos** — o sprint backlog é o conjunto dos itens com
iteração iniciada, o product backlog é o conjunto dos sem iteração, e **os dois são
derivados da atribuição de iteração**, nunca gravados como pertencimento. Antes a
spec só falava de product backlog, e não dizia que a composição é derivada — o que
abriria a porta para materializar pertencimento, o mesmo erro que R3 recusa para
épico contra atômica.

**SC-009a e SC-009b, novos** — nenhum projeto aparece como Scrum sem declaração
registrada; e a soma dos itens no product backlog e nos sprint backlogs é igual ao
total de itens, de modo que nenhum item fique em dois conjuntos nem fora dos dois.

### O que a auditoria conclui sobre o desenho

Só **um** conceito novo precisa entrar na base nesta feature: nenhum. Todos os
alvos existem. O que falta é **anotação** — os 11 conceitos da SYS_SWO sem
`ontouml_stereotype`, sem os quais `cmpo.source_repository` não tem para onde ser
elevado.


---

## R8 — Decisão da pessoa mantenedora sobre as três correspondências

Registrada em 2026-08-11, **substituindo a leitura de R7** no caso do projeto.

| GitHub | Conceito |
|---|---|
| `repository` | `cmpo.source_repository` |
| `issue` | `sro.user_story` e as rotas por tipo |
| `project` | `spo.software_project` |

### O que muda em relação a R7

R7 concluiu que um Project v2 **não** é um projeto no sentido de `spo.project`, e
que promovê-lo exigiria declaração do tenant. Eu apresentei essa leitura, e a
decisão foi **`project → project`**, direta.

A correspondência passa a ser observável: coletar um projeto do GitHub promove a
`spo.software_project`, sem depender de ninguém declarar nada.

### A ressalva que eu levantei, e que continua valendo como limitação

Uma organização mantém vários quadros para o mesmo empreendimento — este
repositório tem dois, `The Band` e `Zeppelin`. Com a correspondência direta, a
plataforma contará dois projetos de software onde há dois quadros, e não
necessariamente dois empreendimentos.

**Isso não invalida a decisão**, e a razão é que a alternativa era pior: exigir
declaração para toda promoção deixaria a tabela de projetos vazia até alguém
preencher formulário, e um projeto não declarado ficaria invisível para todas as
consultas de escopo. Contar quadro como projeto é uma imprecisão **declarada e
mensurável**; um projeto ausente é lacuna silenciosa.

Fica registrado como limitação do mapeamento — `semantics.equivalence: partial`,
com a justificativa escrita no YAML, que é onde a base de conhecimento guarda
exatamente esse tipo de ressalva.

### O que **não** muda

`sro.scrum_project` continua exigindo declaração do tenant, e não por cautela
minha: a matriz de cobertura do `github-to-sro.md` já dizia
`⚠️ por configuração`, com confiança média. A razão é sólida — **adotar Scrum não
é observável**. Um projeto com iterações pode ser Kanban com recorte temporal, e
`sro.scrum_project` é "projeto de software que adota Scrum em seu processo".

Então há duas promoções, em dois níveis:

```
project do GitHub ──▶ spo.software_project     observável, automática
                  └─▶ sro.scrum_project        declarada pelo tenant
```

E `issue → sro.user_story` continua passando pelas rotas por tipo: `Bug` vira
`osdef.defect` e `Task` vira `sro.intended_scrum_development_task`. Promover toda
issue a user story infla o escopo do produto com correção e trabalho técnico — é o
que a própria regra `github.issue_type_routing` existe para evitar, e o erro só
apareceria quando alguém perguntasse por que o backlog cresce sem funcionalidade
nova.
