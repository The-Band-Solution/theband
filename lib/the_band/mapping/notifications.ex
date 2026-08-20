defmodule TheBand.Mapping.Notifications do
  @moduledoc """
  O canal por onde o recálculo de promoção avisa a tela que terminou.

  ## Por que um tópico próprio, e não o da sincronização

  A tela de sincronização já assina `Ingestion.subscribe/1`, e seria mais curto emitir por
  ali. Mas recalcular promoção **não é coletar**: um tópico serve para o assinante decidir
  o que quer ouvir, e juntar os dois obrigaria toda tela interessada em progresso de coleta
  a receber também eventos de transformação.

  ## Por que ele existe, e o que a ausência dele custava

  `Commands.create_rule/4` enfileira o recálculo, e o comentário do enfileiramento já
  dizia o motivo: *"gravar regra sem recalcular deixaria a tela mostrar a regra e o dado
  antigo — e quem lesse concluiria que a regra não funciona"*.

  O recálculo é assíncrono, então a tela recarrega **antes** de ele acontecer. O aviso é o
  que fecha o ciclo. Sem ele o sintoma é exatamente o que o comentário descreve, só mais
  tarde: a regra aparece e o número não muda.

  O job emitia em `"tenant:<id>"`, tópico que **ninguém assinava** — e o `handle_info`
  genérico da tela engolia a mensagem sem sinal. Emitir para tópico sem assinante é o
  mesmo que não emitir, com a agravante de parecer resolvido no código.
  """

  alias TheBand.Tenants.Tenant

  @topic "mapping"

  @doc "Assina os avisos de recálculo de promoção de um tenant."
  @spec subscribe(Tenant.t()) :: :ok | {:error, term()}
  def subscribe(%Tenant{id: tenant_id}),
    do: Phoenix.PubSub.subscribe(TheBand.PubSub, topico(tenant_id))

  @spec broadcast(Ecto.UUID.t(), term()) :: :ok
  def broadcast(tenant_id, message),
    do: Phoenix.PubSub.broadcast(TheBand.PubSub, topico(tenant_id), message)

  defp topico(tenant_id), do: @topic <> ":" <> tenant_id
end
