defmodule TheBand.Profiles.PerfilSchemaTest do
  @moduledoc """
  O schema do perfil obedece ao modo strict do provider — issue #563.

  O provedor de saída estruturada exige, em CADA objeto, que `required` contenha
  TODAS as chaves de `properties`. Um objeto fora disso não falha aqui dentro:
  falha como HTTP 400 na primeira geração — foi exatamente o que aconteceu
  (`escreveu_para_outros` sem `tarefas_citadas` no required), e o erro apareceu
  para quem clicou "Generate again", não para quem editou o schema.

  Este teste percorre o schema INTEIRO, recursivamente: o próximo campo novo
  esquecido reprova no commit, não na tela.
  """
  use ExUnit.Case, async: true

  @schema_path Path.join(:code.priv_dir(:the_band), "profiles/perfil_schema.json")

  test "todo objeto do schema tem required cobrindo todas as properties" do
    schema = @schema_path |> File.read!() |> Jason.decode!()

    falhas = auditar(schema, "$")

    assert falhas == [],
           """
           Objetos fora do modo strict do provider (required não cobre properties):

           #{Enum.map_join(falhas, "\n", fn {caminho, faltam} -> "  #{caminho} — faltam: #{Enum.join(faltam, ", ")}" end)}

           O provider recusa o schema inteiro com HTTP 400 na PRIMEIRA geração —
           o erro aparece para quem clica, não para quem editou (issue #563).
           """
  end

  defp auditar(%{} = node, caminho) do
    proprias =
      if node["type"] == "object" and is_map(node["properties"]) do
        props = node["properties"] |> Map.keys() |> MapSet.new()
        req = MapSet.new(node["required"] || [])
        faltam = MapSet.difference(props, req)

        if MapSet.size(faltam) == 0,
          do: [],
          else: [{caminho, Enum.sort(faltam)}]
      else
        []
      end

    filhas =
      Enum.flat_map(node, fn {chave, valor} -> auditar(valor, "#{caminho}.#{chave}") end)

    proprias ++ filhas
  end

  defp auditar(lista, caminho) when is_list(lista) do
    lista
    |> Enum.with_index()
    |> Enum.flat_map(fn {item, i} -> auditar(item, "#{caminho}[#{i}]") end)
  end

  defp auditar(_outro, _caminho), do: []
end
