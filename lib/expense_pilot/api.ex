defmodule ExpensePilot.Api do
  @moduledoc """
  The API context.
  """

  import Ecto.Query, warn: false
  alias ExpensePilot.Repo
  alias ExpensePilot.Api.ApiKey

  @doc """
  Returns the list of api_keys for a user.
  """
  def list_api_keys(user_id) do
    ApiKey
    |> where([a], a.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Returns the list of api_keys for a company.
  """
  def list_company_api_keys(company_id) do
    ApiKey
    |> where([a], a.company_id == ^company_id)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Gets a single api_key.
  """
  def get_api_key(id), do: Repo.get(ApiKey, id)

  @doc """
  Gets an api_key by its token value.
  """
  def get_api_key_by_token(token) do
    Repo.get_by(ApiKey, key: token)
    |> Repo.preload([:user, :company])
  end

  @doc """
  Creates an api_key.
  """
  def create_api_key(attrs \\ %{}) do
    %ApiKey{}
    |> ApiKey.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes an api_key.
  """
  def delete_api_key(%ApiKey{} = api_key) do
    Repo.delete(api_key)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking api_key changes.
  """
  def change_api_key(%ApiKey{} = api_key, attrs \\ %{}) do
    ApiKey.changeset(api_key, attrs)
  end

  @doc """
  Verifies an API key token and returns the company info if valid.
  """
  def verify_api_key(token) when is_binary(token) do
    case get_api_key_by_token(token) do
      nil -> {:error, :invalid_token}
      api_key -> {:ok, api_key.company}
    end
  end
  def verify_api_key(_), do: {:error, :invalid_token}
end
