defmodule ExpensePilot.NotificationClient do
  @moduledoc """
  Client for sending expense notifications via SQS to the notification service.
  """

  require Logger
  alias ExpensePilot.Accounts

  @doc """
  Send expense notification to all users in the same area who have notifications enabled.
  """
  def send_expense_notification(expense, action, current_user) do
    try do
      # Get all users in the same area with notifications enabled
      recipients = get_notification_recipients(expense, current_user)
      
      if length(recipients) > 0 do
        # Create notification data
        notification_data = build_expense_notification_data(expense, action, current_user)
        
        # Send notification to each recipient
        Enum.each(recipients, fn recipient ->
          send_notification_to_user(recipient, notification_data)
        end)
        
        Logger.info("Sent expense notification to #{length(recipients)} users for #{action} action on expense #{expense.id}")
      else
        Logger.info("No users to notify for expense #{expense.id}")
      end
    rescue
      error ->
        Logger.error("Failed to send expense notification: #{inspect(error)}")
    end
  end

  @doc """
  Send invitation email to a new user.
  """
  def send_invitation_email(user, company, password) do
    try do
      message = %{
        type: "invitation_email",
        recipient: user.email,
        data: %{
          user_email: user.email,
          company_name: company.name,
          password: password,
          login_url: "#{get_frontend_url()}/login"
        }
      }

      case send_to_sqs(message) do
        :ok ->
          Logger.info("Invitation email for user #{user.email} queued successfully")
          {:ok, :queued}
        :error ->
          Logger.error("Failed to queue invitation email for user #{user.email}")
          {:error, :queue_failed}
      end
    rescue
      error ->
        Logger.error("Failed to send invitation email: #{inspect(error)}")
        {:error, error}
    end
  end

  defp get_notification_recipients(expense, current_user) do
    # Get the expense owner's area
    expense_owner = ExpensePilot.Repo.preload(expense, [:user]).user
    area_id = expense_owner.area_id
    company_id = expense.company_id
    
    if area_id do
      # Get all users in the same area with notifications enabled (excluding the current user)
      Accounts.list_users_by_area_with_notifications(area_id, company_id, current_user.id)
    else
      []
    end
  end

  defp build_expense_notification_data(expense, action, current_user) do
    # Preload associations
    expense = ExpensePilot.Repo.preload(expense, [:category, :user, :company])
    
    action_text = case action do
      "create" -> "created"
      "update" -> "updated"
      "delete" -> "deleted"
      _ -> action
    end

    %{
      type: "expense_notification",
      action: action_text,
      expense: %{
        id: expense.id,
        amount: Decimal.to_string(expense.amount),
        date: Date.to_string(expense.date),
        category: expense.category.name,
        owner: expense.user.email,
        company: expense.company.name,
        registered_at: DateTime.to_iso8601(expense.registered_at)
      },
      performed_by: current_user.email,
      performed_at: DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  defp send_notification_to_user(user, notification_data) do
    message = %{
      type: "expense_notification_email",
      recipient: user.email,
      data: notification_data
    }

    # Send to SQS queue
    send_to_sqs(message)
  end

  defp send_to_sqs(message) do
    try do
      # Get SQS configuration
      aws_config = get_aws_config()
      
      if aws_config[:enabled] do
        # Convert message to JSON
        message_body = Jason.encode!(message)
        
        # Send to SQS using ExAws
        ExAws.SQS.send_message(aws_config[:queue_url], message_body)
        |> ExAws.request(aws_config[:config])
        |> case do
          {:ok, _response} ->
            Logger.info("Successfully sent notification to SQS for #{message.recipient}")
            :ok
          {:error, error} ->
            Logger.error("Failed to send notification to SQS: #{inspect(error)}")
            :error
        end
      else
        Logger.warn("AWS SQS not configured, skipping notification")
        :ok
      end
    rescue
      error ->
        Logger.error("Error sending notification to SQS: #{inspect(error)}")
        :error
    end
  end

  defp get_aws_config do
    aws_access_key_id = System.get_env("AWS_ACCESS_KEY_ID")
    aws_secret_access_key = System.get_env("AWS_SECRET_ACCESS_KEY")
    aws_region = System.get_env("AWS_REGION", "us-east-1")
    sqs_queue_url = System.get_env("SQS_QUEUE_URL")

    enabled = aws_access_key_id && aws_secret_access_key && sqs_queue_url

    %{
      enabled: enabled,
      queue_url: sqs_queue_url,
      config: [
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key,
        region: aws_region
      ]
    }
  end

  defp get_frontend_url do
    System.get_env("FRONTEND_URL", "http://localhost:4000")
  end
end
