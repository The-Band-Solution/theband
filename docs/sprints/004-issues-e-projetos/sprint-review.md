# Sprint Review 004 — Issues e projetos das organizações observadas

**Período**: 2026-08-11 · **Encerrado em**: 2026-08-11
**Backlog**: [sprint-backlog.md](sprint-backlog.md) · **Aceitação**: [aceitacao.md](aceitacao.md)

Separa o que foi entregue do que não foi. Nada marcado como pronto sem evidência.

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| Fases | F0 a F3 (MVP) | **4** |
| Tarefas | 29 | 29 |
| Testes | 177 → | **218** |
| Lições novas | — | 2 — L25 e L26 |
| Requisitos acrescentados durante o sprint | — | 15 |

## O que foi feito

### F0 — O kind referenciado, em um conceito

`sys_swo.loaded_software_system_copy` ganhou `ontouml_stereotype: kind`. **Um** conceito,
não onze — a regra da fronteira da constituição IX reduziu a exigência, e os outros 10 da
SysSwO seguem sem estereótipo de propósito.

Cinco testes travam a declaração, e provei que reprovam nos dois sentidos: trocando
`source_repository` para `kind`, 4 de 5 passam; removendo o estereótipo do kind, 3 de 5.

### F1 — Semântica declarada antes do código

Regra do tenant com os três tipos que a organização usa, com os identificadores conferidos
pela API. Nove testes, e dois deles pela violação: mapear `Priority` para `importance`
reprova nomeando o antipadrão.

### F2 — Repositório observado

135 repositórios descobertos a partir das organizações, nenhum conectado individualmente.
Tabela própria com o que **qualquer hospedagem de Git** fornece — e três coisas deixadas de
fora com o motivo: `is_fork` (é relação, não propriedade), a lista de linguagens (exigiria
conceito próprio), licença e tamanho em disco.

### F3 — Issues, promoção, recusa e tela

4455 issues, 4455 promoções vigentes, 1614 vínculos de decomposição. A tela `/trabalho` no
ar, com menu, paginação, organização e repositório.

**O teste que importa passa**: a issue `#3`, com nove sub-issues do tipo `Task`, é
**atômica**. Tarefa atende, não compõe.

### Mudanças de desenho decididas durante o sprint

| Decisão | O que mudou |
|---|---|
| **sincronizar traz tudo** | o worker separado virou fase da mesma sincronização; um registro, um relatório |
| **mapeamento por organização** | escopo passou de tenant para ferramenta conectada, configurado ao definir |
| **repositório vira tabela** | atributos declarados na ontologia, e é isso que faz a extensão existir |
| **identificador em tudo** | `source_external_id` obrigatório; tipo de issue **tem** id, ao contrário do que eu havia escrito |
| **unicidade escopada pelo tipo** | o mesmo identificador pode designar artefatos diferentes |
| **quadro é planejamento** | Projects v2 não é promovido a projeto |

## Evidência

### O dado real, no banco de desenvolvimento

```text
135 repositórios observados       4455 issues coletadas
4455 promoções vigentes           5022 no histórico (append-only)
1614 vínculos                        4 recusados (todos out_of_scope)
4833 payloads de issue             163 payloads de repositório
   0 issues marcadas como ausentes
```

Conferido contra a API: `The-Band-Solution` tem 14 repositórios e 189 issues. A plataforma
coletou **14 e 189**.

### A tela, no ar

```text
Trabalho
4455 issues coletadas · 135 repositórios observados

  PROMOVIDAS         1015     NÃO PROMOVIDAS       3440     DIVERGÊNCIAS   23
    épico              23       sem tipo na origem 3403
    user story atóm.  699       tipo desconhecido    37
    tarefa pretend.   110         Chore (17), Refactor (16), Hotfix (4)
    defeito           183

  organização        repositório        #   tipo    partes  promovida a
  leds-conectafapes  agentes-planning   2   Bug          0  defeito
  leds-conectafapes  agentes-planning   3   Chore        0  tipo desconhecido: Chore
  1–50 de 4455       página 1 de 90
```

### Gates

Nove verdes, por `mix gates`, conferidos por código de saída — não por leitura de saída.

| Gate | Resultado |
|---|---|
| format, compile, credo, dialyzer | passou |
| testes | **218** |
| knowledge.validate, knowledge.graph | passou |
| validador Python | passou, **com a validação de forma** |
| derivação reproduzível | passou nas quatro ontologias |

## O que **não** foi feito

| Item | Por quê |
|---|---|
| **F4 — quadros, campos e iterações** | fora do MVP declarado. Um sprint sem issues não responde nada, e a dependência é nessa direção |
| **F5 — tela de quadros** | idem |
| **F6 — tela de mapeamento** | ficou fora, e a lacuna que ela endereça **cresceu**: 3440 issues sem conceito. Virou a feature 005, já especificada |
| **Contadores do sync** | `records_collected` conta só a fase de EO. A tela mostra "0 coletados" ao lado de "4266 issues nesta coleta" — contradição declarada, correção pendente |
| **Iteration no Projects v2** | não existe para os sprints 003 e 004. Criar mexe na configuração que causou a L11 |
| **Reparo do dado da L19** | acontece na próxima coleta real de cada organização |

## Dois defeitos encontrados no dado real, e nenhum teste os pegava

**O envelope do cliente (L26).** `Client.graphql/4` devolve `{:ok, %{data: ...}}` e eu casei
`{:ok, data}`. O job **completou com sucesso e coletou zero** — nenhum erro, nenhum payload,
e a explicação plausível era "a organização não tem repositórios".

**O número como chave (L25).** Liguei as partes ao pai por `number`, que é único **dentro**
do repositório. Com 135 repositórios, partes de um foram ligadas ao pai de outro, e a tela
mostrava **2 épicos** onde havia 3.

**Os dois são da mesma família das L22 e L23: sucesso silencioso.** Em nenhum houve erro —
houve ausência de resultado lida como resultado. E os dois só apareceram porque alguém olhou
um número que não fechava com a origem.

## Dívida gerada e mantida

| O quê | Situação |
|---|---|
| `connected_tools.status` materializa situação | **mantida**, contra a D7. Não ampliada: esta feature **não** criou `sro_user_stories.status`, e a migração diz isso por extenso |
| Contadores do `sync` incompletos | **gerada neste sprint**. A fase de trabalho não soma em `records_collected` |
| RSRO e SYS_SWO sem estereótipo | 15 conceitos restantes. Era 16; a regra da fronteira exigiu **um** |
| Paridade Elixir/Python | mantida: 4 verificações contra 12 |
| `refused_links` como previsão | 4 linhas no dado real, todas `out_of_scope`. **Nenhuma por ciclo** — a previsão do plano segue sem confirmação, e o critério de reversão continua valendo |
| Aprovação de revisão registrada | bloqueada por ferramenta |

## Lições deste sprint

**L25** — número da issue não identifica: é único dentro do repositório. A tabela já
carregava a regra no índice único, e eu escrevi outra chave ao lado dela.

**L26** — casar o envelope errado devolve lista vazia em vez de erro. Casamento de padrão
largo esconde mudança de forma.

E uma observação que atravessa as duas, e as duas do sprint anterior: **quatro lições
seguidas sobre sucesso silencioso.** L22 (gate que compara duas falhas iguais), L23 (aviso de
verificação pulada), L25 (chave colidindo em silêncio), L26 (job que completa sem fazer).

O padrão é sempre o mesmo: **a ausência de erro sendo lida como presença de resultado.** E o
que achou todos foi conferir um número contra a origem, não rodar a suíte.
