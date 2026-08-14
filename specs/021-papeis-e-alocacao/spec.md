# Feature Specification: os papéis, e quem os desempenha

**Feature**: `021-papeis-e-alocacao` · **Criada em**: 2026-08-14
**Estado**: rascunho, pronta para `/speckit-plan`
**Origem**: [#99](https://github.com/The-Band-Solution/theband/issues/99),
[#100](https://github.com/The-Band-Solution/theband/issues/100) e
[#98](https://github.com/The-Band-Solution/theband/issues/98), abertas em 2026-08-11

## O pedido

> "Cadastrar os papéis reconhecidos pelo tenant, e alocar uma pessoa a um papel, com período."

---

## O que a medida achou

**Contado em 2026-08-14**, depois da coleta das três organizações:

```
101 evidências de vínculo pessoa-equipe · 0 vínculos promovidos · 0 papéis cadastrados
```

**Os três números são o mesmo fato.** O vínculo da ontologia — `eo_team_memberships` — exige
`organizational_role_id`, e a coluna é `NOT NULL`. Nenhum papel foi cadastrado, então nenhum
vínculo pode existir, então as 101 evidências ficam onde estão.

### O que a plataforma sabe, e o que ela recusa afirmar

| Ela sabe | Ela recusa |
|---|---|
| que 101 pessoas aparecem em equipes na origem | que elas **são membros**, no sentido da ontologia |
| o nível de acesso de cada uma na plataforma de origem | que esse nível seja um **papel** |

O nível de acesso observado é este:

| Nível | Evidências |
|---|---:|
| `MEMBER` | 63 |
| *(nenhum)* | 33 — todas em equipes **derivadas**: `LEDS - ConectaFapes` 28, `ifesserra-lab` 5 |
| `MAINTAINER` | 5 |

**`MAINTAINER` e `MEMBER` não são papéis, e é por isso que a promoção nunca aconteceu.** Eles
dizem quem administra o time na ferramenta de origem — quem gere membros e permissões. Não
dizem se a pessoa programa, testa, desenha ou gerencia. Tratá-los como papel produziria um
catálogo de dois papéis que não corresponde a função real nenhuma.

**As 33 sem nível são de equipes que a plataforma criou**, para reunir quem pertence à
organização e não está em time algum. Não há nível porque não há time na origem.

### O que a ontologia já diz

`eo.organizational_role` está definido como **papel social reconhecido pela organização**,
atribuído a agentes quando são contratados, incluídos numa equipe ou alocados. A SRO nomeia
quatro: `sro.product_owner_role`, `sro.scrum_master_role`, `sro.developer_role` e
`sro.client_role`.

**O modelo inteiro já existe e está vazio.** `eo_organizational_roles` tem `code` e `name`;
`eo_team_memberships` tem `started_at` e `ended_at` — que é o período que a #100 pede. O que
falta é o cadastro, a alocação, e a tela de cada um.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A organização declara quais papéis reconhece (Priority: P1)

Quem administra o tenant cadastra os papéis que a organização reconhece — e vê que a
plataforma não os inventou.

**Por que é P1**: sem papel cadastrado, **nenhum** vínculo pode existir, e as 101 evidências
ficam paradas. É o bloqueio, e ele é de uma linha de dado.

**Independent Test**: cadastrar `developer` e conferir que ele aparece na lista, e que a
plataforma continua dizendo que há 101 evidências sem vínculo — cadastrar papel não promove
nada sozinho.

**Cenários de aceitação**

1. **Dado** o tenant sem papel algum, **quando** alguém abre a tela, **então** ela diz que
   nenhum papel foi cadastrado, e **por que isso importa**: 101 evidências esperam por um.
2. **Dado** um papel cadastrado, **quando** alguém tenta cadastrar outro com o mesmo código,
   **então** a plataforma recusa e diz que o código já existe.
3. **Dado** os quatro papéis do Scrum que a ontologia nomeia, **quando** alguém abre a tela,
   **então** ela os oferece como sugestão — **sem cadastrá-los sozinha**.
4. **Dado** um papel cadastrado, **quando** alguém o renomeia, **então** o código permanece: é
   ele que os vínculos referenciam.

---

### User Story 2 - Uma pessoa é alocada a um papel, numa equipe, com período (Priority: P1)

Quem administra escolhe uma evidência de participação e diz **qual papel** aquela pessoa
desempenha naquela equipe, e desde quando.

**Por que é P1**: é o pedido, e é o que transforma evidência em vínculo. Depende da US1.

**Independent Test**: alocar uma pessoa a `developer` numa equipe, e conferir que a página dela
passa a mostrar o vínculo — e que a evidência **continua existindo**, agora promovida.

**Cenários de aceitação**

1. **Dado** uma evidência sem papel, **quando** alguém aloca a pessoa a um papel, **então** o
   vínculo passa a existir, e a evidência aponta para ele.
2. **Dado** a alocação feita, **quando** alguém consulta a pessoa, **então** o papel aparece
   com o período — e a evidência que o originou continua visível.
3. **Dado** uma alocação com data de início, **quando** a pessoa deixa o papel, **então** a
   data de fim é registrada e o vínculo **não é apagado**.
4. **Dado** uma pessoa em duas equipes, **quando** ela é alocada numa, **então** a outra
   continua sem papel — alocação é por equipe, não por pessoa.
5. **Dado** uma alocação sem data de início, **quando** ela é gravada, **então** a plataforma
   diz que não sabe desde quando, em vez de inventar a data de hoje.

---

### User Story 3 - A tela distingue o que foi observado do que foi declarado (Priority: P1)

Quem lê a página de uma pessoa vê o que veio da origem e o que alguém afirmou, **separados**.

**Por que é P1**: é a distinção que a plataforma inteira defende, e é onde ela some com mais
facilidade. Uma tela que mostra "Developer" sem dizer que **alguém digitou aquilo** transforma
declaração em observação.

**Independent Test**: numa pessoa com evidência e alocação, conferir que as duas aparecem com
origens distintas e visíveis.

**Cenários de aceitação**

1. **Dado** uma pessoa com evidência e sem alocação, **quando** alguém a consulta, **então** a
   tela diz que a participação foi **observada** e o papel está **pendente**.
2. **Dado** uma pessoa alocada, **quando** alguém a consulta, **então** a tela diz que o papel
   foi **declarado**, e por quem.
3. **Dado** que a origem deixou de mostrar a pessoa na equipe, **quando** a coleta marca a
   evidência como não mais observada, **então** o vínculo declarado **continua existindo** — e
   a tela diz que a evidência que o originou acabou.

---

### Edge Cases

- **A pessoa foi alocada e a origem nunca mais a mostrou.** O vínculo é declaração humana; a
  evidência é observação. Um não apaga o outro, e a tela precisa dizer os dois.
- **Papel cadastrado e depois removido, com vínculos apontando para ele.** Remover deixaria
  vínculos órfãos — a mesma família da recusa de apagar ferramenta.
- **Duas alocações da mesma pessoa, mesma equipe, papéis diferentes.** É **permitido**, e a
  decisão está nas suposições: em Scrum, acumular Developer e Scrum Master é comum e previsto.
  Recusar produziria uma plataforma que não consegue descrever times reais.
- **Alocação com período que termina antes de começar.**
- **A equipe derivada.** 33 evidências estão em equipes que a plataforma criou. Alocar papel
  numa equipe que não existe na origem é legítimo — mas a tela tem de dizer que a equipe é
  derivada.
- **Vínculo com data de fim no passado.** Continua aparecendo como histórico, nunca some.

---

## Requirements *(mandatory)*

### Cadastrar papel

- **FR-001**: A plataforma MUST permitir cadastrar papéis organizacionais, com código e nome.
- **FR-002**: O código MUST ser único por tenant.
- **FR-003**: A plataforma MUST oferecer os papéis que a ontologia nomeia como **sugestão**, e
  MUST NOT cadastrá-los automaticamente — quem reconhece o papel é a organização.
- **FR-004**: A plataforma MUST permitir renomear um papel, e o código MUST permanecer.
- **FR-005**: A plataforma MUST NOT permitir remover papel que tenha vínculo apontando para
  ele, dizendo quantos são.

### Alocar

- **FR-006**: A plataforma MUST permitir alocar uma pessoa a um papel **dentro de uma equipe**.
- **FR-006a**: A plataforma MUST permitir mais de um papel para a mesma pessoa na mesma equipe,
  e MUST recusar a alocação repetida do **mesmo** papel com período vigente.
- **FR-007**: A alocação MUST aceitar data de início e de fim, e as duas MUST ser opcionais.
- **FR-008**: Data de fim anterior à de início MUST ser recusada.
- **FR-009**: A evidência que originou a alocação MUST passar a apontar para o vínculo.
- **FR-010**: Encerrar uma alocação MUST registrar a data de fim, e MUST NOT apagar o vínculo.
- **FR-011**: A plataforma MUST registrar **quem** declarou a alocação.

### O que a tela mostra

- **FR-012**: A página da pessoa MUST distinguir participação **observada** de papel
  **declarado**, e MUST dizer qual é qual.
- **FR-013**: A tela MUST dizer, quando não há papel algum cadastrado, quantas evidências
  esperam por um.
- **FR-014**: Evidência marcada como não mais observada MUST NOT apagar o vínculo declarado, e
  a tela MUST dizer que a evidência acabou.
- **FR-015**: A tela MUST dizer quando a equipe é **derivada** — criada pela plataforma, não
  observada na origem.

### Escopo e segurança

- **FR-016**: Papel e alocação de outro tenant MUST devolver não encontrado.
- **FR-017**: Cadastrar papel e alocar MUST ser restrito ao perfil administrador.

---

## Success Criteria *(mandatory)*

- **SC-001**: Com um papel cadastrado e uma alocação feita, o número de vínculos sai de **zero**.
- **SC-002**: A pessoa alocada mostra o papel na página dela, com o período, em menos de dois
  cliques a partir da lista de pessoas.
- **SC-003**: Nenhuma evidência é apagada por causa de uma alocação — as **101** continuam
  existindo depois de qualquer número de alocações.
- **SC-004**: A plataforma **não** cadastra papel sozinha: com zero papéis, a tela sugere os
  quatro do Scrum e o número de papéis cadastrados continua zero.
- **SC-005**: Um vínculo cuja evidência deixou de ser observada continua consultável, e a tela
  diz as duas coisas.
- **SC-006**: Nenhuma tela apresenta o nível de acesso da origem como se fosse papel.

---

## Assumptions

- **`MAINTAINER` e `MEMBER` continuam não sendo papéis**, e esta feature não os promove
  automaticamente. Promover por nível de acesso produziria dois papéis que não correspondem a
  função real — é a decisão que a feature 002 já tomou, e ela não muda aqui.
- **A alocação é declaração humana.** Não há origem que a forneça: o GitHub não sabe quem é
  Product Owner. Por isso ela tem autor, e por isso não é coletada nem sobrescrita por coleta.
- **Uma pessoa pode ter mais de um papel na mesma equipe.** Acumular Developer e Scrum Master é
  comum em Scrum, e a ontologia não proíbe. A unicidade é por **pessoa, equipe, papel e período
  vigente** — a mesma pessoa não é alocada duas vezes ao mesmo papel na mesma equipe ao mesmo
  tempo, e isso é o que a chave impede.
- A ontologia nomeia quatro papéis do Scrum, e a organização pode reconhecer outros. O cadastro
  é livre; a sugestão é o que a ontologia traz.

## Fora do escopo

- **Coletar papel da origem.** Nenhuma origem observada fornece papel organizacional. Se um dia
  fornecer, é outra feature — e a distinção observado/declarado já estará no lugar certo.
- **Hierarquia de papéis.** A ontologia tem `sro.scrum_role` como pai dos quatro, e nada nesta
  feature precisa da árvore.
- **Alocação em projeto.** A ontologia distingue equipe organizacional de equipe de projeto, e
  a plataforma só observa a primeira hoje.
