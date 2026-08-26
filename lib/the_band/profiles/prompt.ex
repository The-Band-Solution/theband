defmodule TheBand.Profiles.Prompt do
  @moduledoc """
  Compõe o prompt e o material que vão ao provedor — feature 026.

  ## O texto mora em arquivo, e os números moram na base

  `priv/profiles/perfil.md` carrega as instruções; `profile.thresholds` carrega os limiares.
  A separação não é organização: **as regras que o prompt impõe são requisitos** — sem gênero
  é a `FR-008`, só `#<número>` de tarefa presente é a `FR-005`, comparar com a linha de base
  é a `FR-010`. Mudar o arquivo é mudar o que a tela afirma sobre pessoas.

  ## As tarefas abertas não entram, e a razão é dupla

  **É duplicação.** A tela lista as paradas há mais de 90 dias a partir de dado observado e
  **recalculado a cada leitura**. O texto do modelo sobre elas envelhece; a lista não — uma
  tarefa que fechou depois da geração some da lista e continuaria no texto.

  **E é caro.** Medido em 2026-08-16: sem elas o material de `ManoelRL` cai de 134k para 27k
  caracteres, e o de `vinicius-je` de 320k para 129k. Entre 57% e 80% para quem tem muitas.

  A contagem fica em `COBERTURA`, que é uma linha e serve ao parágrafo de atenção.

  ## O veredito entra pronto

  O material traz a comparação já calculada. Ver `TheBand.Profiles.Material` para o porquê:
  o modelo errou essa divisão na validação, e é ela que decide se a mudança pode ser
  atribuída à pessoa.
  """

  alias TheBand.Profiles.Material

  # O atributo precisa ser registrado, ou o compilador o trata como esquecido e reprova em
  # `--warnings-as-errors`.
  Module.register_attribute(__MODULE__, :sobelow_skip, accumulate: true)

  @corpo_max 1200

  @doc "As instruções, lidas do arquivo."
  @spec instrucoes() :: String.t()
  def instrucoes, do: ler("profiles/perfil.md")

  @doc """
  O schema da resposta, que o provedor recebe com `strict: true`.

  **A estrutura passa a ser garantida, e não pedida.** Antes de existir, o modelo largou os
  subtítulos numa geração e a limpeza do resumo apagou a evidência inteira — porque não havia
  como saber onde o resumo terminava. Com schema, "sem seções" deixa de ser um estado
  possível.
  """
  @spec schema() :: map()
  def schema, do: "profiles/perfil_schema.json" |> ler() |> Jason.decode!()

  # O caminho é literal nos dois chamadores — nada de entrada de usuário chega aqui, e é por
  # isso que o aviso de travessia é dispensado. Mesma postura do coletor de consultas.
  @sobelow_skip ["Traversal.FileModule"]
  defp ler(caminho), do: :the_band |> :code.priv_dir() |> Path.join(caminho) |> File.read!()

  @doc """
  O material da pessoa, no formato que as instruções descrevem.

  Cada tarefa concluída traz `<n>d aberta` — é o que permite dizer onde o trabalho trava,
  comparando contra a mediana da própria pessoa e não contra número absoluto.
  """
  @spec material(Material.t()) :: String.t()
  def material(m) do
    """
    PESSOA            #{m.login}
    PERÍODO           #{m.de} a #{m.ate}

    COBERTURA         #{length(m.concluidas) + length(m.abertas)} tarefas com designação vigente
                      #{length(m.concluidas)} concluídas · #{length(m.abertas)} em aberto
                      #{m.com_corpo} concluídas com corpo de texto
                      #{m.autoria_propria} escritas pela própria pessoa · #{length(m.concluidas) - m.autoria_propria} escritas por outra
                      #{m.compartilhadas} com mais de um designado

    MEDIDO            concluídas por mês — a pessoa, e o projeto inteiro no mesmo mês
                      #{Enum.map_join(m.por_mes, " · ", fn {mes, n, proj} -> "#{mes} #{n}/#{proj}" end)}

                      repositórios
                      #{Enum.map_join(m.repositorios, " · ", fn {r, n} -> "#{r} #{n}" end)}

                      tipos declarados na origem
                      #{Enum.map_join(m.tipos, " · ", fn {t, n} -> "#{t} #{n}" end)}

    CRESCIMENTO DO TEXTO     já comparado; use este veredito, não recalcule
                      #{m.veredito}

    #{Enum.map_join(m.periodos, "\n\n", &periodo/1)}

    #{escritas_para_outros(m.para_outros)}
    TAREFAS CONCLUÍDAS
    #{Enum.map_join(m.periodos, "\n", &tarefas_do_periodo/1)}
    """
  end

  # Issue #364: o que a pessoa escreveu PARA OUTRAS não aparece em lugar nenhum do resto do
  # material, que é só o que foi designado a ela. O modelo não pode analisar o que não recebe.
  #
  # A contagem vai calculada. E a amostra existe porque o número sozinho não separa quem
  # escreve "corrigir typo" de quem escreve tarefa com contexto e critério.
  defp escritas_para_outros(%{total: 0}) do
    """
    ESCRITAS PARA OUTRAS PESSOAS
                      nenhuma no material coletado — não é sinal de nada, é ausência
    """
  end

  defp escritas_para_outros(pa) do
    """
    ESCRITAS PARA OUTRAS PESSOAS     já contado; use estes números, não recalcule
                      #{pa.total} tarefas escritas por esta pessoa e executadas por outras
                      #{pa.pessoas_distintas} pessoas distintas as executaram

                      **pessoas distintas discrimina melhor que o total**: escrever muitas
                      tarefas para uma pessoa e poucas para muitas são coisas diferentes,
                      e a segunda atravessa o time

                      **o que NÃO afirmar**: liderança é conclusão, e escrever tarefa para
                      outros também é papel de quem faz triagem, escreve requisito, coordena
                      entrega, ou é o único com permissão no repositório. O afirmável é o que
                      o texto abaixo sustenta — se traz contexto e critério, ou se não traz,
                      que também é achado

    AMOSTRA DAS ESCRITAS PARA OUTRAS · as #{length(pa.amostra)} mais recentes de #{pa.amostra_de}
    #{Enum.map_join(pa.amostra, "\n", &escrita_para_outro/1)}
    """
  end

  defp escrita_para_outro(t) do
    """

    --- ##{t.number} · criada #{t.data} · #{t.repositorio} · tipo #{t.tipo}
        #{cortar(t.titulo, 200)}
        #{cortar(t.corpo, @corpo_max)}\
    """
  end

  defp periodo(p) do
    """
    PERÍODO #{p.indice} · #{p.de} a #{p.ate} · #{length(p.tarefas)} concluídas
      da pessoa      corpo mediano #{p.corpo_mediano} chars · autoria própria #{p.autoria_propria} de #{length(p.tarefas)}
      linha de base  o projeto nestes meses: #{p.base.criadas} criadas e #{p.base.concluidas} concluídas,
                     corpo mediano #{p.base.corpo_mediano} chars, #{p.base.pct_titulo_tipado}% com título tipado\
    """
  end

  defp tarefas_do_periodo(p) do
    Enum.map_join(p.tarefas, "\n", fn t ->
      """

      --- P#{p.indice} · ##{t.number} · fechada #{t.data} · #{t.dias_aberta}d aberta · #{t.repositorio} · tipo #{t.tipo}
          autoria: #{if t.autoria_propria, do: "própria", else: "de terceiro"} · designados: #{t.designados}
          #{cortar(t.titulo, 200)}
          #{cortar(t.corpo, @corpo_max)}\
      """
    end)
  end

  defp cortar(texto, max) do
    t = texto |> to_string() |> String.replace(~r/\r\n?/, "\n") |> String.trim()
    if String.length(t) > max, do: String.slice(t, 0, max) <> " […truncado]", else: t
  end
end
