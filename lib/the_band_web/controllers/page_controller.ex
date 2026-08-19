defmodule TheBandWeb.PageController do
  use TheBandWeb, :controller

  def home(conn, _params) do
    # A raiz leva direto para onde há o que ver: a lista de pessoas quando há
    # sessão, a entrada quando não há.
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/people")
    else
      redirect(conn, to: ~p"/sign-in")
    end
  end

  # Só existe em desenvolvimento, e existe para uma coisa: **ver a página de erro sem
  # provocar o erro**. Sem isto, conferir o 500 exigiria quebrar a plataforma de propósito, e
  # conferir o 403 exigiria uma conta sem permissão.
  #
  # A rota vive dentro do `if dev_routes` do roteador, então não chega a produção.
  def erro_de_exemplo(conn, %{"codigo" => codigo}) do
    # `put_root_layout` porque esta rota NÃO passa pelo `render_errors` do endpoint: ela
    # renderiza pelo controlador, com o layout dele. Sem isto a página aparece sem folha de
    # estilo aqui e estilizada em produção — e a conferência mentiria sobre o que a pessoa vê.
    conn
    |> put_status(String.to_integer(codigo))
    |> put_view(html: TheBandWeb.ErrorHTML)
    |> put_root_layout(html: {TheBandWeb.Layouts, :root})
    |> put_layout(false)
    |> render("#{codigo}.html")
  end
end
