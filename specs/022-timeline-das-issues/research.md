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

## R2 — A movimentação no quadro **está** na timeline da issue

**Decisão**: a feature coleta a timeline da issue, **e a movimentação vem junto**. A suposição
inicial — de que ela viveria na API do Projects v2 — foi medida e refutada.

**MEDIDO em 2026-08-14**, contra a API real, com a chave mestra da pessoa mantenedora. A
suposição estava **errada**, e a correção muda o tamanho da feature.

`ProjectV2ItemStatusChangedEvent` **está na timeline da issue**, e traz tudo o que os
antipadrões precisam:

```
ProjectV2ItemStatusChangedEvent em 2026-08-12T20:54:47Z por paulossjunior
   "" -> "Backlog"
ProjectV2ItemStatusChangedEvent em 2026-08-14T13:01:06Z por github-project-automation
   "Backlog" -> "Done"
```

Instante, `previousStatus → status`, e o autor. **A dependência da
[#181](https://github.com/The-Band-Solution/theband/issues/181) cai**: os quatro antipadrões
funcionam nesta feature.

### O quadro real, medido em 200 issues

```
187 de 200 issues têm alguma movimentação
Done 182 · Backlog 92 · In review 55 · Ready 28
quem move: paulossjunior 197 · github-project-automation 160
```

**Não existe coluna "Em andamento".** O fluxo observado é `Backlog → Ready → In review → Done`,
e nenhum nome diz "começou".

Isso **não invalida a regra declarada** — a movimentação continua sendo o sinal de início. O que
ela mostra é que **qual movimentação** marca o começo é decisão que só quem conhece o quadro
pode tomar: `Ready` significa pronto para pegar, ou já pego?

É exatamente o que a FR-010 existe para permitir: a tela mostra os estados observados com a
frequência, e alguém decide.

### E quase metade das movimentações é de robô

`github-project-automation` fez **160** das 357. Duas consequências:

- **`performer_id` anulável não é caso raro** — a ontologia já previa, e o dado confirma;
- **movimentação automática não é o mesmo sinal que movimentação humana.** Um cartão que o robô
  moveu para `Done` ao fechar a issue não diz que alguém trabalhou nela: diz que a issue fechou.
  A detecção de antipadrão precisa distinguir os dois, e o `ap02` — movida depois de fechada —
  é justamente esse caso.

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

## O que foi medido, e o que mudou

**As três foram respondidas em 2026-08-14**, contra a API real:

| # | Pergunta | Resposta |
|---|---|---|
| 1 | `timelineItems` vem na mesma consulta da issue | **sim** — e aceita `itemTypes:` para filtrar |
| 2 | quais tipos, e em que volume | **8 tipos** nas issues medidas; máximo de **18 itens** numa issue |
| 3 | movimentação de Projects v2 aparece ali | **sim** — `ProjectV2ItemStatusChangedEvent`, com estado anterior, novo e autor |

Os tipos observados: `CrossReferencedEvent`, `SubIssueAddedEvent`,
`ProjectV2ItemStatusChangedEvent`, `AddedToProjectV2Event`, `ClosedEvent`, `IssueComment`,
`IssueTypeAddedEvent`, `LabeledEvent`, `ParentIssueAddedEvent`.

**Nada pendente.** A fase 0 do plano está cumprida, e o que ela achou mudou duas decisões: a
dependência da #181 caiu, e a distinção entre movimentação humana e automática entrou.
