# As 17 specs sem issue — a decisão de não preencher

**Decidido em**: 2026-09-13 · **Delegado pela pessoa mantenedora**

O papel de Product Owner, ao auditar, encontrou que a feature 060 — 29 tarefas, em produção —
não tem issue nenhuma no GitHub. Medi mais amplo depois, e não é uma feature esquecida.

---

## O tamanho, medido

| | |
|---|---|
| specs com `tasks.md` | **32** |
| com issues no GitHub | 15 |
| **sem issue nenhuma** | **17** |
| tarefas nessas 17 | **390** |

As 17: `001`(76) `002`(27) `003`(30) `004`(57) `005`(25) `007`(7) `008`(9) `009`(9) `010`(9)
`018`(16) `019`(5) `026`(17) `027`(29) `030`(12) `032`(19) `044`(14) `060`(29)

## A decisão: **não preencher retroativamente**

E a razão não é preguiça — é que **o dado de origem não presta**.

### A caixa de seleção mente, e dá para provar

Das 390 tarefas, o `tasks.md` diz que **255 estão abertas**. Elas não estão.

A prova mais curta é a primeira tarefa da spec 001:

```
- [ ] T001 Gerar o projeto Phoenix com `mix phx.new . --app the_band …`
```

**Aberta.** E o projeto existe, compila, passa 2 149 testes, está em produção e coletou
5 033 issues. A caixa nunca foi marcada porque ninguém volta ao `tasks.md` depois de
entregar — e não havia nada que obrigasse.

Então a caixa não é registro de conclusão. É registro de **intenção no dia em que foi
escrita**.

### Criar issue a partir dela produziria erro, não ausência

Duas formas de errar, e as duas piores que o buraco atual:

1. **criar 255 issues abertas** para trabalho que está em produção. O quadro passaria a
   afirmar que a plataforma tem 255 tarefas pendentes desde agosto, e `flow.wip.count` —
   a medida que o achado do PO queria consertar — ficaria **pior** do que está;
2. **criar 390 issues fechadas hoje**, com a data de hoje. Toda medida de fluxo que use a
   data de fechamento passaria a dizer que 390 tarefas foram concluídas em 2026-09-13.
   Seria a plataforma medindo errado a si mesma, no repositório que ela observa.

A própria base de conhecimento já nomeia isso, na seção que recusa 1 274 prefixos como tipo:

> **Conceito errado é pior que conceito ausente**: a medida passa a existir e a mentir, e
> ninguém tem como notar.

Vale igual aqui. A ausência de issue é visível — some do quadro, e alguém pergunta. Uma issue
com data errada não é visível por ninguém.

## O que fazer em vez disso

**Declarar a fronteira.** A convenção `NNN/TXXX` começa na spec **042** e vale daí em diante.
Antes dela, o registro de trabalho está nos commits e nos PRs, não no quadro.

Isso é uma frase escrita, não 390 issues — e responde a mesma pergunta: *por que o quadro não
mostra a feature 060?* Porque ela é anterior à convenção.

**O que NÃO fazer**: tratar a medida de fluxo como se cobrisse todo o histórico. Ela cobre da
042 em diante, e qualquer leitura que a estenda para trás está lendo ausência como zero — o
defeito que esta casa persegue nos dados dos outros.

## O que fica em aberto de verdade

**A caixa do `tasks.md` não é confiável em spec nenhuma**, inclusive nas novas. Ninguém a
marca ao concluir, e agora há o comentário de prova na issue (constituição 1.8.0, princípio
VII) fazendo esse papel — melhor, porque traz o comando e o código de saída.

Vale decidir se a caixa continua existindo. Duas coisas registrando conclusão, e uma delas
sempre desatualizada, é pior que uma só.
