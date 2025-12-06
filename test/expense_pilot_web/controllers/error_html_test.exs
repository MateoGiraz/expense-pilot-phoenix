defmodule ExpensePilotWeb.ErrorHTMLTest do
  use ExpensePilotWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    html = render_to_string(ExpensePilotWeb.ErrorHTML, "404", "html", [])
    assert html =~ "404"
    assert html =~ "We're sorry, the page you were looking for isn't found here"
    assert html =~ "Return to Dashboard"
    assert html =~ "class=\"error\""
  end

  test "renders 500.html" do
    assert render_to_string(ExpensePilotWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
