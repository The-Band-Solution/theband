# Aceitação — feature 014, clicar leva à página

**Avaliada em**: 2026-08-13 · **PR**: [#284](https://github.com/The-Band-Solution/theband/pull/284)

## Requisitos funcionais — 10 de 10

| # | Requisito | Veredito | Evidência |
|---|---|---|---|
| FR-001 | nome leva à página quando há pessoa | **aceito** | autor, designado e membro de equipe, três casos |
| FR-002 | login sem pessoa não vira ligação | **aceito** | o `refute` do `href`, com a frase explicativa ainda presente |
| FR-003 | entidade sem página não vira ligação | **aceito** | organização, na lista de pessoas |
| FR-004 | a ligação envolve o nome, não a linha | **aceito** | o markup — `<a>` dentro da célula |
| FR-005 | alcançável por teclado | **aceito** | `<.link>` renderiza `<a href>` real, sem `phx-click` |
| FR-006 | distinguível sem cor | **aceito** | `underline decoration-dotted`, além da cor |
| FR-007 | nenhuma ligação para rota inexistente | **aceito** | os destinos são `/people/:id`, rota existente |
| FR-008 | navegação dentro da plataforma | **aceito** | o botão do GitHub continua separado |
| FR-009 | conteúdo igual | **aceito** | o texto exibido é o mesmo; muda o que é clicável |
| FR-010 | nenhuma consulta nova | **aceito** | **39 antes, 38 depois** |

## Critérios de sucesso — 7 de 7

| # | Critério | Veredito | Medida |
|---|---|---|---|
| SC-001 | autor e designado com pessoa levam à página | **aceito** | conferido na aplicação em execução |
| SC-002 | membro de equipe leva à página | **aceito** | e nome e login levam ao mesmo lugar |
| SC-003 | os 288 continuam sem ligação | **aceito** | zero `href="/people/` na issue de quem saiu antes |
| SC-004 | organização não vira ligação | **aceito** | o `refute` |
| SC-005 | nenhuma ligação quebrada | **aceito** | todos os destinos são `/people/:id` |
| SC-006 | consultas por render não mudam | **aceito** | 39 → 38 |
| SC-007 | conteúdo textual idêntico | **aceito** | o texto é o mesmo; a diferença é o `<a>` |

## O que a implementação achou

**O primeiro teto do teste de custo estava errado nos dois sentidos.** Escrevi `<= 30`, que reprova
com o código certo; trocar por `<= 300` passaria com o defeito. Medi os dois lados — 39 e 38 — e o
número virou a medida.

## Veredito

**Aceita.** Dez requisitos e sete critérios com evidência, mais a conferência na aplicação em
execução.
