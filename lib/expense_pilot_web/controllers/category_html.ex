defmodule ExpensePilotWeb.CategoryHTML do
  use ExpensePilotWeb, :html

  embed_templates "category_html/*"

  @doc """
  Renders a category form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def category_form(assigns)
  
  @doc """
  Returns CSS class for progress bar based on percentage value.
  """
  def get_progress_color(percent) when is_nil(percent), do: "bg-gray-500"
  def get_progress_color(percent) do
    percent_float = case percent do
      %Decimal{} -> 
        if Decimal.compare(percent, Decimal.new(0)) == :eq do
          0
        else
          Decimal.to_float(percent)
        end
      _ when is_number(percent) -> percent
      _ -> 0
    end
    
    cond do
      percent_float == 0 -> "bg-gray-500"
      percent_float > 75 -> "bg-red-600"
      percent_float > 50 -> "bg-yellow-400"
      true -> "bg-green-600"
    end
  end
end 