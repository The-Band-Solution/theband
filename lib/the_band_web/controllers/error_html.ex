defmodule TheBandWeb.ErrorHTML do
  @moduledoc """
  As páginas de erro — issue #437.

  ## Por que elas existem

  Aconteceu de verdade em 2026-08-19: `/works/verifications` — com `s` — devolveu o 404 cru
  do Phoenix, e a leitura natural de quem viu foi *"a tela não existe"*. A rota certa era
  `/work/verifications`, e a plataforma tinha a informação para dizer isso e não disse.

  É a mesma família do defeito que esta casa mais reincide: **ausência de resposta lida como
  ausência de coisa**. O 404 do Phoenix diz que algo não foi encontrado; não diz **o quê**.

  ## A metáfora vem do nome, e não de um dicionário de piadas

  The Band é a metáfora da tese: cada serviço é um músico tocando um instrumento — uma
  ontologia —, e juntos produzem **música** (informação) a partir de **notas** (os dados das
  aplicações) para um **público** (a organização).

  As frases usam esse vocabulário e só ele: partitura, palco, corda. Trocadilho com nome de
  banda ou de música seria enfeite estranho ao produto, e envelheceria mal.

  **E a metáfora nunca substitui a informação.** Cada página tem DUAS frases: a musical como
  título, e a técnica logo abaixo. Quem chega perdido precisa da segunda; a primeira existe
  para a página não ser hostil. Ter só a primeira tornaria a página bonita e inútil.

  Duas frases foram descartadas por dizerem coisa errada, e o motivo importa:

    * *"This note isn't in the score"* para o 404 — mais bonita, e pior: **"nota" já significa
      dado** neste produto, então a frase diria que o DADO não existe, quando o problema é o
      endereço. Era exatamente a confusão que originou a issue;
    * *"The band stopped playing"* para o 500 — sugere que a plataforma **toda** caiu. Um 500
      numa página não diz isso, e alarmar além do que se sabe é o erro que esta casa registra
      em L64.

  ## O que cada página diz, e o que ela não pode dizer

  | código | o que houve | a frase |
  |---|---|---|
  | 404 | o **caminho** não existe | que é o caminho, e a rota parecida quando houver |
  | 403 | autenticada, sem permissão | que falta permissão, **sem** revelar se o recurso existe |
  | 500 | a plataforma quebrou | que foi ela, e não o pedido |

  ## O 403 é o mais delicado, e a regra já é praticada

  As LiveViews desta plataforma devolvem *"não encontrada"* para recurso de outro tenant,
  **nunca** *"sem permissão"* — porque dizer "sem permissão" confirmaria que o recurso
  existe. A página de 403 sustenta a mesma postura: ela só aparece quando a existência já é
  conhecida de quem pede.

  Por isso o texto dela não menciona **o quê** faltou permissão. Nomear o recurso seria
  entregar a existência pela porta que a regra fechou.

  ## A sugestão de rota parecida é literal, e a lista é fechada

  `/works/…` → `/work/…` é a única sugestão. Ela vem de uma lista escrita à mão, e não de
  distância de edição: adivinhar rota por similaridade produziria sugestão inventada para
  qualquer caminho, e a plataforma passaria a afirmar que existe tela onde não existe.

  Quando nada casa, a página não sugere nada — e dizer "não sei" é resposta.

  ## As ilustrações são SVG embutido, e isso não é preferência

  Nenhum arquivo, nenhuma requisição: **a página de erro tem de funcionar quando a plataforma
  está com problema**, e depender de um asset é depender de mais uma coisa que pode falhar.

  Todas usam `currentColor`, então acompanham claro e escuro sem segunda paleta — e sem o
  risco de cor definida só dentro de um dos dois temas.
  """
  use TheBandWeb, :html

  alias Phoenix.Controller

  # As confusões de caminho que já aconteceram, e só elas. Lista fechada de propósito: ver o
  # `@moduledoc`.
  @caminhos_parecidos %{
    "/works" => "/work",
    "/person" => "/people",
    "/team" => "/teams",
    "/project" => "/projects",
    "/board" => "/boards",
    "/sync" => "/syncs",
    "/tool" => "/tools",
    "/profile" => "/profiles"
  }

  def render("404.html", assigns) do
    assigns = normalizar(assigns)

    ~H"""
    <.moldura codigo="404" titulo="Nothing plays at this address">
      <:ilustracao><.pauta_com_lacuna /></:ilustracao>

      <p>
        The address <span class="font-mono break-all">{@caminho}</span>
        matches no page on this platform.
      </p>
      <%!-- A sugestão é o que faltava no caso real: `/works/verifications` devolveu 404 sem
            dizer que a rota é `/work/verifications`, e quem leu concluiu que a tela não
            existia. --%>
      <p :if={@sugestao} class="alert mt-3 block text-sm">
        Did you mean <.link navigate={@sugestao} class="link font-mono">{@sugestao}</.link>?
      </p>
      <p class="mt-3 text-sm opacity-70">
        <strong>This says nothing about the data.</strong>
        A page that exists may still have nothing collected yet — and that is a different
        sentence, shown on the page itself.
      </p>
    </.moldura>
    """
  end

  def render("403.html", assigns) do
    assigns = normalizar(assigns)

    ~H"""
    <.moldura codigo="403" titulo="The stage door is closed">
      <:ilustracao><.porta_de_palco /></:ilustracao>

      <p>
        Your account is signed in, and this action is not available to it.
      </p>
      <%!-- NÃO nomeia o recurso. As LiveViews devolvem "não encontrada" para recurso de
            outro tenant justamente para não confirmar que ele existe, e esta página
            sustenta a mesma postura: nomear aqui entregaria a existência pela porta que a
            regra fechou. --%>
      <p class="mt-3 text-sm opacity-70">
        Some screens are restricted to who administers the tenant. If you believe this is
        wrong, whoever administers it can check your role.
      </p>
    </.moldura>
    """
  end

  def render("500.html", assigns) do
    assigns = normalizar(assigns)

    ~H"""
    <.moldura codigo="500" titulo="A string broke mid-song">
      <:ilustracao><.corda_rompida /></:ilustracao>

      <p>
        Something failed on our side while handling this page. Repeating the request may
        work — and if it does not, the failure is reproducible and worth reporting.
      </p>
      <%!-- O identificador da requisição é o que liga o que a pessoa viu ao que o log
            registrou. Sem ele, "deu erro" não tem como ser investigado. --%>
      <p :if={@referencia} class="mt-3 text-sm">
        <span class="opacity-70">Reference for whoever investigates:</span>
        <span class="font-mono break-all">{@referencia}</span>
      </p>
    </.moldura>
    """
  end

  # Qualquer outro código cai aqui, **sem ilustração**: desenhar algo para "502 Bad Gateway"
  # exigiria inventar metáfora para o que não se sabe. O texto do Phoenix é o nome do status, e
  # ele diz mais que uma frase genérica.
  def render(template, assigns) do
    # Fora do `~H`: variável dentro do template desliga o rastreio de mudança do LiveView, e
    # o compilador avisa. O valor vira assign.
    # `Map.merge` e não `assign/2`: `assign` exige a estrutura completa de assigns, e esta
    # função é chamada pelo endpoint com o que ele tiver — inclusive um mapa cru. Numa página
    # de erro o rastreio de mudança do LiveView não serve a nada, e exigi-lo faria a página de
    # erro levantar exceção.
    assigns =
      Map.merge(assigns, %{codigo: codigo_do_template(template), titulo: mensagem(template)})

    ~H"""
    <.moldura codigo={@codigo} titulo={@titulo}>
      <p>The platform could not complete this request.</p>
    </.moldura>
    """
  end

  attr :codigo, :string, required: true
  attr :titulo, :string, required: true
  slot :ilustracao
  slot :inner_block, required: true

  # A moldura é uma só para as três páginas, e **não usa `Layouts.app`**: o layout do app
  # depende de `current_tenant` e `current_user`, e numa página de erro esses assigns podem não
  # existir — seria a página de erro dando erro. O layout raiz, que só depende de
  # `@inner_content`, é configurado no `render_errors` do endpoint.
  defp moldura(assigns) do
    ~H"""
    <main class="mx-auto max-w-3xl px-4 py-12 sm:px-6 sm:py-16">
      <div class="mb-10">
        <a href="/" class="text-lg font-semibold">The Band</a>
      </div>

      <%!-- Empilha no telefone e fica lado a lado a partir de `sm:`. A ilustração é
            **companhia, não conteúdo**, e por isso no telefone ela vem depois do texto:
            `order-first` a põe acima no desenho de mesa sem mexer na ordem do documento, que é
            a que o leitor de tela segue. --%>
      <div class="flex flex-col gap-8 sm:flex-row sm:items-start sm:gap-10">
        <div class="min-w-0 flex-1">
          <div class="flex items-baseline gap-3">
            <span class="font-mono text-4xl tabular-nums opacity-25">{@codigo}</span>
            <h1 class="text-xl font-semibold">{@titulo}</h1>
          </div>

          <div class="mt-4 space-y-1">{render_slot(@inner_block)}</div>

          <%!-- O caminho de volta em toda página: erro sem saída obriga quem lê a apagar a
                barra de endereço à mão. --%>
          <div class="mt-8 flex flex-wrap gap-2">
            <.link navigate={~p"/people"} class="btn btn-sm">People</.link>
            <.link navigate={~p"/work"} class="btn btn-ghost btn-sm">Work</.link>
          </div>
        </div>

        <%!-- `aria-hidden` porque as três são decorativas: quem usa leitor de tela recebe o
              título e as duas frases, que carregam a informação toda. --%>
        <div :if={@ilustracao != []} class="shrink-0 opacity-70 sm:mt-2" aria-hidden="true">
          {render_slot(@ilustracao)}
        </div>
      </div>
    </main>
    """
  end

  # ---------------------------------------------------------------- ilustrações

  # A pauta com uma lacuna — 404. As notas seguem e **uma falta**: é o desenho do caminho que
  # não existe, e não de algo quebrado.
  defp pauta_com_lacuna(assigns) do
    ~H"""
    <svg width="132" height="112" viewBox="0 0 132 112" fill="none">
      <g stroke="currentColor" stroke-width="1.25" opacity="0.35">
        <line x1="6" y1="34" x2="126" y2="34" />
        <line x1="6" y1="46" x2="126" y2="46" />
        <line x1="6" y1="58" x2="126" y2="58" />
        <line x1="6" y1="70" x2="126" y2="70" />
        <line x1="6" y1="82" x2="126" y2="82" />
      </g>

      <g stroke="currentColor" stroke-width="2" fill="currentColor">
        <ellipse cx="26" cy="70" rx="7.5" ry="5.5" />
        <line x1="33.5" y1="70" x2="33.5" y2="40" stroke-linecap="round" />
        <ellipse cx="54" cy="58" rx="7.5" ry="5.5" />
        <line x1="61.5" y1="58" x2="61.5" y2="28" stroke-linecap="round" />
      </g>

      <%!-- A nota que falta: tracejada e vazada. **Vazio desenhado** é diferente de espaço em
            branco — o segundo pareceria a pauta ter acabado ali. --%>
      <ellipse
        cx="90"
        cy="46"
        rx="7.5"
        ry="5.5"
        fill="none"
        stroke="currentColor"
        stroke-width="1.75"
        stroke-dasharray="3 3"
        opacity="0.55"
      />

      <g stroke="currentColor" stroke-width="2" fill="currentColor">
        <ellipse cx="116" cy="70" rx="7.5" ry="5.5" />
        <line x1="123.5" y1="70" x2="123.5" y2="40" stroke-linecap="round" />
      </g>
    </svg>
    """
  end

  # A porta de palco fechada — 403. **Fechada, não trancada com corrente**: falta de permissão
  # é estado, não acusação. E a placa é o que faz a porta ser de palco, e não de armário.
  defp porta_de_palco(assigns) do
    ~H"""
    <svg width="132" height="112" viewBox="0 0 132 112" fill="none">
      <rect
        x="30"
        y="14"
        width="72"
        height="88"
        rx="4"
        stroke="currentColor"
        stroke-width="1.5"
        opacity="0.45"
      />
      <line
        x1="66"
        y1="14"
        x2="66"
        y2="102"
        stroke="currentColor"
        stroke-width="1.5"
        opacity="0.45"
      />

      <g stroke="currentColor" stroke-width="1.75" stroke-linecap="round">
        <line x1="58" y1="58" x2="52" y2="58" />
        <line x1="74" y1="58" x2="80" y2="58" />
      </g>

      <rect
        x="46"
        y="30"
        width="40"
        height="14"
        rx="2"
        stroke="currentColor"
        stroke-width="1.25"
        opacity="0.5"
      />
      <g stroke="currentColor" stroke-width="1.5" opacity="0.6">
        <line x1="52" y1="37" x2="62" y2="37" />
        <line x1="66" y1="37" x2="80" y2="37" />
      </g>

      <line
        x1="10"
        y1="102"
        x2="122"
        y2="102"
        stroke="currentColor"
        stroke-width="1.25"
        opacity="0.3"
      />
    </svg>
    """
  end

  # A corda rompida — 500. Ela vinha inteira e **parou no meio**: é o desenho de algo que
  # estava funcionando, e não de algo que nunca funcionou.
  defp corda_rompida(assigns) do
    ~H"""
    <%!-- Maior que as outras duas (180 contra 132), e o motivo é legibilidade e não ênfase:
          medido nas capturas, em 132px as pontas enroladas viravam um borrão, e é justamente
          nelas que o desenho diz "arrebentou" em vez de "linha cortada". Engrossar o traço
          resolveria o borrão e desequilibraria as três. --%>
    <svg width="180" height="112" viewBox="0 0 132 112" fill="none">
      <g stroke="currentColor" stroke-width="1.25" opacity="0.3">
        <line x1="10" y1="22" x2="122" y2="22" />
        <line x1="10" y1="90" x2="122" y2="90" />
      </g>

      <%!-- As duas cordas inteiras existem para o desenho dizer "uma corda arrebentou", e não
            "instrumento quebrado". Sem elas, a rompida pareceria a única. --%>
      <g stroke="currentColor" stroke-width="1.5" opacity="0.4">
        <line x1="14" y1="40" x2="118" y2="40" />
        <line x1="14" y1="72" x2="118" y2="72" />
      </g>

      <g stroke="currentColor" stroke-width="2.25" stroke-linecap="round">
        <path d="M14 56 H52" />
        <%!-- As pontas enrolam para dentro: é o que corda de aço faz ao arrebentar, e é o
              detalhe que faz o desenho ser lido como ruptura e não como linha cortada. --%>
        <path d="M52 56 c 6 0 8 -6 3 -8 c -4 -1.5 -6 3 -2 4" />
        <path d="M118 56 H80" />
        <path d="M80 56 c -6 0 -8 6 -3 8 c 4 1.5 6 -3 2 -4" />
      </g>

      <g fill="currentColor" opacity="0.45">
        <circle cx="14" cy="40" r="2" />
        <circle cx="14" cy="56" r="2" />
        <circle cx="14" cy="72" r="2" />
      </g>
    </svg>
    """
  end

  # ---------------------------------------------------------------------- apoio

  # **A página de erro não pode depender de `conn`.** O endpoint sempre o passa, mas
  # `render_to_string` não — e uma página cujo trabalho é funcionar quando algo quebrou não
  # pode quebrar por assign faltando. Era o que o moduledoc prometia e o código não cumpria:
  # dois testes gerados pelo Phoenix pegaram.
  #
  # Sem caminho, o 404 diz "this address" em vez de citar qual: menos informação, e nunca
  # exceção.
  defp normalizar(assigns) do
    conn = Map.get(assigns, :conn)
    caminho = if is_struct(conn, Plug.Conn), do: conn.request_path

    Map.merge(assigns, %{
      caminho: caminho || "this address",
      sugestao: sugestao(caminho),
      referencia: identificador(conn)
    })
  end

  defp sugestao(caminho) when is_binary(caminho) do
    Enum.find_value(@caminhos_parecidos, fn {errado, certo} ->
      # Prefixo seguido de `/` ou fim: `/works` casa, `/workspace` não. Sem essa checagem a
      # sugestão apareceria para caminho que só começa parecido.
      if caminho == errado or String.starts_with?(caminho, errado <> "/") do
        certo <> String.trim_leading(caminho, errado)
      end
    end)
  end

  defp sugestao(_), do: nil

  # O `x-request-id` que o Phoenix já põe em toda resposta. É o que liga a tela ao log.
  defp identificador(%Plug.Conn{} = conn) do
    case Plug.Conn.get_resp_header(conn, "x-request-id") do
      [id | _] -> id
      _ -> nil
    end
  end

  defp identificador(_), do: nil

  defp codigo_do_template(template) do
    template |> Path.rootname() |> to_string()
  end

  defp mensagem(template), do: Controller.status_message_from_template(template)
end
