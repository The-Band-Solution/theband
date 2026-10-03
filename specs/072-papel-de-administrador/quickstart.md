# Quickstart — validar a 072

1. `mix test test/the_band/tenants/papel_de_administrador_test.exs`: promover, rebaixar, o último,
   a corrida de dez rebaixamentos cruzados (SC-001), e o ator rebaixado recusado.
2. `mix test test/the_band/tenants/ator_relido_test.exs`: cada ato de R2 recusa um ator que perdeu
   a marca, com o defeito injetado (a conferência retirada) reprovando.
3. `mix test test/the_band/tenants/registro_do_papel_test.exs`: os triggers e o trigger adiado com
   `SET CONSTRAINTS ALL IMMEDIATE`, como na 070.
4. `mix test test/the_band_web/live/accounts_papel_test.exs`: a tela contra a régua de
   `prototipo/PROMPT.md` §3, e a aba aberta do rebaixado indo para `/people` (FR-008).
5. A conferência do QA contra o protótipo, item a item.
