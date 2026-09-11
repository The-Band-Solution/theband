defmodule TheBandWeb.VersionController do
  @moduledoc """
  `GET /version` — a versão que **esta instância** está servindo.

  ## Por que existe

  Em toda release desta base foi preciso escrever a mesma ressalva à mão: *o webhook do
  Dokploy respondeu `deployed successfully`, e isso **não prova** que o container subiu a
  versão publicada*. Não havia como medir — `/health`, `/version` e `/api/version` devolviam
  404, e a produção puxa a imagem por `latest`, que responde *"o que foi publicado por
  último"* e não *"o que está rodando"* (achado **H7**).

  Com esta rota, a CD pergunta e **falha** quando a resposta não é a versão do merge. É a
  diferença entre *entregou* e *entregou, e se conferiu*.

  ## Sem autenticação, e é decisão

  A versão do software **já é pública** por construção: está na tag git, no registro da
  release, no `mix.exs` do repositório e no nome da imagem publicada no GitHub Packages.
  Exigir sessão aqui esconderia de quem opera o que qualquer pessoa lê no repositório, e
  quebraria o único consumidor que a rota tem — a CD, que roda antes de haver sessão.

  **E não diz mais do que a versão.** Nada de ambiente, host, commit, dependências ou estado
  do banco: cada campo a mais seria superfície nova por conveniência de depuração, e a
  pergunta que originou a rota tem uma resposta só.

  ## Texto puro, e não JSON

  O consumidor compara uma string — `[ "$VERSAO" = "$ESPERADA" ]` num passo de shell. JSON
  obrigaria a CD a ter um parser para comparar sete caracteres, e a forma existe para ser
  comparada, não para crescer.
  """
  use TheBandWeb, :controller

  # Lida em COMPILAÇÃO, e não em tempo de execução.
  #
  # `Application.spec/2` leria a versão da aplicação carregada, que é a mesma coisa por outro
  # caminho — mas depende de a aplicação estar no ar para responder, e esta rota existe
  # justamente para ser perguntada a uma instância que acabou de subir. Constante de módulo é
  # gravada na imagem, e é o que faz a resposta ser sobre **este artefato**.
  @versao Mix.Project.config()[:version]

  @doc "A versão desta instância, em texto puro e sem quebra de linha."
  def show(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, @versao)
  end
end
