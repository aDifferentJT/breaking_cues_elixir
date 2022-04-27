defmodule BreakingCuesWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel("output", BreakingCuesWeb.OutputChannel)
  channel("preview_output:*", BreakingCuesWeb.OutputChannel)

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
