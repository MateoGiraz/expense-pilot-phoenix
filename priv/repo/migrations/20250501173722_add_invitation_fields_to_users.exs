defmodule ExpensePilot.Repo.Migrations.AddInvitationFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :invitation_token, :string
      add :invitation_accepted_at, :utc_datetime
      add :invitation_sent_at, :utc_datetime
    end

    create index(:users, [:invitation_token])
  end
end
