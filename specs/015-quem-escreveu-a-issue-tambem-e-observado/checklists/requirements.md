# Specification Quality Checklist: quem escreveu a issue também é observado

**Criada em**: 2026-08-13 · **Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhe de implementação nos requisitos
- [x] Focada no valor: o trabalho deixa de ficar sem autor
- [x] Legível por quem não programa
- [x] Todas as seções obrigatórias preenchidas

## Requirement Completeness

- [x] Nenhum marcador `[NEEDS CLARIFICATION]` — as quatro decisões foram tomadas pela pessoa
      mantenedora durante a escrita, e estão nomeadas com quem decidiu
- [x] Requisitos testáveis, inclusive os de **não** mudar: FR-006, FR-007, FR-011
- [x] Critérios mensuráveis: 288 → o que a origem não resolve; 75 membros continuam 75
- [x] Critérios independentes de tecnologia
- [x] Cenários de aceitação nas três user stories
- [x] Casos de borda identificados — seis, incluindo o login renomeado e a pessoa que volta
- [x] Escopo delimitado: papel organizacional e pertencimento ficam **fora**
- [x] Premissas identificadas, incluindo a que dói: sem nova coleta, nada muda

## Feature Readiness

- [x] Todo requisito funcional tem critério correspondente
- [x] As user stories cobrem observar, recusar bot, e separar trabalhar de pertencer
- [x] Fatia vertical: a coleta produz, e a página da pessoa exibe

## Notas

**As quatro decisões desta spec são da pessoa mantenedora**, tomadas durante a conversa que a
originou, e estão registradas com o motivo:

| Decisão | Por que não foi minha |
|---|---|
| criar as pessoas | eu havia argumentado contra, citando o comentário do código |
| cadastrar em `eo_people` | e não num conceito separado |
| identidade pela origem | escolhida depois de eu medir que o payload só tem o login |
| participação pelo trabalho | e **não** pertencimento |

**A terceira decisão só existiu porque a medida veio antes.** A pergunta era "crie as pessoas", e a
resposta óbvia — criar a partir do login que já está no banco — teria chaveado identidade por string
mutável. Conferir o payload guardado antes de propor mudou o caminho.

**E a quarta é a que protege o produto**: "quem é da organização" e "quem trabalhou nela" são
perguntas diferentes, com respostas diferentes. A feature faz a segunda crescer sem tocar na
primeira, e a FR-006 existe para que isso seja verificado em vez de suposto.
