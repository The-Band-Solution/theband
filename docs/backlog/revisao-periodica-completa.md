# A revisão periódica completa — o resíduo do corte por atividade

**Registrado em 2026-09-09**, junto do conserto do corte das issues.

## O que o conserto resolveu

O corte que decide se um repositório vale ser lido comparava com `pushedAt` — o último
**push de código** — e atividade de issue não é push. Repositórios de **quadro**, onde se
trabalha em issue e ninguém empurra código, eram pulados para sempre.

Medido contra a API em 2026-09-09: `plataformas-project` tinha push de **21 de julho** e
issue fechada **no dia da medição**. As **712** issues dele estavam congeladas.

O corte passou a comparar a **atividade de issue mais recente**, que vem na mesma consulta
de repositórios e não custa requisição.

## O resíduo, e é este item

**Apagar uma issue não move o sinal.** Ela deixou de existir, e o `updatedAt` da mais
recente não muda por causa dela.

Na prática, qualquer outra atividade no repositório move o sinal, o repositório é
percorrido, e `mark_issues_no_longer_observed/3` pega a apagada. Nos repositórios reais da
`leds-conectafapes` há atividade diária.

**O que fica descoberto** é o repositório onde uma issue é apagada e **nada mais acontece
nunca**. Ele não é percorrido, e a apagada continua contando como aberta — entrando em
*Problems now*, no burn, na previsão e no que cada pessoa tem aberto.

## O que fecharia

Uma **revisão periódica completa**, independente de corte: a cada N dias, todo repositório
observado é percorrido, aconteça o que acontecer no sinal.

Três decisões que ela exige, e nenhuma se toma por analogia:

1. **qual N.** Sete dias custa 121 consultas por semana na organização medida; trinta dias
   custa menos e deixa a apagada contando por um mês;
2. **se a revisão é por repositório ou por organização.** Espalhar no tempo — uma fração
   dos repositórios por dia — evita o pico, e o pico é o que estoura cota;
3. **como a tela diz.** Uma issue apagada há três semanas e ainda contada é uma medida
   errada que ninguém sabe que está errada. A revisão precisa deixar rastro, senão o
   conserto é invisível a quem leu o número no meio.

## Por que isto não entrou no conserto

O conserto do corte era **uma premissa errada** — trocar `pushedAt` pela atividade de
issue, com o teste que faltava. Tem causa medida e efeito conferido.

A revisão periódica é **desenho novo**: agendamento, orçamento de cota e uma decisão de
produto sobre o rastro. Juntar as duas coisas faria o conserto medido depender de três
decisões não tomadas.

## Referências

- `lib/the_band/ingestion/github_work_items.ex` — `percorrer?/2`, com a medida escrita;
- `docs/backlog/investigar-estado-divergente-da-issue.md` — os dois casos que acharam isto;
- `test/the_band/ingestion/pular_sem_atividade_test.exs` — o teste que faltava, e o par que
  guarda a economia;
- ADR 0007 — o gestor de cotas, que a revisão periódica vai ter de respeitar.
