# Specification Quality Checklist: Detalhe da issue, e a decomposição navegável

**Purpose**: Validar completude e qualidade antes do planejamento
**Created**: 2026-08-11
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhes de implementação
- [x] Focada em valor de usuário
- [x] Escrita para quem não implementa
- [x] Seções obrigatórias preenchidas

## Requirement Completeness

- [x] Nenhum [NEEDS CLARIFICATION] restante
- [x] Requisitos testáveis e sem ambiguidade
- [x] Critérios de sucesso mensuráveis
- [x] Critérios independentes de tecnologia
- [x] Cenários de aceitação definidos
- [x] Edge cases identificados
- [x] Escopo delimitado
- [x] Dependências e suposições identificadas

## Feature Readiness

- [x] Todo requisito funcional tem critério de aceitação
- [x] Cenários cobrem os fluxos principais
- [x] A feature atende aos resultados mensuráveis
- [x] Nenhum detalhe de implementação vazou

## Notas da validação

**O complemento do pedido é o que a feature tem de maior valor.** "Se for um EPIC devo ver
as US e suas Tasks; se for uma US, as Tasks" parece requisito de navegação, e é requisito
**semântico**: as duas relações são diferentes.

```
épico  ──compõe-se de──▶  user story  ──é atendida por──▶  tarefa
```

Composição soma escopo; atendimento não. Uma lista única de "filhas" somaria as duas, e o
esforço seria contado duas vezes — no épico e nas partes. É o que `sro.rule07` proíbe, e daí
FR-015, FR-016 e SC-004.

**O dado real dá o número que torna isso verificável**: a issue `#1` tem **3** user stories e
**36** tarefas. SC-004 exige que a tela mostre 3 e 36 — e **nunca 39 em lugar nenhum**.

**A US3 existe porque o dado real já viola a regra.** Medido:

```
41  tarefas cujo pai é ÉPICO
 3  tarefas SEM pai
```

Sem esta história, a violação fica no banco e ninguém a encontra. Com ela, o time decide se
decompõe melhor ou se aquelas tarefas pertencem a outra história. **A plataforma não corrige
— ela mostra**, e FR-024 garante que a issue continua promovida: o inválido é o vínculo.

**Duas recusas que a spec faz e valem registro.**

`FR-005` — rótulo é preservado e **não** promovido. Um rótulo `bug` não faz a issue um
defeito; quem decide é o tipo declarado ou a regra da organização. Promover rótulo por nome é
o antipadrão do princípio I, e a feature 005 existe justamente para não fazê-lo.

`FR-002` — comentários **não** são coletados. A issue `#1` tem 48 itens de timeline;
coletá-los multiplicaria o consumo por issue. Comentário é entidade própria, com autor e
data, e merece decisão própria.

**Uma suposição que a spec declara em vez de esconder**: o retrofito dos campos novos ocorre
na coleta seguinte. Issues já coletadas ficam sem corpo até serem reobservadas, e a tela diz
isso — em vez de mostrar vazio e deixar a pessoa concluir que a issue não tem descrição.
