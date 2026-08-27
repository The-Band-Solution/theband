defmodule TheBand.Ontology.Continuum.SMPO do
  @moduledoc """
  SMPO — o planejamento macro do projeto. Fachada da ontologia.

  ## O que esta camada resolve

  A coleta promovia **todo** campo de iteração do Projects v2 a `sro.sprint`. Medido em
  2026-08-26, o par (quadro, campo) mostra que são coisas diferentes:

      DevOps                     Quarter      6 iterações   86 dias de média
      Conecta Fapes - Delivery   Quarter      6 iterações   86 dias
      Zeppelin                   Iteration    4 iterações   14 dias

  **669 vínculos de issue em 2.685 — 25% — apontavam para trimestre lido como sprint.**

  ## A plataforma não escolhe pelo nome

  `Quarter` parece trimestre. Classificar por padrão de nome publicaria a suposição como
  medida, e o erro cai para o lado barato: o não reconhecido alguém corrige, o reconhecido
  errado vira número. A organização declara; a tela mostra volume e duração média para a
  decisão ser informada, e **nada vem recomendado**.

  ## Resolve na leitura, nunca materializa

  O papel declarado decide como a MESMA linha de `sro_sprints` é lida. Nada é copiado para
  outra tabela, e por dois motivos:

  1. o mesmo argumento da feature 042 — o gravado abre uma janela em que ele discorda do
     declarado, e o papel é **revogável**;
  2. a declaração vale **imediatamente para o que já foi coletado**. As 27 iterações de
     trimestre já no banco deixam de ser sprint no instante da declaração, sem esperar
     recoleta e sem migração de dado.
  """

  alias TheBand.Ontology.Continuum.SMPO.FieldRoles
  alias TheBand.Ontology.Continuum.SMPO.Schemas.IterationFieldRole

  defdelegate declare_field_role(tenant, board_id, field_name, role, actor_id), to: FieldRoles
  defdelegate revoke_field_role(tenant, board_id, field_name, actor_id), to: FieldRoles
  defdelegate field_roles(tenant, board_id), to: FieldRoles
  defdelegate iteration_fields(tenant, board_id), to: FieldRoles
  defdelegate planning_horizons(tenant), to: FieldRoles
  defdelegate horizon_field?(tenant, board_id, field_name), to: FieldRoles
  defdelegate horizon_field_external_ids(tenant, board_id), to: FieldRoles

  @doc "Os papéis que a organização pode declarar. Uma lista só — a tela lê daqui."
  defdelegate papeis, to: IterationFieldRole
end
