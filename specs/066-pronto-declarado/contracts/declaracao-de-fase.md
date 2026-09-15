# Contrato — a declaração de fase por opção

Escrito **antes** da implementação (princípio IV e a regra da casa).

## Comandos

```elixir
@spec declare_item_phase(Tenant.t(), map(), Ecto.UUID.t()) ::
        {:ok, PhaseDeclaration.t()} | {:error, Ecto.Changeset.t() | recusa()}
# attrs: observed_project_id, field_external_id, option_external_id,
#        option_name_at_declaration, target_concept
# recusa(): :conceito_nao_admitido | :quadro_nao_encontrado | :opcao_nao_observada
# Declarar sobre uma opção que já tem declaração vigente REVOGA a anterior e cria a nova,
# na mesma transação — a tela chama isso de "Replace", como o critério de início.

@spec revoke_item_phase(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
        {:ok, PhaseDeclaration.t()} | {:error, :nao_encontrada | Ecto.Changeset.t()}
```

## Consultas

```elixir
@spec phase_declarations_for(Tenant.t(), Ecto.UUID.t()) :: [PhaseDeclaration.t()]
# As VIGENTES do quadro. Ordem: a das opções no campo.

@spec revoked_phase_declarations_for(Tenant.t(), Ecto.UUID.t()) :: [PhaseDeclaration.t()]
# As revogadas — a tela mostra a anterior sob a ativa (D4 do protótipo).

@spec status_vocabulary(Tenant.t(), Ecto.UUID.t()) :: [vocabulo()]
# vocabulo(): %{field_external_id, field_name, option_external_id, option_name, position,
#               itens: n, abertas: n, fechadas: n,
#               declaracao: PhaseDeclaration.t() | nil,
#               proposta: String.t() | nil}
# TODA opção observada do campo, na ordem observada, com a contagem de hoje.
# `proposta` só quando não há declaração vigente E o nome casa o vocabulário reconhecido.

@spec phase_of_items(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => [afirmacao()]}
# afirmacao(): %{quadro_id, quadro_title, estagio, fase}
# Uma por quadro em que o item está. UMA consulta para qualquer número de itens.

@spec board_disagreement(Tenant.t(), Ecto.UUID.t()) ::
        %{concluidas_abertas: n, fechadas_nao_concluidas: n} | :nao_declarado
```

## O que NENHUMA função faz

- **não grava fase no item** — a resolução é na leitura;
- **não soma** as duas afirmações, nem devolve um "estado" único;
- **não propõe destino** que não esteja na regra declarada;
- **não devolve zero** onde a resposta é *não declarado* — devolve `nil` ou `:nao_declarado`,
  e a tela escreve.
