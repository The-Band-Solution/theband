defmodule TheBandWeb.DesignTokensTest do
  @moduledoc """
  Os tokens do design system estão **no CSS compilado**, e não só no fonte.

  Existe porque "apliquei a paleta" é uma afirmação sobre o build, e não sobre o arquivo que
  eu editei: o Tailwind poda o que não encontra no markup, e um token declarado que ninguém
  usa não chega ao navegador.

  A pergunta que este teste responde é a que a pessoa mantenedora fez — *"o novo design foi
  aplicado?"* —, e ela merecia ser respondida por medição.
  """
  use ExUnit.Case, async: true

  @fonte "assets/css/app.css"
  @compilado "priv/static/assets/css/app.css"

  # `setup_all` devolvendo `{:skip, _}` **não é retorno válido**, e o efeito foi pior que o
  # teste falhar: o módulo inteiro foi invalidado no CI, com a mensagem "failure on setup_all
  # callback". Passava aqui porque eu já tinha o build.
  #
  # Agora o gate compila os assets antes dos testes, e a ausência do arquivo é uma falha com
  # a instrução do que rodar.

  defp compilado! do
    unless File.exists?(@compilado) do
      flunk("""
      O CSS compilado não existe em #{@compilado}.

      Rode `mix assets.build`. O gate de testes já o faz — se você chegou aqui, ou rodou
      `mix test` direto, ou o passo de assets saiu do `mix gates`.
      """)
    end

    File.read!(@compilado)
  end

  describe "a paleta" do
    test "o verdete é a primária dos dois temas, no fonte" do
      fonte = File.read!(@fonte)

      assert fonte =~ "--color-primary: #1f6f68;", "tema claro sem o verdete"
      assert fonte =~ "--color-primary: #5cbcb2;", "tema escuro sem o verdete"
    end

    test "o roxo e o laranja do gerador do Phoenix saíram" do
      fonte = File.read!(@fonte)

      refute fonte =~ "oklch(58% 0.233 277.117)", """
      A primária roxa do tema gerado voltou. Ela aparece na marca de evidência, onde
      significa "a origem afirmou" — e uma cor de alerta ali diria que observar é urgente.
      """

      refute fonte =~ "oklch(70% 0.213 47.604)", "a primária laranja do tema claro voltou"
    end

    test "a cor semântica é separada da primária" do
      fonte = File.read!(@fonte)

      # Âmbar para divergência, barro para recusa. Nenhum dos dois é vermelho de erro:
      # os dois são fato sobre o dado, não falha do sistema.
      assert fonte =~ "--color-warning: #8a5a0c;"
      assert fonte =~ "--color-error: #8c3327;"
    end

    test "o verdete chega ao CSS compilado" do
      compilado = compilado!()

      assert compilado =~ "#1f6f68" or compilado =~ "#5cbcb2", """
      A paleta está no fonte e não no build. O Tailwind poda o que não encontra no markup —
      um token declarado que ninguém usa não chega ao navegador.
      """
    end
  end

  describe "a tipografia" do
    test "as três vozes são variáveis do Tailwind, e não classes próprias" do
      fonte = File.read!(@fonte)

      # Como variáveis do tema, elas viram `font-sans`, `font-serif` e `font-mono` — então
      # quem escreve markup usa utilitário, e não uma classe que só existe aqui.
      assert fonte =~ "--font-sans:"
      assert fonte =~ "--font-serif:"
      assert fonte =~ "--font-mono:"
    end

    test "o corpo é serifado e os títulos são grotescos" do
      fonte = File.read!(@fonte)

      assert fonte =~ ~r/body\s*\{[^}]*font-family: var\(--font-serif\)/s, """
      Esta interface explica muito — por que uma issue divergiu, o que a plataforma manteve,
      de quem é a ausência. Prosa longa em grotesca cansa.
      """

      assert fonte =~ ~r/h1, h2, h3, h4[^{]*\{[^}]*font-family: var\(--font-sans\)/s
    end

    test "nenhuma webfont é buscada na rede" do
      fonte = File.read!(@fonte)

      refute fonte =~ "@font-face", "webfont embutida: o peso não se justifica"
      refute fonte =~ "fonts.googleapis", "webfont remota: uma requisição por carregamento"
    end
  end

  describe "o que o CSS ainda carrega, e por quê" do
    test "cada bloco que não é utilitário tem justificativa escrita" do
      fonte = File.read!(@fonte)

      for bloco <- ["FOCO VISÍVEL", "ALVO DE TOQUE", "MOVIMENTO", "TABELA QUE VIRA LISTA"] do
        assert fonte =~ bloco, "bloco #{bloco} desapareceu do CSS"
      end

      assert fonte =~ "Por que não é utilitário", """
      Um bloco de CSS próprio sem a razão escrita é um convite para alguém convertê-lo em
      utilitário e quebrar o que ele protegia.
      """
    end

    test "a gramática da evidência NÃO está mais no CSS global" do
      fonte = File.read!(@fonte)

      refute fonte =~ ".evidence-solid", """
      O padrão voltou para o CSS global. Ele vive em `TheBandWeb.UI`, junto do componente
      que o usa — quem lê o componente precisa ver que sólido e hachurado diferem no
      preenchimento sem abrir outro arquivo.
      """
    end
  end
end
