defmodule ExpensePilotWeb.Plugs.EnsureCompanySelected do
  import Plug.Conn
  import Phoenix.Controller
  alias ExpensePilot.Accounts.User
  alias ExpensePilot.Accounts
  use ExpensePilotWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns.current_user
    
    if User.is_superadmin?(user) do
      # Permitir acceso a rutas específicas sin selección de compañía
      is_exempt_route = is_companies_route?(conn) || is_company_selector_route?(conn)
      
      if is_exempt_route do
        conn
      else
        case get_session(conn, :selected_company_id) do
          nil ->
            conn
            |> put_flash(:error, "Please select a company first")
            |> redirect(to: ~p"/company-selector")
            |> halt()
          company_id ->
            case Accounts.get_selected_company(company_id) do
              nil ->
                conn
                |> put_flash(:error, "Selected company not found")
                |> redirect(to: ~p"/company-selector")
                |> halt()
              company ->
                conn
                |> assign(:current_company_id, company_id)
                |> assign(:current_company, company)
            end
        end
      end
    else
      # Para non-superadmins, company is already set via their user record
      company = ExpensePilot.Repo.preload(user, :company).company
      conn
      |> assign(:current_company_id, company.id)
      |> assign(:current_company, company)
    end
  end

  # Helpers para verificar rutas específicas
  defp is_companies_route?(%{path_info: path_info}) do
    path_info
    |> Enum.take(2)
    |> Enum.join("/")
    |> Kernel.==("admin/companies")
  end

  defp is_company_selector_route?(%{path_info: path_info}) do
    path_info
    |> Enum.take(1)
    |> Enum.join("/")
    |> Kernel.==("company-selector")
  end
end 