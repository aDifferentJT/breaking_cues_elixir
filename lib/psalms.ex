defmodule Psalms do
  use GenServer

  def lookup(id, psalm_num, verse_start, verse_end) do
    GenServer.call(__MODULE__, {:lookup, id, psalm_num, verse_start, verse_end})
  end

  def start_link(dir) do
    GenServer.start_link(__MODULE__, dir, name: __MODULE__)
  end

  @impl GenServer
  def init(dir) do
    psalters =
      case File.ls(dir) do
        {:ok, filenames} ->
          filenames
          |> Enum.into(%{}, fn filename ->
            path = :filename.join(dir, filename)
            id = :filename.basename(filename, ".json")

            with {:ok, data} <- File.read(path),
                 {:ok, psalter} <- Poison.decode(data) do
              {id, psalter}
            else
              {:error, _} -> {nil, nil}
            end
          end)
          |> Map.delete(nil)

        {:error, _} ->
          %{}
      end

    send(self(), :after_init)
    {:ok, psalters}
  end

  @impl GenServer
  def handle_info(:after_init, psalters) do
    Scenic.PubSub.register(:psalters)
    Scenic.PubSub.publish(:psalters, psalters)
    {:noreply, psalters}
  end

  @impl GenServer
  def handle_call({:lookup, id, psalm_num, verse_start, verse_end}, _, psalters) do
    psalm =
      psalters[id]
      |> Enum.at(psalm_num - 1)

    verse_end =
      case verse_end do
        :end -> Enum.count(psalm)
        _ -> verse_end
      end

    {:reply, Enum.slice(psalm, verse_start - 1, verse_end - verse_start + 1), psalters}
  end
end
