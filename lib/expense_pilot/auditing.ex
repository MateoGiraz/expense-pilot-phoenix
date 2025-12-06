defmodule ExpensePilot.Auditing do
  @moduledoc """
  The Auditing context.
  """

  alias ExpensePilot.Auditing.AuditClient
  require Logger

  def list_audit_logs(company_id, limit \\ 50, offset \\ 0) do
    Logger.info("Fetching audit logs from microservice for company_id: #{inspect(company_id)}")
    
    # Calculate page from offset and limit
    page = div(offset, limit) + 1
    
    case AuditClient.list_audit_logs(company_id, page, limit) do
      {:ok, data} ->
        # Transform the response to match the expected format
        logs = Map.get(data, "audit_logs", [])
        total_count = Map.get(data, "total_count", 0)
        
        # Transform the logs to have the expected structure
        transformed_logs = Enum.map(logs, &transform_audit_log/1)
        
        %{
          logs: transformed_logs,
          total_count: total_count,
          page_size: limit,
          page: page,
          total_pages: ceil(total_count / limit)
        }
      
      {:error, reason} ->
        Logger.info("Audit microservice unavailable: #{inspect(reason)}")
        # Return empty result as fallback
        %{
          logs: [],
          total_count: 0,
          page_size: limit,
          page: page,
          total_pages: 1
        }
    end
  end

  def get_audit_log!(id, _company_id) do
    Logger.info("Fetching audit log #{id} from microservice")
    
    case AuditClient.get_audit_log(id) do
      {:ok, data} ->
        transform_audit_log(data)
      
      {:error, "Audit log not found"} ->
        raise Ecto.NoResultsError, queryable: "audit_log"
      
      {:error, reason} ->
        Logger.info("Failed to fetch audit log from microservice: #{inspect(reason)}")
        raise "Failed to fetch audit log"
    end
  end

  def log_action(action, resource_type, resource_id, user, company_id, data \\ %{}) do
    Logger.info("Creating audit log via microservice")
    
    # Extract user_id and user_email from user struct or use provided values
    {user_id, user_email} = case user do
      %{id: id, email: email} -> {id, email}
      %{id: id} -> {id, nil}
      id when is_integer(id) -> {id, nil}
      _ -> {nil, nil}
    end
    
    audit_log_params = %{
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      user_id: user_id,
      user_email: user_email,
      company_id: company_id,
      data: data
    }
    
    case AuditClient.create_audit_log(audit_log_params) do
      {:ok, data} ->
        {:ok, transform_audit_log(data)}
      
      {:error, errors} when is_list(errors) ->
        Logger.info("Failed to create audit log via microservice: #{inspect(errors)}")
        {:error, %{errors: errors}}
      
      {:error, reason} ->
        Logger.info("Failed to create audit log via microservice: #{inspect(reason)}")
        {:error, %{errors: [reason]}}
    end
  end

  # Transform the audit log data from the microservice to match the expected structure
  defp transform_audit_log(data) when is_map(data) do
    %{
      id: data["id"],
      action: data["action"],
      resource_type: data["resource_type"],
      resource_id: data["resource_id"],
      user_id: data["user_id"],
      company_id: data["company_id"],
      data: data["data"] || %{},
      inserted_at: parse_datetime(data["created_at"]),
      updated_at: parse_datetime(data["updated_at"]),
      # For now, we'll create a simple user struct
      user: %{
        id: data["user_id"],
        email: data["user_email"] || "unknown@example.com"
      }
    }
  end

  defp parse_datetime(nil), do: DateTime.utc_now()
  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  end
  defp parse_datetime(_), do: DateTime.utc_now()
end
