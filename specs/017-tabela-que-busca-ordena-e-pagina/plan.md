# Plano de implementação: a tabela que busca, ordena e pagina

**Feature**: `specs/017-tabela-que-busca-ordena-e-pagina/` · **Branch**: `026-tabela-que-busca`
**Spec**: [spec.md](spec.md) · **Origem**: [#289](https://github.com/The-Band-Solution/theband/issues/289)

## Summary

Um componente de tabela no design system — busca, ordenação por coluna e paginação numerada — e as
listas passam a usá-lo. **Componente próprio**, decidido com protótipos.

## O que já existe, e é onde a feature começa

`list_issues/2` **já** recebe `limit` e `offset`, e **já** ordena com desempate estável
(`observed_repository_id`, `number`, `id`) — porque número repete entre repositórios. A tela de
trabalho **já** pagina, com 50 por página e botões anterior/próxima.

**O que falta**: busca, ordenação escolhida por quem lê, e índices numerados.

## O que este plano decide

| Decisão | Escolha | O que a alternativa quebraria |
|---|---|---|
| onde a ordem é decidida | no **banco**, com o desempate que já existe | ordenar em memória ordena a página, não a lista |
| busca | no banco, com escopo **declarado por tela** | buscar em memória acha 25 de 4 529 e parece busca |
| ordenar por coluna derivada | pela mesma junção lateral da feature 013 | materializar é a ADR 0004 D7 |
| estado | na **URL** | recarregar perderia, e o endereço não seria compartilhável |
| paginação | numerada com reticências, preservando primeira, última e vizinhas | mostrar 181 índices é ruído |
| o total | contado por consulta própria | medido: **6,8 ms** — o receio era infundado |

## Constitution Check

**I, II, IV, IX** — não se aplicam.

**III** — conforme: nada é gravado; a ordem é derivada na leitura.

**V** — conforme: as consultas continuam escopadas por tenant.

**VI** — conforme.

**VII** — conforme, lacuna de revisão declarada.

**VIII** — o componente é o padrão. **Existe agora**: sete tabelas, e a #289 pede o mesmo
comportamento nas sete. **O que fica pior**: o componente precisa aceitar declaração de colunas, e
uma tela que declare errado ordena por um campo que não existe — por isso a declaração é validada em
compilação sempre que possível.

**X** — conforme: o componente faz uma coisa.

## Riscos

| Risco | Mitigação |
|---|---|
| ordenar em memória sem perceber | o teste ordena por coluna e vai à **última** página conferir |
| busca alcançando só a página | o teste busca por algo que só existe fora da primeira página |
| ordem instável entre páginas | o desempate já existe em `list_issues/2`, e o teste compara duas páginas |
| contar por render ficar caro | medido em 6,8 ms; a FR-012 exige medir de novo depois |
| coluna derivada custar | medido em 14,2 ms; o teste mede e falha se passar de 50 |

## Fases

| Fase | O que |
|---|---|
| **F1** | a consulta: busca, ordem escolhida e contagem |
| **F2** | o componente, e a lista de trabalho usando |
| **F3** | as outras listas |
| **F4** | a prova: última página, ordem entre páginas, e a medida |
