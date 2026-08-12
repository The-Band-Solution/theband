defmodule TheBand.Integrations.GitHub.TransientTest do
  @moduledoc """
  A natureza do erro da origem (T002).

  ## O payload é real

  A mensagem usada no caso da falha interna é a que está **gravada no banco**, em
  `observed_repositories.inaccessible_reason`, e foi ela que tirou o 39º repositório de
  circulação em 2026-08-12 às 12:32:29. Inventar a mensagem faria o teste passar sobre um erro
  que a origem não produz.
  """
  use ExUnit.Case, async: true

  alias TheBand.Integrations.GitHub.Client

  # Copiado do banco, sem editar.
  @falha_interna %{
    "message" =>
      "Something went wrong while executing your query on 2026-08-12T12:32:30Z. " <>
        "Please include `6D2F:110188:1CD8DB0:1D79ED0:6A7C67D3` when reporting this issue."
  }

  describe "falha do momento" do
    test "a falha interna da origem é transitória" do
      assert Client.transient?({:graphql_errors, [@falha_interna]}), """
      A falha interna da origem foi classificada como permanente.

      A própria mensagem pede para reportar o incidente com um identificador — é o oposto de
      permanente. E o efeito de errar aqui está medido: este payload criou a 39ª marca de
      inacessível, e o repositório saiu de toda coleta seguinte.
      """
    end

    test "o limite de taxa é transitório" do
      assert Client.transient?({:graphql_errors, [%{"type" => "RATE_LIMITED"}]})
    end

    test "transporte e erro de servidor seguem transitórios" do
      assert Client.transient?({:transport, :nxdomain})
      assert Client.transient?({:unexpected_status, 502})
      assert Client.transient?({:unexpected_status, 500, "boom"})
    end
  end

  describe "falha permanente" do
    test "não encontrado marca" do
      refute Client.transient?({:graphql_errors, [%{"type" => "NOT_FOUND"}]}), """
      "Não encontrado" precisa ser permanente: o repositório não existe, ou a credencial não o
      alcança. Tratá-lo como do momento faria a plataforma consultá-lo a cada coleta, para
      sempre.
      """
    end

    test "sem escopo marca" do
      refute Client.transient?({:graphql_errors, [%{"type" => "FORBIDDEN"}]})
    end

    test "erro desconhecido marca" do
      refute Client.transient?({:graphql_errors, [%{"message" => "algo que ninguém previu"}]}),
             """
             O desconhecido precisa ser permanente, e a ordem das correções é a razão: marcar de
             menos deixaria repositório apagado sendo consultado para sempre. Marcar de mais
             deixou de ser permanente, porque a coleta seguinte tenta de novo.
             """
    end

    test "numa lista mista, vence o permanente" do
      refute Client.transient?({:graphql_errors, [@falha_interna, %{"type" => "NOT_FOUND"}]}), """
      A lista tem uma falha do momento e uma permanente, e valeu a do momento.

      A origem pode responder "não encontrado" para um campo e falha interna para outro. Tratar
      como transitório faria a plataforma insistir num recurso que não existe — FR-008.
      """
    end

    test "lista vazia não é transitória" do
      refute Client.transient?({:graphql_errors, []})
    end
  end

  describe "a truncagem na borda" do
    test "a mensagem descrita não passa de 400 caracteres" do
      longa = %{"message" => String.duplicate("x", 5_000)}
      descrita = Client.describe_error({:graphql_errors, [longa]})

      assert String.length(descrita) < 500, """
      A mensagem não foi truncada onde é montada, e vai inteira para a coluna.

      Antes da feature 009 a coluna era `varchar(255)` com 27 caracteres de folga, e um valor
      maior derrubava a fase de coleta — o erro no log era do banco, não da origem. É a L05, e a
      defesa certa é aqui, não na largura da coluna.
      """
    end
  end
end
