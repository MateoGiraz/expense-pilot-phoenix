defmodule ExpensePilot.Repo.Migrations.AddAreaToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :area_id, references(:areas, on_delete: :nilify_all)
    end

    create index(:users, [:area_id])
  end
end
