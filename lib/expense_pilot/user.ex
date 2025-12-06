defmodule ExpensePilot.User do
  @moduledoc """
  Helper functions for user operations.
  Works with the existing ExpensePilot.Accounts.User schema.
  """

  alias ExpensePilot.Accounts.User, as: UserSchema

  @doc """
  Check if a user is a superadmin
  """
  def is_superadmin?(%UserSchema{role: "superadmin"}), do: true
  def is_superadmin?(%{role: "superadmin"}), do: true
  def is_superadmin?(_), do: false

  @doc """
  Check if a user is an admin
  """
  def is_admin?(%UserSchema{role: role}) when role in ["admin", "superadmin"], do: true
  def is_admin?(%{role: role}) when role in ["admin", "superadmin"], do: true
  def is_admin?(_), do: false
end
