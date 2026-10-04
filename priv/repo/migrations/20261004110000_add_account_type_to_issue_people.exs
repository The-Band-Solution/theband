defmodule TheBand.Repo.Migrations.AddAccountTypeToIssuePeople do
  @moduledoc """
  O tipo da conta de quem abriu a issue e de cada responsável, gravado na coleta — feature 076,
  T021 (`specs/076-analise-de-rede/data-model.md` §3; research.md R13; A3 da revisão semântica 2).

  ## Por que gravar

  A coleta já recebe `author.__typename` e `assignees.nodes.__typename` (`issues.graphql`), mas
  guardava só o login. Sem o tipo, a conta de máquina cujo login vem **sem** o sufixo `[bot]`
  cairia em `unlinked_person` e não em `bot_or_app` na rede de designação: medido em
  desenvolvimento em 2026-10-04, 3 issues de autor não ligado nessa situação (R13).

  ## As restrições

  - **anuláveis**: a linha coletada antes desta migração não tem o tipo, e nulo é *"não se sabe"*,
    nunca *"pessoa"*. A T022 preenche o que o payload bruto permite; o resto fica nulo e é contado
    (`provenance.account_type_unknown`);
  - **`check` em `('person', 'bot', 'app')`**: os três valores de `Mapper.account_type/1`. Valor
    novo entra por migração, nunca por digitação (estado como string livre, §7.7).

  Aditiva: o rollback tira as duas colunas e as duas restrições.
  """
  use Ecto.Migration

  def change do
    alter table(:collected_issues) do
      add :author_account_type, :text
    end

    alter table(:issue_assignees) do
      add :account_type, :text
    end

    create constraint(:collected_issues, :collected_issues_author_account_type_allowed,
             check:
               "author_account_type is null or author_account_type in ('person', 'bot', 'app')"
           )

    create constraint(:issue_assignees, :issue_assignees_account_type_allowed,
             check: "account_type is null or account_type in ('person', 'bot', 'app')"
           )
  end
end
