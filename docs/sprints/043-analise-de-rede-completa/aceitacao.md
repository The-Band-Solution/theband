# Sprint 043 — conferência da tela da 076 (T053)

**2026-10-06.** O QA e o Design conferiram, em par, cada página entregue da análise de rede contra
`specs/076-analise-de-rede/prototipo/PROMPT.md` §3. A tela usada foi a real, com o dado real de
`leds-conectafapes`, capturada a 1280 px e a 360 px.

A tabela item a item, com as capturas, está em
[`specs/076-analise-de-rede/prototipo/conferencia.md`](../../../specs/076-analise-de-rede/prototipo/conferencia.md).

## O resultado

| | quantos |
|---|---|
| defeitos encontrados | 19, um deles grave (o contorno das comunidades saía opaco e cobria os nós) |
| defeitos consertados nesta branch, cada um com guarda vista reprovando ou medida no navegador | 19 |
| divergências que seguem a spec mas não estavam em R21 | 10, registradas em R21 e **aprovadas** pela pessoa mantenedora em 2026-10-06 (ficam como estão) |
| itens só verificáveis por teste (alcance parcial, estados que o dado real não produz) | 6 linhas, marcadas *"conforme por teste"* |
| abertos | 3.9.1 (republicar o protótipo com as decisões) e o núcleo denso do grafo |

## O que não é aceitação

Esta conferência diz que a tela é a do protótipo, salvo o que está listado. **Ela não aceita a
feature.** A aceitação é a T054, da pessoa mantenedora: conferir os números contra a origem, e
decidir as propostas da R21. Se a decisão for o protótipo, o código volta a ele antes do merge.
