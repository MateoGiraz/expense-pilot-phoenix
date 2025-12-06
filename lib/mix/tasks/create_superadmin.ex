defmodule Mix.Tasks.CreateSuperadmin do
  use Mix.Task
  alias ExpensePilot.Accounts

  @shortdoc "Creates a new superadmin user"
  @moduledoc """
  Creates a new superadmin user with the given email and password.

  ## Examples

      mix create_superadmin email@example.com password
  """

  def run([email, password]) do
    Mix.Task.run("app.start")
    
    case Accounts.create_superadmin(email, password) do
      {:ok, user} ->
        Mix.shell().info("Superadmin created successfully with ID: #{user.id}")
      
      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
        |> Enum.map(fn {key, msgs} -> "#{key}: #{Enum.join(msgs, ", ")}" end)
        |> Enum.join("\n")
        
        Mix.shell().error("Failed to create superadmin:\n#{errors}")
    end
  end

  def run(_) do
    Mix.shell().error("Expected arguments: email password")
  end
end 