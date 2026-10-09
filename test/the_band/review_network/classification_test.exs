defmodule TheBand.ReviewNetwork.ClassificationTest do
  @moduledoc """
  Cada par cai em um destino só — feature 073, T011 (research.md R3; R9 da segurança).

  ## As asserções que carregam este arquivo

  1. **A14**: conta `User` ligada a pessoa que EO diz ser `bot` é bot, e não nó;
  2. a conta apagada na origem é **sem pessoa ligada**, e não bot (decidido em 2026-10-03);
  3. a ordem: bot vence não ligada, que vence auto-revisão;
  4. pessoa ligada fora do mapa de tipos (de outro tenant) é não ligada: falha fechada;
  5. o par classificado não carrega login;
  6. **A7 (076, T027)**: a pessoa declarada como conta da organização é `:organization_account`
     — depois de máquina, antes de não ligada e de auto-revisão.
  """
  use ExUnit.Case, async: true

  alias TheBand.ReviewNetwork.Classification

  @ana "00000000-0000-0000-0000-00000000000a"
  @bia "00000000-0000-0000-0000-00000000000b"
  @robo "00000000-0000-0000-0000-0000000000b0"
  @de_fora "00000000-0000-0000-0000-0000000000ff"
  @tipos %{@ana => "person", @bia => "person", @robo => "bot"}

  defp par(revisor, autor) do
    {rid, rlogin, rtipo} = revisor
    {aid, alogin} = autor

    %{
      change_request_id: "cr-1",
      reviewer_person_id: rid,
      reviewer_login: rlogin,
      reviewer_type: rtipo,
      author_person_id: aid,
      author_login: alogin,
      last_submitted_at: ~U[2026-09-01 10:00:00Z]
    }
  end

  defp destino(revisor, autor, contas \\ MapSet.new()),
    do:
      [par(revisor, autor)]
      |> Classification.classify(@tipos, contas)
      |> hd()
      |> Map.fetch!(:destino)

  test "duas pessoas distintas viram aresta, do revisor para o autor" do
    assert destino({@ana, "ana", "User"}, {@bia, "bia"}) == {:aresta, @ana, @bia}
  end

  test "A14: conta User ligada a pessoa que EO classifica como bot é bot, e não nó" do
    assert destino({@robo, "algo[bot]", "User"}, {@bia, "bia"}) == :bot_or_app
  end

  test "conta não ligada é classificada pelo Mapper: __typename Bot e sufixo [bot]" do
    assert destino({nil, "dependabot", "Bot"}, {@bia, "bia"}) == :bot_or_app
    assert destino({nil, "renovate[bot]", "User"}, {@bia, "bia"}) == :bot_or_app
    assert destino({@ana, "ana", "User"}, {nil, "github-actions[bot]"}) == :bot_or_app
  end

  test "a conta apagada na origem é sem pessoa ligada, e não bot" do
    assert destino({nil, nil, nil}, {@bia, "bia"}) == :unlinked_person
    assert destino({@ana, "ana", "User"}, {nil, nil}) == :unlinked_person
  end

  test "login humano sem pessoa ligada é não ligada" do
    assert destino({nil, "prestador", "User"}, {@bia, "bia"}) == :unlinked_person
  end

  test "pessoa ligada que não está no mapa (outro tenant) é não ligada" do
    assert destino({@de_fora, "fora", "User"}, {@bia, "bia"}) == :unlinked_person
  end

  test "a ordem: bot vence não ligada, e não ligada vence auto-revisão" do
    assert destino({@robo, "algo[bot]", "User"}, {nil, nil}) == :bot_or_app
    assert destino({nil, nil, nil}, {nil, "github-actions[bot]"}) == :bot_or_app
    assert destino({@ana, "ana", "User"}, {@ana, "ana"}) == :self_review
  end

  test "o par classificado não carrega login" do
    [classificado] =
      Classification.classify([par({@ana, "ana", "User"}, {@bia, "bia"})], @tipos, MapSet.new())

    assert Map.keys(classificado) |> Enum.sort() ==
             [:change_request_id, :destino, :last_submitted_at]
  end

  describe "A7 (076, T027): a conta declarada da organização" do
    test "de qualquer lado, é organization_account e não aresta" do
      contas = MapSet.new([@bia])
      assert destino({@ana, "ana", "User"}, {@bia, "bia"}, contas) == :organization_account
      assert destino({@bia, "bia", "User"}, {@ana, "ana"}, contas) == :organization_account
    end

    test "a ordem: máquina vence a declaração, e a declaração vence não ligada e auto-revisão" do
      contas = MapSet.new([@robo, @bia])
      assert destino({@robo, "algo[bot]", "User"}, {@bia, "bia"}, contas) == :bot_or_app
      assert destino({@bia, "bia", "User"}, {nil, nil}, contas) == :organization_account
      assert destino({@bia, "bia", "User"}, {@bia, "bia"}, contas) == :organization_account
    end

    test "sem declaração, a mesma conta é pessoa e é aresta" do
      assert destino({@ana, "ana", "User"}, {@bia, "bia"}) == {:aresta, @ana, @bia}
    end
  end
end
