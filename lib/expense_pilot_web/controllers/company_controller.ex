defmodule ExpensePilotWeb.CompanyController do
  use ExpensePilotWeb, :controller
  alias ExpensePilot.Companies
  alias ExpensePilot.Companies.Company
  alias ExpensePilot.Accounts.User
  alias ExpensePilot.AuditClient

  def index(conn, _params) do
    companies = Companies.list_companies()
    render(conn, :index, companies: companies)
  end

  def new(conn, _params) do
    changeset = Companies.change_company(%Company{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"company" => company_params}) do
    current_user = conn.assigns.current_user
    
    case Companies.create_company(company_params) do
      {:ok, company} ->
        # Log audit
        AuditClient.log_action(
          "create",
          "Company",
          company.id,
          current_user,
          company.id,
          %{
            name: company.name,
            address: company.address,
            website: company.website
          }
        )
        
        conn
        |> put_flash(:info, "Company created successfully.")
        |> redirect(to: ~p"/admin/companies/#{company}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    # Para superadmins, redirigir a la selección de compañía después de ver los detalles
    redirect_to_selector = User.is_superadmin?(current_user) &&
                           !conn.assigns[:current_company] &&
                           !is_a_companies_action?(conn)

    company = Companies.get_company_with_assocs(id, [users: :area])

    conn
    |> maybe_redirect_to_selector(redirect_to_selector)
    |> render_if_not_redirected(:show, company: company)
  end

  def edit(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    # Para superadmins, redirigir a la selección de compañía después de editar
    redirect_to_selector = User.is_superadmin?(current_user) &&
                           !conn.assigns[:current_company] &&
                           !is_a_companies_action?(conn)

    company = Companies.get_company!(id)
    changeset = Companies.change_company(company)

    conn
    |> maybe_redirect_to_selector(redirect_to_selector)
    |> render_if_not_redirected(:edit, company: company, changeset: changeset)
  end

  def update(conn, %{"id" => id, "company" => company_params}) do
    current_user = conn.assigns.current_user

    # Para superadmins, redirigir a la selección de compañía después de actualizar
    redirect_to_selector = User.is_superadmin?(current_user) &&
                           !conn.assigns[:current_company] &&
                           !is_a_companies_action?(conn)

    company = Companies.get_company!(id)

    case Companies.update_company(company, company_params) do
      {:ok, updated_company} ->
        # Log audit
        AuditClient.log_action(
          "update",
          "Company",
          updated_company.id,
          current_user,
          updated_company.id,
          %{
            old_data: %{
              name: company.name,
              address: company.address,
              website: company.website
            },
            new_data: %{
              name: updated_company.name,
              address: updated_company.address,
              website: updated_company.website
            }
          }
        )
        
        conn
        |> put_flash(:info, "Company updated successfully.")
        |> maybe_redirect_to_selector(redirect_to_selector)
        |> redirect_if_not_redirected(to: ~p"/admin/companies/#{updated_company}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, company: company, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    company = Companies.get_company!(id)

    case Companies.delete_company(company) do
      {:ok, _company} ->
        # Log audit
        AuditClient.log_action(
          "delete",
          "Company",
          company.id,
          current_user,
          company.id,
          %{
            name: company.name,
            address: company.address,
            website: company.website
          }
        )
        
        conn
        |> put_flash(:info, "Company deleted successfully.")
        |> redirect(to: ~p"/admin/companies")

      {:error, %Ecto.ConstraintError{}} ->
        conn
        |> put_flash(:error, "Cannot delete the company because it has associated users. Please delete all users from this company first.")
        |> redirect(to: ~p"/admin/companies/#{company}")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Error deleting the company.")
        |> redirect(to: ~p"/admin/companies/#{company}")
    end
  end

  # Helpers para manejar redirecciones condicionales
  defp maybe_redirect_to_selector(conn, true) do
    conn
    |> put_flash(:info, "Please select a company to continue")
    |> redirect(to: ~p"/company-selector")
  end
  defp maybe_redirect_to_selector(conn, false), do: conn

  defp render_if_not_redirected(%{status: 302} = conn, _template, _assigns), do: conn
  defp render_if_not_redirected(conn, template, assigns), do: render(conn, template, assigns)

  defp redirect_if_not_redirected(%{status: 302} = conn, _opts), do: conn
  defp redirect_if_not_redirected(conn, opts), do: redirect(conn, opts)

  defp is_a_companies_action?(conn) do
    conn.path_info
    |> Enum.take(2)
    |> Enum.join("/")
    |> Kernel.==("admin/companies")
  end
end
