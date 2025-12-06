defmodule ExpensePilot.Auditing.AuditClient do
  @moduledoc """
  HTTP client for communicating with the audit microservice via API Gateway.
  """

  require Logger

  defp base_url do
    api_gateway_url = System.get_env("API_GATEWAY_URL")
    "#{api_gateway_url}/api/v1"
  end

  def list_audit_logs(company_id, page \\ 1, per_page \\ 50) do
    url = "#{base_url()}/audit_logs?company_id=#{company_id}&page=#{page}&per_page=#{per_page}"
    headers = [{"accept", "application/json"}]

    Logger.info("Fetching audit logs for company_id: #{company_id} via API Gateway")

    case Finch.build(:get, url, headers) |> Finch.request(ExpensePilot.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, "Invalid JSON response"}
        end
      {:ok, %Finch.Response{status: 406}} ->
        Logger.info("Audit service returned 406 - API format issue")
        {:error, "API format not acceptable"}
      {:ok, %Finch.Response{status: status, body: _body}} ->
        Logger.info("Audit service returned HTTP #{status}")
        {:error, "HTTP #{status}"}
      {:error, reason} ->
        Logger.info("Audit service unavailable: #{inspect(reason)}")
        {:error, "Connection failed"}
    end
  end

  def get_audit_log(id) do
    url = "#{base_url()}/audit_logs/#{id}"
    headers = [{"accept", "application/json"}]

    Logger.info("Fetching audit log #{id} via API Gateway")

    case Finch.build(:get, url, headers) |> Finch.request(ExpensePilot.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, "Invalid JSON response"}
        end
      {:ok, %Finch.Response{status: 404}} ->
        {:error, "Audit log not found"}
      {:ok, %Finch.Response{status: 406}} ->
        Logger.info("Audit service returned 406 - API format issue")
        {:error, "API format not acceptable"}
      {:ok, %Finch.Response{status: status, body: _body}} ->
        Logger.info("Audit service returned HTTP #{status}")
        {:error, "HTTP #{status}"}
      {:error, reason} ->
        Logger.info("Audit service unavailable: #{inspect(reason)}")
        {:error, "Connection failed"}
    end
  end

  @doc """
  Creates an audit log entry via the API Gateway.

  ## Parameters

  - `audit_log_params`: A map containing the audit log data

  ## Expected Parameters

  - `action`: String - The action performed (e.g., "create", "update", "delete")
  - `resource_type`: String - The type of resource (e.g., "expense", "user")
  - `resource_id`: Integer - The ID of the resource
  - `user_id`: Integer - The ID of the user performing the action
  - `company_id`: Integer - The ID of the company
  - `data`: Map - Additional data related to the action

  ## Request Body Format

  The request is sent with the following JSON structure:
  ```json
  {
    "audit_log": {
      "action": "user_login",
      "resource_type": "User",
      "resource_id": 123,
      "user_id": 123,
      "company_id": 456,
      "data": {
        // Additional data here
      }
    }
  }
  ```
  """
  def create_audit_log(audit_log_params) do
    url = "#{base_url()}/audit_logs"
    headers = [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]

    # Wrap the parameters in the expected "audit_log" key
    body = Jason.encode!(%{audit_log: audit_log_params})

    Logger.info("Creating audit log for #{audit_log_params[:resource_type]} via API Gateway")

    case Finch.build(:post, url, headers, body) |> Finch.request(ExpensePilot.Finch) do
      {:ok, %Finch.Response{status: 201, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, "Invalid JSON response"}
        end
      {:ok, %Finch.Response{status: 422, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"errors" => errors}} -> {:error, errors}
          {:error, _} -> {:error, "Validation failed"}
        end
      {:ok, %Finch.Response{status: status, body: _body}} ->
        Logger.info("Audit service returned HTTP #{status}")
        {:error, "HTTP #{status}"}
      {:error, reason} ->
        Logger.info("Audit service unavailable: #{inspect(reason)}")
        {:error, "Connection failed"}
    end
  end
end
