defmodule TheBand.VaultTest do
  @moduledoc """
  O rótulo do cipher é o que torna a rotação possível (FR-005b).

  Este teste existe por causa de um defeito real: as duas chaves compartilhavam
  rótulo, o Cloak escolhia o cipher pela ordem da configuração, e usava a chave
  errada. A falha aparecia como "não consigo decifrar", sem dizer por quê.
  """

  use ExUnit.Case, async: true

  alias TheBand.Vault

  describe "rótulo derivado da chave" do
    test "chaves diferentes produzem rótulos diferentes" do
      uma = :crypto.strong_rand_bytes(32)
      outra = :crypto.strong_rand_bytes(32)

      refute Vault.tag_for(uma) == Vault.tag_for(outra)
    end

    test "a mesma chave produz sempre o mesmo rótulo" do
      chave = :crypto.strong_rand_bytes(32)

      assert Vault.tag_for(chave) == Vault.tag_for(chave)
    end

    test "o rótulo não revela a chave" do
      chave = :crypto.strong_rand_bytes(32)
      rotulo = Vault.tag_for(chave)

      refute rotulo =~ Base.encode16(chave, case: :lower)
      refute rotulo =~ Base.encode64(chave)
      # Oito caracteres hexadecimais: 32 bits de um digest de 256.
      assert String.length(rotulo) == String.length("AES.GCM.") + 8
    end
  end

  describe "leitura da chave mestra" do
    test "aceita 32 bytes em Base64" do
      assert {:ok, chave} = Vault.master_key()
      assert byte_size(chave) == 32
    end
  end

  describe "cifragem" do
    test "o valor cifrado carrega o rótulo da chave que o cifrou" do
      {:ok, chave} = Vault.master_key()
      cifrado = Vault.encrypt!("segredo")

      # O rótulo vive no início do valor cifrado. É por ele que o Cloak decide
      # qual chave usar na leitura — e é por isso que ele precisa identificar a
      # chave, não a versão do algoritmo.
      assert String.contains?(cifrado, Vault.tag_for(chave))
      assert {:ok, "segredo"} = Vault.decrypt(cifrado)
    end

    test "o texto claro não aparece no valor cifrado" do
      cifrado = Vault.encrypt!("ghp_um_token_qualquer")

      refute String.contains?(cifrado, "ghp_um_token_qualquer")
    end
  end
end
