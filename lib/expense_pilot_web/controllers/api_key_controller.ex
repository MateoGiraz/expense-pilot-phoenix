defmodule ExpensePilotWeb.ApiKeyController do
  use ExpensePilotWeb, :controller
  alias ExpensePilot.Api
  alias ExpensePilot.Api.ApiKey
  alias ExpensePilot.Accounts.User
  alias ExpensePilot.AuditClient

  def index(conn, _params) do
    case conn.assigns do
      %{current_user: current_user} ->
        api_keys = Api.list_api_keys(current_user.id)
        render(conn, :index, api_keys: api_keys)
      _ ->
        conn
        |> put_flash(:error, "You must be logged in to see your API keys.")
        |> redirect(to: "/login")
    end
  end

  @spec new(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def new(conn, _params) do
    case conn.assigns do
      %{current_user: _current_user} ->
        changeset = Api.change_api_key(%ApiKey{})
        render(conn, :new, changeset: changeset)
      _ ->
        conn
        |> put_flash(:error, "You must be logged in to create an API key.")
        |> redirect(to: "/login")
    end
  end

  def create(conn, %{"api_key" => api_key_params}) do
    case conn.assigns do
      %{current_user: current_user} ->
        # Obtener el company_id correcto según el rol del usuario
        company_id = if User.is_superadmin?(current_user) do
          case conn.assigns do
            %{current_company_id: id} when is_binary(id) -> String.to_integer(id)
            %{current_company_id: id} when is_integer(id) -> id
            _ -> raise "Company not selected for superadmin"
          end
        else
          current_user.company_id
        end

        api_key_params = api_key_params
        |> Map.put("user_id", current_user.id)
        |> Map.put("company_id", company_id)

        case Api.create_api_key(api_key_params) do
          {:ok, api_key} ->
            # Log audit
            AuditClient.log_action(
              "create",
              "ApiKey",
              api_key.id,
              current_user,
              company_id,
              %{
                name: api_key.name,
                key_prefix: String.slice(api_key.key, 0, 8) <> "..."  # Only log prefix for security
              }
            )
            
            conn
            |> put_flash(:info, "API key created successfully.")
            |> render(:created, api_key: api_key)

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, :new, changeset: changeset)
        end
      _ ->
        conn
        |> put_flash(:error, "You must be logged in to create an API key.")
        |> redirect(to: "/login")
    end
  end

  def delete(conn, %{"id" => id}) do
    case conn.assigns do
      %{current_user: current_user} ->
        api_key = Api.get_api_key(id)

        # Los superadmins pueden borrar cualquier API key de la compañía seleccionada
        can_delete = cond do
          User.is_superadmin?(current_user) &&
          get_company_id(conn, current_user) == api_key.company_id -> true
          api_key && api_key.user_id == current_user.id -> true
          true -> false
        end

        if can_delete do
          # Log audit before deletion
          AuditClient.log_action(
            "delete",
            "ApiKey",
            api_key.id,
            current_user,
            api_key.company_id,
            %{
              name: api_key.name,
              key_prefix: String.slice(api_key.key, 0, 8) <> "..."  # Only log prefix for security
            }
          )
          
          {:ok, _} = Api.delete_api_key(api_key)

          conn
          |> put_flash(:info, "API key deleted successfully.")
          |> redirect(to: ~p"/admin/api-keys")
        else
          conn
          |> put_flash(:error, "API key not found or does not belong to you.")
          |> redirect(to: ~p"/admin/api-keys")
        end
      _ ->
        conn
        |> put_flash(:error, "You must be logged in to delete an API key.")
        |> redirect(to: "/login")
    end
  end

  # Helper para obtener el company_id correcto
  defp get_company_id(conn, user) do
    if User.is_superadmin?(user) do
      case conn.assigns do
        %{current_company_id: id} when is_binary(id) -> String.to_integer(id)
        %{current_company_id: id} when is_integer(id) -> id
        _ -> raise "Company not selected for superadmin"
      end
    else
      user.company_id
    end
  end
end
