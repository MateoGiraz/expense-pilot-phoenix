defmodule ExpensePilot.Repo.Migrations.AddSuperadminRoleConstraint do
  use Ecto.Migration

  def up do
    # Drop the not null constraint on company_id to allow superadmins without a company
    execute """
    ALTER TABLE users ALTER COLUMN company_id DROP NOT NULL;
    """

    # Add constraint that all users except superadmins must have a company
    execute """
    ALTER TABLE users ADD CONSTRAINT users_company_id_required 
    CHECK (role = 'superadmin' OR company_id IS NOT NULL);
    """
  end

  def down do
    # Remove the check constraint
    execute """
    ALTER TABLE users DROP CONSTRAINT users_company_id_required;
    """

    # Add back the not null constraint for company_id
    execute """
    ALTER TABLE users ALTER COLUMN company_id SET NOT NULL;
    """
  end
end
