# Retomar — feature 022, a timeline das issues

**Estado**: as 13 tarefas implementadas, PR aberta. **Branch**: `049-timeline-atividade`

## O primeiro comando ao voltar

```bash
set -a && . ./.env && set +a      # a chave mestra mora aqui; mix run sobe a app e precisa dela
```

## O que depende de você

1. **Acrescentar um estado de "em andamento" no quadro** — a plataforma não cria estado,
   e não deveria: o quadro é da organização. Vale **só para frente**: issue que já
   percorreu o fluxo antigo não ganha movimentação retroativa;
2. **rodar uma coleta real** depois disso, e reavaliar em `/process`;
3. **declarar qual movimentação marca "peguei"** — é feature própria, e só faz sentido
   depois que o quadro tiver onde declarar.

## O que a feature entregou

| Fase | O que existe agora |
|---|---|
| F1 | `spo_performed_project_activities` — a primeira materialização do conceito |
| F2 | a timeline coletada, dentro da janela da 020, sem descartar nada |
| F3 | a sequência na página da issue, o cycle time recusado, e `/process` |
| F4 | os quatro antipadrões de instância, e os dois estruturais sinalizados |

## O que ficou fora, de propósito

- **varredura da organização inteira** — não há tela que responda "quais issues têm
  antipadrão". A detecção roda ao abrir a issue. Varrer tem custo e desenho próprios;
- **os comentários** — [#318](https://github.com/The-Band-Solution/theband/issues/318);
- **calcular cycle time, WIP ou CFD** — dependem da declaração do item 3 acima.

## O que ficou medido pela metade

Sondei quatro repositórios e **dois voltaram `NOT_FOUND`** — pareei repositório com a
organização errada. A comparação entre quadros se apoia em **dois**. O achado sobrevive
(um tem estado de andamento, o outro não), mas não sustenta dizer quão comum é.
