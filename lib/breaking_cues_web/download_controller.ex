defmodule BreakingCuesWeb.DownloadController do
  use BreakingCuesWeb, :controller

  def programme(conn, _) do
    json(conn, Slides.get_programme())
  end

  def deck(conn, %{"id" => id}) do
    id = String.replace_suffix(id, ".bcd", "")
    json(conn, Slides.get_deck(id))
  end
end
