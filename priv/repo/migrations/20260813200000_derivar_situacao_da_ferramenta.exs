defmodule TheBand.Repo.Migrations.DerivarSituacaoDaFerramenta do
  @moduledoc """
  `connected_tools.status` sai — issue #178.

  ## Por que ela existia, e por que sai

  A ADR 0004 D7: situação é derivável dos instantes dos eventos e **não** se materializa, porque
  persistir cria um terceiro lugar guardando o mesmo fato.

  E ele discordava dos outros dois. Medido em 2026-08-13: `ifesserra-lab` tem cinco eventos de
  observação, o último `ended`, e a coluna dizia `active`. `end_observation/3` grava o evento,
  destrói as credenciais e marca a organização — e nunca tocou nela.

  A tela não chegou a mentir, porque já derivava o encerramento por `observation_ended?/1` e só lia
  a coluna no resto. **A coluna era uma armadilha esperando alguém confiar nela.**

  ## O que sobrevive, e é o que importa

  `needs_attention_since` e `needs_attention_reason` **ficam**: são fato datado — quando se notou, e
  por quê —, não situação. A situação sai deles, em `Sources.situacao/1`.

  ## A volta

  `down` recria a coluna e a repovoa **do mesmo jeito derivado**, para que reverter não devolva o
  desacordo: quem tem evento `ended` volta como `disabled`, quem tem `needs_attention_since` volta
  como `needs_attention`, o resto como `active`.
  """
  use Ecto.Migration

  def up do
    alter table(:connected_tools) do
      remove :status
    end
  end

  def down do
    alter table(:connected_tools) do
      add :status, :string, null: false, default: "active"
    end

    execute("""
    UPDATE connected_tools t SET status =
      CASE
        WHEN (SELECT e.event FROM tool_observation_events e
               WHERE e.connected_tool_id = t.id
               ORDER BY e.occurred_at DESC, e.inserted_at DESC LIMIT 1) = 'ended' THEN 'disabled'
        WHEN t.needs_attention_since IS NOT NULL THEN 'needs_attention'
        ELSE 'active'
      END
    """)
  end
end
