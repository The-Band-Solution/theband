# O burn da página da pessoa parte de zero

Achado ao planejar a feature 057, em 2026-09-02. **Declarado, não escondido** —
a correção equivalente foi feita para a equipe no mesmo sprint, e a da pessoa
ficou de fora por motivo declarado.

## O que acontece

`TheBand.WorkItems.PersonWork.burn/2` acumula a série a partir de
`aberto_inicial`. A **equipe** passa a contagem de itens já em aberto no começo
da janela; a **página da pessoa passa zero**.

Com zero, `escopo - feito` mede apenas **os itens nascidos dentro da janela e
ainda abertos** — e não o trabalho em aberto da pessoa.

```text
aberto(t) = 0 + criadas(t₀..t) - fechadas(t₀..t)
```

Uma pessoa com trinta issues abertas há seis meses e nenhuma abertura nas
últimas oito semanas aparece com **`aberto` próximo de zero**, enquanto o
trabalho dela não mudou.

## Por que não foi corrigido junto

Três motivos, e nenhum é prazo:

1. **Teto de consultas próprio.** A página da pessoa está *exatamente* no teto
   medido em `person_detail_test.exs`, e a linha de base custa uma consulta a
   mais. Acrescentá-la exige decidir o que sai — decisão que não é desta feature;
2. **Critério de revisão próprio.** A mudança altera números já exibidos na
   página da pessoa, e misturá-la com a tela da equipe tornaria impossível saber
   de onde veio uma diferença. É a mesma razão que fez a US1 da 057 sair num PR
   sozinho;
3. **A pergunta pode ser outra.** Na equipe, "trabalho em aberto" é a fila que a
   equipe carrega. Na pessoa, pode ser que o recorte de janela seja o desejado —
   *o que nasceu e não fechou neste período*. **Isso precisa ser decidido, não
   deduzido**, e é a razão de este item existir em vez de um `TODO` no código.

## O que fazer

Decidir a pergunta (motivo 3) antes de qualquer código. Se a resposta for
"trabalho em aberto", então:

- acrescentar `WorkItems.person_open_at/3`, espelhando `TeamWork.open_at/3`;
- passar o resultado como `aberto_inicial` em `burn/2` na página da pessoa;
- rever o teto de consultas de `person_detail_test.exs` **no mesmo commit**, com
  o número novo declarado.

A limitação está escrita no `@doc` de `burn/2`, para quem ler a assinatura não
concluir que a pessoa tem linha de base — ela não tem.

## Onde isto está registrado

- `lib/the_band/work_items/person_work.ex` — no `@doc` de `burn/2`
- `specs/057-tela-da-equipe-complexa/research.md` — R2
- `specs/057-tela-da-equipe-complexa/plan.md` — seção "Dívida assumida"

**Prioridade**: média. O número não é falso — é uma medida diferente da que o
rótulo sugere, e ninguém decidiu qual das duas a página quer.
