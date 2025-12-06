defmodule ExpensePilot.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias ExpensePilot.Repo
  alias ExpensePilot.Accounts.User
  alias ExpensePilot.Companies.Company

  def get_user(id) do
    Repo.get(User, id)
  end

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Authenticates a user.
  """
  def authenticate_user(email, password) do
    case get_user_by_email(email) do
      nil -> {:error, :invalid_credentials}
      user -> authenticate_user(user, password, user)
    end
  end

  @doc """
  Creates a superadmin user with the given email and password.
  Superadmins do not belong to any company.
  """
  def create_superadmin(email, password) do
    attrs = %{
      email: email,
      password: password,
      role: "superadmin",
      invited: false
    }

    create_user(attrs)
  end

  @doc """
  Gets the currently selected company for a superadmin.
  """
  def get_selected_company(company_id) when is_binary(company_id) do
    case Integer.parse(company_id) do
      {id, _} -> get_selected_company(id)
      :error -> nil
    end
  end

  def get_selected_company(company_id) when is_integer(company_id) do
    Repo.get(Company, company_id)
  end

  def get_selected_company(_), do: nil

  @doc """
  Invites a user to a company.
  """
  def invite_user(%Company{} = company, email, role \\ "member", area_id \\ nil) do
    # Generate secure token for invitation
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64()
    password = generate_temporary_password()

    # First create user in auth service
    auth_attrs = %{
      email: email,
      password: password,
      role: role,
      company_id: company.id,
      invited: true,
      invitation_token: token,
      area_id: area_id
    }

    case create_user_in_auth_service(auth_attrs) do
      {:ok, auth_user} ->
        # Create local user with same ID from auth service
        local_attrs = %{
          id: auth_user.id,
          email: email,
          password: password,
          role: role,
          company_id: company.id,
          area_id: area_id,
          invited: true,
          invitation_token: token,
          invitation_sent_at: DateTime.utc_now()
        }

        with {:ok, user} <- create_user(local_attrs) do
          # Queue email via notification service
          ExpensePilot.NotificationClient.send_invitation_email(user, company, password)
          {:ok, user}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all invited users for a company that haven't accepted yet.
  """
  def list_pending_invitations(company_id) when is_nil(company_id), do: []
  
  def list_pending_invitations(company_id) do
    from(u in User,
      where: u.company_id == ^company_id and
             u.invited == true and
             is_nil(u.invitation_accepted_at),
      order_by: [desc: u.invitation_sent_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists all users for a company.
  """
  def list_users(company_id) do
    from(u in User,
      where: u.company_id == ^company_id,
      order_by: [asc: u.email]
    )
    |> Repo.all()
  end

  @doc """
  Resends an invitation email to a user.
  """
  def resend_invitation(user_id) do
    user = Repo.get(User, user_id) |> Repo.preload(:company)

    if user && user.invited && is_nil(user.invitation_accepted_at) do
      # Generate new token and password
      token = :crypto.strong_rand_bytes(32) |> Base.url_encode64()
      password = generate_temporary_password()

      # Update password in auth service
      case update_user_password_in_auth_service(user.id, password) do
        {:ok, _} ->
          # Update local user
          {:ok, updated_user} = user
          |> User.changeset(%{
              invitation_token: token,
              invitation_sent_at: DateTime.utc_now(),
              password_hash: Bcrypt.hash_pwd_salt(password)
            })
          |> Repo.update()

          # Queue email via notification service
          ExpensePilot.NotificationClient.send_invitation_email(updated_user, user.company, password)

          {:ok, updated_user}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :invalid_invitation}
    end
  end

  @doc """
  Cancels/revokes an invitation.
  """
  def cancel_invitation(user_id) do
    user = Repo.get(User, user_id)

    if user && user.invited && is_nil(user.invitation_accepted_at) do
      {:ok, _deleted} = Repo.delete(user)
      {:ok, user}
    else
      {:error, :invalid_invitation}
    end
  end

  @doc """
  Accepts an invitation and sets a new password.
  """
  def accept_invitation(token, password) do
    case get_user_by_invitation_token(token) do
      nil ->
        {:error, :invalid_token}

      user ->
        if is_nil(user.invitation_accepted_at) do
          user
          |> User.changeset(%{
              password_hash: Bcrypt.hash_pwd_salt(password),
              invitation_accepted_at: DateTime.utc_now(),
              invited: false
            })
          |> Repo.update()
        else
          {:error, :already_accepted}
        end
    end
  end

  @doc """
  Gets a user by their invitation token.
  """
  def get_user_by_invitation_token(token) do
    Repo.get_by(User, invitation_token: token)
  end

  @doc """
  Gets all users in the same area with expense notifications enabled, excluding the current user.
  """
  def list_users_by_area_with_notifications(area_id, company_id, exclude_user_id) do
    from(u in User,
      where: u.area_id == ^area_id and 
             u.company_id == ^company_id and 
             u.expense_notifications == true and
             u.id != ^exclude_user_id,
      select: u
    )
    |> Repo.all()
  end

  def authenticate_user(user, password, user) do
    if Bcrypt.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

  @doc """
  Creates a user with the given attributes.
  """
  def create_user(attrs) do
    # Extract password from attrs
    password = attrs["password"] || attrs[:password]

    %User{}
    |> User.changeset(
        Map.merge(
          attrs,
          %{password_hash: Bcrypt.hash_pwd_salt(password)}
        )
      )
    |> Repo.insert()
  end

  @doc """
  Updates a user with the given attributes.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a user from auth service data for local database sync.
  This is used when a user exists in the auth service but not locally.
  """
  def create_user_from_auth_service(auth_data) do
    # Get complete user data from auth service
    case get_user_from_auth_service(auth_data.id) do
      {:ok, full_user_data} ->
        attrs = %{
          id: full_user_data.id,
          email: full_user_data.email,
          role: full_user_data.role,
          company_id: full_user_data.company_id,
          area_id: nil, # area_id is not stored in auth service, will be synced from local data
          password_hash: "AUTH_SERVICE", # Placeholder - auth is handled by auth service
          invited: full_user_data.invited || false,
          invitation_token: full_user_data.invitation_token,
          invitation_accepted_at: if(full_user_data.invited == false, do: DateTime.utc_now(), else: nil)
        }

        %User{}
        |> User.changeset(attrs)
        |> Repo.insert()
        
      {:error, _reason} ->
        # Fallback to minimal data if auth service call fails
        attrs = %{
          id: auth_data.id,
          email: auth_data.email,
          role: auth_data.role,
          password_hash: "AUTH_SERVICE", # Placeholder - auth is handled by auth service
          invited: false
        }

        %User{}
        |> User.changeset(attrs)
        |> Repo.insert()
    end
  end

  @doc """
  Gets a user from the auth service by ID.
  """
  defp get_user_from_auth_service(user_id) do
    url = "#{Application.get_env(:expense_pilot, :api_gateway_url)}/users/by-ids"

    body = %{ids: [user_id]}

    case HTTPoison.post(url, Jason.encode!(body), [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"users" => [user_data]}} ->
            {:ok, %{
              id: user_data["id"],
              email: user_data["email"],
              role: user_data["role"],
              company_id: user_data["companyId"],
              invited: user_data["invited"],
              invitation_token: user_data["invitationToken"]
            }}
          {:ok, %{"users" => []}} ->
            {:error, :user_not_found}
          {:error, _} ->
            {:error, :invalid_response}
        end

      {:ok, %HTTPoison.Response{status_code: _}} ->
        {:error, :auth_service_error}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Generates a random temporary password.
  """
  defp generate_temporary_password do
    :crypto.strong_rand_bytes(12) |> Base.encode64()
  end

  @doc """
  Creates a user in the auth service.
  """
  defp create_user_in_auth_service(attrs) do
    url = "#{Application.get_env(:expense_pilot, :api_gateway_url)}/users/"

    body = %{
      email: attrs.email,
      password: attrs.password,
      role: attrs.role,
      companyId: attrs.company_id,
      invited: attrs.invited,
      invitationToken: attrs.invitation_token,
      area_id: attrs.area_id
    }

    case HTTPoison.post(url, Jason.encode!(body), [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 201, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"user" => user_data}} ->
            {:ok, %{
              id: user_data["id"],
              email: user_data["email"],
              role: user_data["role"]
            }}
          {:error, _} -> {:error, :invalid_response}
        end

      {:ok, %HTTPoison.Response{status_code: 409, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => "User already exists"}} ->
            {:error, :user_already_exists}
          _ -> {:error, :user_already_exists}
        end

      {:ok, %HTTPoison.Response{status_code: 400, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => error}} -> {:error, error}
          _ -> {:error, :bad_request}
        end

      {:ok, %HTTPoison.Response{status_code: _}} ->
        {:error, :auth_service_error}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Updates a user's password in the auth service.
  """
  defp update_user_password_in_auth_service(user_id, new_password) do
    url = "#{Application.get_env(:expense_pilot, :api_gateway_url)}/users/#{user_id}/password"

    body = %{password: new_password}

    case HTTPoison.put(url, Jason.encode!(body), [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        {:ok, :updated}

      {:ok, %HTTPoison.Response{status_code: _}} ->
        {:error, :auth_service_error}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
