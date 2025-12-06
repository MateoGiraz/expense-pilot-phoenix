defmodule ExpensePilotWeb.Plugs.ApiAuth do
  import Plug.Conn
  alias ExpensePilot.Api

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_api_key(conn) do
      nil ->
        conn
        |> send_resp(401, "Unauthorized - Missing API Key")
        |> halt()
      api_key ->
        case Api.verify_api_key(api_key) do
          {:ok, company} ->
            assign(conn, :current_company, company)
          {:error, _} ->
            conn
            |> send_resp(401, "Unauthorized - Invalid API Key")
            |> halt()
        end
    end
  end

  defp get_api_key(conn) do
    # First check for the x-api-key header
    case get_req_header(conn, "x-api-key") do
      [api_key] -> api_key
      _ ->
        # Check for Authorization Bearer token
        case get_req_header(conn, "authorization") do
          ["Bearer " <> token] -> token
          _ -> nil
        end
    end
  end
end
