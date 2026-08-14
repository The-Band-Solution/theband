# Quickstart — provar que a atividade chegou, e que nada foi descartado

**Feature** `022-timeline-das-issues`

---

## 0. A verificação que bloqueia o resto

Três perguntas, uma consulta, uma sessão de `iex`.

```bash
export THE_BAND_MASTER_KEY=...   # no seu terminal, nunca no chat
iex -S mix
```

| # | Perguntar | O que decide |
|---|---|---|
| 1 | `timelineItems` vem na mesma consulta da issue? | o custo, e a US3 |
| 2 | quais tipos voltam, e em que volume? | o mapeamento, e o teto da paginação |
| 3 | **a movimentação de Projects v2 aparece ali?** | se os antipadrões funcionam nesta feature ou dependem da #181 |

**A terceira pode mudar o tamanho da feature.** Se a resposta for sim, a dependência da
[#181](https://github.com/The-Band-Solution/theband/issues/181) cai.

Se alguma responder diferente do esperado, o `research.md` e o contrato são corrigidos **antes**
de qualquer código.

## 1. Os treze gates

```bash
mix gates
echo $?     # 0, e o veredito é este número
```

Nunca com `| tail` — o corte esconde a falha, e o `$?` passa a ser do `tail`.

## 2. A prova automatizada

### Que a ocorrência não duplica

```bash
mix test test/the_band/ontology/seon/spo/atividade_test.exs
```

| Caso | Espera |
|---|---|
| gravar o mesmo evento duas vezes | **uma** linha, e a segunda devolve `:unchanged` |
| evento sem executor | gravado, com `performer_id` nulo |
| dois eventos no mesmo instante, tipos diferentes | duas linhas |
| a mesma coleta em dois tenants | duas linhas, e nenhuma enxerga a outra |

### Que nada foi descartado

```bash
mix test test/the_band/ingestion/timeline_test.exs
```

| Caso | Espera |
|---|---|
| origem devolve cinco eventos, dois sem conceito | **cinco** linhas gravadas |
| os dois sem conceito | `concept_id` nulo, `activity_type` **com o nome da origem** |
| soma | classificados + sem conceito = total recebido — é a **SC-003** |

**A asserção é a soma**, e não "os eventos apareceram". Um teste que só verifica os mapeados
passa igual com o descarte.

### Que a coleta não encarece

| Caso | Espera |
|---|---|
| repositório pulado pela 020 | **zero** pedidos de timeline — a borda simulada reprova se for chamada |
| issue cuja atualização não mudou | idem |

### Que a plataforma diz o que não sabe

```bash
mix test test/the_band_web/live/timeline_test.exs
```

| Caso | Espera |
|---|---|
| issue sem evento de movimentação | a tela **não** mostra cycle time, e diz o que falta |
| a mesma issue | **não** mostra lead time no lugar — SC-004 e FR-009 |
| a tela de tipos | lista os observados com a contagem de cada um |

---

## 3. A conferência no dado real

Depois de uma coleta com a timeline ligada:

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select activity_type, concept_id, count(*)
  from spo_performed_project_activities
 group by 1,2 order by 3 desc limit 10;"
```

| O que conferir | Esperado |
|---|---|
| tipos com `concept_id` nulo | existem, e o nome é o da origem — não `unknown` genérico |
| coletar duas vezes | a contagem total **não muda** |
| repositórios pulados | nenhuma atividade deles |

### E a conferência de tela

`/work/issues/<id>` de uma issue fechada: os eventos aparecem **em ordem**, com autor e instante,
e o evento de bot diz que não houve executor humano em vez de sumir.

Se a issue não tem movimentação, a tela diz que o cycle time não pode ser calculado — **e nomeia
o motivo**. Uma tela que simplesmente não mostra a medida é indistinguível de uma que esqueceu.
