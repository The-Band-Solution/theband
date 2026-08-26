defmodule TheBand.Repo.Migrations.VersaoDaConsultaPorRepositorio do
  @moduledoc """
  Registra **com qual versão da consulta** cada repositório foi percorrido — issue #452.

  ## O que o corte incremental não sabia

  `changes_collected_at` responde *"já coletei este registro"*. Quando a consulta ganha um
  campo, a pergunta passa a ser outra: *"já coletei este registro **com esta consulta**"*.

  As duas coincidem até alguém acrescentar campo. A feature 041 acrescentou
  `statusCheckRollup`, e duas semanas depois havia **763 solicitações integradas em 10
  repositórios** sem o campo — 100% em cada um dos dez. Repositório inteiro sem o campo é
  repositório não tocado desde que o campo existe.

  E não deu erro nenhum: a tela dizia "não dá para saber" para dado que a origem responde.

  ## Um mapa, e não uma coluna por fase

  `%{"changes" => 2, "comments" => 1}`. Seis fases já têm corte, e uma coluna por fase
  significaria migração a cada fase nova — o que faria a próxima nascer sem versão, que é
  o defeito de novo.

  ## Vazio significa "nunca percorrido com versão registrada"

  E não versão zero. O repositório coletado antes desta migração tem mapa vazio, e a
  primeira passagem de cada fase o preenche. É por isso que o padrão é `{}` e não um mapa
  com as fases em 1: afirmar versão 1 para quem foi coletado com a versão 2 seria inventar
  o passado ao contrário.
  """
  use Ecto.Migration

  def change do
    alter table(:observed_repositories) do
      add :query_versions, :map, null: false, default: %{}
    end
  end
end
