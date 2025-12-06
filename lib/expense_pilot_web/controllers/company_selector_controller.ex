defmodule ExpensePilotWeb.CompanySelectorController do
  use ExpensePilotWeb, :controller
  
  alias ExpensePilot.Companies
  alias ExpensePilot.Accounts.User
  
  def index(conn, _params) do
    user = conn.assigns.current_user
    companies = Companies.list_companies()
    render(conn, :index, companies: companies, user: user)
  end
  
  def select(conn, %{"company_id" => company_id}) do
    user = conn.assigns.current_user
    
    if User.is_superadmin?(user) do
      conn
      |> put_session(:selected_company_id, company_id)
      |> redirect(to: "/")
    else
      conn
      |> put_flash(:error, "Only superadmins can select companies")
      |> redirect(to: "/")
    end
  end
end 