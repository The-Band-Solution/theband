# Specification Quality Checklist: a tabela que busca, ordena e pagina

**Criada em**: 2026-08-13 · **Feature**: [spec.md](../spec.md)

- [x] Sem detalhe de implementação nos requisitos
- [x] Focada no valor: achar a linha sem varrer a lista
- [x] Nenhum `[NEEDS CLARIFICATION]` — a decisão de base foi tomada com protótipos
- [x] Requisitos testáveis
- [x] Critérios mensuráveis: 6,8 ms para contar, 14,2 ms para ordenar por derivada
- [x] Casos de borda: última página, telefone, duas abas, recarregar
- [x] Escopo delimitado — busca semântica fica fora
- [x] Premissas identificadas, inclusive a que pode envelhecer

## Notas

**A medida derrubou o receio principal.** A paginação numerada precisa de um total, e contar parecia
caro depois da tela de 6,12 s da feature 013. **Custa 6,8 ms** — e com filtro de busca, 4,9 ms.

**O caro é outro**: ordenar por coluna **derivada** resolve a promoção vigente para as 4 529 antes de
cortar 25 — 14,2 ms. É herança direta do desenho da 013, e é onde a feature pode regredir.

**A decisão de base veio de protótipo, não de opinião**: três versões funcionais da mesma tabela,
com os mesmos dados reais, usadas lado a lado antes de escolher.
