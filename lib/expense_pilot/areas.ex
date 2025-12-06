defmodule ExpensePilot.Areas do
  @moduledoc """
  The Areas context.
  """

  import Ecto.Query, warn: false
  alias ExpensePilot.Repo
  alias ExpensePilot.Areas.Area

  @doc """
  Returns the list of areas for a specific company.
  """
  def list_areas(company_id) when is_nil(company_id), do: []
  
  def list_areas(company_id) do
    from(a in Area,
      where: a.company_id == ^company_id,
      order_by: [asc: a.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single area.
  Raises `Ecto.NoResultsError` if the Area does not exist.
  """
  def get_area!(id), do: Repo.get!(Area, id)

  @doc """
  Gets a single area within a company scope.
  """
  def get_area!(id, company_id) do
    from(a in Area,
      where: a.id == ^id and a.company_id == ^company_id
    )
    |> Repo.one!()
  end

  @doc """
  Creates an area.
  """
  def create_area(attrs \\ %{}) do
    %Area{}
    |> Area.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an area.
  """
  def update_area(%Area{} = area, attrs) do
    area
    |> Area.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an area.
  """
  def delete_area(%Area{} = area) do
    Repo.delete(area)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking area changes.
  """
  def change_area(%Area{} = area, attrs \\ %{}) do
    Area.changeset(area, attrs)
  end
end 