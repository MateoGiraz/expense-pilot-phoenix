defmodule ExpensePilot.AuthClient do
  @moduledoc """
  Client for communicating with the authentication microservice via API Gateway.
  This module only handles authentication - all user data remains in the main app.
  """

  defp get_api_gateway_url do
    System.get_env("API_GATEWAY_URL")
  end

  @doc """
  Authenticate user credentials against the auth service via API Gateway
  """
  def authenticate(email, password) do
    url = "#{get_api_gateway_url()}/auth/login"

    body = Jason.encode!(%{
      email: email,
      password: password
    })

    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"user" => user_data, "token" => token, "message" => "Login successful"}} ->
            {:ok, %{token: token, user_id: user_data["id"], email: user_data["email"], role: user_data["role"]}}
          {:ok, %{"message" => message}} ->
            {:error, message}
          _ ->
            {:error, "Invalid response from auth service"}
        end

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, "Invalid credentials"}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "Auth service error: #{status}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Connection error: #{reason}"}
    end
  end

  @doc """
  Validate JWT token via API Gateway
  """
  def validate_token(token) do
    url = "#{get_api_gateway_url()}/auth/validate-token"

    body = Jason.encode!(%{
      token: token
    })

    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"valid" => true, "user" => user_data}} ->
            {:ok, user_data}
          {:ok, %{"valid" => false}} ->
            {:error, "Invalid token"}
          _ ->
            {:error, "Invalid response from auth service"}
        end

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, "Invalid token"}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "Auth service error: #{status}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Connection error: #{reason}"}
    end
  end

  @doc """
  Check if API Gateway and auth service are available
  """
  def health_check do
    # Check API Gateway health first
    gateway_url = "#{get_api_gateway_url()}/health"

    case HTTPoison.get(gateway_url, [], timeout: 5000) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        # Also check auth service health via gateway
        auth_health_url = "#{get_api_gateway_url()}/health/services"
        case HTTPoison.get(auth_health_url, [], timeout: 5000) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            case Jason.decode(body) do
              {:ok, %{"services" => %{"auth-service" => %{"status" => "healthy"}}}} ->
                :ok
              _ ->
                :error
            end
          _ ->
            :error
        end
      _ ->
        :error
    end
  end
end
