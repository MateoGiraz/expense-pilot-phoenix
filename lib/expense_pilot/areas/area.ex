defmodule ExpensePilot.Areas.Area do
  use Ecto.Schema
  import Ecto.Changeset

  schema "areas" do
    field :name, :string
    field :description, :string

    belongs_to :company, ExpensePilot.Companies.Company
    has_many :users, ExpensePilot.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(area, attrs) do
    area
    |> cast(attrs, [:name, :description, :company_id])
    |> validate_required([:name, :company_id])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:description, max: 500)
    |> unique_constraint([:name, :company_id], message: "Area name must be unique within the company")
  end
end 