defmodule ExpensePilot.Companies do
  @moduledoc """
  The Companies context.
  """

  import Ecto.Query, warn: false
  alias ExpensePilot.Repo
  alias ExpensePilot.Companies.Company
  alias ExpensePilot.Accounts.User

  @doc """
  Returns the list of companies.
  """
  def list_companies do
    Repo.all(Company)
  end

  @doc """
  Gets a single company.
  Raises `Ecto.NoResultsError` if the Company does not exist.
  """
  def get_company!(id), do: Repo.get!(Company, id)

  @doc """
  Gets a company with preloaded associations.
  """
  def get_company_with_assocs(id, assocs) do
    company = Repo.get(Company, id)
    if company, do: Repo.preload(company, assocs), else: nil
  end

  @doc """
  Creates a company.
  """
  def create_company(attrs \\ %{}) do
    %Company{}
    |> Company.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a company.
  """
  def update_company(%Company{} = company, attrs) do
    company
    |> Company.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a company.
  """
  def delete_company(%Company{} = company) do
    Repo.delete(company)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking company changes.
  """
  def change_company(%Company{} = company, attrs \\ %{}) do
    Company.changeset(company, attrs)
  end

  @doc """
  Gets the appropriate company_id for a user, handling superadmins specially.
  
  For regular users, returns their assigned company_id.
  For superadmins, returns their selected company_id from the session.
  """
  def get_company_id(user, selected_company_id \\ nil) do
    if User.is_superadmin?(user) do
      selected_company_id
    else
      user.company_id
    end
  end
end
