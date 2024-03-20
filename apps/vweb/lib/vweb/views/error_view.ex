defmodule Vweb.ErrorView do
  use Vweb, :view

  def render("500.json", _assigns) do
    %{error: "Internal server error"}
  end

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
