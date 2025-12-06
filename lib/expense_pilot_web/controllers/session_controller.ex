defmodule ExpensePilotWeb.SessionController do
  use ExpensePilotWeb, :controller
  require Logger
  alias ExpensePilot.Accounts
  alias ExpensePilot.Accounts.{Guardian, User}
  alias ExpensePilot.AuthClient

  def new(conn, _params) do
    # Check if user is already logged in
    case Guardian.Plug.current_resource(conn) do
      nil ->
        # User not logged in, show login form
        conn = assign(conn, :current_user, nil)
        render(conn, :new)
      user ->
        # User already logged in, redirect to appropriate page
        Logger.info("User #{user.email} already logged in, redirecting")
        if User.is_superadmin?(user) do
          redirect(conn, to: ~p"/company-selector")
        else
          redirect(conn, to: ~p"/")
        end
    end
  end

  def create(conn, %{"session" => %{"email" => email, "password" => password}}) do
    # Check if user is already logged in
    case Guardian.Plug.current_resource(conn) do
      nil ->
        # User not logged in, proceed with authentication
        authenticate_user(conn, email, password)
      user ->
        # User already logged in, redirect to appropriate page
        Logger.info("User #{user.email} already logged in during login attempt, redirecting")
        conn
        |> put_flash(:info, "You are already logged in.")
        |> redirect_after_login(user)
    end
  end

  # Helper function to handle authentication logic
  defp authenticate_user(conn, email, password) do
    # First, authenticate with the auth service
    case AuthClient.authenticate(email, password) do
      {:ok, %{token: token, user_id: user_id, email: auth_email, role: auth_role}} ->
        Logger.info("Auth service authenticated user #{user_id} with email #{auth_email}")

        # Clear any existing session data after successful authentication
        conn = clear_session(conn)

        # Use email as the primary identifier - get or create user by email
        user = case Accounts.get_user_by_email(auth_email) do
          nil ->
            Logger.info("No local user found with email #{auth_email}, creating new user")
            # Create new user with auth service data
            case Accounts.create_user_from_auth_service(%{
              id: user_id,
              email: auth_email,
              role: auth_role
            }) do
              {:ok, new_user} ->
                Logger.info("Created new local user #{new_user.id} for email #{auth_email}")
                new_user
              {:error, error} ->
                Logger.error("Failed to create local user: #{inspect(error)}")
                # Fallback: create a minimal user struct for session
                Logger.warning("Using minimal user struct for email #{auth_email}")
                %User{id: user_id, email: auth_email, role: auth_role}
            end
          existing_user ->
            Logger.info("Found existing local user #{existing_user.id} for email #{auth_email}")

            # Always use auth service data as source of truth for the session
            session_user = %User{existing_user | email: auth_email, role: auth_role}
            Logger.info("Created session user with auth service data: #{session_user.id} (#{session_user.email})")

            # Try to update local database asynchronously
            Task.start(fn ->
              updates = %{}

              # Update role if changed
              if existing_user.role != auth_role do
                Logger.info("Background: Updating role from #{existing_user.role} to #{auth_role}")
                updates = Map.put(updates, :role, auth_role)
              end

              # If user was invited but successfully logged in, mark as accepted
              if existing_user.invited && is_nil(existing_user.invitation_accepted_at) do
                updates = updates
                  |> Map.put(:invited, false)
                  |> Map.put(:invitation_accepted_at, DateTime.utc_now())
              end

              # Apply updates if any
              if map_size(updates) > 0 do
                case Accounts.update_user(existing_user, updates) do
                  {:ok, _updated_user} ->
                    Logger.info("Background: Successfully updated user #{existing_user.id} in database")
                  {:error, changeset} ->
                    Logger.warning("Background: Failed to update user #{existing_user.id}: #{inspect(changeset.errors)}")
                end
              end
            end)

            session_user
        end

        Logger.info("FINAL: Using user #{user.id} (#{user.email}) for session")

        # Store the auth service token in session
        conn = conn
        |> put_session(:auth_token, token)
        |> put_session(:updated_user_data, %{email: user.email, role: user.role})
        |> put_flash(:info, "Welcome back!")

        # Sign in user with Guardian (for compatibility with existing code)
        conn = Guardian.Plug.sign_in(conn, user, %{role: user.role})

        # Redirect after successful login
        redirect_after_login(conn, user)

      {:error, reason} ->
        # Don't clear session on failed login to preserve CSRF token
        Logger.warn("Login failed for #{email}: #{reason}")
        conn
        |> put_flash(:error, "Login failed: #{reason}")
        |> render(:new)
    end
  end

  # Helper function to handle post-login redirection
  defp redirect_after_login(conn, user) do
    # Handle different user roles
    if User.is_superadmin?(user) do
      # Redirect superadmins to company selector
      redirect(conn, to: ~p"/company-selector")
    else
      # For regular users, set company_id and redirect to dashboard
      company = ExpensePilot.Repo.preload(user, :company).company
      conn
      |> put_session(:company_id, company.id)
      |> redirect(to: ~p"/")
    end
  end

  def delete(conn, _params) do
    conn
    |> Guardian.Plug.sign_out()
    |> clear_session()
    |> delete_session(:updated_user_data)
    |> put_flash(:info, "Successfully logged out.")
    |> redirect(to: ~p"/login")
  end
end
