defmodule Controller do
  def preview_deck(
        preview_deck_id,
        %Slides.State{decks: decks, default_formatting: default_formatting}
      ) do
    preview_slide_id = Slides.default_slide(decks[preview_deck_id])

    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("go_live", %{
      deck: decks[preview_deck_id],
      slide_id: preview_slide_id,
      quiet: false,
      default_formatting: default_formatting
    })

    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("upcoming_services_shown", %{value: false})

    BreakingCuesWeb.OutputChannel.broadcast_preview_msg("service_details_shown", %{value: false})

    preview_slide_id
  end
end
