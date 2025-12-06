defmodule ExpensePilotWeb.Plugs.EnsureAdmin do
  import Plug.Conn
  import Phoenix.Controller
  alias ExpensePilot.Accounts.User
  use ExpensePilotWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    
    if user && User.is_superadmin?(user) do
      conn
    else
      conn
      |> put_flash(:error, "Administrative access required.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end
end 