# Tarefas — Busca, ordenação e página no endereço (#292)

- [x] T001 Ler o estado da tabela do endereço
  - **Pronta quando**: nada além do repositório
  - **Descrição**: `lib/the_band_web/estado_da_tabela.ex` com `ler/2`, `para_query/2` e
    `proxima_ordem/2`. Plano D1 a D3
  - **Feita quando**: `ler/2` devolve o padrão e um aviso para cada parâmetro que não serve;
    `para_query/2` omite o que está no padrão
  - **Teste**: `estado_na_url_test.exs` — os quatro casos de parâmetro inválido

- [x] T002 [US1] `/work` lê e escreve no endereço
  - **Pronta quando**: T001
  - **Descrição**: `handle_params/3` assume o lugar do estado no `mount`; `buscar`, `ordenar`,
    `pagina` e `filtrar` passam a `push_patch`
  - **Feita quando**: abrir `/work?q=agulha` mostra o resultado; buscar muda o endereço
  - **Teste**: "abrir com ?q= já mostra o resultado da busca", "o clique escreve no endereço"

- [x] T003 [US1] A página do repositório segue a mesma regra
  - **Pronta quando**: T001
  - **Descrição**: mesmo desenho em `repository_live/show.ex`; o `mount` que não acha o
    repositório passa a assinalar `repositorio: nil`, para o `handle_params` não correr sobre
    tela que já está saindo
  - **Feita quando**: abrir com `?q=` e `?ordem=` já vem aplicado
  - **Teste**: describe "a página do repositório segue a mesma regra"

- [x] T004 [US2] Parâmetro inválido é dito
  - **Pronta quando**: T002, T003
  - **Descrição**: os avisos viram flash de erro. A mensagem nomeia o valor recebido e o que foi
    usado no lugar
  - **Feita quando**: `?ordem=inexistente` mostra a frase e lista as colunas disponíveis;
    `?dir=deitado` mantém a coluna; nenhuma combinação derruba a tela
  - **Teste**: describe "parâmetro inválido é dito" — quatro casos

- [x] T005 [US3] Os estados convivem
  - **Pronta quando**: T002
  - **Descrição**: `caminho/2` compõe o filtro de repositório com busca, ordem e página
  - **Feita quando**: buscar com repositório filtrado preserva os dois; apagar a busca tira o
    parâmetro do endereço
  - **Teste**: describe "os estados convivem no mesmo endereço"
