defmodule TheBand.Platform.SchemasTest do
  @moduledoc """
  Os schemas do operador não mostram segredo — spec 070, T021.

  `inspect/1` de cada struct esconde os campos redigidos, e `totp_secret` vai cifrado ao banco e não
  é carregado por consulta comum (`load_in_query: false`, seguranca-totp.md T4).
  """
  use TheBand.DataCase, async: true

  alias TheBand.Platform.{Grant, Operator, OperatorSession, RecoveryCode}

  @segredo "JBSWY3DPEHPK3PXPJBSW"

  test "inspect/1 não mostra nenhum campo redigido" do
    casos = [
      %Operator{
        password_hash: "hash-da-senha",
        setup_code_hash: "hash-da-definicao",
        enrollment_code_hash: "hash-do-cadastro",
        ack_code_hash: "hash-da-guarda",
        totp_secret: @segredo
      },
      %OperatorSession{token_hash: "hash-do-token"},
      %RecoveryCode{code_hash: "hash-do-codigo"}
    ]

    for struct <- casos,
        {_campo, valor} <- Map.from_struct(struct),
        (is_binary(valor) and valor =~ "hash") or valor == @segredo do
      refute inspect(struct) =~ valor, "#{inspect(struct.__struct__)} mostrou #{valor}"
    end

    assert %Grant{} |> inspect() =~ "Grant"
  end

  test "totp_secret vai cifrado ao banco, e a consulta comum não o carrega" do
    op =
      Repo.insert!(%Operator{
        email: "op-#{System.unique_integer([:positive])}@example.org",
        name: "Op",
        totp_secret: @segredo
      })

    %{rows: [[cru]]} =
      Repo.query!("SELECT totp_secret FROM platform_operators WHERE id = $1", [
        Ecto.UUID.dump!(op.id)
      ])

    refute cru == @segredo
    refute cru =~ @segredo

    assert Repo.get!(Operator, op.id).totp_secret == nil

    assert Repo.one!(from(o in Operator, where: o.id == ^op.id, select: o.totp_secret)) ==
             @segredo
  end
end
