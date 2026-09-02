# Specification Quality Checklist: O tamanho do texto é escolha de quem lê

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-01
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notas da validação

**Nenhum mecanismo aparece nos requisitos.** `localStorage`, atributo na raiz e
script sem `defer` foram descritos no pedido e **não** entraram em FR algum — o
que está lá é o comportamento: *aplica imediatamente*, *sobrevive a reabrir*,
*não pisca*, *vale nas outras abas*. Se o mecanismo mudar, a spec continua
válida. Como se persiste é decisão do `plan.md`.

**O FR-007 é o que separa esta feature de "aumentar a fonte".** A escala é
**proporcional** à preferência do navegador, e não a substitui. Sem ele, quem já
tinha configurado fonte maior receberia o aumento duas vezes — e o pedido teria
piorado a vida exatamente de quem mais precisa de texto grande.

**O FR-010 protege o FR-007 de ser desfeito sem querer.** Uma medida fixa
acrescentada em qualquer tela quebra a proporcionalidade naquele ponto, e o
defeito não aparece para quem não usa a preferência do navegador — que é a
maioria de quem revisa.

**As duas user stories são P1 juntas, e a razão está escrita**: a US1 sozinha
troca uma reclamação por outra. Aumentar para todo mundo atende quem lê texto e
prejudica quem compara tabela; sem o controle, a próxima reclamação vem do outro
lado.

**A ausência de entidade é decisão, não esquecimento.** A escolha é da pessoa
naquele dispositivo — a mesma pessoa pode querer tamanhos diferentes no monitor e
no telefone. Guardar na conta forçaria um só, e criaria dado de organização a
partir de preferência de leitura.

**O que ficou de fora é maior do que o que entrou**, e está dito: as **461
ocorrências** do menor tamanho, em 33 arquivos. É o defeito de fundo. Feita junto
com a escala, ninguém saberia qual das duas resolveu — e é justamente essa
confusão que a aceitação por critérios existe para evitar.

**O que esta validação NÃO prova**: que a feature funciona. Os SC são medidas do
produto, e nenhuma foi executada — inclusive a do SC-004, que só existe abrindo
as telas de tabela em 390px nas três escalas.

## Notes

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
