defmodule TheBandWeb.Components.DataTable do
  @moduledoc """
  A tabela que busca, ordena e pagina — uma vez, para todas as telas.

  ## Por que um componente, e não a repetição que já existia

  As features 017 e 019 entregaram este comportamento em **duas** telas: `/work` e o detalhe
  do repositório. As duas ficaram com a mesma caixa de busca, o mesmo cabeçalho ordenável, a
  mesma linha de contagem e a mesma paginação — copiadas.

  Duas cópias são um custo aceitável. Dez não são: o corte declarado da 017 dizia "as
  tabelas menores" ficam de fora, e quando alguém precisou procurar numa delas — a página da
  pessoa, com 350 e 609 issues — a conta chegou.

  O componente não inventa comportamento novo. Ele empacota `busca/1`, `th_ordenavel/1` e
  `paginacao/1`, que já existiam em `CoreComponents`, mais a moldura que estava sendo
  copiada junto.

  ## O que ele NÃO faz, e por quê

  **Não consulta o banco.** Recebe as linhas já buscadas, ordenadas e paginadas. Uma tabela
  que busca sozinha decidiria como cada tela consulta — e as consultas destas telas são
  diferentes: uma filtra por repositório, outra por pessoa, outra por equipe.

  **Não guarda estado.** O estado mora no endereço, e quem o lê é `EstadoDaTabela` — é a
  feature 019, e o motivo é que o endereço é o que se manda para alguém.

  **Não decide as colunas ordenáveis.** A tela declara quais são, e o átomo sai dessa lista
  declarada, nunca do texto recebido. Aceitar qualquer átomo já existente faria a coluna
  ordenável depender do que o resto do sistema criou.
  """

  use Phoenix.Component

  import TheBandWeb.CoreComponents

  @doc """
  Uma tabela com busca, colunas ordenáveis e paginação.

  ## Uso

      <.data_table
        rows={@issues}
        busca={@busca}
        ordem={@ordem}
        pagina={@pagina}
        por_pagina={@por_pagina}
        total={@total}
        onde="title and number"
      >
        <:col :let={issue} field={:number} label="#" class="text-right">{issue.number}</:col>
        <:col :let={issue} field={:title} label="title">{issue.title}</:col>
        <:col :let={issue} label="repository">{@nomes[issue.repository_id]}</:col>
      </.data_table>

  Uma coluna **sem** `field` não é ordenável, e o cabeçalho dela é texto simples. É o caso da
  coluna derivada de outra consulta: ordenar por ela exigiria ordenar por algo que a consulta
  não trouxe, e o resultado pareceria ordenação sem ser.
  """
  attr :id, :string, required: true, doc: "identifica esta tabela nos eventos que ela emite"
  attr :rows, :list, required: true
  attr :estado, :map, required: true, doc: "busca, ordem e página, de `TabelaLive.aplicar/3`"
  attr :por_pagina, :integer, required: true
  attr :total, :integer, required: true
  attr :onde, :string, required: true, doc: "em quais colunas esta tela procura"
  attr :vazio, :string, default: "Nothing found."
  attr :class, :string, default: "table table-sm stacked"

  slot :col, required: true do
    attr :field, :atom, doc: "coluna ordenável; ausente = cabeçalho de texto"
    attr :label, :string, required: true
    attr :class, :string
  end

  def data_table(assigns) do
    ~H"""
    <div class="space-y-3">
      <.busca tabela={@id} valor={@estado.busca} onde={@onde} />

      <%!-- A contagem diz **o que se está vendo de quanto**, e não só o total. Com 91 páginas,
            "4529 issues" não ajuda quem quer saber onde está. --%>
      <div class="text-xs opacity-70">
        {faixa(@estado.pagina, @por_pagina, @total)} of {@total}
      </div>

      <div class="overflow-x-auto">
        <table class={@class}>
          <thead>
            <tr>
              <%= for col <- @col do %>
                <.th_ordenavel
                  :if={col[:field]}
                  tabela={@id}
                  campo={col[:field]}
                  rotulo={col[:label]}
                  ordem={@estado.ordem}
                  class={col[:class]}
                />
                <th :if={is_nil(col[:field])} class={col[:class]}>{col[:label]}</th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%!-- `data-label` não é enfeite: é o que a classe `stacked` usa para escrever o nome
                  da coluna ao lado do valor quando a tabela vira lista, em tela estreita. Sem
                  ele, 360 px mostra uma coluna de valores sem dizer de quê. --%>
            <tr :for={row <- @rows}>
              <td :for={col <- @col} data-label={col[:label]} class={col[:class]}>
                {render_slot(col, row)}
              </td>
            </tr>
            <%!-- A linha vazia é uma linha da tabela, e não um parágrafo depois dela: fora da
                  tabela, o cabeçalho fica sozinho afirmando colunas de nada. --%>
            <tr :if={@rows == []}>
              <td colspan={length(@col)} class="text-center opacity-60 py-6">{@vazio}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <.paginacao tabela={@id} pagina={@estado.pagina} por_pagina={@por_pagina} total={@total} />
    </div>
    """
  end

  # "0" quando não há nada: "1–0" afirmaria uma primeira linha que não existe.
  defp faixa(_pagina, _por_pagina, 0), do: "0"

  defp faixa(pagina, por_pagina, total) do
    primeira = (pagina - 1) * por_pagina + 1
    ultima = min(pagina * por_pagina, total)
    "#{primeira}–#{ultima}"
  end
end
