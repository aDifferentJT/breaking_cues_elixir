defmodule BreakingCuesWeb.ControlPanel do
  # use Phoenix.LiveView, layout: {BreakingCuesWeb.LayoutView, "live.html"}
  use Phoenix.LiveView
  import Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  import Controller

  def formatting_controls(assigns) do
    ~H"""
    <div class="input-group input-group-sm mb-2">
      <span class="input-group-text">Background</span>
      <span class="input-group-text">Colour</span>
      <%= color_input(@f, :bg_colour,
        value: @formatting.bg_colour,
        disabled: @disabled,
        class: "form-control form-control-color flex-grow-0",
        style: "min-width:50px;"
      ) %>
      <span class="input-group-text">Alpha</span>
      <span class="input-group-text">
        <%= Integer.to_string(@formatting.bg_alpha, 16) %>
      </span>
      <%= range_input(@f, :bg_alpha,
        value: @formatting.bg_alpha,
        min: 0,
        max: 255,
        disabled: @disabled,
        class: "form-control form-range",
        style: "height:31px;"
      ) %>
    </div>
    <div class="input-group input-group-sm mt-2 mb-2">
      <span class="input-group-text">Text</span>
      <span class="input-group-text">Colour</span>
      <%= color_input(@f, :text_colour,
        value: @formatting.text_colour,
        disabled: @disabled,
        class: "form-control form-control-color flex-grow-0",
        style: "min-width:50px;"
      ) %>
      <span class="input-group-text">Alpha</span>
      <span class="input-group-text">
        <%= Integer.to_string(@formatting.text_alpha, 16) %>
      </span>
      <%= range_input(@f, :text_alpha,
        value: @formatting.text_alpha,
        min: 0,
        max: 255,
        disabled: @disabled,
        class: "form-control form-range",
        style: "height:31px;"
      ) %>
    </div>
    <div class="input-group input-group-sm mt-2 mb-2">
      <span class="input-group-text">Lines</span>
      <span class="input-group-text">
        <%= Integer.to_string(@formatting.lines_size) %>
      </span>
      <%= range_input(@f, :lines_size,
        value: @formatting.lines_size,
        min: 1,
        max: 128,
        disabled: @disabled,
        class: "form-control form-range",
        style: "height:31px;"
      ) %>
    </div>
    <div class="input-group input-group-sm mt-2">
      <span class="input-group-text">Paragraphs</span>
      <span class="input-group-text">
        <%= Integer.to_string(@formatting.paragraphs_size) %>
      </span>
      <%= range_input(@f, :paragraphs_size,
        value: @formatting.paragraphs_size,
        min: 1,
        max: 128,
        disabled: @disabled,
        class: "form-control form-range",
        style: "height:31px;"
      ) %>
    </div>
    """
  end

  def mount(_params, session, socket) do
    Scenic.PubSub.subscribe(:slide_state)
    Scenic.PubSub.subscribe(:bible_versions)
    Scenic.PubSub.subscribe(:psalters)

    BreakingCuesWeb.Endpoint.subscribe("all_previews")

    socket =
      socket
      |> assign(:pid, self())
      |> assign(:state, Scenic.PubSub.get(:slide_state))
      |> assign(:bible_versions, Scenic.PubSub.get(:bible_versions))
      |> assign(:psalters, Scenic.PubSub.get(:psalters))
      |> assign(:preview_deck_id, nil)
      |> assign(:preview_slide_id, nil)
      |> assign(:editing, false)
      |> assign(:editing_service_details, false)
      |> assign(:editing_upcoming_services, false)
      |> assign(:modal, nil)
      |> assign(:preview_preview, true)
      |> assign(:live_preview, false)
      |> allow_upload(:programme, accept: :any, auto_upload: true, progress: &handle_progress/3)
      |> allow_upload(:deck, accept: :any, auto_upload: true, progress: &handle_progress/3)

    {:ok, socket}
  end

  defp handle_progress(:programme, entry, socket) do
    if entry.done? do
      programme = consume_uploaded_entry(socket, entry, &File.read!(&1.path))
      programme = Poison.decode!(programme, keys: :atoms!)
      Slides.set_programme(programme)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp handle_progress(:deck, entry, %{assigns: %{preview_deck_id: preview_deck_id}} = socket) do
    if entry.done? do
      deck = consume_uploaded_entry(socket, entry, &File.read!(&1.path))
      deck = Poison.decode!(deck, keys: :atoms!)
      deck = Slides.Deck.decode(deck)
      Slides.add_deck(deck, preview_deck_id)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("programme_upload", _, socket) do
    {:noreply, socket}
  end

  def handle_event("deck_upload", _, socket) do
    {:noreply, socket}
  end

  @impl GenServer
  def handle_info(
        :update_preview,
        %{
          assigns: %{
            state: %Slides.State{decks: decks, default_formatting: default_formatting},
            preview_deck_id: preview_deck_id,
            preview_slide_id: preview_slide_id
          }
        } = socket
      ) do
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("go_live", %{
      deck: decks[preview_deck_id],
      slide_id: preview_slide_id,
      quiet: true,
      default_formatting: default_formatting
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

    {:noreply, socket}
  end

  @impl GenServer
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "preview_deck", payload: preview_deck_id},
        %{assigns: %{state: state}} = socket
      ) do
    preview_slide_id = preview_deck(preview_deck_id, state)

    socket =
      socket
      |> assign(:preview_deck_id, preview_deck_id)
      |> assign(:preview_slide_id, preview_slide_id)
      |> assign(:editing_service_details, false)
      |> assign(:editing_upcoming_services, false)

    {:noreply, socket}
  end

  @impl GenServer
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "notify_live", payload: live_deck_id},
        %{
          assigns: %{
            state: %Slides.State{
              decks: decks,
              deck_order: deck_order,
              default_formatting: default_formatting
            },
            preview_deck_id: preview_deck_id
          }
        } = socket
      ) do
    if preview_deck_id == live_deck_id or preview_deck_id == nil do
      preview_deck_id =
        Enum.at(deck_order, Enum.find_index(deck_order, &(&1 == live_deck_id)) + 1)

      preview_slide_id = Slides.default_slide(decks[preview_deck_id])

      case decks[preview_deck_id] do
        nil ->
          BreakingCuesWeb.OutputChannel.broadcast_preview_msg("close_live", %{})

        preview_deck ->
          BreakingCuesWeb.OutputChannel.broadcast_preview_msg("go_live", %{
            deck: preview_deck,
            slide_id: preview_slide_id,
            quiet: false,
            default_formatting: default_formatting
          })
      end

      socket =
        socket
        |> assign(:preview_deck_id, preview_deck_id)
        |> assign(:preview_slide_id, preview_slide_id)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "preview_deck",
        %{"id" => preview_deck_id},
        %{assigns: %{state: state}} = socket
      ) do
    preview_slide_id = preview_deck(preview_deck_id, state)

    socket =
      socket
      |> assign(:preview_deck_id, preview_deck_id)
      |> assign(:preview_slide_id, preview_slide_id)
      |> assign(:editing_service_details, false)
      |> assign(:editing_upcoming_services, false)

    {:noreply, socket}
  end

  def handle_event(
        "preview_slide",
        %{"id" => preview_slide_id},
        %{
          assigns: %{
            state: %Slides.State{decks: decks, default_formatting: default_formatting},
            preview_deck_id: preview_deck_id
          }
        } = socket
      ) do
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("go_live", %{
      deck: decks[preview_deck_id],
      slide_id: preview_slide_id,
      quiet: true,
      default_formatting: default_formatting
    })

    socket = socket |> assign(:preview_slide_id, preview_slide_id)

    {:noreply, socket}
  end

  def handle_event("show_settings_modal", _, socket) do
    socket = socket |> assign(:modal, :settings)
    {:noreply, socket}
  end

  def handle_event("show_bible_version_modal", _, socket) do
    socket = socket |> assign(:modal, :bible_version)
    {:noreply, socket}
  end

  def handle_event("show_bible_modal", _, socket) do
    socket = socket |> assign(:modal, :bible)
    {:noreply, socket}
  end

  def handle_event("show_psalm_modal", _, socket) do
    socket = socket |> assign(:modal, :psalm)
    {:noreply, socket}
  end

  def handle_event("hide_modal", _, socket) do
    socket = socket |> assign(:modal, nil)
    {:noreply, socket}
  end

  def handle_event("add_deck", _, %{assigns: %{preview_deck_id: preview_deck_id}} = socket) do
    Slides.add_deck(%Slides.Deck{}, preview_deck_id)
    {:noreply, socket}
  end

  def handle_event("add_bible_version", %{"bible" => %{"id" => id, "path" => path}}, socket) do
    Bibles.add_bible(id, path)
    {:noreply, socket}
  end

  def handle_event(
        "add_bible",
        %{"bible" => %{"version" => version, "ref" => ref}},
        %{assigns: %{preview_deck_id: preview_deck_id}} = socket
      ) do
    Slides.add_deck(Slides.Deck.bible(version, ref), preview_deck_id)
    {:noreply, socket}
  end

  def handle_event(
        "add_psalm",
        %{
          "psalm" => %{
            "version" => version,
            "psalm_num" => psalm_num,
            "verse_start" => verse_start,
            "verse_end" => verse_end
          }
        },
        %{assigns: %{preview_deck_id: preview_deck_id}} = socket
      ) do
    psalm_num = String.to_integer(psalm_num)
    verse_start = String.to_integer(verse_start)

    verse_end =
      case verse_end do
        "end" -> :end
        _ -> String.to_integer(verse_end)
      end

    Slides.add_deck(
      Slides.Deck.psalm(version, psalm_num, verse_start, verse_end),
      preview_deck_id
    )

    {:noreply, socket}
  end

  def handle_event("remove-deck", %{"id" => id}, socket) do
    Slides.remove_deck(id)
    {:noreply, socket}
  end

  def handle_event("move-deck-up", %{"id" => id}, socket) do
    Slides.move_deck_up(id)
    {:noreply, socket}
  end

  def handle_event("move-deck-down", %{"id" => id}, socket) do
    Slides.move_deck_down(id)
    {:noreply, socket}
  end

  def handle_event(
        "go_live",
        %{"deck_id" => deck_id, "slide_id" => slide_id, "quiet" => quiet},
        socket
      ) do
    Slides.go_live(deck_id, slide_id, quiet)
    {:noreply, socket}
  end

  def handle_event("close_live", _, socket) do
    Slides.close_live()
    {:noreply, socket}
  end

  def handle_event("live_slide", %{"id" => id}, socket) do
    Slides.live_slide(id)
    {:noreply, socket}
  end

  def handle_event("edit", _, socket) do
    socket = socket |> assign(:editing, true)
    {:noreply, socket}
  end

  def handle_event("done-editing", _, socket) do
    socket = socket |> assign(:editing, false)
    {:noreply, socket}
  end

  def handle_event(
        "editing-changes",
        %{
          "editing" =>
            changes = %{
              "title" => title,
              "subtitle" => subtitle,
              "heading_style" => heading_style,
              "style" => style,
              "default_formatting" => default_formatting,
              "body" => body
            }
        },
        %{assigns: %{preview_deck_id: preview_deck_id}} = socket
      ) do
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

    formatting =
      case {default_formatting, changes} do
        {"true", _} ->
          :default

        {"false",
         %{
           "bg_colour" => bg_colour,
           "bg_alpha" => bg_alpha,
           "text_colour" => text_colour,
           "text_alpha" => text_alpha,
           "lines_size" => lines_size,
           "paragraphs_size" => paragraphs_size
         }} ->
          {bg_alpha, ""} = Integer.parse(bg_alpha)
          {text_alpha, ""} = Integer.parse(text_alpha)
          {lines_size, ""} = Integer.parse(lines_size)
          {paragraphs_size, ""} = Integer.parse(paragraphs_size)

          %Slides.Formatting{
            bg_colour: bg_colour,
            bg_alpha: bg_alpha,
            text_colour: text_colour,
            text_alpha: text_alpha,
            lines_size: lines_size,
            paragraphs_size: paragraphs_size
          }

        {"false", _} ->
          %Slides.Formatting{}
      end

    deck = Slides.from_editable(title, subtitle, heading_style, style, formatting, body)

    Slides.replace_deck(preview_deck_id, deck)
    {:noreply, socket}
  end

  def handle_event(
        "default_formatting",
        %{
          "default_formatting" =>
            changes = %{
              "bg_colour" => bg_colour,
              "bg_alpha" => bg_alpha,
              "text_colour" => text_colour,
              "text_alpha" => text_alpha,
              "lines_size" => lines_size,
              "paragraphs_size" => paragraphs_size
            }
        },
        socket
      ) do
    {bg_alpha, ""} = Integer.parse(bg_alpha)
    {text_alpha, ""} = Integer.parse(text_alpha)
    {lines_size, ""} = Integer.parse(lines_size)
    {paragraphs_size, ""} = Integer.parse(paragraphs_size)

    Slides.default_formatting(%Slides.Formatting{
      bg_colour: bg_colour,
      bg_alpha: bg_alpha,
      text_colour: text_colour,
      text_alpha: text_alpha,
      lines_size: lines_size,
      paragraphs_size: paragraphs_size
    })

    {:noreply, socket}
  end

  def handle_event("toggle_service_details", _, socket) do
    Slides.toggle_service_details()
    {:noreply, socket}
  end

  def handle_event("edit_service_details", _, socket) do
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("close_live", %{})

    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("upcoming_services_shown", %{value: false})

    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("service_details_shown", %{value: true})

    socket =
      socket
      |> assign(:preview_deck_id, nil)
      |> assign(:editing_service_details, true)
      |> assign(:editing_upcoming_services, false)

    {:noreply, socket}
  end

  def handle_event(
        "service_details_changes",
        %{
          "service_details" => %{
            "title" => title,
            "subtitle1" => subtitle1,
            "subtitle2" => subtitle2,
            "timer_caption" => timer_caption,
            "timer_destination" => timer_destination
          }
        },
        socket
      ) do
    Slides.set_service_details(title, subtitle1, subtitle2, timer_caption, timer_destination)
    {:noreply, socket}
  end

  def handle_event("toggle_upcoming_services", _, socket) do
    Slides.toggle_upcoming_services()
    {:noreply, socket}
  end

  def handle_event("edit_upcoming_services", _, socket) do
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("close_live", %{})
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("service_details_shown", %{value: false})
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("upcoming_services_shown", %{value: true})

    socket =
      socket
      |> assign(:preview_deck_id, nil)
      |> assign(:editing_service_details, false)
      |> assign(:editing_upcoming_services, true)

    {:noreply, socket}
  end

  def handle_event(
        "upcoming_services_changes",
        %{
          "upcoming_services" => %{
            "title1" => title1,
            "title2" => title2
          }
        },
        socket
      ) do
    Slides.set_upcoming_services(title1, title2)
    {:noreply, socket}
  end

  def handle_event(
        "previews",
        %{"previews" => %{"preview" => preview, "live" => live}},
        %{assigns: %{preview_preview: preview_preview, live_preview: live_preview}} = socket
      ) do
    preview =
      case preview do
        "true" -> true
        "false" -> false
      end

    live =
      case live do
        "true" -> true
        "false" -> false
      end

    socket =
      socket
      |> assign(:preview_preview, preview)
      |> assign(:live_preview, live)

    {:noreply, socket}
  end

  def handle_info(
        {{Scenic.PubSub, :data},
         {:slide_state,
          %Slides.State{
            decks: decks,
            default_formatting: default_formatting,
            service_details: service_details,
            upcoming_services: upcoming_services
          } = state, _timestamp}},
        %{
          assigns: %{
            preview_deck_id: preview_deck_id,
            preview_slide_id: preview_slide_id
          }
        } = socket
      ) do
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("go_live", %{
      deck: decks[preview_deck_id],
      slide_id: preview_slide_id,
      quiet: true,
      default_formatting: default_formatting
    })

    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("service_details", service_details)
    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("upcoming_services", upcoming_services)

    socket = socket |> assign(:state, state)

    {:noreply, socket}
  end

  def handle_info({{Scenic.PubSub, :data}, {:bible_versions, versions, _timestamp}}, socket) do
    socket = socket |> assign(:bible_versions, versions)
    {:noreply, socket}
  end

  def handle_info({{Scenic.PubSub, :data}, {:psalters, versions, _timestamp}}, socket) do
    socket = socket |> assign(:psalters, versions)
    {:noreply, socket}
  end
end
