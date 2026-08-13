# Specification Quality Checklist: clicar leva à página

**Criada em**: 2026-08-13 · **Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhe de implementação nos requisitos
- [x] Focada no valor: do trabalho para quem o fez
- [x] Legível por quem não programa
- [x] Todas as seções obrigatórias preenchidas

## Requirement Completeness

- [x] Nenhum marcador `[NEEDS CLARIFICATION]`
- [x] Requisitos testáveis — inclusive o FR-010, sobre não acrescentar consulta
- [x] Critérios mensuráveis: 8 470 nomes ganham saída, 288 continuam sem
- [x] Critérios independentes de tecnologia
- [x] Cenários de aceitação nas três user stories
- [x] Casos de borda identificados — cinco, incluindo a mesma pessoa duas vezes na tela
- [x] Escopo delimitado: página de organização fica **fora**, e está escrito
- [x] Premissas identificadas

## Feature Readiness

- [x] Todo requisito funcional tem critério correspondente
- [x] As user stories cobrem os dois lugares onde falta, e o caso que não pode ganhar ligação
- [x] Nenhuma mudança de conteúdo — muda o que é clicável (FR-009, SC-007)

## Notas

**A medida encolheu o pedido, e vale registrar.** A issue supunha que a plataforma não ligava os
elementos; a contagem mostrou o contrário — `/work` tem **135** repositórios clicáveis e zero
mortos, e o mesmo vale para a lista de pessoas, o detalhe da pessoa e a lista do repositório.

**O que falta está em duas telas**, e é sempre o nome de uma pessoa: no detalhe da issue (autor e
designados) e no detalhe da equipe (membros).

**E a US3 é a que impede a feature de virar defeito.** São **288** logins cuja pessoa não foi
coletada — a tela hoje **declara** isso, e transformá-los em ligação para ganhar uniformidade
trocaria uma declaração honesta por um clique que promete e não entrega.
