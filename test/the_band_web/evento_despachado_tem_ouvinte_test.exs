defmodule TheBandWeb.EventoDespachadoTemOuvinteTest do
  @moduledoc """
  Nenhum evento que o servidor despacha para o navegador fica sem quem o escute.

  (A frase começava com *"Todo evento"*, e o `credo` a leu como uma etiqueta `TODO` —
  pela segunda vez nesta sessão, depois de *"todos de uma vez"*.)

  ## O defeito que esta guarda existe para pegar

  A tela de tokens despachava `the_band:copy` desde a v0.8.0, e **ninguém escutava**. O
  `JS.dispatch` tinha exatamente uma ocorrência no repositório: a que dispara.

  O botão `Copy value` existia, tinha aparência de primário, **não dava erro**, e não copiava
  nada. É o pior lugar possível para um sucesso silencioso — o valor do token é mostrado uma
  vez, a própria tela diz que ele não volta, e quem clicava e saía perdia a credencial que
  tinha acabado de gerar.

  Nenhum teste de LiveView pegaria isso: o HTML servido está perfeito. Um `<button>` com
  `phx-click` é indistinguível, no HTML, de um que funciona — a metade que falta mora no
  JavaScript, e é por isso que a guarda olha os dois lados.

  ## O que ela NÃO prova

  Não prova que o ouvinte **faz** a coisa certa — isso só se vê abrindo a tela. Prova que ele
  existe. A distância entre as duas é real, e fica dita aqui em vez de virar confiança.
  """
  use ExUnit.Case, async: true

  @raiz File.cwd!()

  test "nenhum evento `the_band:*` despachado pelo servidor fica sem ouvinte" do
    despachados = despachados()

    assert despachados != [], """
    Nenhum `JS.dispatch("the_band:…")` encontrado em `lib/`.

    Ou o padrão de nome mudou, ou esta guarda deixou de olhar onde o código está — e uma
    guarda que não acha nada passa sempre.
    """

    escutados = escutados()

    orfaos = despachados -- escutados

    assert orfaos == [], """
    Evento despachado pelo servidor e por ninguém escutado: #{Enum.join(orfaos, ", ")}

    O controle existe na tela, não dá erro, e não faz nada. Escreva o ouvinte em
    `assets/js/app.js`, e faça-o **dizer quando falhar** — foi a falha calada que criou
    este teste.

    despachados: #{inspect(despachados)}
    escutados:   #{inspect(escutados)}
    """
  end

  defp despachados do
    Path.wildcard(Path.join(@raiz, "lib/**/*.{ex,heex}"))
    |> Enum.flat_map(fn arquivo ->
      Regex.scan(~r/JS\.dispatch\(\s*"(the_band:[a-z0-9_:-]+)"/, File.read!(arquivo))
    end)
    |> Enum.map(&List.last/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp escutados do
    Path.wildcard(Path.join(@raiz, "assets/js/**/*.js"))
    |> Enum.flat_map(fn arquivo ->
      Regex.scan(~r/addEventListener\(\s*"(the_band:[a-z0-9_:-]+)"/, File.read!(arquivo))
    end)
    |> Enum.map(&List.last/1)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
