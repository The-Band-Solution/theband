# Feature Specification: Papéis por organização, e a promoção das evidências de vínculo

**Feature Branch**: `043-papeis-por-organizacao`
**Created**: 2026-08-24
**Status**: Draft
**Fecha**: [#317](https://github.com/The-Band-Solution/theband/issues/317)
**Input**: Decisão da pessoa mantenedora em 2026-08-24 — *"podemos ter um cadastro de papéis que pode ser reusado em várias equipes. Quem associa os papéis é uma pessoa via sistema, e o cadastro de papéis é por organização"*, seguida de *"podemos ter papéis básicos do scrum pré-cadastrados"* e *"esses papéis pré-cadastrados estão em todas as organizações"*.

## A cadeia parada, medida

```
12  equipes gravadas
101 evidências de vínculo coletadas do GitHub
  0 vínculos promovidos
  0 papéis organizacionais cadastrados
```

E `eo_team_memberships.organizational_role_id` é **`NOT NULL`**.

A cadeia está parada no **primeiro elo**: sem papel cadastrado, nenhuma das 101 evidências pode virar vínculo, e as 12 equipes ficam vazias.

**Consequência medida**: todo o nível Equipe dos painéis está vazio. Quatro das cinco medidas declaram `team` — taxa de CI, vazão, tempo até a primeira revisão e retrabalho — e **nenhuma calcula**.

Isto não é defeito: é o desenho funcionando e esperando o ato humano que a `FR-007` da feature 021 exige. Falta o cadastro que torna o ato possível.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Os quatro papéis do Scrum já estão lá (Priority: P1)

Quem administra abre a tela de papéis de uma organização e **encontra os quatro do Scrum já disponíveis**, sem cadastrar nada.

**Why this priority**: é o que destrava a promoção. Sem papel, a evidência não vira vínculo.

**Independent Test**: abrir a tela de papéis numa organização recém-observada e conferir que os quatro aparecem, marcados como vindos do catálogo.

**Acceptance Scenarios**:

1. **Dado** uma organização sem papel algum declarado, **quando** a tela de papéis é aberta, **então** os quatro do Scrum aparecem — Product Owner, Scrum Master, Developer e Client — cada um marcado como **do catálogo**.
2. **Dado** três organizações no mesmo tenant, **quando** cada uma é aberta, **então** as três têm os quatro disponíveis, **independentemente**.
3. **Dado** um papel do catálogo, **quando** quem administra tenta apagá-lo, **então** a plataforma recusa e explica: o catálogo vem da rede, e o que se pode fazer é **não usá-lo**.

---

### User Story 2 - Cadastrar papéis próprios da organização (Priority: P1)

A organização declara papéis que o Scrum não nomeia — *Tech Lead*, *Analista de Requisitos*, o que ela usar —, e eles valem **só nela**.

**Why this priority**: as três organizações observadas não compartilham vocabulário. Um papel que vaza entre elas produz lista que ninguém reconhece.

**Independent Test**: declarar um papel numa organização e conferir que ele **não** aparece nas outras duas.

**Acceptance Scenarios**:

1. **Dado** uma organização, **quando** quem administra declara um papel, **então** ele fica gravado **com autor** e passa a aparecer na lista dela.
2. **Dado** o papel declarado na organização A, **quando** a tela de papéis da organização B é aberta, **então** ele **não** aparece.
3. **Dado** um papel declarado, **quando** a tela é aberta, **então** ele é distinguível dos do catálogo — a origem fica visível, não implícita.

---

### User Story 3 - Promover as evidências a vínculo (Priority: P1)

Quem administra vê as evidências coletadas — **pessoa e equipe** — e **confirma** o vínculo escolhendo o papel a partir do que sabe da organização.

**Why this priority**: são as 101 que estão paradas, e é o que enche as 12 equipes.

**Independent Test**: promover uma evidência e conferir que a equipe passa a ter um membro, com autor gravado.

**Acceptance Scenarios**:

1. **Dado** uma evidência não promovida, **quando** quem administra escolhe um papel e confirma, **então** o vínculo é criado com **quem confirmou e quando**, e a evidência passa a apontar para ele.
1a. **Dado** a mesma promoção, **quando** quem administra informa que a pessoa assumiu o papel em março, **então** o vínculo grava **março** como início — e a data do registro continua sendo hoje, separada.
1b. **Dado** quem administra não sabe desde quando, **quando** deixa a data em branco, **então** o vínculo é criado **sem** data de início — e nenhuma data é inventada.
2. **Dado** uma evidência já promovida, **quando** a lista é aberta, **então** ela aparece como resolvida, e não é oferecida de novo.
3. **Dado** uma evidência da equipe da organização A, **quando** quem administra escolhe um papel da organização B, **então** a plataforma **recusa** — o papel do vínculo tem de ser da mesma organização da equipe.
4. **Dado** que nenhuma evidência foi promovida, **quando** a tela da equipe é aberta, **então** ela diz **quantas** evidências estão esperando confirmação — e não mostra a equipe como se não tivesse ninguém.
5. **Dado** uma pessoa já vinculada como Developer, **quando** quem administra a vincula também como Product Owner na mesma equipe, **então** os **dois** vínculos coexistem — e a contagem de pessoas da equipe **não** sobe.
6. **Dado** a mesma pessoa e o mesmo papel, **quando** quem administra tenta vincular de novo, **então** a plataforma recusa e diz que o vínculo já existe.

---

### Edge Cases

- **Evidência cuja pessoa saiu da equipe na origem** — `no_longer_observed_at` preenchido: não é oferecida para promoção, e se já foi promovida o vínculo **permanece**, com a data de fim. Marca nunca apaga.
- **Papel do catálogo que a organização não quer**: pode ser **ocultado** dela, e ocultar não é apagar — a rede continua nomeando-o, e vínculos que já o usam continuam válidos.
- **A rede ganha um quinto papel de Scrum**: ele aparece em todas as organizações na leitura seguinte, sem migração. É a propriedade que faz o catálogo valer a pena.
- **A rede deixa de nomear um papel que já tem vínculos**: os vínculos continuam, e o papel aparece marcado como **não mais no catálogo**. Sumir em silêncio deixaria vínculos apontando para nada.
- **Duas organizações com papel de mesmo código**: são papéis diferentes, e isso é correto. A unicidade é por organização, nunca por tenant — e o índice de hoje impede, ver `FR-006`.
- **A mesma pessoa como Product Owner e Developer**: os dois vínculos coexistem, e ela conta como **uma** pessoa no tamanho da equipe.

---

## Requirements *(mandatory)*

### O cadastro

- **FR-001**: O cadastro de papéis MUST ser **por organização**. Um papel MUST NOT ficar visível em organização que não a sua.
- **FR-002**: Os quatro papéis do Scrum que a **SRO** nomeia MUST estar disponíveis em **todas** as organizações, sem cadastro prévio — `sro.product_owner_role`, `sro.scrum_master_role`, `sro.developer_role` e `sro.client_role`, todos filhos de `sro.scrum_role`.

  > **São os únicos papéis que a plataforma traz prontos**, e a razão é que eles têm origem
  > numa ontologia de referência: a SRO os define, e a definição é revisável em commit. Papel
  > que a rede não nomeia é declaração da organização, e nasce com autor.
  >
  > **Nenhum papel vem da ferramenta.** `MAINTAINER` e `MEMBER` não entram no catálogo, e
  > `EO.Constraints.platform_access_level_is_not_a_role/1` já os recusa desde a feature 021.
- **FR-003**: Cada papel MUST declarar sua **origem** — do catálogo da rede, ou declarado por uma pessoa. A origem MUST ser visível na tela, e não inferida do nome.
- **FR-004**: Papel do catálogo MUST NOT ser apagável. Ele MAY ser **ocultado** de uma organização, e ocultar MUST NOT invalidar vínculos que já o usam.
- **FR-005**: Papel declarado MUST gravar **quem** o declarou e **quando**.
- **FR-006**: A unicidade do código MUST ser por **organização**, e não por tenant. Duas organizações MAY ter papéis de mesmo código, e eles são papéis diferentes.

  > **O índice de hoje impede isto.** `eo_organizational_roles_tenant_id_code_index` é `UNIQUE (tenant_id, code)`. Com o catálogo presente em todas as organizações, a segunda organização a receber `scrum_master` bateria na constraint. O índice MUST passar a incluir a organização.

### Mais de um papel na mesma equipe

- **FR-006a**: Uma pessoa MAY ocupar **mais de um papel** na mesma equipe. Product Owner e Developer simultâneos é situação real, e não erro a impedir.
- **FR-006b**: O mesmo papel MUST NOT ser atribuído duas vezes à mesma pessoa na mesma equipe **enquanto vigente** — repetir não acrescenta informação, e a segunda linha tornaria a contagem de ocupantes errada.
- **FR-006c**: Toda contagem de pessoas por equipe MUST contar **pessoas distintas**, e nunca vínculos. Uma pessoa com dois papéis é **uma** pessoa na equipe, e somar vínculos faria a equipe parecer maior do que é.

> **O esquema já sustenta os dois primeiros.** `eo_team_memberships_vigente_index` é
> `UNIQUE (tenant_id, person_id, team_id, organizational_role_id, …)` — o papel está na
> chave, então papéis diferentes são linhas diferentes e o mesmo papel é recusado. O que
> esta feature acrescenta é a `FR-006c`, que é de leitura, e a tela que permite atribuir o
> segundo.

### A promoção

- **FR-007**: Promover uma evidência a vínculo MUST ser **ato de uma pessoa**, com autor gravado. A plataforma MUST NOT promover sozinha.
- **FR-008**: O papel escolhido MUST pertencer à **mesma organização da equipe**. A plataforma MUST recusar a combinação inválida, e a recusa MUST dizer o porquê.
- **FR-009**: Uma evidência já promovida MUST NOT ser oferecida de novo, e MUST apontar para o vínculo que a promoveu.
- **FR-010**: Evidência cuja observação terminou MUST NOT ser oferecida para promoção. Vínculo já promovido a partir dela MUST permanecer.

### O nível de acesso não entra nesta decisão

Decisão da pessoa mantenedora, 2026-08-24: *"não use os níveis de acesso do GitHub, isso não indica role dos projetos"*.

- **FR-011**: A tela de promoção MUST NOT exibir o nível de acesso da plataforma de origem — `MAINTAINER` ou `MEMBER`. Nem como sugestão, **nem como contexto**.
- **FR-012**: A plataforma MUST NOT inferir, sugerir ou pré-selecionar papel organizacional a partir do nível de acesso. Nenhum papel MUST vir pré-selecionado, por qualquer critério.
- **FR-013**: O que a evidência afirma é **que uma pessoa pertence a uma equipe** na origem. É só isso que a tela MUST mostrar. Quem decide o papel decide a partir do que sabe da organização, e não do que a ferramenta permite a quem.

> **Por que a versão anterior desta seção estava errada.** Ela dizia que a tela *poderia*
> mostrar o acesso "como contexto", e proibia só a inferência. Não se sustenta: exibir
> `MAINTAINER` ao lado de um seletor de papel **faz dele uma dica**, por mais que o texto
> negue.
> A proibição da inferência viraria letra morta, e o viés entraria sem nenhum código o
> declarar.
>
> **`MAINTAINER` diz quem pode gerir membros e permissões do time.** É atributo da
> ferramenta, não da organização — e não diz se a pessoa é programadora, testadora,
> designer ou gerente.
>
> **A plataforma já sabe disso, e antes desta feature.**
> `EO.Constraints.platform_access_level_is_not_a_role/1` existe desde a feature 021, com a
> justificativa escrita: promover acesso a papel produziria um catálogo que não corresponde
> a função nenhuma, e faria as perguntas de competência `CQ12`, `CQ14` e `CQ16` devolverem
> **resposta falsa em vez de nenhuma**. Esta spec não cria a regra: ela impede que a tela a
> contorne.

### As 101 evidências afirmam uma coisa só

**Que a pessoa é membro da equipe.** Medido em 2026-08-24:

| valor | evidências | o que afirma |
|---|---:|---|
| `MEMBER` | 63 | é membro |
| nulo | 33 | é membro |
| `MAINTAINER` | 5 | é membro |

Os três dizem **a mesma coisa**. A diferença entre `MEMBER` e `MAINTAINER` é permissão na
ferramenta — quem pode gerir membros e permissões do time —, e não grau de pertencimento nem
função. Ninguém é *"mais membro"* por ser `MAINTAINER`.

Daí sai a razão prática da `FR-011`: **o nível não acrescenta nada à decisão de papel.** Não
é que ele seja perigoso e útil; ali ele é perigoso e **inútil**. As 33 evidências com nível
nulo sustentam a promoção exatamente como as outras 68 — o que confirma que a informação que
importa é o pertencimento, e ela está presente nas 101.

**O que continua sendo coletado.** `platform_access_level` permanece em
`eo_team_membership_evidence`: é fato observado sobre a plataforma, e apagá-lo seria perder
dado verdadeiro que outras telas já mostram — a da equipe e a da pessoa. O que esta feature
proíbe é **usá-lo para decidir papel**, inclusive mostrando-o onde a decisão acontece.

### Quando a pessoa assumiu o papel

Pedido da pessoa mantenedora, 2026-08-24: *"guarde quando uma pessoa assume um papel"*.

- **FR-016**: O vínculo MUST gravar **quando a pessoa assumiu o papel**, e essa data MUST ser distinta da data em que o registro foi feito.
- **FR-017**: A data de início MUST ser **editável por quem promove**, e MAY vir preenchida com a data corrente como ponto de partida. A origem **não sabe** desde quando a pessoa está na equipe — carimbar a data corrente sem permitir correção afirmaria algo falso para quem entrou há um ano.
- **FR-018**: A data de início MAY ficar **em branco**, e branco significa **desconhecido** — nunca a data de hoje. Medida que dependa dela MUST excluir os vínculos sem data e MUST dizer **quantos** excluiu.
- **FR-019**: A data em que a observação da evidência ocorreu MUST NOT ser usada como data de início. Ela diz **quando a coleta viu**, não quando a pessoa entrou — as 101 evidências têm `observed_at` entre 2026-08-09 e 2026-08-14, que é quando a plataforma foi ligada.

> **As três datas, e por que nenhuma substitui a outra**
>
> | data | o que significa |
> |---|---|
> | início do vínculo | quando a pessoa **assumiu o papel** — o fato |
> | registro | quando alguém **gravou** — automático, já existe |
> | observação da evidência | quando a **coleta viu** — não serve, e a `FR-019` proíbe |
>
> Colapsar as duas primeiras apagaria a distinção entre o que aconteceu e o que foi
> declarado, que é a distinção que a plataforma inteira sustenta.

### Editar um papel declarado

- **FR-020**: O **nome** de um papel declarado MAY ser editado, com autor e data da edição.
- **FR-021**: O **código** MUST NOT ser editado. Ele é a identidade, e trocá-lo faria os vínculos existentes apontarem para outra coisa sem que nada avisasse.
- **FR-022**: Papel do catálogo MUST NOT ter nome nem código editados. Ambos vêm da rede, e editá-los aqui produziria divergência silenciosa com o YAML.

### A tela

- **FR-014**: A tela da equipe MUST dizer **quantas evidências esperam confirmação**, e MUST NOT mostrar equipe sem membro como se ninguém pertencesse a ela — são coisas diferentes.
- **FR-015**: A lista de papéis MUST distinguir visualmente os do catálogo dos declarados, e MUST dizer **quantos vínculos** usam cada um antes de permitir ocultar.

---

### Key Entities

- **Papel organizacional** — o que a organização reconhece como função. Tem nome, código, origem (catálogo ou declarado) e a organização a que pertence.
- **Catálogo de papéis** — os que a rede nomeia, disponíveis em toda organização, não apagáveis.
- **Evidência de vínculo** — o que foi observado: uma pessoa pertence a uma equipe, com um nível de acesso. Já é coletada.
- **Vínculo** — a afirmação de que uma pessoa ocupa um papel numa equipe. Declarado por uma pessoa a partir da evidência.

---

## Success Criteria *(mandatory)*

- **SC-001**: Numa organização recém-observada, quem administra encontra os quatro papéis do Scrum **sem cadastrar nada** — zero passos antes de poder promover.
- **SC-002**: Promover uma evidência leva **menos de trinta segundos**, e o resultado aparece na tela da equipe na leitura seguinte.
- **SC-003**: Das **101 evidências** medidas em 2026-08-24, **100%** podem ser promovidas sem nenhum cadastro prévio de papel — inclusive as **33 com nível de acesso nulo**, porque o nível não participa da promoção.
- **SC-004**: Um papel declarado na organização A **não aparece** em nenhuma listagem da organização B — verificável abrindo as duas.
- **SC-005**: Nenhum papel vem pré-selecionado, por critério nenhum. Verificável: em toda evidência, o campo de papel começa **vazio**.
- **SC-005a**: O nível de acesso da origem **não aparece** na tela de promoção. Verificável procurando `MAINTAINER` e `MEMBER` no que ela renderiza: deve ser **zero**.
- **SC-006**: Depois de promovidas as evidências de uma equipe, as medidas de nível Equipe passam a calcular para ela — o que hoje **nenhuma** faz.
- **SC-007**: A tela da equipe sem membros distingue *"nenhuma evidência"* de *"N evidências esperando confirmação"*. Nunca mostra as duas com a mesma frase.
- **SC-008**: Uma pessoa com dois papéis numa equipe conta como **uma** pessoa em toda contagem de tamanho de equipe — verificável comparando a contagem com o número de vínculos, que serão diferentes.
- **SC-009**: Nenhum vínculo recebe data de início igual à data de observação da evidência. Verificável comparando as duas colunas: a coincidência sistemática seria o defeito que a `FR-019` proíbe.
- **SC-010**: Vínculo com data de início em branco é contado e **nomeado** por toda medida que dependa dela — nunca silenciosamente excluído, e nunca preenchido com a data de hoje.

---

## Assumptions

- **O catálogo vem da rede, e a rede já o tem.** `sro.product_owner_role`, `sro.scrum_master_role`, `sro.developer_role` e `sro.client_role`, todos filhos de `sro.scrum_role`. `EO.suggested_roles/0` já os deriva do YAML — o que muda é deixarem de ser sugestão de preenchimento e passarem a estar disponíveis.
- **A forma copia `Mapping.Catalog`.** As regras de mapeamento já distinguem catálogo de declaração por um `catalog_key` nulável: presente significa que veio do catálogo, nulo que alguém escreveu. Reusar essa forma é preferível a inventar outra — a casa já a provou e ela é reconhecível.
- **A coluna de organização nasce obrigatória.** Há **zero** papéis cadastrados, e essa é a única janela em que tornar a coluna obrigatória não custa migração. Nula significaria *"papel de todo o tenant"*, que é o comportamento de hoje e é o que esta feature existe para corrigir.
- **É a mesma classe de defeito da issue #446** — filtrar por tenant onde a pergunta é por organização. Lá custou percorrer 480 repositórios em vez de 160, com a credencial errada.
- **A promoção é o ato que a feature 021 previu.** O `declared_by_user_id` já existe em `eo_team_memberships` e está nulo em 100% das linhas — porque não há linhas. A coluna estava esperando esta feature.

## Fora do escopo

- **Sugerir o papel a partir de qualquer coisa.** Nem de acesso — a `FR-011` proíbe —, nem de comportamento: quem revisa mais, quem fecha mais tarefa. O segundo tem os mesmos riscos do primeiro e merece spec própria, se algum dia for desejado.
- **Hierarquia de equipes** — [#397](https://github.com/The-Band-Solution/theband/issues/397). Depende desta: hierarquia sem membro não soma nada.
- **Alocar papel a pessoa fora de equipe.** O vínculo é pessoa-em-equipe; papel organizacional sem equipe é outro conceito.
