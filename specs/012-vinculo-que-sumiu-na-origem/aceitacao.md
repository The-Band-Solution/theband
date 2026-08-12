# Aceitação — feature 012, o vínculo que sumiu na origem

**Avaliada em**: 2026-08-12 · **PR**: [#278](https://github.com/The-Band-Solution/theband/pull/278)
**Método**: cada critério avaliado **um a um**, com a evidência ao lado. Suíte verde não é
evidência de critério — é evidência de que a suíte passou.

---

## Requisitos funcionais — 14 de 14

| # | Requisito | Veredito | Evidência |
|---|---|---|---|
| FR-001 | marca o vínculo do repositório coletado que a execução não reviu | **aceito** | `decomposition_absence_test.exs` — "marca o vínculo que a execução não reviu" |
| FR-002 | corte é o início da execução; data é o instante em que se notou | **aceito** | "a data gravada é o instante em que se notou, não o corte" — compara marca com corte |
| FR-003 | escopo é o repositório do **pai** | **aceito** | "não alcança o vínculo cujo pai está em outro repositório"; e o caso de coleta cruzada na integração |
| FR-004 | uma vez por repositório, só depois da leitura bem-sucedida | **aceito** | a chamada está no ramo `{:ok, …}` de `coletar_issues/2`; os três casos de falha asserem zero |
| FR-005 | repositório não coletado não tem vínculo marcado | **aceito** | três casos: transitória, permanente e inacessível |
| FR-006 | vínculo que reaparece volta a vigente, com a observação original | **aceito** | "a parte que volta a ser declarada volta a vigente"; e a comparação de `observed_at` |
| FR-007 | nada é apagado | **aceito** | `map_size(por_filha) == 2` depois da marca — a linha continua |
| FR-008 | idempotente | **aceito** | segunda chamada devolve `{:ok, 0}` e o mapa de datas é idêntico |
| FR-009 | marca existente não é reescrita | **aceito** | "coleta posterior não reescreve a data de quem já estava marcado" |
| FR-010 | escopado por tenant | **aceito** | "não alcança vínculo de outro tenant" — a asserção é sobre o vínculo do vizinho |
| FR-011 | a lista exibe o vínculo ausente como ausente, com texto | **aceito** | `decomposition_absence_screen_test.exs` — estado montado **pela coleta** |
| FR-012 | contagens contam só vigentes | **aceito** | "um pai vigente e um vínculo que a coleta marcou é UM pai, não dois" |
| FR-013 | a coleta registra, por repositório, quantos marcou | **aceito** | `resultado.decomposition_links_absent`, e os dois casos de log — fala quando marca, cala quando não |
| FR-014 | recusas permanecem fora | **aceito** | "a recusa registrada não é tocada pela marca" — `refused_at` inalterado |

## Critérios de sucesso — 3 aceitos, 4 pendentes de dado real

| # | Critério | Veredito | Evidência ou o que falta |
|---|---|---|---|
| SC-001 | os 52 vínculos que a origem não declara mais aparecem marcados | **pendente** | exige coleta com a origem respondendo — chave mestra, T009 |
| SC-002 | os que a origem ainda declara continuam vigentes: 157 no `theband`, e só os 15 saem | **pendente** | mesmo motivo. O mecanismo está aserido: a coleta que deixa de declarar **uma** parte marca **uma** |
| SC-003 | zero marcados em repositório não coletado | **aceito em teste, pendente no dado real** | três casos de falha asserem zero; a consulta do quickstart confere no banco |
| SC-004 | a lista de `eo_lib` deixa de apresentar as 29 como atuais | **pendente** | exige **olho humano** na tela, depois da coleta |
| SC-005 | duas coletas sem mudança produzem as mesmas datas | **aceito** | "coleta sem mudança na origem não marca nada" e o mapa de datas na idempotência |
| SC-006 | o log nomeia repositório e número | **aceito** | `capture_log` exige a linha quando marca e a **ausência** dela quando não |
| SC-007 | o painel da `sro.rule07` cai de 293 para 281 | **pendente** | medido **antes** no banco (12 dos 52); a conferência depois da coleta é de T009 |

---

## Por que os pendentes não são contados como cumpridos

**Os quatro dependem da origem respondendo, e três deles de olho humano.** A chave mestra é da
pessoa mantenedora, não entra no chat nem no repositório, e nenhuma asserção em HTML substitui
alguém olhar a tela.

Marcar esses critérios como atendidos porque a suíte passou seria exatamente o defeito que esta
feature corrige, aplicado ao processo: afirmar o que não se observou.

## O que a implementação achou, e a spec não previa

| # | Achado | Onde ficou registrado |
|---|---|---|
| 1 | duas coletas na suíte caem no **mesmo segundo**, e o corte é estrito — sem envelhecer o dado, nenhuma marca acontece | comentário em `tempo_passou/1`, nos três arquivos de teste |
| 2 | corte no **futuro** marca tudo que não foi revisto, o que está certo — e torna a asserção de idempotência uma comparação de **datas**, não de contagem | comentário no caso "coleta posterior não reescreve" |
| 3 | **vínculo entre repositórios só existe na segunda coleta**: na primeira a filha ainda não foi gravada, e a relação vira recusa `out_of_scope` | comentário no caso de coleta cruzada — e explica as 4 recusas do dado real |

**O terceiro é conhecimento novo sobre o dado**, não detalhe de teste: os 57 vínculos que cruzam
repositório existem porque houve uma coleta anterior que os recusou.

## Escopo recusado, e por quê

| Fora | Razão |
|---|---|
| `order_by` em `fetch_parent/2` ([#261](https://github.com/The-Band-Solution/theband/issues/261)) | defeito vizinho, outra tela, issue própria |
| filha promovida a defeito no detalhe do pai ([#262](https://github.com/The-Band-Solution/theband/issues/262)) | idem |
| generalizar as quatro marcações de ausência | os cortes não são iguais — um por data, dois por lista |
| campo em `syncs` contando vínculos marcados | número ao lado de números que respondem outra pergunta |

## Veredito

**Feature aceita quanto ao que pode ser verificado sem a origem.** Os 14 requisitos funcionais
têm evidência; três dos sete critérios de sucesso estão aceitos, e **quatro seguem declarados
como pendentes** até a coleta no dado real e a conferência de tela.

A user story **US2** só está provada em teste: a conferência visual de `eo_lib` é de quem tem a
chave.
