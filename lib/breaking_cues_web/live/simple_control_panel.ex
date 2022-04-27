defmodule BreakingCuesWeb.SimpleControlPanel do
  use Phoenix.LiveView
  import Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  def mount(_params, session, socket) do
    Scenic.PubSub.subscribe(:slide_state)

    socket =
      socket
      |> assign(:state, Scenic.PubSub.get(:slide_state))

    {:ok, socket}
  end

  def handle_event("previous_event", _, socket) do
    Slides.previous_event()
    {:noreply, socket}
  end

  def handle_event("next_event", _, socket) do
    Slides.next_event()
    {:noreply, socket}
  end

  def handle_event("close_live", _, socket) do
    Slides.close_live()
    {:noreply, socket}
  end

  def handle_info({{Scenic.PubSub, :data}, {:slide_state, state, _timestamp}}, socket) do
    socket = socket |> assign(:state, state)
    {:noreply, socket}
  end
end
