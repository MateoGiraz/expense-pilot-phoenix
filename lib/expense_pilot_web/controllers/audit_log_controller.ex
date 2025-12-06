defmodule ExpensePilotWeb.AuditLogController do
  use ExpensePilotWeb, :controller

  alias ExpensePilot.AuditClient
  alias ExpensePilot.Accounts.User

  def index(conn, params) do
    current_user = conn.assigns.current_user
    
    # Only superadmins and admins can view audit logs
    if current_user.role not in ["admin", "superadmin"] do
      conn
      |> put_flash(:error, "You don't have permission to view audit logs.")
      |> redirect(to: ~p"/")
    else
      company_id = get_company_id(conn, current_user)
      
      # Build filters from params
      filters = build_filters(params)
      
      case AuditClient.get_audit_logs(company_id, filters) do
        {:ok, data} ->
          audit_logs = data["audit_logs"] || []
          total_count = data["total_count"] || 0
          
          render(conn, :index, 
            audit_logs: audit_logs,
            total_count: total_count,
            filters: filters,
            current_user: current_user
          )
        
        {:error, _reason} ->
          conn
          |> put_flash(:error, "Failed to load audit logs.")
          |> render(:index, 
            audit_logs: [],
            total_count: 0,
            filters: filters,
            current_user: current_user
          )
      end
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    
    # Only superadmins and admins can view audit logs
    if current_user.role not in ["admin", "superadmin"] do
      conn
      |> put_flash(:error, "You don't have permission to view audit logs.")
      |> redirect(to: ~p"/")
    else
      # For individual audit log viewing, we would need to add a show endpoint to the audit service
      # For now, redirect to index
      conn
      |> redirect(to: ~p"/admin/audit-logs")
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

  # Build filters from request parameters
  defp build_filters(params) do
    %{}
    |> maybe_add_filter("start_date", params["start_date"])
    |> maybe_add_filter("end_date", params["end_date"])
    |> maybe_add_filter("user_email", params["user_email"])
    |> maybe_add_filter("audit_action", params["audit_action"])
    |> maybe_add_filter("resource_type", params["resource_type"])
    |> maybe_add_filter("page", params["page"])
    |> maybe_add_filter("per_page", params["per_page"])
  end

  defp maybe_add_filter(filters, _key, value) when value in [nil, ""], do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)
end
