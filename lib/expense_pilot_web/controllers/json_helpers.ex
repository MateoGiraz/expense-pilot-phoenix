defmodule ExpensePilotWeb.JsonHelpers do
  @moduledoc """
  Helper functions for working with JSON serialization,
  especially for types that don't implement the Jason.Encoder protocol.
  """

  @doc """
  Recursively traverses a data structure and converts
  values like Decimal, Date, DateTime to string representation.

  ## Examples

      iex> ExpensePilotWeb.JsonHelpers.prepare_for_json(%{amount: Decimal.new("10.5")})
      %{amount: "10.5"}

      iex> ExpensePilotWeb.JsonHelpers.prepare_for_json([%{date: ~D[2023-01-01]}])
      [%{date: "2023-01-01"}]
  """
  # Handle Decimal values first to avoid trying to use them as Enumerable
  def prepare_for_json(%Decimal{} = decimal) do
    Decimal.to_string(decimal)
  end

  # Handle Date, DateTime, and NaiveDateTime values
  def prepare_for_json(%Date{} = date) do
    Date.to_string(date)
  end

  def prepare_for_json(%DateTime{} = datetime) do
    DateTime.to_string(datetime)
  end

  def prepare_for_json(%NaiveDateTime{} = datetime) do
    NaiveDateTime.to_string(datetime)
  end

  # Now handle collection types
  def prepare_for_json(data) when is_map(data) do
    Enum.reduce(data, %{}, fn {k, v}, acc ->
      Map.put(acc, k, prepare_for_json(v))
    end)
  end

  def prepare_for_json(data) when is_list(data) do
    Enum.map(data, &prepare_for_json/1)
  end

  # Default case for other types
  def prepare_for_json(other), do: other
end
