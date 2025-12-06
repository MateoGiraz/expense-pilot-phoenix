defmodule ExpensePilotWeb.Plugs.EnsureAuthentication do
  import Plug.Conn
  import Phoenix.Controller
  use ExpensePilotWeb, :verified_routes
  require Logger

  alias ExpensePilot.Accounts.Guardian
  alias ExpensePilot.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip authentication for the login page to avoid redirect loops
    if conn.request_path == "/login" do
      conn
    else
      with %{"guardian_default_token" => token} <- get_session(conn),
           {:ok, claims} <- Guardian.decode_and_verify(token),
           {:ok, user} when not is_nil(user) <- Guardian.resource_from_claims(claims) do

        # Check if we have updated user data in session (from auth service)
        case get_session(conn, :auth_token) do
          nil ->
            # No auth token, use database user as before
            assign(conn, :current_user, user)
          _auth_token ->
            # We have an auth token, check if user data was updated in session
            case get_session(conn, :updated_user_data) do
              nil ->
                # No updated data in session, use database user
                assign(conn, :current_user, user)
              %{email: email, role: role} = updated_data ->
                # Use updated data from session (auth service data)
                Logger.info("Using updated user data from session: #{inspect(updated_data)}")
                updated_user = %{user | email: email, role: role}
                assign(conn, :current_user, updated_user)
              _ ->
                # Invalid updated data format, use database user
                Logger.warn("Invalid updated_user_data format in session, using database user")
                assign(conn, :current_user, user)
            end
        end
      else
        {:ok, nil} ->
          Logger.warn("Guardian returned nil user, clearing session and redirecting to login")
          conn
          |> clear_session()
          |> put_flash(:error, "Your session has expired. Please log in again.")
          |> redirect(to: ~p"/login")
          |> halt()
        {:error, :token_expired} ->
          Logger.warn("Guardian token expired, clearing session and redirecting to login")
          conn
          |> clear_session()
          |> put_flash(:error, "Your session has expired. Please log in again.")
          |> redirect(to: ~p"/login")
          |> halt()
        _ ->
          Logger.warn("Authentication failed, clearing session and redirecting to login")
          conn
          |> clear_session()
          |> put_flash(:error, "Your session has expired. Please log in again.")
          |> redirect(to: ~p"/login")
          |> halt()
      end
    end
  end
end
