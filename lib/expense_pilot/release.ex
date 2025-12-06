defmodule ExpensePilot.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :expense_pilot

  def migrate do
    load_app()

    for repo <- repos() do
      case repo.__adapter__.storage_up(repo.config) do
        :ok -> IO.puts("Database created")
        {:error, :already_up} -> IO.puts("Database already exists")
        {:error, term} -> raise "Database creation failed: #{inspect(term)}"
      end

      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def seed do
    {:ok, _} = Application.ensure_all_started(:expense_pilot)

    for repo <- repos() do
      seed_script = priv_path_for(repo, "seeds.exs")

      if File.exists?(seed_script) do
        IO.puts("Running seed script for #{inspect(repo)}")
        Code.eval_file(seed_script)
      end
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.fetch!(repo.config, :otp_app)
    priv_dir = :code.priv_dir(app)
    Path.join([priv_dir, "repo", filename])
  end

  defp load_app do
    Application.load(@app)
  end
end
