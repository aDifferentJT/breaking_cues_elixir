defmodule BreakingCuesWeb.APIController do
  use BreakingCuesWeb, :controller

  def get_programme(conn, _) do
    json(conn, Slides.get_programme())
  end
end
