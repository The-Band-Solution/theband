# Implementation Plan: Os três papéis na solicitação de mudança, e a verificação do commit

**Branch**: `044-pr-e-ci-da-pessoa` | **Date**: 2026-08-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/044-pr-e-ci-da-pessoa/spec.md`

## Summary

Ler o que já está coletado e mostrar na aba de trabalho da página da pessoa: os três
papéis dela na solicitação de mudança — abriu, revisou, integrou —, o veredito de cada
revisão traduzido para conceito da rede, e o desfecho da verificação sobre os commits
dela.

**Nada é coletado, nada é migrado, nada é recoletado.** O dado existe: 5.635 solicitações,
4.233 avaliações com 4.127 pessoas identificadas, 15.671 execuções de verificação.

## Technical Context

**Language/Version**: Elixir 1.20.2 / OTP 29

**Primary Dependencies**: Phoenix LiveView 1.2, Ecto 3.14 — nenhuma nova

**Storage**: PostgreSQL. Tabelas existentes: `collected_change_requests`,
`collected_artifact_evaluations`, `collected_verifications`, `collected_commits`,
`commit_authors`. **Nenhuma migração.**

**Testing**: ExUnit, com injeção de defeito por asserção

**Target Platform**: a mesma aplicação web

**Project Type**: aplicação web multitenant

**Performance Goals**: a página abre dentro do teto de **23 consultas por render** medido
em `test/the_band_web/live/person_detail_test.exs`

**Constraints**: medido em 2026-08-27 — os nove números cabem em **duas** consultas, de
25ms e 42ms sobre o banco de desenvolvimento. O teto passa a 25.

**Scale/Scope**: 88 pessoas observadas, 63 com trabalho designado. A pessoa com mais
participação tem 793 solicitações abertas, 844 integradas e 627 revisadas.

## Constitution Check

| princípio | como esta feature o respeita |
|---|---|
| **V.** consulta sem filtro de tenant é bug de segurança | as duas consultas filtram por tenant na cláusula, e o teste de fronteira injeta a remoção |
| **VIII.** desenho que o problema justifica | ver *Decisões de desenho*, abaixo — três padrões, três custos nomeados |
| **X.** responsabilidade única, em módulo e em tela | a leitura de solicitação vive em `TheBand.Changes`; a de avaliação em `TheBand.Quality`; a de verificação em `TheBand.Verifications`. A tela compõe, e não consulta |
| **XI.** estado conferido antes | não se aplica: a feature não escreve |
| ausência nomeada, nunca zero | FR-012, e três cenários de aceitação a exercitam |
| relator nunca booleano | os três papéis são relatores da rede, e a tela os mostra separados (FR-013) |

### Decisões de desenho, com o custo de cada uma

**1. Uma consulta agregada por bloco, e não uma por número.**

- *Problema que resolve*: a página está exatamente no teto de 23 consultas por render, e
  são nove números. Nove consultas empurrariam para 32.
- *O problema existe agora?* **Sim, medido.** O teste-guarda reprova em 24.
- *O que piora*: a consulta com seis `filter` é mais difícil de ler que seis consultas
  simples, e um erro em qualquer filtro afeta todos os números juntos. Mitigado por teste
  que injeta defeito em cada `filter` separadamente.

**2. A tradução do veredito acontece na leitura, e não em coluna nova.**

- *Problema que resolve*: o `value_map` é dado da base de conhecimento, e pode mudar.
  Materializá-lo criaria uma segunda cópia que diverge da primeira.
- *O problema existe agora?* **Sim** — é o mesmo defeito que a #514 e a #368 evitaram, e
  a #514 mediu: 27 iterações de trimestre que teriam exigido migração se materializadas.
- *O que piora*: toda leitura paga a tradução, e o `value_map` precisa estar carregado. É
  barato — três chaves num mapa — e a base de conhecimento já é carregada no boot.

**3. As listas são separadas das contagens, e carregadas só quando a seção abre.**

- *Problema que resolve*: 793 solicitações não cabem numa tela, e carregá-las para mostrar
  o número "793" seria trabalho jogado fora.
- *O problema existe agora?* **Sim** — `vinicius-je` tem 793, 844 e 627.
- *O que piora*: a lista exige uma interação a mais para aparecer. É o preço de a página
  abrir rápido, e a contagem já responde a pergunta principal.

**Padrão recusado:** um módulo `PersonContributions` que reunisse as três leituras. Ele
atravessaria três fronteiras de domínio — `Changes`, `Quality`, `Verifications` — para
poupar três chamadas na tela. O princípio X existe contra isso: quem quiser saber de
avaliação pergunta a quem é dono de avaliação.

## Project Structure

### Documentation (this feature)

```
specs/044-pr-e-ci-da-pessoa/
├── spec.md
├── plan.md              ← este arquivo
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── leituras.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```
lib/the_band/
├── changes.ex                     ← fachada; ganha `participacao_da_pessoa/2`
├── changes/queries.ex             ← a consulta agregada dos três papéis
├── quality.ex                     ← fachada; ganha `vereditos_da_pessoa/2`
├── quality/verdict.ex             ← NOVO: traduz estado cru → conceito da rede
└── verifications/queries.ex       ← a consulta agregada do desfecho da CI

lib/the_band_web/live/people_live/
└── show.ex                        ← a seção nova na aba de trabalho

test/the_band/
├── changes/participacao_test.exs         ← NOVO
├── quality/veredito_test.exs             ← NOVO
└── verifications/por_pessoa_test.exs     ← NOVO

test/the_band_web/live/
├── painel_da_pessoa_test.exs             ← cenários de tela
└── person_detail_test.exs                ← o teto sobe de 23 para 25, com a conta nomeada
```

**Nenhuma migração. Nenhum arquivo em `priv/repo/migrations/`.**

## Phase 0 — o que precisou ser pesquisado

Ver [research.md](./research.md). Três perguntas, todas respondidas por medição, e
nenhuma `NEEDS CLARIFICATION` restante.

## Phase 1 — desenho

- [data-model.md](./data-model.md) — as entidades já existentes e como se ligam; nenhuma
  nova.
- [contracts/leituras.md](./contracts/leituras.md) — a assinatura das três leituras novas,
  e o formato que cada uma devolve.
- [quickstart.md](./quickstart.md) — o percurso na tela, com os números do banco de
  desenvolvimento para conferir contra.

## Complexity Tracking

| o que se acrescenta | por quê | alternativa recusada |
|---|---|---|
| **2 consultas por render** (23 → 25) | nove números, e nenhum deriva dos já carregados: os três papéis saem de `collected_change_requests`, que nenhuma consulta da página toca | derivar — impossível, o dado não está em memória |
| `TheBand.Quality.Verdict` | traduzir estado cru → conceito, num lugar só | traduzir na tela — espalharia o mapa por cada uso |
| — | | |

**O teto sobe de 23 para 25, com as duas consultas nomeadas no teste.** É o que o próprio
teste exige de quem acrescenta: justificar e nomear, ou derivar. Derivar não é possível
aqui, e a justificativa está medida.
