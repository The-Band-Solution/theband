# Sprint 018 — Competências da equipe

**Período**: 2026-08-16 · **Feature**: [029](../../../specs/029-competencias-da-equipe/spec.md)

## Objetivo

Ao abrir uma equipe, a leitura que nenhum currículo dá: cobertura de competências, quem
demonstra o quê, resumo calculado e evolução por geração — tudo contado dos perfis que já
existem, zero chamadas a modelo.

## Lições aplicadas

| Lição | Como |
|---|---|
| L60/L59 | gates por `> log; ec=$?; exit $ec`; contador único de consultas no teste de custo |
| sucesso silencioso | sem-perfil é nomeado, nunca zero; mês sem geração não existe na série |
| #372 | o teste de custo usa `TheBand.ContadorDeConsultas` |

## Tarefas

| # | Tarefa | Estado |
|---|---|---|
| T001 | Contrato `TeamSkills` (coverage/evolution/summary) | feito (com a spec) |
| T002 | `Profiles.TeamSkills` — agregação com nº fixo de consultas | feito |
| T003 | Evolução por mês com geração — perfis vigentes na data | feito |
| T004 | Resumo calculado, com teto e a frase da granularidade | feito |
| T005 | A seção na tela da equipe — barras, matriz, sparklines, hachura | feito |
| T006 | Testes: SC-001 a SC-004 + FR-006a (sem ranking) | feito |
| T007 | Associar equipe↔projeto também pela tela da equipe (pedido em sessão) | feito |

**Iteration**: não criada (L11). Issue única da feature: ver acima.

## DoD

- [x] gates 13 verdes (971 testes, 14 novos) · [x] SC-001..004 por teste · [x] tela verificada no app com dado real (PLATAFORMA, 18 membros)
- [ ] PR com revisor `the-band` conferido · [ ] review + lições

## O que o dado real ensinou (vai para as lições)

Os domínios dos perfis são hiperespecíficos por pessoa: no time real, TODO domínio deu
1/18, e a frase de ponto único listou 40+ nomes. Dois consertos no mesmo dia: teto na
frase (3 nomes + contagem) e a frase da granularidade — "é limite do registro, não
ausência de sobreposição". A agregação por área é exatamente o que a #363 vai dar.
