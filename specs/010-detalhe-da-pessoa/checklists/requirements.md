# Specification Quality Checklist: o detalhe da pessoa

**Purpose**: Validar completude e qualidade da especificação antes do planejamento
**Created**: 2026-08-12
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhe de implementação (linguagem, framework, API)
- [x] Focada em valor para quem usa
- [x] Escrita para quem decide, não para quem implementa
- [x] Todas as seções obrigatórias completas

## Requirement Completeness

- [x] Nenhum marcador `[NEEDS CLARIFICATION]` restante
- [x] Requisitos testáveis e sem ambiguidade
- [x] Critérios de sucesso mensuráveis
- [x] Critérios de sucesso independentes de tecnologia
- [x] Cenários de aceitação definidos para as três user stories
- [x] Casos de borda identificados — seis
- [x] Escopo delimitado, com o que fica fora e por quê
- [x] Dependências e premissas declaradas

## Feature Readiness

- [x] Cada requisito funcional tem critério de aceitação
- [x] Os cenários cobrem o fluxo principal
- [x] A feature atende aos resultados mensuráveis
- [x] Nenhum detalhe de implementação vazou

## O que a medida decidiu, e entrou na spec

**O zero é o achado, e ele desenha a feature.** 88 evidências de vínculo pessoa-equipe contra **zero**
vínculos materializados, e zero papéis cadastrados. Não é defeito: o vínculo da ontologia exige papel,
e cadastrar papel é outra feature — #99 e #100.

A consequência para a tela é o requisito mais importante daqui: ela mostra **três** coisas onde uma
tela comum mostraria uma. O que a origem declarou, que a plataforma **não** promoveu, e **por quê**.

| esconder | produziria |
|---|---|
| a evidência | uma pessoa sem equipe nenhuma, o que é falso |
| a não promoção | a tela afirmando um vínculo que a plataforma recusou |
| o motivo | a recusa parecendo defeito da plataforma |

**Os números proibidos estão escritos**, e é a lição da feature 006 — *"mostre 9 e 30, nunca 39"*. Aqui:
**4 232** designações e **4 241** autorias não se somam, e FR-009 proíbe exibir a soma. Um requisito que
proíbe um número é verificável; "não confunda designação com autoria" não é.

**A confusão mais fácil desta feature ganhou requisito próprio**: FR-004 proíbe derivar papel de nível
de acesso. `MAINTAINER` é permissão na ferramenta, `sro.scrum_master` é papel no processo — e mapear um
no outro seria mapear por semelhança de nome, que o projeto proíbe.

**O que ficou fora, ficou por decisão.** Cadastrar papel resolveria o zero e é outra feature; as 288
issues sem autor não pertencem a pessoa nenhuma; e editar dado da pessoa criaria uma segunda verdade
sobre o que a origem declara.

## O que a análise achou, e uma correção é crítica

`/speckit-analyze` rodou antes do código. **Seis das sete suspeitas procederam**, e a crítica é sobre
**fronteira**:

| # | O que estava errado | O que passou a valer |
|---|---|---|
| **A1** | `repositories_of_person/2` devolve identificador e contagens, e **nada** diz o nome do repositório. O nome é de **CMPO** — uma **terceira** fronteira que o plano não declarava. A implementação descobriria o dado faltando e resolveria por linha, violando FR-016 | CMPO declarado no plano e em T005/T009; o nome vem de **uma** consulta virando mapa, como o `onde/2` da feature 007 |
| A2 | há **dois** `no_longer_observed_at` — issue e designação — e nada dizia o que fazer com designação vigente em issue **ausente** | FR-008a: **a issue manda**. A pessoa não trabalha no que a plataforma não observa mais |
| A3 | o plano dizia **quatro** consultas; as tarefas produzem **oito**. E V8 media "um número que não cresce", que passa com 8 e com 80 | oito declarado e **asserido**, com a tabela do que é cada uma |
| A4 | o terceiro caso da explicação dizia *"a causa não é a ausência de papel"* — plausível e sem conteúdo | medido: `eo_organizational_roles` é catálogo do tenant, e `organizational_role_id` é NOT NULL. O terceiro caso passa a ser **verificável**: ninguém alocou papel a esta pessoa nesta equipe |
| A5 | as 288 issues sem autor eram afirmação **sem verificação** | SC-009a e V10: a soma das autorias fecha com **4 241** |
| A6 | o componente era justificado por **três** usos | são **dois** — equipe e vínculo ausente são a mesma lista. Fica no limiar do projeto, e isso está declarado |

**Uma suspeita não procedeu**: `fetch_person/2` não duplica nada — a fronteira EO tem seis funções de
leitura de pessoa e **nenhuma** busca por identificador.

**O A1 é o achado que mais importa, e não é sobre lógica**: é sobre um **registro errado de
fronteira**. `repository_live/show.ex` já compõe três fronteiras, então não havia violação — mas um
plano que afirma duas autoriza a próxima pessoa a cruzar uma sem pensar.

## Notes

Nenhum item incompleto.

**Dezoito requisitos, treze critérios.** Cresceu em relação à primeira versão — 17 e 12 —, e o
acréscimo veio da análise.

**Medido antes de escrever**: 75 pessoas, 12 equipes, 88 evidências, 0 vínculos, 4 232 designações,
4 241 autorias, 288 issues sem autor. E a distribuição: 59 pessoas com designação, 44 com autoria, **75
com evidência de equipe**, nenhuma sem nada.

O caso de borda 1 — pessoa sem nada coletado — **não existe hoje**, e está na lista porque a página tem
de abrir para ela sem inventar conteúdo.
