defmodule BreakingCuesWeb.OutputChannel do
  use BreakingCuesWeb, :channel

  def broadcast_msg(event, msg) do
    BreakingCuesWeb.Endpoint.broadcast!("output", event, msg)
  end

  def broadcast_preview_msg(event, msg) do
    BreakingCuesWeb.Endpoint.broadcast!(
      "preview_output:#{:erlang.pid_to_list(self())}",
      event,
      msg
    )
  end

  @impl true
  def join("output", payload, socket) do
    {:ok,
     %{
       deck: Slides.get_live(),
       service_details: Slides.get_service_details(),
       service_details_shown: Slides.get_service_details_shown(),
       upcoming_services: Slides.get_upcoming_services(),
       upcoming_services_shown: Slides.get_upcoming_services_shown()
     }, socket}
  end

  @impl true
  def join(<<"preview_output:", pid::binary>>, payload, socket) do
    pid = :erlang.list_to_pid(to_charlist(pid))

    IO.inspect(pid)
    IO.inspect(Process.alive?(pid))

    deck = send(pid, :update_preview)

    IO.inspect(deck)

    {:ok,
     %{
       deck: deck,
       service_details: Slides.get_service_details(),
       service_details_shown: false,
       upcoming_services: Slides.get_upcoming_services(),
       upcoming_services_shown: false
     }, socket}
  end
end
