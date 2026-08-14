# Research — a timeline da issue

**Feature** `022-timeline-das-issues` · **Data**: 2026-08-14

Cinco decisões. A primeira é a que dura mais que esta feature.

---

## R1 — A forma da tabela de atividade

**Decisão**: `spo_performed_project_activities`, modelada pelo **critério de identidade do
conceito**, e não pela timeline do GitHub.

**Fundamento**: `spo.performed_project_activity` é o *kind* de todas as ocorrências de atividade
da rede, e a ontologia diz que elas *"compartilham o mesmo princípio de identidade"*. O critério
já está escrito:

```
tenant_id · organization_id · project_id · activity_type · performer_id · occurred_at · source_external_id
```

com `performer_id` e `source_external_id` anuláveis, e a nota da própria ontologia explicando por
quê: *"atividades automatizadas não têm executor humano"*, e *"source_external_id preserva a
identidade da fonte quando ela existe"*.

**Medido em 2026-08-14**: nenhuma tabela materializa o conceito. Esta é a primeira.

**O que isso obriga.** Commits, execuções de teste, cerimônias e implantações vão para a **mesma
tabela**. Três consequências no desenho:

| Decisão | Por quê |
|---|---|
| `activity_type` é texto, não `Ecto.Enum` | um enum obrigaria migração a cada origem nova, e a lista de tipos é do mundo, não do código |
| a referência à issue **não** é coluna obrigatória | um commit não tem issue; forçar a coluna faria metade das linhas nulas quando a segunda origem chegar |
| `project_id` fica no critério mesmo sem uso hoje | está no conceito, e omiti-lo agora faria o hash mudar quando ele for preenchido — quebrando toda referência existente |

**Alternativas consideradas**:

| Alternativa | Por que não |
|---|---|
| uma tabela por origem — `github_issue_events` | contraria o conceito: a ontologia põe o *kind* em SPO justamente para as origens não definirem cada uma o seu |
| guardar só em `raw_payloads` | o payload já é guardado; o que falta é a **ocorrência** consultável, com executor e instante |
| ligar a atividade à issue por coluna dedicada agora | ver acima — e a ligação genérica resolve, porque a issue já tem identidade própria |

---

## R2 — A movimentação no quadro **não** está na timeline da issue

**Decisão**: a feature coleta a timeline da issue. A movimentação no Projects v2 **fica de fora**,
e a dependência é declarada.

**Fundamento**: a timeline de uma issue no GitHub traz `assigned`, `unassigned`, `labeled`,
`unlabeled`, `closed`, `reopened`, `renamed`, `cross-referenced`, `mentioned`. A mudança de
coluna num quadro do **Projects v2** vive na API do projeto — é a issue
[#181](https://github.com/The-Band-Solution/theband/issues/181).

> **NÃO MEDIDO AQUI.** Confirmar exige a chave mestra e é **uma** consulta. É a primeira tarefa
> do plano, pelo mesmo motivo da feature 020: construir sobre suposição de API é a **L23**.

**A consequência, e ela precisa estar na tela.** As quatro máximas de antipadrão dependem da
movimentação. Com esta feature sozinha, a detecção devolve **zero** — e o
`process_antipatterns.yaml` já diz que zero ali não significa processo saudável.

**Por que a feature vale assim mesmo:**

| O que ela entrega sem a #181 |
|---|
| a primeira materialização de `spo.performed_project_activity`, com a forma que as irmãs herdam |
| quem designou, quem fechou, quem reabriu — com autor e instante |
| a base do `ap03` (designada e nunca iniciada), que só precisa da ausência de movimentação |
| os tipos de evento observados e a frequência de cada um — o que permite decidir |

---

## R3 — O que fazer com o tipo que a rede não nomeia

**Decisão**: registrar, nomeando o tipo **como a origem o nomeou**, com o conceito nulo.

**Fundamento**: `labeled`, `mentioned`, `cross-referenced` e `renamed` não têm conceito na rede.
Descartá-los faria a soma dos eventos registrados divergir do que a origem devolveu — e ninguém
notaria, porque não haveria erro.

É o defeito da **L57** na forma exata: percorrer o que existe, filtrar por um critério que
elimina tudo, e devolver verde.

**A SC-003 é a asserção disso**: classificados mais desconhecidos igual ao total recebido.

**Alternativas consideradas**:

| Alternativa | Por que não |
|---|---|
| coletar só os tipos mapeáveis | o que a origem mandou e a plataforma não guardou não volta; e o mapeamento pode crescer depois |
| traduzir para vocabulário próprio | esconderia o que a origem disse, e a proveniência exige o oposto |
| gravar tudo como `unknown` sem o tipo | perderia a informação que permite decidir o que mapear a seguir |

---

## R4 — O custo, e por que ele mudou

**Decisão**: coletar a timeline dentro da janela da feature 020 — repositório pulado não tem
timeline pedida, issue não alterada também não.

**Fundamento, medido em 2026-08-14**:

```
121 repositórios da leds-conectafapes · 106 sem push desde a última revisão
5032 issues · 1967 comentários no total · máximo 16 numa issue
```

A issue [#179](https://github.com/The-Band-Solution/theband/issues/179) foi adiada em 2026-08-11
por custo, estimado a partir de um caso extremo — *"a issue #1 tem 48 itens de timeline"*. A
medida dos comentários mostrou que o extremo não se generaliza: o máximo real é 16, e três em
cada quatro issues não têm comentário algum.

**A distribuição de eventos de timeline continua não medida** — a plataforma não os coleta. É a
segunda pergunta da tarefa de verificação.

---

## R5 — Onde a detecção de antipadrão vive

**Decisão**: **fora desta feature.** A 022 coleta e registra; a detecção é consumidora.

**Fundamento**: a mesma separação que a plataforma já usa entre coletar issue e promover conceito.
`Mapping` lê o que `Ingestion` gravou, com regra declarada em YAML e confiança registrada.

Misturar as duas faria a coleta decidir o que é antipadrão, e mudar a regra exigiria recoletar.

**O `process_antipatterns.yaml` já está na base**, com `enforcement: detection` e os limites
escritos. Esta feature entrega o **dado** que ele consome.

---

## O que fica pendente de medida

| # | O que verificar | Como | Bloqueia |
|---|---|---|---|
| 1 | `timelineItems` vem na mesma consulta da issue | uma consulta com a chave mestra | o custo, e a US3 |
| 2 | quais tipos de evento a origem devolve, e em que volume | a mesma consulta, contando | o mapeamento, e o teto da tabela |
| 3 | movimentação de Projects v2 aparece na timeline da issue | a mesma consulta, procurando | a dependência da #181 |

As três são **uma tarefa**, e nenhuma linha é escrita antes dela. Se a terceira responder "sim",
a dependência da #181 cai e os antipadrões funcionam nesta feature.
