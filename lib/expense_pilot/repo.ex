defmodule ExpensePilot.Repo do
  use Ecto.Repo,
    otp_app: :expense_pilot,
    adapter: Ecto.Adapters.Postgres
end
