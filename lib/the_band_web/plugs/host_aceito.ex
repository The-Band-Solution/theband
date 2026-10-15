defmodule TheBandWeb.Plugs.HostAceito do
  @moduledoc """
  Recusa o pedido cujo host da conexão não está na lista aceita — EEF-CVE-2026-105660 (MEDIUM,
  `bandit` 1.12.5, sem versão consertada em 2026-10-15).

  Um pedido HTTP/1 em forma absoluta (`GET http://outro/x HTTP/1.1`) deixa o cliente escolher
  `conn.host` e `conn.port`. O código da plataforma não lê o host da conexão (os links saem do
  `url:` do endpoint), e atrás do Traefik o host só pode ser um que a regra do roteador aceite.
  Este plug fecha o caminho de quem fala direto com a aplicação: host fora da lista, 400, e nada
  mais roda. A lista é a mesma do `check_origin` (`TheBandWeb.Origens.hosts/2`).

  O `force_ssl` roda **antes** dos plugs do endpoint, e por isso não é protegido por este: o
  redirecionamento dele tem o host fixo em `config/prod.exs`.

  Depende de: nenhuma ontologia.
  """
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opcoes), do: opcoes

  @impl Plug
  def call(conn, _opcoes) do
    if conn.host in Application.fetch_env!(:the_band, :hosts_aceitos) do
      conn
    else
      # O host veio do cliente: não vai para o log, e a resposta não diz qual seria o certo.
      conn |> send_resp(400, "Bad request") |> halt()
    end
  end
end
