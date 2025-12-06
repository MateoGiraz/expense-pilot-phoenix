defmodule ExpensePilot.Messaging.Queue do
  @moduledoc """
  This module handles interactions with AWS SQS.
  """

  require Logger

  @doc """
  Send a message to the SQS queue
  """
  def send_message(message) do
    queue_url = get_queue_url()

    ExAws.SQS.send_message(queue_url, Jason.encode!(message))
    |> ExAws.request()
    |> case do
      {:ok, _result} ->
        Logger.info("Message sent to SQS queue: #{queue_url}")
        :ok
      {:error, error} ->
        Logger.error("Failed to send message to SQS queue: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Receive messages from the SQS queue
  """
  def receive_messages(max_number \\ 10) do
    queue_url = get_queue_url()

    ExAws.SQS.receive_message(queue_url, max_number: max_number, wait_time_seconds: 20)
    |> ExAws.request()
    |> case do
      {:ok, %{body: %{messages: messages}}} when messages != [] ->
        {:ok, messages}
      {:ok, %{body: %{messages: []}}} ->
        {:ok, []}
      {:error, error} ->
        Logger.error("Failed to receive messages from SQS queue: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Delete a message from the SQS queue
  """
  def delete_message(receipt_handle) do
    queue_url = get_queue_url()

    ExAws.SQS.delete_message(queue_url, receipt_handle)
    |> ExAws.request()
    |> case do
      {:ok, _result} ->
        :ok
      {:error, error} ->
        Logger.error("Failed to delete message from SQS queue: #{inspect(error)}")
        {:error, error}
    end
  end

  defp get_queue_url do
    System.get_env("AWS_SQS_QUEUE_URL") || raise "AWS_SQS_QUEUE_URL environment variable is not set"
  end
end
