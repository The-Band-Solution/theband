# Sprint 044 — Review

**Período**: 2026-10-14 a 2026-10-15
**Feature**: [074](../../../specs/074-jornada-entrar-e-sair/spec.md)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories (US4, US5) | 2 | 2 com o código pronto; **nenhuma aceita** (a aceitação é em produção, depois da T027) |
| Tarefas de código (T021, T022, T023, T030, T031) | 5 | 5 (a T031 com este PR) |
| Tarefa bloqueada (T029) | 1 | 0 — depende da T026 (👤) |

## O que foi feito

| Tarefa | Issue | Entregável | Aceito |
|---|---|---|---|
| T021 | [#1255](https://github.com/The-Band-Solution/theband/issues/1255) | Os sete casos de senha na régua e as sentinelas das duas portas. O defeito do motivo derivado do changeset reprova (31/32), e também o vazamento com a camada do filtro desligada (2/3) | sim, pelos testes |
| T022 | [#1256](https://github.com/The-Band-Solution/theband/issues/1256) | `deploy/signoz/paineis/entrar-e-sair.json`, seis quadros, conferido no SigNoz local com dado real: números batendo, período vazio e abandono (2 depois de 30 min). Capturas em `evidencia/` | sim, no local |
| T023 | [#1257](https://github.com/The-Band-Solution/theband/issues/1257) | `deploy/signoz/alertas/enumeracao.json`. 200 tentativas dispararam o alerta, e o corpo não tem atributo de traço | sim, no local |
| T030 | [#1264](https://github.com/The-Band-Solution/theband/issues/1264) | A mediana com e sem telemetria, −0,7%, registrada na ADR 0005 | sim |
| T031 | [#1265](https://github.com/The-Band-Solution/theband/issues/1265) | Este PR | ao abrir |

## O que não foi feito

| Tarefa | Issue | Motivo | Destino |
|---|---|---|---|
| T029 Atualizar o runbook | [#1263](https://github.com/The-Band-Solution/theband/issues/1263) | depende da T026: o SigNoz em produção, com o túnel e o canal do alerta definidos | depois da T026 |
| T024–T028 | #1258–#1262 | 👤 pessoa mantenedora, em produção | quando ela subir o SigNoz |

## Entregáveis não aceitos

Nenhum foi recusado. As US4 e US5 seguem **sem aceitação**: o painel e o alerta só se aceitam em
produção, com a aplicação ligada ao coletor (T027).

## Evidências

- `specs/074-jornada-entrar-e-sair/evidencia/`: três capturas do painel, o corpo do alerta e o
  script da T030.
- O código de saída dos gates está no corpo do PR.

## Dívida gerada

- **#1433**: o alerta conta traços, e não sobrevive ao descarte da fila (S12). A contagem antes do
  descarte exige um canal de métricas.
- O texto do período vazio é o *No data* do SigNoz, e não "nenhuma tentativa".

## Incidente

Ao criar a iteration do sprint, a mutação apagou as seis iterations completas (L11, terceira
reincidência). Os 536 itens foram reatribuídos a partir do retrato e conferidos idênticos. Os ids
antigos se perderam. Ver o backlog.

## Lições deste sprint

Consolidadas em [licoes-aprendidas.md](../licoes-aprendidas.md):

- **L11, reincidente.** Virou procedimento na skill `sprint-backlog`: reenviar todas as iterations,
  inclusive as completas, e conferir pelo retrato.
- **L111.** No SigNoz, agrupar por chave opcional descarta a linha que não a tem.
- **L112.** Um freio novo muda o motivo que o alerta conta.
