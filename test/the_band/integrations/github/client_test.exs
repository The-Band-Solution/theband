defmodule TheBand.Integrations.GitHub.ClientTest do
  @moduledoc """
  Taxonomia e mensagens de erro.

  O teste existe porque `%Req.TransportError{reason: :nxdomain}` chegou ao
  registro de uma sincronização real e não disse a quem operava o que havia
  acontecido nem o que fazer.
  """

  use ExUnit.Case, async: true

  alias TheBand.Integrations.GitHub.Client

  describe "mensagem legível" do
    test "endereço não resolvido diz o que conferir" do
      mensagem = Client.describe_error({:transport, :nxdomain})

      assert mensagem =~ "não foi possível resolver o endereço"
      assert mensagem =~ "conexão de rede"
      refute mensagem =~ "nxdomain"
    end

    test "organização não encontrada lembra que se usa o login, não a URL" do
      mensagem = Client.describe_error({:organization_not_found, "leds-conectafapes"})

      assert mensagem =~ "leds-conectafapes"
      assert mensagem =~ "github.com/"
    end

    test "escopo insuficiente nomeia o que falta" do
      mensagem = Client.describe_error({:missing_scopes, ["read:org"]})

      assert mensagem =~ "read:org"
    end

    test "nenhuma mensagem expõe struct" do
      for erro <- [
            {:transport, :nxdomain},
            {:transport, :timeout},
            :unauthorized,
            {:missing_scopes, ["read:org"]},
            {:organization_not_found, "acme"},
            {:unexpected_status, 500},
            {:unexpected_status, 404}
          ] do
        refute Client.describe_error(erro) =~ "%{", "struct vazou em #{inspect(erro)}"
      end
    end

    test "falha desconhecida ainda produz frase, sem quebrar" do
      assert Client.describe_error(:algo_novo) =~ "não classificada"
    end
  end

  describe "o que vale retentar" do
    test "falha de transporte e erro 5xx são transitórios" do
      assert Client.transient?({:transport, :nxdomain})
      assert Client.transient?({:transport, :timeout})
      assert Client.transient?({:unexpected_status, 503})
    end

    test "credencial, escopo, organização e 4xx são terminais" do
      refute Client.transient?(:unauthorized)
      refute Client.transient?({:missing_scopes, ["read:org"]})
      refute Client.transient?({:organization_not_found, "acme"})
      refute Client.transient?({:unexpected_status, 404})
      refute Client.transient?({:graphql_errors, [%{"message" => "x"}]})
    end
  end
end
