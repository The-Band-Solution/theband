# O protótipo aprovado

[`team-of-teams.html`](team-of-teams.html) — abrir no navegador. Duas telas numa
página só, separadas pela faixa `screen 1` / `screen 2`.

Aprovado pela pessoa mantenedora em 2026-09-02, e é **a referência visual desta
feature**. Publicado durante o desenho em
`https://claude.ai/code/artifact/f4aea865-b14a-44d9-bba2-6622974b287e`; a cópia
aqui é a que vale, porque o endereço publicado pode mudar e a spec não pode
depender dele.

## O que cada tela mostra

**Screen 1 — a equipe complexa.** Composição, o que a equipe está fazendo, o que
já fez, o que vem a seguir, o que sabe, estrutura e projetos. Uma linha por
subequipe, **sem nenhum total** — e a tela diz por que não soma. **Nenhum
gráfico**, por decisão: aqui se compara, e comparação se faz em números
alinhados.

**Screen 2 — a subequipe.** As medidas, semana a semana, burn-up/burn-down,
previsão de Monte Carlo, o que cada pessoa está fazendo, e as habilidades
demonstradas.

## Como ler o protótipo contra a spec

| No protótipo | Requisito |
|---|---|
| linhas de subequipe sem célula de total | FR-008, FR-009 |
| ausência de gráfico na screen 1 | FR-011 |
| faixa hachurada entre as duas curvas | FR-027 |
| `still open` como distância medida, com a seta | FR-028 |
| duas hipóteses da previsão, com confiança | FR-032, FR-033 |
| linhas de tarefa por pessoa, sem "tarefa atual" | FR-017, FR-018 |
| `No open task assigned` escrito | FR-021 |
| pílulas âmbar tracejadas com marca `derived` | FR-022 |
| Rafael Dias sem nenhuma habilidade, com o motivo | FR-023 |

## Onde o protótipo diverge da spec, e a spec vence

O protótipo foi desenhado antes de conferir o código. Dois pontos foram
corrigidos na spec depois, e **o protótipo ainda mostra a versão antiga**:

1. **Tempo em tarefa.** O protótipo diz *"days since the task was assigned to
   that person"*. A origem não registra essa data — ver R1 em
   [research.md](../research.md). O texto correto é **desde a abertura do item**.

2. **A linha de base do burn.** O protótipo acumula a partir de zero na primeira
   semana da janela. Sem a contagem de itens já abertos no início, a distância
   entre as curvas mede menos trabalho aberto do que existe — ver R2.

Os números do protótipo são **inventados para o desenho**. Nenhum deles é medida:
não citar em documento, review ou apresentação.
