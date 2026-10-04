defmodule TheBandWeb.SessionController do
  @moduledoc """
  Entrada, saída e a definição forçada de senha — feature 045 (US1).

  Desde a 064 (T013), cada entrada abre uma linha em `user_sessions`, e o cookie leva o id dela
  e o token bruto; o banco guarda só o resumo. Definir a senha sobe a época e encerra as sessões
  da conta, e por isso os dois POSTs de senha daqui abrem uma sessão nova para quem fica.
  Quem lê e escreve o cookie é `TheBandWeb.Sessao`.

  A recusa de login é UMA frase (FR-002), e o `{:throttled, _}` mostra a MESMA:
  distinguir daria ao ataque o relógio que a espera crescente existe para tirar.
  """

  use TheBandWeb, :controller

  alias TheBand.Tenants
  alias TheBand.Tenants.AccessEvents
  alias TheBand.Tenants.Sessions
  alias TheBandWeb.Sessao

  # A recusa única da 045 (FR-002 de lá): byte-idêntica entre identificador
  # inexistente, senha errada e conta sem senha — provada em login_test.exs por
  # Enum.uniq. Vive numa função (gettext é runtime; atributo congelaria a língua
  # na compilação) e num único ponto, para continuar única por construção.
  defp mensagem_unica, do: dgettext("errors", "Credenciais inválidas.")

  def create(conn, %{"identifier" => identificador, "password" => senha}) do
    # O CORRELATOR DA JORNADA — spec 074, T013 (FR-011; seguranca.md, S4 e S5).
    #
    # Lido **só da sessão**, nunca dos parâmetros: o cliente não escolhe com qual abertura a
    # tentativa se casa. E apagado **antes** de decidir, com qualquer desfecho: a sessão é
    # assinada e não cifrada, e uma chave apagada num motivo e mantida noutro diria ao cliente
    # qual dos dois aconteceu.
    jornada_id = get_session(conn, :jornada_id)
    conn = delete_session(conn, :jornada_id)

    case Tenants.authenticate(identificador, senha, jornada_id: jornada_id) do
      {:ok, user} ->
        destino = get_session(conn, :redirect_to) || ~p"/people"

        conn
        |> Sessao.abrir(user)
        |> delete_session(:redirect_to)
        |> redirect(to: if(user.must_change_password, do: ~p"/set-password", else: destino))

      {:error, _qualquer} ->
        conn |> put_flash(:error, mensagem_unica()) |> redirect(to: ~p"/sign-in")
    end
  end

  # SAIR ENCERRA NO SERVIDOR — 064, achado S5. Antes, sair só apagava o cookie local, e uma
  # cópia do cookie feita antes continuava valendo.
  #
  # SAIR DIZ SE ENCERROU ALGUMA COISA — spec 074, T016. `current_session` só existe se
  # `CurrentScope` conferiu a sessão aberta; sem ela, não havia o que encerrar, e a saída é uma
  # falha nomeada. Quando o cookie trazia uma sessão já encerrada, a mesma requisição produz dois
  # passos — `sessao_derrubada`, emitido por `CurrentScope`, e este —, e são dois fatos.
  # `Sessions.encerrar/1` não muda (contrato §8).
  def delete(conn, _params) do
    case conn.assigns[:current_session] do
      nil ->
        passo(:sair, :falhou, :sessao_ja_nao_existia, nil)

      sessao ->
        Sessions.encerrar(sessao)
        passo(:sair, :concluiu, nil, nil, sessao.tenant_id)
    end

    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/sign-in")
  end

  @doc """
  Troca de senha pela própria pessoa (FR-012/015) — no controller pelo mesmo
  motivo de `set_password/2`: o token gira, e a sessão que fica precisa dele.
  """
  def update_password(conn, %{"current" => atual, "password" => nova}) do
    user = conn.assigns.current_user

    # O MOTIVO VEM DO RAMO, e nunca do changeset — spec 074, T021; seguranca.md, S1. O changeset
    # carrega a senha nova em `changes`; lê-lo para nomear o motivo seria o caminho mais curto
    # para ela sair.
    case Tenants.change_password(user.tenant, user.id, atual, nova) do
      {:ok, atualizada} ->
        passo(:trocar_a_senha, :concluiu, nil, nil, user.tenant_id)

        conn
        |> Sessao.abrir(atualizada)
        |> put_flash(
          :info,
          dgettext("sistema", "Senha trocada. As outras sessões foram encerradas.")
        )
        |> redirect(to: ~p"/profile")

      {:error, :invalid_current} ->
        passo(:trocar_a_senha, :falhou, :senha_atual_nao_confere, user)

        conn
        |> put_flash(:error, dgettext("errors", "A senha atual não confere."))
        |> redirect(to: ~p"/profile")

      {:error, %Ecto.Changeset{}} ->
        passo(:trocar_a_senha, :falhou, :recusada_pela_regra, user)
        recusar_a_troca(conn)

      # A conta da sessão sumiu entre a conferência e a troca: inalcançável sem corrida, e sem
      # motivo declarado na taxonomia — por isso sem passo, e dito no contrato §2.
      {:error, :not_found} ->
        recusar_a_troca(conn)
    end
  end

  defp recusar_a_troca(conn) do
    conn
    |> put_flash(:error, dgettext("errors", "A senha precisa de pelo menos 12 caracteres."))
    |> redirect(to: ~p"/profile")
  end

  @doc """
  Primeira definição de senha (fluxo da temporária, FR-013).

  Vive num controller, e não em LiveView, porque `set_password` gira o token e a
  SESSÃO precisa receber o token novo — LiveView não escreve cookie de sessão.
  """
  def set_password(conn, %{"password" => senha, "password_confirmation" => confirmacao}) do
    # A MESMA CONFERÊNCIA DO RESTO DA PLATAFORMA — 064, achado S3. Aqui havia uma comparação
    # de campo própria, `user.session_token == get_session(...)`, que era uma segunda porta: sem
    # ela, `nil == nil` numa conta sem token deixaria definir a senha de outra pessoa com um
    # cookie velho. `current_user` só existe se o plug conferiu a sessão.
    with %{} = user <- conn.assigns[:current_user],
         # ESTA PORTA SERVE **SÓ** AO FLUXO DA TEMPORÁRIA — achado H1, 2026-09-09.
         #
         # Sem esta cláusula, quem alcança uma sessão válida por alguns minutos — o
         # navegador esquecido aberto, a máquina compartilhada, o cookie capturado —
         # trocava a senha **sem apresentar a antiga em momento nenhum**, e o giro do
         # `session_token` derrubava a pessoa legítima. Acesso temporário virava posse
         # permanente da conta.
         #
         # A guarda de `/profile/password` já exigia a senha atual, e estava certa. O
         # defeito era haver uma SEGUNDA porta sem ela — o antipadrão que este
         # repositório persegue nos próprios dados, dentro de casa.
         #
         # A conta em regime normal cai no `else` que já existia: sessão derrubada e
         # `/sign-in`. Derrubar, e não redirecionar para `/profile` com uma frase, é a
         # escolha segura — quem chegou aqui com sessão de outra pessoa não deve ganhar
         # uma dica do que tentar em seguida. Se o gentil for preferido, é decisão de
         # produto, e está registrada no achado.
         true <- user.must_change_password do
      if senha == confirmacao do
        aplicar_definicao(conn, user, senha)
      else
        passo(:definir_a_senha, :falhou, :confirmacao_diferente, user)

        conn
        |> put_flash(:error, dgettext("errors", "A confirmação não confere com a senha."))
        |> redirect(to: ~p"/set-password")
      end
    else
      # Sem sessão, ou conta em regime normal na rota da temporária (H1): fora do fluxo. A conta
      # vai no passo quando é conhecida — uma sessão válida tentando esta porta é o sinal do H1.
      _ ->
        passo(:definir_a_senha, :falhou, :fora_do_fluxo, conn.assigns[:current_user])
        conn |> configure_session(drop: true) |> redirect(to: ~p"/sign-in")
    end
  end

  # O motivo vem do ramo, e nunca do changeset — ver `update_password/2`.
  defp aplicar_definicao(conn, user, senha) do
    case Tenants.set_password(user.tenant, user.id, senha) do
      {:ok, atualizada} ->
        passo(:definir_a_senha, :concluiu, nil, nil, user.tenant_id)

        conn
        |> Sessao.abrir(atualizada)
        |> put_flash(:info, dgettext("sistema", "Senha definida."))
        |> redirect(to: ~p"/people")

      {:error, erro} ->
        if match?(%Ecto.Changeset{}, erro),
          do: passo(:definir_a_senha, :falhou, :recusada_pela_regra, user)

        conn
        |> put_flash(:error, dgettext("errors", "A senha precisa de pelo menos 12 caracteres."))
        |> redirect(to: ~p"/set-password")
    end
  end

  # O passo de jornada — spec 074, contracts/jornada.md §2. A conta entra como id, e só nos
  # desfechos que pedem ação (FR-004, D1): `passo/4` recebe a conta da recusa; `passo/5`, o
  # concluído, recebe só a organização.
  defp passo(passo, desfecho, motivo, conta),
    do: passo(passo, desfecho, motivo, conta && conta.id, conta && conta.tenant_id)

  defp passo(passo, desfecho, motivo, user_id, tenant_id) do
    AccessEvents.passo(%{
      passo: passo,
      desfecho: desfecho,
      motivo: motivo,
      tenant_id: tenant_id,
      user_id: user_id
    })
  end
end
