# Implementation Plan: Perfil de competências e evolução

**Branch**: `056-perfil-de-competencias` · **Spec**: [spec.md](./spec.md) · **Data**: 2026-08-15

## Summary

Uma aba na página da pessoa que mostra as habilidades que a evidência sustenta, como o
trabalho mudou, e onde a evidência é rala. O texto é escrito por um modelo de linguagem a
partir das descrições das tarefas; os números ao redor são observados.

A feature é **uma fatia vertical**: migração, montagem do material, borda HTTP nova, job e
tela, todos na mesma entrega. Não há passo de infraestrutura sem consumidor visível.

## Technical Context

| | |
|---|---|
| **Linguagem** | Elixir 1.18 / OTP 27, Phoenix LiveView |
| **Persistência** | PostgreSQL 16, Ecto, multitenant por `tenant_id` |
| **Trabalho de fundo** | Oban, fila nova `perfis` |
| **Borda externa nova** | provedor de modelo de linguagem, compatível com a API de *chat completions* |
| **Credencial** | `API_KEY` no ambiente; nunca em repositório, nunca em log |
| **Modelo padrão** | configurável; `gpt-5.4-mini` na validação — 24k tokens de entrada, ~2k de saída, 25 a 60 s |
| **Escala** | 25 pessoas com 30+ tarefas designadas; geração sob demanda, uma por vez |
| **Testes** | ExUnit, Mox **só** na borda HTTP do provedor |

Nenhum `NEEDS CLARIFICATION` restante: `FR-023` e `FR-024` foram decididos em 2026-08-15.

## Constitution Check

| princípio | como esta feature atende |
|---|---|
| **I — domínio vem das ontologias** | atendido **pela negativa**: nenhum conceito de competência é criado. O perfil é documento sobre `eo.person`, e a decisão está em [research.md R1](./research.md) com as alternativas recusadas |
| **IV — semântica em YAML** | os limiares que decidem o que a tela afirma — piso de evidência, critério de destaque, limiar da linha de base — moram em YAML, não em constante de módulo |
| **VII — revisão independente** | PR com revisor pedido; esta condição **não pode ser satisfeita por mim** e fica declarada como lacuna, não marcada como cumprida |
| **VIII — desenho que o problema justifica** | tabela abaixo |
| **IX — ontologias modulares** | nenhuma ontologia é tocada |
| **X — uma tela faz uma coisa** | a aba responde *"em que esta pessoa é boa, e como isso mudou"*. Não mostra trabalho corrente, que é a aba ao lado |

### Os padrões que esta feature introduz

Princípio VIII exige três respostas por padrão. Padrões já justificados em `AGENTS.md` §7.7
não são rejustificados; o que aparece aqui é uso **fora** do problema original, ou padrão novo.

| padrão | que problema concreto resolve | o problema existe agora? | o que fica pior |
|---|---|---|---|
| **Porta e adaptador na borda do provedor** (`LLM.HTTP` + Mox) | é o único ponto que o teste substitui; sem ele, testar geração exige rede e crédito | **sim** — a validação de 2026-08-15 gastou chamadas reais para exercitar o formato | mais um `Application.get_env`, e um salto de leitura entre quem pede o perfil e quem faz o HTTP |
| **Job Oban em vez de chamada síncrona** | a chamada leva de 25 a 60 s, medidos; segurar o LiveView prenderia a aba e um timeout derrubaria a tela | **sim**, medido | a tela ganha um terceiro estado — *pedido, ainda não pronto* — que precisa ser distinguível de *nunca gerado* e de *falhou* |
| **Tabela somente-acréscimo** | `FR-015`: geração nova não apaga a anterior | **sim** — é requisito, não previsão | a consulta do perfil vigente precisa de `order by … limit 1`, e a tabela cresce sem poda. Com 25 pessoas e geração sob demanda, o crescimento é desprezível |
| **Veredito calculado fora do modelo** | o modelo errou a divisão na validação: chamou 415 → 814 de "perto de estável" | **sim**, observado | duplica em código uma leitura que o texto também faz; se divergirem, a tela mostra duas versões da mesma comparação. Mitigado porque o veredito **entra no prompt**, e o texto parte dele |
| **Limpeza do resumo em código** | o modelo ignorou quatro vezes o teto de citações no resumo | **sim**, observado | edição mecânica de texto gerado é frágil e pode deixar frase quebrada; por isso a limpeza cobre também o conectivo órfão, e o log diz quantas citações saíram |

**Nenhum padrão especulativo.** Não há behaviour com uma implementação prevista para "quando
trocarmos de provedor": a borda existe porque o teste precisa dela hoje.

## Complexity Tracking

Nada a registrar: nenhuma violação de princípio, e nenhum padrão sem problema presente.

Um ponto merece nota, e não é violação: **a feature grava texto de máquina sobre pessoa real,
legível por todo o tenant, sem caminho de contestação** (`FR-023`, `FR-024`, decididos em
2026-08-15). A contenção inteira do risco fica nas recusas `FR-007` a `FR-011` — não há
segunda barreira. Isso eleva o peso dos testes dessas recusas: eles não são higiene, são a
única defesa.

## Project Structure

### Documentation (this feature)

```text
specs/026-perfil-de-competencias/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── contracts/perfil-derivado.md
├── quickstart.md
└── checklists/requirements.md
```

### Source Code

```text
priv/knowledge_base/
├── information_needs/people_demonstrated_domains.yaml   necessidade declarada — §17
└── rules/profile_thresholds.yaml                        pisos e limiares — princípio IV

priv/repo/migrations/
└── ..._create_eo_person_profiles.exs                    somente-acréscimo

lib/the_band/ontology/seon/eo/
├── schemas/person_profile.ex
├── profiles.ex                                          comando e consulta
└── eo.ex                                                fachada, defdelegate

lib/the_band/profiles/
├── material.ex          monta o recorte por pessoa: períodos, linha de base, veredito
├── baseline.ex          a linha de base do tenant por mês — uma consulta
├── prompt.ex            lê o prompt do YAML e compõe
├── sanitizer.ex         a limpeza do resumo, com contagem
└── generate_worker.ex   job Oban

lib/the_band/integrations/llm/
├── http.ex              behaviour — o único ponto que o Mox substitui
└── http/req.ex

lib/the_band_web/live/people_live/
└── show.ex              a aba

test/the_band/profiles/          material, baseline, sanitizer, worker
test/the_band_web/live/          a aba: recusa, proveniência, os três estados
```

## O que cada fase entrega

| fase | entrega | por que nesta ordem |
|---|---|---|
| **1 — base de conhecimento** | necessidade de informação e limiares em YAML | princípio IV: os números que decidem o que a tela afirma não nascem no código |
| **2 — o material** | `Material`, `Baseline`, e o veredito calculado | é testável sem rede, e é onde mora o defeito mais caro se estiver errado |
| **3 — a borda e o job** | `LLM.HTTP`, `Req`, `Sanitizer`, `GenerateWorker` | a borda existe porque o job precisa dela; o sanitizador é testado com o texto real da validação |
| **4 — a persistência** | migração, schema, comando e consulta | só agora, porque o que se grava já está definido |
| **5 — a tela** | a aba, com os três estados e a proveniência | a fatia fecha aqui |

Fases 1 e 2 são pré-requisito de tudo. As demais são sequenciais.
