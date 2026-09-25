defmodule TheBand.MCP.Ferramentas do
  @moduledoc """
  O registro das ferramentas MCP — a **lista fechada**, casada uma a uma (feature 062, FR-023).

  Nenhuma ferramenta genérica, nenhum filtro livre, nenhum campo de ordenação vindo de
  argumento. O protocolo exige `tools/list`, e é este módulo que o responde. Acrescentar uma
  ferramenta exige tocar aqui, e isso é intencional: não se liga uma por configuração.

  **É o caminho único até uma ferramenta** (T006, R6 da revisão independente), e a ordem nele é
  fixa: carregar a equipe no tenant, aplicar o veredito, registrar a leitura concedida ou a
  recusa, e só então carregar e montar a resposta. Nenhuma ferramenta aplica o veredito nem
  registra por conta própria.

  ## A fronteira

  Este módulo, e tudo em `lib/the_band/mcp/`, **não conhece o transporte**: nada aqui referencia
  `TheBandWeb` nem a biblioteca do protocolo. É o que torna a troca da `ex_mcp` um trabalho de
  adaptador (plan.md, *Structure Decision*). E nada aqui consulta o banco direto: as respostas
  vêm dos contextos, como na API da 061 (T008).
  """
end
