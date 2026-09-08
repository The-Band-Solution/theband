# O backup restaurado de verdade — o §6 do runbook

**Bloqueado em**: a conta no destino S3-compatível **não existe ainda**. Registrado pela
pessoa mantenedora em 2026-09-08: *"tenho que criar a conta na S3 ainda para isso"*.

**Consequência hoje**: a **050/US2** (*os dados sobrevivem*) segue **não aceita**, e segue
desde a v0.1.0.

## O que é, e a frase que resume

`docs/producao/runbook.md`, §6: *"o backup só existe depois de restaurado uma vez"*.

Um backup nunca restaurado é um arquivo. Não se sabe se está completo, se o formato abre, se
a restauração roda, nem se ele contém o que se imagina. As três dúvidas se resolvem juntas, e
só restaurando.

## Os cinco passos, e o que cada um prova

1. **anotar três números da produção** — pessoas, issues, organizações, de `/people` e
   `/organizations`. São a referência: sem eles, a restauração "funciona" sem que se saiba se
   trouxe tudo;
2. **baixar o arquivo do destino S3** — prova que o job de backup escreve onde se pensa que
   escreve, e que o arquivo é legível de fora da máquina;
3. **criar um banco VAZIO no Dokploy** (`band_ensaio`) e restaurar nele — prova que o formato
   abre e que a restauração completa;
4. **apontar uma aplicação temporária** para esse banco e conferir os três números **na
   tela** — prova que o dado restaurado é o dado da aplicação, e não só linhas numa tabela;
5. **derrubar** a instância e o banco de ensaio.

Falhou qualquer passo, o backup **não existe de verdade**.

## O que já foi feito, e por que não substitui

Em 2026-09-08 ensaiei a **migração** que altera dados contra uma cópia restaurada do banco de
desenvolvimento — `docs/producao/ensaio-2026-09-08-migracao-060.md`. Passou: 90 vínculos
intactos, backfill em 34 linhas, zero pares incompletos, e a ordem errada reprovada de
propósito.

**São perguntas diferentes**, e parecem a mesma:

| pergunta | respondida? |
|---|---|
| *a migração roda sobre dado real?* | **sim**, medido |
| *o backup existe de verdade?* | **não** |

A primeira é sobre o código da migração. A segunda é sobre a rotina de backup — e é a que
importa no momento em que se precisa dela.

## O risco que fica de pé

A `v0.6.0` sobe com uma migração que **altera dados** (`20260908010000`: backfill de
`declared_at` e duas CHECKs). Se ela falhar em produção de um jeito não previsto, o caminho
de volta é o backup.

O que reduz o risco, e já existe:

- o **ensaio da migração** sobre cópia do banco real (acima);
- as duas CHECKs são **satisfeitas por construção** num banco pré-migração — está demonstrado
  no ensaio;
- a migração roda **numa transação**: falha inteira, e o esquema fica como estava;
- o **rollback do §5** — reapontar o Dokploy para a imagem anterior — **não depende de
  backup**, porque as migrações desta casa são só-acréscimo.

O que **não** reduz: perda de dado por qualquer outra causa. Aí o backup é o único caminho, e
ele continua não verificado.

## Quando fazer

**Assim que a conta no S3 existir**, e antes da próxima release com migração que altere
dados. O runbook manda repetir a cada mudança no desenho do backup e **no mínimo uma vez por
mês** (SC-006: a rotina roda 7 dias e a mais antiga restaura).

## O que fecha este item

- os três números conferidos **na tela** da instância de ensaio, com data e valores anotados
  em `docs/releases/` junto do release corrente;
- a **050/US2** passa de *não aceita* para aceita;
- este documento sai do backlog.

## Referências

- `docs/producao/runbook.md` §4 (o backup), §5 (rollback), §6 (o ensaio);
- `docs/producao/ensaio-2026-09-08-migracao-060.md` — o que foi ensaiado, e o que não;
- `docs/releases/v0.6.0.md` — o adiamento registrado como decisão, com o risco aceito;
- spec 050, US2 e FR-007/FR-014 (destino fora da máquina), FR-008/SC-003 (o ensaio).
