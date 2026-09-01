defmodule TheBandWeb.OrigensTest do
  @moduledoc """
  Feature 054 — contrato em `specs/054-dominio-proprio/contracts/origens-aceitas.md`.

  **As violações vêm primeiro**, e aqui elas são de uma classe específica: o
  defeito que esta feature pode introduzir não é recusar demais, é **aceitar
  demais**. Um caminho feliz que só prova "os dois endereços declarados entram"
  passaria numa implementação que aceita qualquer origem — que é a correção
  fácil, a que ninguém reclama, e a que troca um defeito visível por um buraco
  silencioso (FR-007).

  Por isso os dois primeiros describes provam o que NÃO pode acontecer.
  """
  use ExUnit.Case, async: true

  alias TheBandWeb.Origens

  @host "theband.dev"

  describe "a ausência restringe (C2, FR-005, SC-006)" do
    test "nil produz exatamente a origem principal" do
      assert Origens.aceitas(@host, nil) == ["https://theband.dev"]
    end

    test "string vazia produz exatamente a origem principal" do
      assert Origens.aceitas(@host, "") == ["https://theband.dev"]
    end

    test "só espaços produz exatamente a origem principal" do
      assert Origens.aceitas(@host, "   ") == ["https://theband.dev"]
    end

    test "só vírgulas produz exatamente a origem principal" do
      assert Origens.aceitas(@host, ",,,") == ["https://theband.dev"]
    end
  end

  describe "não existe valor que aceite qualquer origem (C7, FR-007)" do
    # Cada um destes é uma forma de dizer "aceita todo mundo" em alguma
    # biblioteca. Nenhuma delas pode virar isso aqui: no máximo, viram uma
    # origem literal — inútil e inofensiva.
    for entrada <- ["*", "true", "all", "//", "*.*", "https://*"] do
      test "#{inspect(entrada)} não libera origem arbitrária" do
        lista = Origens.aceitas(@host, unquote(entrada))

        refute Enum.any?(lista, &(&1 in ["*", "true", "all", "//", "*.*"]))
        assert "https://theband.dev" in lista
      end
    end

    test "a lista nunca é vazia, mesmo com entrada absurda" do
      # Lista vazia em `check_origin` é o pior dos mundos: o Phoenix a trata
      # como lista, e nenhuma origem casa — nem a principal. A plataforma
      # ficaria sem socket em endereço nenhum.
      refute Origens.aceitas(@host, "") == []
      refute Origens.aceitas(@host, nil) == []
      refute Origens.aceitas(@host, ", , ,") == []
    end
  end

  describe "a origem principal (C1)" do
    test "vem sempre em primeiro lugar" do
      assert ["https://theband.dev" | _] = Origens.aceitas(@host, "https://outro.test")
    end

    test "continua presente mesmo se a declaração estiver errada" do
      assert "https://theband.dev" in Origens.aceitas(@host, "isto não é uma origem")
    end
  end

  describe "a declaração (C3, C4, C5, C6)" do
    test "preserva a ordem em que foi escrita" do
      assert Origens.aceitas(@host, "https://a.test,https://b.test") == [
               "https://theband.dev",
               "https://a.test",
               "https://b.test"
             ]
    end

    test "ignora espaços em volta e entradas vazias" do
      assert Origens.aceitas(@host, " https://a.test ,, https://b.test ") == [
               "https://theband.dev",
               "https://a.test",
               "https://b.test"
             ]
    end

    test "entrada sem esquema recebe https" do
      assert Origens.aceitas(@host, "outro.test") == [
               "https://theband.dev",
               "https://outro.test"
             ]
    end

    test "http declarado explicitamente é preservado" do
      # Quem escreve `http://` está pedindo. O padrão é `https://` (C5), mas o
      # explícito não é reescrito — reescrever seria a plataforma decidindo
      # calada o oposto do que se declarou.
      assert "http://legado.test" in Origens.aceitas(@host, "http://legado.test")
    end

    test "não repete a origem principal declarada de novo" do
      assert Origens.aceitas(@host, "https://theband.dev") == ["https://theband.dev"]
    end

    test "não repete entradas duplicadas entre si" do
      assert Origens.aceitas(@host, "https://a.test,https://a.test") == [
               "https://theband.dev",
               "https://a.test"
             ]
    end
  end
end
