# Implementation Plan: As medidas que faltam na tela da equipe, e o elo com o projeto

**Branch**: `058-medidas-da-equipe` | **Date**: 2026-09-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/058-medidas-da-equipe/spec.md`

## Summary

Três medidas chegam à tela da equipe, e **duas colunas de período ganham o
primeiro consumidor** desde que foram criadas.

A pesquisa respondeu a pergunta que a spec deixou aberta e **mudou a US3**:
existem dois caminhos de uma verificação até uma equipe, e eles afirmam coisas
diferentes. O escolhido é por **repositório → projeto → equipe**; o do ator
responde *quem apertou o botão*, e não *quem cuida do código*.

Nenhuma migração. Um módulo novo, e ele é **puro**.

**A abordagem em uma frase**: a interseção de períodos vira função pura usada
pelas três histórias, e cada medida ganha função na fachada que já possui o
conceito.

## Technical Context

**Language/Version**: Elixir 1.17

**Primary Dependencies**: Phoenix 1.8 (LiveView), Ecto — nenhuma nova

**Storage**: PostgreSQL, tabelas compartilhadas com `tenant_id`. **Sem migração**

**Testing**: ExUnit; `Phoenix.LiveViewTest`; dois tenants nos testes de
isolamento

**Target Platform**: monólito Phoenix

**Project Type**: aplicação web monolítica modular multitenant

**Performance Goals**: as três medidas somam **no máximo 6 consultas** por render
na tela da equipe, dentro do teto de 16 que a feature 057 declarou — subi-lo é
decisão, e aparece no teste

**Constraints**: `mix gates` verde; nenhuma consulta sem tenant

**Scale/Scope**: 3 medidas, 4 módulos tocados, 1 módulo novo e puro, ~7 funções
públicas, 15 cenários de verificação

## Constitution Check

| Princípio | Situação | Como |
|---|---|---|
| **I** Domínio pelas ontologias | ✅ | cada medida na fachada que possui o conceito |
| **II** Fonte externa não é domínio | ✅ | nenhum conector tocado |
| **III** Proveniência e idempotência | ✅ | nada é gravado |
| **IV** Semântica em YAML | ⚠️ | ver abaixo |
| **V** Monólito modular multitenant | ✅ | `%Tenant{}` explícito; `TheBand.Periodos` é puro e não alcança schema nenhum |
| **VI** Spec Kit antes do código | ✅ | contrato antes da primeira função; fatia vertical |
| **VII** Gates e revisão independente | ⚠️ | ver abaixo |
| **VIII** Desenho que o problema justifica | ✅ | duas decisões registradas abaixo |
| **IX** Ontologias autônomas | ✅ | nenhuma alterada |
| **X** Responsabilidade única | ✅ | `Periodos` faz uma coisa; as medidas vão para quem já tem o conceito |
| **XI** Estado conferido, sinal nunca silenciado | ✅ | três relatores: `{:aguardando,_}`, `{:sem_projeto,_}`, `{:parcial,_}` |

### ⚠️ IV — as medidas precisam ser declaradas antes da tela

`review.time_to_first_review.duration` e `ci.pipeline_success_rate.ratio` **já
existem** em `priv/knowledge_base/measurements/`. O que muda é o **nível**: as
duas ganham `team`, e as limitações do recorte precisam entrar.

`spo.who_worked_on` é pergunta nova, e precisa de necessidade de informação
própria.

**Não é ressalva, é tarefa** — e vem antes das tarefas de tela.

### ⚠️ VII — a revisão independente, pelo terceiro sprint

Os cinco PRs do sprint 028 foram incorporados com **zero revisões**. A L95 nasceu
no 027 e reincidiu no 028.

**A lacuna é declarada, e não marcada como cumprida.** O template de PR criado
no #763 agora tem campo próprio para isso — é a L98 em ação: a obrigação foi para
o artefato onde o ato acontece.

## Decisões de desenho — as três respostas do princípio VIII

### D1 — `TheBand.Periodos`, módulo novo e puro

**Que problema concreto resolve**: a interseção de períodos aparece em três
histórias, com três a quatro períodos cada, e a regra do `nil` é a mesma nas
três. Escrita em cada lugar, divergiria na primeira correção.

**O problema existe agora?** **Sim.** A US2 precisa de três períodos, a US3 de
quatro, e a US1 do mesmo tratamento de borda.

**O que piora**: mais um módulo na raiz de `lib/the_band/`, e quem lê precisa
saber que ele existe para não reescrever a regra. Mitigado por ser pequeno, puro,
e por o contrato apontá-lo das três funções que o usam.

**Alternativa descartada**: pôr a interseção dentro de `EO` ou `SPO`. Intersectar
datas não pertence a ontologia nenhuma, e escolher uma obrigaria as outras a
alcançá-la — contra o princípio V.

### D2 — O caminho da taxa é o repositório, e o do ator não entra

**Que problema concreto resolve**: `actor_person_id` existe e daria uma taxa com
menos trabalho. Ela responderia *as verificações disparadas por quem pertencia à
equipe* — que **não é** a saúde do pipeline dela.

**O problema existe agora?** **Sim.** Execução agendada tem por ator quem
configurou o agendamento; de `push`, quem empurrou. Uma equipe cujo CI roda por
agendamento apareceria quase vazia.

**O que piora**: equipe **sem projeto declarado** fica sem a taxa, mesmo tendo CI
rodando. É ausência correta — a plataforma não sabe de quais repositórios aquela
equipe cuida, e o relator `{:sem_projeto, _}` diz isso.

**Alternativa descartada**: oferecer as duas. Dois números com o mesmo rótulo e
denominadores diferentes é a **L67** — comparar totais esconde que são fenômenos
diferentes.

### O que **não** foi introduzido, e por quê

| Não feito | Por quê |
|---|---|
| tabela de "membros do projeto" | a interseção responde sem materializar, e materializar criaria a segunda fonte que diverge |
| cache da interseção | é aritmética sobre datas; cache traz invalidação, que é o problema |
| behaviour para "provedor de medida" | há três implementações concretas e nenhuma variação pedida |

## Project Structure

```text
specs/058-medidas-da-equipe/
├── plan.md · spec.md · research.md (R1–R7) · data-model.md · quickstart.md
├── contracts/medidas-e-periodos.md
└── checklists/requirements.md

lib/the_band/
├── periodos.ex                        # NOVO — interseccao/1, puro
├── quality.ex                         # + team_time_to_first_review/3 e por pessoa
├── verification.ex                    # + team_pipeline_rate/3
└── ontology/seon/spo/
    ├── projects.ex                    # + who_worked_on/3, project_repositories_in/3
    └── queries.ex                     # os períodos de spo_project_teams e _repositories

lib/the_band_web/live/teams_live/show.ex   # as três seções

priv/knowledge_base/
├── information_needs/                 # a pergunta nova: quem trabalhou no projeto
└── measurements/                      # nível `team` nas duas medidas existentes

test/the_band/
├── periodos_test.exs                  # a borda, e os três estados
├── quality_test.exs                   # recorte pela abertura, espera em curso
├── verification_test.exs              # as cinco fases, o ator que não entra
└── ontology/seon/spo/projects_test.exs # a interseção de três períodos

test/the_band_web/live/teams_live/
└── medidas_da_equipe_test.exs         # as três seções, e o teto de consultas
```

**Structure Decision**: sem diretório novo. `TheBand.Periodos` fica na raiz
porque não pertence a ontologia nenhuma.

## Ordem de implementação

| Fase | O que entra | Prova |
|---|---|---|
| **1** | `TheBand.Periodos` | Cenários 1 e 2 — o `nil` e a borda |
| **2** | as medidas declaradas em YAML | `mix knowledge.validate` |
| **3** | `who_worked_on/3` e a seção na tela | Cenários 3, 4 e 5 |
| **4** | o tempo de revisão, recortado | Cenários 6, 7 e 8 |
| **5** | a taxa do pipeline, e a recusa | Cenários 9 a 12 |
| **6** | tenants, teto de consultas, gates | Cenários 13 e 14 |

**A fase 1 vai primeiro e sozinha** porque as três histórias dependem dela, e
porque é a única cuja correção é puramente lógica — testável sem banco.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| **a cobertura do dado ser quase zero** | a taxa existe e não informa | Cenário 0 mede antes da aceitação; `execucoes_consideradas` na tela |
| o `{:parcial, _}` ser ignorado por quem consome | volta o fallback silencioso | o tipo tem três estados; o `case` sem a terceira cláusula não compila limpo |
| teto de consultas da tela estourar | tela lenta, gate vermelho | teto de 16 já é teste desde a 057; as novas cabem em 6 |
| revisão independente de novo não acontecer | princípio VII violado pelo terceiro sprint | campo no template de PR, criado no #763 |

## Dívida assumida

**A cobertura do dado é desconhecida** e permanece assim até alguém rodar o
Cenário 0 com a chave mestra. Está declarado em R6, no quickstart e aqui — não
escondido.

## Complexity Tracking

Nenhuma violação. Os dois ⚠️ são **tarefa** (declarar em YAML) e **lacuna
declarada** (revisão independente), não desvios.
