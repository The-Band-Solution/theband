defmodule TheBand.Repo do
  use Ecto.Repo,
    otp_app: :the_band,
    adapter: Ecto.Adapters.Postgres
end
