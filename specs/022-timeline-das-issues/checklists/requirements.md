# Specification Quality Checklist: a timeline da issue

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-14
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

**Nota.** A spec cita `spo.performed_project_activity` e o critério de identidade dele. Não é
detalhe de implementação: é **o conceito da ontologia que a feature materializa**, e a
constituição (princípio I) exige que o domínio seja organizado por eles. Omiti-lo faria a spec
descrever uma tabela em vez de um conceito.

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

**Uma suposição continua sem medida, e está declarada como tal**: a distribuição de eventos por
issue. A plataforma não coleta timeline hoje, então não há como medir daqui — e a issue original
citava 48 numa issue, número que a medida dos comentários já mostrou ser de caso extremo. Medir é
tarefa do plano, e é o que decide a US3.

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## O que a análise achou, antes do plano

Décima feature seguida com defeito de desenho encontrado na fase de análise. Aqui são **dois**, e
o primeiro quase virou a feature inteira.

### 1. Nenhum evento significa "começou"

A timeline traz `assigned`, `labeled`, `closed`, `reopened`. **Nenhum deles é "o trabalho
começou"** — e qual marca o início é decisão de cada organização: umas usam a designação, outras
um rótulo, outras a movimentação no quadro.

Uma plataforma que escolhesse sozinha produziria um cycle time **plausível e errado**, e ninguém
perceberia — porque o número pareceria razoável.

Virou a **US2 inteira, P1**: a plataforma coleta o dado e **diz que não sabe derivar**, nomeando
a decisão que falta. E a FR-009 fecha a saída fácil: não devolver lead time no lugar de cycle
time, porque são medidas diferentes.

É o mesmo desenho da promoção de issue, que declara a evidência e a confiança em vez de afirmar.

### 2. Esta é a primeira materialização de um conceito compartilhado

**Nada materializa `spo.performed_project_activity` hoje** — não existe tabela de atividade no
banco.

O conceito é o *kind* de **todas** as ocorrências de atividade da rede: commits, execuções de
teste, cerimônias, implantações. A ontologia diz que elas *"compartilham o mesmo princípio de
identidade"*.

Modelar em torno da timeline do GitHub obrigaria a retrabalhar quando o primeiro commit chegar. O
plano precisa desenhar para o **conceito**, e não para a origem — e a FR-002 é isso virando
requisito.

## Notes

- **O tipo do evento é dado da origem**, e não classificação da plataforma. Traduzi-lo esconderia
  o que a origem disse, e a FR-005 registra o desconhecido nomeando o tipo;
- a **SC-003** é a asserção mais forte: a soma dos classificados e dos desconhecidos é igual ao
  total recebido. É o que impede o descarte silencioso — o defeito que a L57 descreve.
