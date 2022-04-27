defmodule BreakingCues.Repo do
  use Ecto.Repo,
    otp_app: :breaking_cues,
    adapter: Ecto.Adapters.Postgres
end
