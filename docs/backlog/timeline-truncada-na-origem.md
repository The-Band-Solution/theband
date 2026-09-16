# A timeline vem truncada, e a origem diz que não

**Aberto em**: 2026-09-15 · **Achado ao investigar** por que 282 entregas do Conecta Fapes não
tinham data de conclusão.

> ✅ **RESOLVIDO em 2026-09-16.** A coleta passou a pedir 10 issues por página no
> [#923](https://github.com/The-Band-Solution/theband/pull/923), e a base inteira foi recolhida
> no [#924](https://github.com/The-Band-Solution/theband/pull/924) — 33 repositórios, todos com
> veredito `completa`, 858 pontos de cota. As chegadas a `Done` foram de 1 794 para 3 294.
>
> **O documento fica pelo registro do defeito**, que é o que ele tem de mais útil: a origem
> declarou `totalCount` igual ao que cortou, com `hasNextPage: false`, e a guarda que existia
> olhava a bandeira errada. Quem escrever a próxima guarda precisa saber disso.
>
> A recoleta revelou outros três defeitos abaixo deste, e eles têm itens próprios:
> [o evento não diz o quadro](o-evento-de-coluna-nao-diz-o-quadro.md) e
> [`Done` é alegação, não aceite](done-e-alegacao-nao-aceite.md).

## O defeito, reproduzido

A mesma issue, os mesmos 12 tipos de evento, o mesmo `first: 100`:

| como se pergunta | `totalCount` | itens | último evento |
|---|---|---|---|
| dentro de `issues(first: 50)` — **como a coleta faz** | **12** | 12 | `2026-05-04` |
| `issue(number: 1828)` — direto | **14** | 14 | `2026-06-11 → Done` |

**E `hasNextPage` vem `false` nas duas.** A origem não diz que cortou: ela declara que o total é
12. A guarda `avisar_se_truncou/4` está correta e **nunca dispara**, porque só pode olhar o que a
origem afirma.

Não é profundidade de paginação — acontece na **primeira página**. Medido em 8 issues dela:

| issue | pela conexão | direto | faltam |
|---|---|---|---|
| #10 | 10 | **19** | 9 |
| #20 | 10 | **17** | 7 |
| #11 | 12 | 13 | 1 |
| #40 | 10 | 11 | 1 |

Quatro de oito cortadas, com teto aparente de **10 itens por issue**. Por alias
(`issue(number:)`) vem completo — verificado com 1, 5 e 10 aliases na mesma consulta, sempre 14
na #1828, ao custo de **1 ponto**.

## O que isso custou, medido

No quadro 43 do Conecta Fapes, 377 cartões que o quadro marca como concluídos e a origem mantém
abertos:

| situação | quantas |
|---|---|
| **têm o evento de chegada a Done na origem, e o banco não tem** | **282 (75%)** |
| fecharam depois da última coleta | 25 (6%) |
| chegaram a Done sem gerar evento nenhum | 69 (18%) |

As 282 são entregas que existem, têm data na origem, e a plataforma não consegue datar —
abril 10, maio 81, junho 35, **julho 152**, agosto 4. Julho sozinho tem 152 conclusões
invisíveis no gráfico por mês.

**E o alcance é maior que o Conecta.** A coleta é a mesma para toda a base: qualquer issue com
timeline longa perdeu os eventos mais recentes, em todo repositório observado. Quanto, não se
sabe — a medida está na lista abaixo.

## É a L57 na forma mais cara

*"O número confere e está errado."* A soma bate com o que chegou, porque é com o que chegou que
ela é comparada. Nada na plataforma indicava ausência — e a guarda que existia para isso
confiava no `totalCount` que a origem mente.

## O que fazer, na ordem

1. **A timeline sai da conexão e passa a ser pedida por aliases**, em lotes de 10. A conexão
   continua trazendo os campos da issue, que não estão corrompidos. Custo medido: 1 ponto por
   lote — 267 consultas para os 2 669 do `conectafapes-project`, contra uma cota de 5 000/hora;
2. **uma guarda que dispara**: comparar, por amostra em cada coleta, o `totalCount` da conexão
   com o do alias. Divergiu, reprova ruidosamente. Sem isso, a próxima mudança de comportamento
   da origem volta a passar em silêncio;
3. **medir o tamanho do estrago** antes de recoletar: quantas issues têm exatamente 10 itens no
   banco — a assinatura do corte;
4. **recoletar a timeline por inteiro**, e não incrementalmente. O corte não deixou marca, então
   não há como saber quais issues precisam sem perguntar por todas;
5. **só então** declarar o critério de fim e o significado de Done (feature 066) — antes disso, a
   data não existe para datar.

## Duas perguntas que este item não responde

- **o limite de 10 é documentado ou emergente?** Medido em 8 issues de um repositório. Se varia
  com o tamanho da resposta, o lote de 10 aliases também precisa de teto medido;
- **a data do evento é a data da entrega?** O evento diz quando o cartão chegou a Done. Onde
  alguém arrumou o quadro em lote, é a data da arrumação. Não medido.
