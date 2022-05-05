defmodule Slides do
  use GenServer

  defmodule Formatting do
    @derive Jason.Encoder
    @derive Poison.Encoder

    defstruct bg_colour: "#206080",
              bg_alpha: 0xC0,
              text_colour: "#ffffff",
              text_alpha: 0xFF,
              lines_size: 40,
              paragraphs_size: 30

    def fill_default(:default, default), do: default
    def fill_default(formatting, _), do: formatting

    def decode("default"), do: :default

    def decode(%{
          bg_colour: bg_colour,
          bg_alpha: bg_alpha,
          text_colour: text_colour,
          text_alpha: text_alpha,
          lines_size: lines_size,
          paragraphs_size: paragraphs_size
        }) do
      %Formatting{
        bg_colour: bg_colour,
        bg_alpha: bg_alpha,
        text_colour: text_colour,
        text_alpha: text_alpha,
        lines_size: lines_size,
        paragraphs_size: paragraphs_size
      }
    end
  end

  defmodule Deck do
    @derive Jason.Encoder
    @derive Poison.Encoder

    defstruct title: "",
              subtitle: "",
              heading_style: :default,
              style: :lines,
              slides: [],
              formatting: :default

    def decode(%{
          title: title,
          subtitle: subtitle,
          heading_style: heading_style,
          style: style,
          slides: slides,
          formatting: formatting
        }) do
      heading_style =
        case heading_style do
          "default" ->
            :default

          "hold" ->
            :hold

          "skip" ->
            :skip

          "quiet_skip" ->
            :quiet_skip

          _ ->
            IO.puts("Invalid heading style: #{heading_style}")
            :default
        end

      style =
        case style do
          "lines" ->
            :lines

          "paragraphs" ->
            :paragraphs

          _ ->
            IO.puts("Invalid style: #{style}")
            :lines
        end

      formatting = Formatting.decode(formatting)

      %Deck{
        title: title,
        subtitle: subtitle,
        heading_style: heading_style,
        style: style,
        slides: slides,
        formatting: formatting
      }
    end

    def bible(version, ref) do
      %Deck{
        title: ref,
        subtitle: version,
        heading_style: :default,
        style: :paragraphs,
        slides: Enum.chunk_every(Enum.map(Bibles.lookup(version, ref), &[&1]), 3)
      }
    end

    def psalm(version, psalm_num, verse_start, verse_end) do
      %Deck{
        title:
          if verse_end == :end do
            if verse_start == 1 do
              "Psalm #{psalm_num}"
            else
              "Psalm #{psalm_num}: #{verse_start} - end"
            end
          else
            "Psalm #{psalm_num}: #{verse_start} - #{verse_end}"
          end,
        subtitle: version,
        heading_style: :default,
        style: :lines,
        slides:
          Enum.map(Psalms.lookup(version, psalm_num, verse_start, verse_end), fn verse ->
            [line1, line2] = String.split(verse, " : ", parts: 2)
            [line1, ": #{line2}"]
          end)
      }
    end
  end

  defmodule ServiceDetails do
    @derive Jason.Encoder

    defstruct title: "Title",
              subtitle1: "Subtitle 1",
              subtitle2: "Subtitle 2",
              timer_caption: "The service begins in",
              timer_destination: "",
              formatting: :default
  end

  defmodule UpcomingServices do
    @derive Jason.Encoder

    defstruct title1: "Title 1",
              title2: "Title 2"
  end

  defmodule State do
    @derive Jason.Encoder

    defstruct decks: %{},
              deck_order: [],
              next_deck_id: 0,
              live_deck: nil,
              live_slide_id: 0,
              default_formatting: %Formatting{},
              live_default_formatting: %Formatting{},
              service_details: %ServiceDetails{},
              service_details_shown: false,
              upcoming_services: %UpcomingServices{},
              upcoming_services_shown: false
  end

  # Client

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def get_programme() do
    GenServer.call(__MODULE__, :get_programme)
  end

  def set_programme(programme) do
    GenServer.cast(__MODULE__, {:set_programme, programme})
  end

  def new_deck_id() do
    GenServer.call(__MODULE__, :new_deck_id)
  end

  def get_deck(id) do
    GenServer.call(__MODULE__, {:get_deck, id})
  end

  def get_live() do
    GenServer.call(__MODULE__, :get_live)
  end

  def go_live(deck_id, slide_id, quiet) do
    GenServer.cast(__MODULE__, {:go_live, deck_id, slide_id, quiet})
  end

  def close_live() do
    GenServer.cast(__MODULE__, :close_live)
  end

  def live_slide(slide) do
    GenServer.cast(__MODULE__, {:live_slide, slide})
  end

  def previous_event() do
    GenServer.cast(__MODULE__, :previous_event)
  end

  def next_event() do
    GenServer.cast(__MODULE__, :next_event)
  end

  def replace_deck(id, deck) do
    GenServer.cast(__MODULE__, {:replace_deck, id, deck})
  end

  def add_deck(deck, after_deck_id) do
    GenServer.cast(__MODULE__, {:add_deck, deck, after_deck_id})
  end

  def remove_deck(id) do
    GenServer.cast(__MODULE__, {:remove_deck, id})
  end

  def move_deck_up(id) do
    GenServer.cast(__MODULE__, {:move_deck_up, id})
  end

  def move_deck_down(id) do
    GenServer.cast(__MODULE__, {:move_deck_down, id})
  end

  def get_service_details() do
    GenServer.call(__MODULE__, :get_service_details)
  end

  def set_service_details(
        title,
        subtitle1,
        subtitle2,
        timer_caption,
        timer_destination,
        formatting
      ) do
    GenServer.cast(
      __MODULE__,
      {:set_service_details, title, subtitle1, subtitle2, timer_caption, timer_destination,
       formatting}
    )
  end

  def get_service_details_shown() do
    GenServer.call(__MODULE__, :get_service_details_shown)
  end

  def hide_service_details() do
    GenServer.cast(__MODULE__, :hide_service_details)
  end

  def toggle_service_details() do
    GenServer.cast(__MODULE__, :toggle_service_details)
  end

  def get_upcoming_services() do
    GenServer.call(__MODULE__, :get_upcoming_services)
  end

  def set_upcoming_services(title1, title2) do
    GenServer.cast(
      __MODULE__,
      {:set_upcoming_services, title1, title2}
    )
  end

  def get_upcoming_services_shown() do
    GenServer.call(__MODULE__, :get_upcoming_services_shown)
  end

  def hide_upcoming_services() do
    GenServer.cast(__MODULE__, :hide_upcoming_services)
  end

  def toggle_upcoming_services() do
    GenServer.cast(__MODULE__, :toggle_upcoming_services)
  end

  def default_formatting(default_formatting) do
    GenServer.cast(__MODULE__, {:default_formatting, default_formatting})
  end

  def to_string(:lines, lines) do
    Enum.join(lines, "\n")
  end

  def to_string(:paragraphs, paragraphs) do
    Enum.join(Enum.map(paragraphs, &Enum.join(&1, "\n")), "\n\n")
  end

  def to_editable(%Deck{style: :lines, slides: slides}) do
    Enum.join(Enum.map(slides, &Enum.join(&1, "\n")), "\n\n")
  end

  def to_editable(%Deck{style: :paragraphs, slides: slides}) do
    Enum.join(
      Enum.map(slides, fn slide ->
        Enum.join(Enum.map(slide, &Enum.join(&1, "\n")), "\n\n")
      end),
      "\n\n\n"
    )
  end

  def from_editable(title, subtitle, heading_style, :lines, formatting, body) do
    %Slides.Deck{
      title: title,
      subtitle: subtitle,
      heading_style: heading_style,
      style: :lines,
      formatting: formatting,
      slides:
        if body == "" do
          []
        else
          Enum.map(String.split(body, "\n\n"), &String.split(&1, "\n"))
        end
    }
  end

  def from_editable(title, subtitle, heading_style, :paragraphs, formatting, body) do
    %Slides.Deck{
      title: title,
      subtitle: subtitle,
      heading_style: heading_style,
      style: :paragraphs,
      formatting: formatting,
      slides:
        if body == "" do
          []
        else
          Enum.map(String.split(body, "\n\n\n"), fn slide ->
            Enum.map(String.split(slide, "\n\n"), fn paragraph ->
              String.split(paragraph, "\n")
            end)
          end)
        end
    }
  end

  def to_json(deck) do
    Poison.encode!(deck)
  end

  def from_json(data) do
    deck = Poison.encode!(data, as: %Deck{})

    deck = %{
      deck
      | style:
          case deck.style do
            "lines" ->
              :lines

            "paragraphs" ->
              :paragraphs

            _ ->
              IO.puts("Invalid style: #{deck.style}")
              :lines
          end
    }

    deck
  end

  def previous_slide(nil, _slide_id) do
    nil
  end

  def previous_slide(_deck, 0) do
    "title"
  end

  def previous_slide(_deck, slide_id) when is_number(slide_id) and slide_id > 0 do
    slide_id - 1
  end

  def previous_slide(_deck, "title") do
    nil
  end

  def previous_slide(_deck, nil) do
    nil
  end

  def next_slide(nil, _slide_id) do
    nil
  end

  def next_slide(deck, slide_id) do
    num_slides = Enum.count(deck.slides)

    case slide_id do
      n when is_number(n) and n + 1 < num_slides ->
        n + 1

      n when is_number(n) and n + 1 >= num_slides ->
        nil

      "title" when num_slides > 0 ->
        0

      "title" when num_slides == 0 ->
        nil

      nil ->
        false
    end
  end

  def default_slide(%Deck{slides: []}) do
    "title"
  end

  def default_slide(%Deck{heading_style: :hold}) do
    "title"
  end

  def default_slide(_) do
    0
  end

  # Server (callbacks)

  @impl true
  def init([]) do
    send(self(), :after_init)
    {:ok, %State{}}
  end

  def handle_info(
        :after_init,
        %State{live_deck: live_deck, live_slide_id: live_slide_id} = state
      ) do
    Scenic.PubSub.register(:slide_state)
    Scenic.PubSub.publish(:slide_state, state)

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_call(
        :get_programme,
        _,
        %State{
          decks: decks,
          deck_order: deck_order,
          default_formatting: default_formatting,
          service_details: service_details
        } = state
      ) do
    {:reply,
     %{
       decks: Enum.map(deck_order, &decks[&1]),
       default_formatting: default_formatting,
       service_details: service_details
     }, state}
  end

  @impl GenServer
  def handle_call(:new_deck_id, _, %State{next_deck_id: next_deck_id} = state) do
    new_deck_id = next_deck_id
    state = %{state | next_deck_id: next_deck_id + 1}
    Scenic.PubSub.publish(:slide_state, state)
    {:reply, new_deck_id, state}
  end

  @impl GenServer
  def handle_call({:get_deck, id}, _, %State{decks: decks} = state) do
    {:reply, decks[id], state}
  end

  @impl GenServer
  def handle_call(
        :get_live,
        _,
        %State{live_deck: live_deck, live_slide_id: live_slide_id} = state
      ) do
    {:reply, %{deck: live_deck, slide_id: live_slide_id, quiet: true}, state}
  end

  @impl GenServer
  def handle_cast(
        {:set_programme,
         %{
           decks: programme,
           default_formatting: default_formatting,
           service_details: service_details
         }},
        state
      ) do
    decks = Map.new(Enum.with_index(programme, &{&2, Deck.decode(&1)}))
    deck_order = Enum.to_list(0..(Enum.count(programme) - 1))
    next_deck_id = Enum.count(programme)

    default_formatting = Formatting.decode(default_formatting)

    state = %{
      state
      | decks: decks,
        deck_order: deck_order,
        next_deck_id: next_deck_id,
        default_formatting: default_formatting,
        service_details: service_details
    }

    BreakingCuesWeb.Endpoint.broadcast!("all_previews", "preview_deck", nil)

    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(
        {:go_live, live_deck_id, live_slide_id, quiet},
        %State{
          decks: decks,
          deck_order: deck_order,
          default_formatting: default_formatting
        } = state
      ) do
    live_deck = decks[live_deck_id]
    live_slide_id = live_slide_id || default_slide(live_deck)

    state = %{
      state
      | live_deck: live_deck,
        live_slide_id: live_slide_id,
        live_default_formatting: default_formatting
    }

    Scenic.PubSub.publish(:slide_state, state)

    BreakingCuesWeb.Endpoint.broadcast!("all_previews", "notify_live", live_deck_id)

    BreakingCuesWeb.OutputChannel.broadcast_msg("go_live", %{
      deck: live_deck,
      slide_id: live_slide_id,
      quiet: quiet,
      default_formatting: default_formatting
    })

    {:noreply, state}
  end

  @impl true
  def handle_cast(:close_live, state) do
    live_deck = nil
    live_slide_id = 0
    state = %{state | live_deck: live_deck, live_slide_id: live_slide_id}
    Scenic.PubSub.publish(:slide_state, state)
    BreakingCuesWeb.OutputChannel.broadcast_msg("close_live", %{})
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:live_slide, live_slide_id},
        %State{
          decks: decks,
          live_deck: live_deck,
          live_default_formatting: live_default_formatting
        } = state
      ) do
    state = %{
      state
      | live_slide_id: live_slide_id,
        live_default_formatting: live_default_formatting
    }

    Scenic.PubSub.publish(:slide_state, state)

    BreakingCuesWeb.OutputChannel.broadcast_msg("go_live", %{
      deck: live_deck,
      slide_id: live_slide_id,
      quiet: true,
      default_formatting: live_default_formatting
    })

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        :previous_event,
        %State{live_deck: live_deck, live_slide_id: live_slide_id} = state
      ) do
    case previous_slide(live_deck, live_slide_id) do
      nil -> {:noreply, state}
      slide -> handle_cast({:live_slide, slide}, state)
    end
  end

  @impl true
  def handle_cast(
        :next_event,
        %State{
          live_deck: live_deck,
          live_slide_id: live_slide_id
        } = state
      ) do
    # TODO
    preview_deck_id = 0

    case next_slide(live_deck, live_slide_id) do
      nil ->
        if live_deck == nil do
          # TODO
          if preview_deck_id == nil do
            handle_cast({:go_live, 0, nil, false}, state)
          else
            handle_cast({:go_live, preview_deck_id, 0, false}, state)
          end
        else
          handle_cast(:close_live, state)
        end

      slide ->
        handle_cast({:live_slide, slide}, state)
    end
  end

  @impl true
  def handle_cast(
        {:replace_deck, id, deck},
        %State{decks: decks} = state
      ) do
    decks = %{decks | id => deck}
    state = %{state | decks: decks}

    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:add_deck, deck, after_deck_id},
        %State{decks: decks, deck_order: deck_order, next_deck_id: next_deck_id} = state
      ) do
    decks = Map.put(decks, next_deck_id, deck)

    deck_order =
      List.insert_at(
        deck_order,
        (Enum.find_index(deck_order, &(&1 == after_deck_id)) || -2) + 1,
        next_deck_id
      )

    next_deck_id = next_deck_id + 1
    state = %{state | decks: decks, deck_order: deck_order, next_deck_id: next_deck_id}
    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:remove_deck, id},
        %State{decks: decks, deck_order: deck_order} = state
      ) do
    decks = Map.delete(decks, id)
    deck_order = List.delete(deck_order, id)
    state = %{state | decks: decks, deck_order: deck_order}
    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  def move_up([], _), do: []
  def move_up([x0 | [x1 | xs]], x1), do: [x1 | [x0 | xs]]
  def move_up([x | xs], y), do: [x | move_up(xs, y)]

  def move_down([], _), do: []
  def move_down([x0 | [x1 | xs]], x0), do: [x1 | [x0 | xs]]
  def move_down([x | xs], y), do: [x | move_down(xs, y)]

  @impl true
  def handle_cast(
        {:move_deck_up, id},
        %State{deck_order: deck_order} = state
      ) do
    deck_order = move_up(deck_order, id)
    state = %{state | deck_order: deck_order}
    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:move_deck_down, id},
        %State{deck_order: deck_order} = state
      ) do
    deck_order = move_down(deck_order, id)
    state = %{state | deck_order: deck_order}
    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  @impl true
  def handle_call(
        :get_service_details,
        _,
        %State{service_details: service_details} = state
      ) do
    {:reply, service_details, state}
  end

  @impl true
  def handle_cast(
        {:set_service_details, title, subtitle1, subtitle2, timer_caption, timer_destination, formatting},
        %State{service_details: service_details} = state
      ) do
    service_details = %ServiceDetails{
      title: title,
      subtitle1: subtitle1,
      subtitle2: subtitle2,
      timer_caption: timer_caption,
      timer_destination: timer_destination,
      formatting: formatting
    }

    state = %{state | service_details: service_details}

    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  @impl true
  def handle_call(
        :get_service_details_shown,
        _,
        %State{service_details_shown: service_details_shown} = state
      ) do
    {:reply, service_details_shown, state}
  end

  @impl true
  def handle_cast(:hide_service_details, state) do
    service_details_shown = false
    state = %{state | service_details_shown: service_details_shown}

    BreakingCuesWeb.OutputChannel.broadcast_msg("service_details_shown", %{
      value: service_details_shown
    })

    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        :toggle_service_details,
        %State{
          default_formatting: default_formatting,
          service_details: service_details,
          service_details_shown: service_details_shown
        } = state
      ) do
    service_details_shown = !service_details_shown
    state = %{state | service_details_shown: service_details_shown}

    if service_details_shown do
      hide_upcoming_services()

      BreakingCuesWeb.OutputChannel.broadcast_msg("service_details", %{
        service_details: service_details,
        default_formatting: default_formatting
      })
    end

    BreakingCuesWeb.OutputChannel.broadcast_msg("service_details_shown", %{
      value: service_details_shown
    })

    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  @impl true
  def handle_call(
        :get_upcoming_services,
        _,
        %State{upcoming_services: upcoming_services} = state
      ) do
    {:reply, upcoming_services, state}
  end

  @impl true
  def handle_cast(
        {:set_upcoming_services, title1, title2},
        %State{upcoming_services: upcoming_services} = state
      ) do
    upcoming_services = %UpcomingServices{
      title1: title1,
      title2: title2
    }

    state = %{state | upcoming_services: upcoming_services}

    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  @impl true
  def handle_call(
        :get_upcoming_services_shown,
        _,
        %State{upcoming_services_shown: upcoming_services_shown} = state
      ) do
    {:reply, upcoming_services_shown, state}
  end

  @impl true
  def handle_cast(:hide_upcoming_services, state) do
    upcoming_services_shown = false
    state = %{state | upcoming_services_shown: upcoming_services_shown}

    BreakingCuesWeb.OutputChannel.broadcast_msg("upcoming_services_shown", %{
      value: upcoming_services_shown
    })

    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        :toggle_upcoming_services,
        %State{
          upcoming_services: upcoming_services,
          upcoming_services_shown: upcoming_services_shown
        } = state
      ) do
    upcoming_services_shown = !upcoming_services_shown
    state = %{state | upcoming_services_shown: upcoming_services_shown}

    if upcoming_services_shown do
      hide_service_details()
      BreakingCuesWeb.OutputChannel.broadcast_msg("upcoming_services", upcoming_services)
    end

    BreakingCuesWeb.OutputChannel.broadcast_msg("upcoming_services_shown", %{
      value: upcoming_services_shown
    })

    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:default_formatting, default_formatting}, state) do
    state = %{state | default_formatting: default_formatting}

    Scenic.PubSub.publish(:slide_state, state)
    {:noreply, state}
  end
end
