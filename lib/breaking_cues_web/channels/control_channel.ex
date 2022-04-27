defmodule BreakingCuesWeb.ControlSocket do
  @behaviour Phoenix.Socket.Transport

  import Controller

  @impl Phoenix.Socket.Transport
  def child_spec(opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @impl Phoenix.Socket.Transport
  def connect(socket) do
    # Callback to retrieve relevant data from the connection.
    # The map contains options, params, transport and endpoint keys.
    {:ok, socket}
  end

  @impl Phoenix.Socket.Transport
  def init(socket) do
    Scenic.PubSub.subscribe(:slide_state)

    socket =
      socket
      |> Map.put(:state, Scenic.PubSub.get(:slide_state))
      |> Map.put(:preview_deck_id, nil)
      |> Map.put(:preview_slide_id, nil)

    send(self(), :after_init)

    {:ok, socket}
  end

  @impl Phoenix.Socket.Transport
  def terminate(_reason, _socket) do
    Scenic.PubSub.unsubscribe(:slide_state)

    :ok
  end

  defp encode_state(
         %{state: state, preview_deck_id: preview_deck_id, preview_slide_id: preview_slide_id} =
           socket
       ) do
    message =
      state
      |> Map.from_struct()
      |> Map.put(:preview_deck_id, preview_deck_id)
      |> Map.put(:preview_slide_id, preview_slide_id)
      |> Poison.encode!()

    {:binary, message}
  end

  defp push_state(socket) do
    {:push, encode_state(socket), socket}
  end

  defp reply_state(socket) do
    {:reply, :ok, encode_state(socket), socket}
  end

  @impl Phoenix.Socket.Transport
  def handle_info(:after_init, socket) do
    send(self(), :after_init2)
    push_state(socket)
  end

  @impl Phoenix.Socket.Transport
  def handle_info(:after_init2, socket) do
    IO.inspect(self())
    {:push, {:text, to_string(:erlang.pid_to_list(self()))}, socket}
  end

  @impl Phoenix.Socket.Transport
  def handle_info(
        {{Scenic.PubSub, :data},
         {:slide_state,
          %Slides.State{
            decks: decks,
            service_details: service_details,
            upcoming_services: upcoming_services
          } = state, _timestamp}},
        %{preview_deck_id: preview_deck_id, preview_slide_id: preview_slide_id} = socket
      ) do
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("go_live", %{
      deck: decks[preview_deck_id],
      slide_id: preview_slide_id,
      quiet: true
    })

    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("service_details", service_details)
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("upcoming_services", upcoming_services)

    socket = %{socket | state: state}

    push_state(socket)
  end

  def handle_in(%{"preview_deck" => preview_deck_id}, %{state: state} = socket) do
    preview_slide_id = preview_deck(preview_deck_id, state)

    socket = %{socket | preview_deck_id: preview_deck_id, preview_slide_id: preview_slide_id}

    reply_state(socket)
  end

  def handle_in(
        %{"preview_slide" => preview_slide_id},
        %{state: %Slides.State{decks: decks}, preview_deck_id: preview_deck_id} = socket
      ) do
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("go_live", %{
      deck: decks[preview_deck_id],
      slide_id: preview_slide_id,
      quiet: true
    })

    socket = %{socket | preview_slide_id: preview_slide_id}

    reply_state(socket)
  end

  def handle_in(
        %{"go_live" => %{"deck_id" => deck_id, "slide_id" => slide_id, "quiet" => quiet}},
        socket
      ) do
    Slides.go_live(deck_id, slide_id, quiet)
    {:ok, socket}
  end

  @impl true
  def handle_in(%{"live_slide" => id}, socket) do
    Slides.live_slide(id)
    {:ok, socket}
  end

  @impl true
  def handle_in(%{"close_live" => %{}}, socket) do
    Slides.close_live()
    {:ok, socket}
  end

  @impl Phoenix.Socket.Transport
  def handle_in({msg, _opts}, socket) do
    handle_in(Poison.decode!(msg), socket)
  end

  def handle_info(
        :update_preview,
        %{
          state: %{decks: decks},
          preview_deck_id: preview_deck_id,
          preview_slide_id: preview_slide_id
        } = socket
      ) do
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("go_live", %{
      deck: decks[preview_deck_id],
      slide_id: preview_slide_id,
      quiet: true
    })

    BreakingCuesWeb.OutputChannel.broadcast_preview_msg(
      "service_details",
      Slides.get_service_details()
    )

    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("service_details_shown", %{value: false})

    BreakingCuesWeb.OutputChannel.broadcast_preview_msg(
      "upcoming_services",
      Slides.get_upcoming_services()
    )

    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("upcoming_services_shown", %{value: false})

    {:ok, socket}
  end
end
