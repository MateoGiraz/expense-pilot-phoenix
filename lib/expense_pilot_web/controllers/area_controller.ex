defmodule ExpensePilotWeb.AreaController do
  use ExpensePilotWeb, :controller

  alias ExpensePilot.Areas
  alias ExpensePilot.Areas.Area
  alias ExpensePilot.Accounts.User
  alias ExpensePilot.AuditClient

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    current_company = conn.assigns[:current_company]
    
    company_id = if current_company, do: current_company.id, else: current_user.company_id

    if is_nil(company_id) do
      conn
      |> put_flash(:error, "No company associated with your account. Please contact support.")
      |> redirect(to: ~p"/")
    else
      areas = Areas.list_areas(company_id)
      render(conn, :index, areas: areas)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_company = conn.assigns[:current_company]
    
    company_id = if current_company, do: current_company.id, else: current_user.company_id

    if is_nil(company_id) do
      conn
      |> put_flash(:error, "No company associated with your account. Please contact support.")
      |> redirect(to: ~p"/areas")
    else
      area = Areas.get_area!(id, company_id)
      render(conn, :show, area: area)
    end
  end

  def new(conn, _params) do
    current_user = conn.assigns.current_user
    
    if User.is_superadmin?(current_user) do
      changeset = Areas.change_area(%Area{})
      render(conn, :new, changeset: changeset)
    else
      conn
      |> put_flash(:error, "You don't have permission to create areas.")
      |> redirect(to: ~p"/areas")
    end
  end

  def create(conn, %{"area" => area_params}) do
    current_user = conn.assigns.current_user
    current_company = conn.assigns[:current_company]
    
    if User.is_superadmin?(current_user) do
      company_id = if current_company, do: current_company.id, else: current_user.company_id
      
      if is_nil(company_id) do
        conn
        |> put_flash(:error, "No company associated with your account. Please contact support.")
        |> redirect(to: ~p"/areas")
      else
        area_params = Map.put(area_params, "company_id", company_id)
        
        case Areas.create_area(area_params) do
          {:ok, area} ->
            # Log audit
            AuditClient.log_action(
              "create",
              "Area",
              area.id,
              current_user,
              company_id,
              %{
                name: area.name,
                description: area.description
              }
            )
            
            conn
            |> put_flash(:info, "Area created successfully.")
            |> redirect(to: ~p"/areas/#{area}")

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, :new, changeset: changeset)
        end
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to create areas.")
      |> redirect(to: ~p"/areas")
    end
  end

  def edit(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_company = conn.assigns[:current_company]
    
    if User.is_superadmin?(current_user) do
      company_id = if current_company, do: current_company.id, else: current_user.company_id

      if is_nil(company_id) do
        conn
        |> put_flash(:error, "No company associated with your account. Please contact support.")
        |> redirect(to: ~p"/areas")
      else
        area = Areas.get_area!(id, company_id)
        changeset = Areas.change_area(area)
        render(conn, :edit, area: area, changeset: changeset)
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to edit areas.")
      |> redirect(to: ~p"/areas")
    end
  end

  def update(conn, %{"id" => id, "area" => area_params}) do
    current_user = conn.assigns.current_user
    current_company = conn.assigns[:current_company]
    
    if User.is_superadmin?(current_user) do
      company_id = if current_company, do: current_company.id, else: current_user.company_id

      if is_nil(company_id) do
        conn
        |> put_flash(:error, "No company associated with your account. Please contact support.")
        |> redirect(to: ~p"/areas")
      else
        area = Areas.get_area!(id, company_id)

        case Areas.update_area(area, area_params) do
          {:ok, updated_area} ->
            # Log audit
            AuditClient.log_action(
              "update",
              "Area",
              updated_area.id,
              current_user,
              company_id,
              %{
                old_data: %{
                  name: area.name,
                  description: area.description
                },
                new_data: %{
                  name: updated_area.name,
                  description: updated_area.description
                }
              }
            )
            
            conn
            |> put_flash(:info, "Area updated successfully.")
            |> redirect(to: ~p"/areas/#{updated_area}")

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, :edit, area: area, changeset: changeset)
        end
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to update areas.")
      |> redirect(to: ~p"/areas")
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    current_company = conn.assigns[:current_company]
    
    if User.is_superadmin?(current_user) do
      company_id = if current_company, do: current_company.id, else: current_user.company_id

      if is_nil(company_id) do
        conn
        |> put_flash(:error, "No company associated with your account. Please contact support.")
        |> redirect(to: ~p"/areas")
      else
        area = Areas.get_area!(id, company_id)

        case Areas.delete_area(area) do
          {:ok, _area} ->
            # Log audit
            AuditClient.log_action(
              "delete",
              "Area",
              area.id,
              current_user,
              company_id,
              %{
                name: area.name,
                description: area.description
              }
            )
            
            conn
            |> put_flash(:info, "Area deleted successfully.")
            |> redirect(to: ~p"/areas")

          {:error, %Ecto.ConstraintError{}} ->
            conn
            |> put_flash(:error, "Cannot delete the area because it has associated users. Please reassign users to other areas first.")
            |> redirect(to: ~p"/areas/#{area}")

          {:error, _changeset} ->
            conn
            |> put_flash(:error, "Error deleting the area.")
            |> redirect(to: ~p"/areas/#{area}")
        end
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to delete areas.")
      |> redirect(to: ~p"/areas")
    end
  end
end 