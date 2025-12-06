defmodule ExpensePilotWeb.DashboardHTML do
  use ExpensePilotWeb, :html

  embed_templates "dashboard_html/*"

  @doc """
  Returns CSS class for expense limit progress bar based on percentage value.
  """
  def get_limit_bar_color(percent) do
    cond do
      Decimal.compare(percent, Decimal.new(90)) != :lt -> "bg-red-500"
      Decimal.compare(percent, Decimal.new(75)) != :lt -> "bg-yellow-500"
      true -> "bg-green-500"
    end
  end
end 