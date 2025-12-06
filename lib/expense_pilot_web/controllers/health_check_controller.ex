defmodule ExpensePilotWeb.HealthCheckController do
  use ExpensePilotWeb, :controller

  def index(conn, _params) do
    # Check database connection
    db_status = case ExpensePilot.Repo.query("SELECT 1") do
      {:ok, _} -> "ok"
      {:error, reason} -> "error: #{inspect(reason)}"
    end

    # Check dependencies

    status = %{
      status: "ok",
      services: %{
        database: db_status
      },
      timestamp: DateTime.utc_now(),
      version: Application.spec(:expense_pilot, :vsn)
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(status))
  end
end
