# Contrato — equipe derivada

**Feature**: 002 · **Requisitos**: FR-004 a FR-007, FR-011

## O que é

Uma equipe com o nome da organização observada, criada pela plataforma para
acolher os membros que não integram nenhuma equipe daquela organização.

Ela **não existe na ferramenta de origem**. Todo este contrato existe para que
isso permaneça verdadeiro e visível.

## Quando é criada

Avaliada **ao fim de cada coleta**, depois de equipes e integrantes processados —
é o único momento em que se sabe quem ficou de fora.

| Situação da organização | Resultado |
|---|---|
| membros fora de todas as equipes observadas | a equipe derivada existe, e recebe esses membros |
| todos os membros em equipes observadas | **nenhuma** equipe derivada é criada |
| a derivada existia e ficou sem integrantes | marcada como não mais observada; **não** apagada |

Criar a equipe vazia foi rejeitado por FR-007: registro sem referente. E faria a
contagem de derivadas crescer com o número de organizações, sem significar nada.

## Identidade

```text
source_system    the_band
source_instance  a instância que originou a coleta
external_id      derived:default_team:<external_id da organização>
```

Determinístico de propósito: reprocessar a mesma organização produz o mesmo
identificador, o upsert reconhece, e nada duplica.

**`source_system` é o que distingue observada de derivada.** Nenhuma coluna nova
foi criada — a que responde já existe por exigência do princípio III.

## Garantias

**Nunca se apresenta como observada.** Nem na proveniência, nem na contagem, nem
na tela. Quem comparar o número da plataforma com o do GitHub precisa ver a
diferença sem investigar.

**Idempotente.** Coletar duas vezes sem mudança na origem não cria uma segunda
equipe derivada nem altera a existente.

**Não duplica pessoa.** Quem já está em equipe observada não entra na derivada. A
avaliação é por organização: a mesma pessoa pode estar na equipe observada de uma
organização e na derivada de outra.

**O vínculo derivado não carrega nível de acesso.** `MAINTAINER` e `MEMBER` são o
que a origem informa sobre um vínculo que ela conhece; para este, ela não informa
nada. O campo fica nulo — ausência é nula, nunca zero.

## O que este contrato NÃO faz

| Ausente | Razão |
|---|---|
| criar equipe derivada para organização sem membro algum | não haveria quem acolher; a organização aparece vazia, e o estado vazio diz por quê |
| promover a equipe derivada a observada quando um time é criado no GitHub | são registros distintos com origens distintas. O time novo é observado; a derivada perde os integrantes que migrarem e some por esvaziamento |
| usar a equipe derivada como equipe de projeto | ela é `organizational_team`, como toda equipe vinda desta fonte |
