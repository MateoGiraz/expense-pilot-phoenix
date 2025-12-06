defmodule ExpensePilot.AuditClient do
  @moduledoc """
  Client for sending audit logs to the audit service.
  """

  require Logger

  @doc """
  Log an action to the audit service.
  """
  def log_action(action, resource_type, resource_id, user, company_id, data \\ %{}) do
    url = "#{get_audit_service_url()}/api/v1/audit_logs"
    
    body = %{
      audit_log: %{
        action: action,
        resource_type: resource_type,
        resource_id: resource_id,
        user_id: user.id,
        user_email: user.email,
        company_id: company_id,
        data: data
      }
    }

    headers = [
      {"Content-Type", "application/json"},
      {"X-API-Key", get_api_key()}
    ]

    case HTTPoison.post(url, Jason.encode!(body), headers) do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        Logger.info("Audit log created: #{action} on #{resource_type}##{resource_id} by user #{user.email}")
        :ok
      
      {:ok, %HTTPoison.Response{status_code: status, body: response_body}} ->
        Logger.error("Failed to create audit log: HTTP #{status} - #{response_body}")
        {:error, :audit_service_error}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Failed to connect to audit service: #{reason}")
        {:error, :connection_error}
    end
  end

  @doc """
  Get audit logs with optional filters.
  """
  def get_audit_logs(company_id, filters \\ %{}) do
    url = "#{get_audit_service_url()}/api/v1/audit_logs"
    
    query_params = filters
    |> Map.put(:company_id, company_id)
    |> URI.encode_query()
    
    full_url = "#{url}?#{query_params}"
    
    headers = [
      {"X-API-Key", get_api_key()}
    ]

    case HTTPoison.get(full_url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, :invalid_response}
        end
      
      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.error("Failed to get audit logs: HTTP #{status}")
        {:error, :audit_service_error}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Failed to connect to audit service: #{reason}")
        {:error, :connection_error}
    end
  end

  defp get_audit_service_url do
    Application.get_env(:expense_pilot, :api_gateway_url)
  end

  defp get_api_key do
    System.get_env("API_SECRET_KEY") || "expense-pilot-internal-api-key-12345"
  end
end 