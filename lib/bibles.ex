defmodule Bibles do
  use GenServer

  def add_bible(id, path) do
    GenServer.cast(__MODULE__, {:add_bible, id, path})
  end

  def bibles() do
    GenServer.call(__MODULE__, :bibles)
  end

  def lookup(id, ref) do
    GenServer.call(__MODULE__, {:lookup, id, ref})
  end

  def start_link(dir) do
    GenServer.start_link(__MODULE__, dir, name: __MODULE__)
  end

  @impl GenServer
  def init(dir) do
    bibles =
      case File.ls(dir) do
        {:ok, filenames} ->
          filenames
          |> Enum.into(%{}, fn filename ->
            path = :filename.join(dir, filename)
            id = :filename.basename(filename, ".SQLite3")

            case Exqlite.Sqlite3.open(path) do
              {:ok, bible} -> {id, bible}
              {:error, _} -> {nil, nil}
            end
          end)
          |> Map.delete(nil)

        {:error, _} ->
          %{}
      end

    send(self(), :after_init)
    {:ok, bibles}
  end

  @impl GenServer
  def handle_info(:after_init, bibles) do
    Scenic.PubSub.register(:bible_versions)
    Scenic.PubSub.publish(:bible_versions, bibles)
    {:noreply, bibles}
  end

  @impl GenServer
  def handle_cast({:add_bible, id, path}, bibles) do
    {:ok, bible} = Exqlite.Sqlite3.open(path)
    bibles = Map.put(bibles, id, bible)
    Scenic.PubSub.publish(:bible_versions, bibles)
    {:noreply, bibles}
  end

  @impl GenServer
  def handle_call(:bibles, _, bibles) do
    {:reply, Enum.map(bibles, fn {id, _} -> id end), bibles}
  end

  @embedded_tags_to_be_removed ~r/<S>\d*<\/S>|<m>[^<]*<\/m>|<i>|<\/i>|<J>|<\/J>|<n>[^<]*<\/n>|<e>|<\/e>|<t>|<\/t>|<br\/>|<f>[^<]*<\/f>|<h>[^<]*<\/h>/

  @impl GenServer
  def handle_call({:lookup, id, ref}, _, bibles) do
    bible = bibles[id]

    {{book_start, chapter_start, verse_start}, {book_end, chapter_end, verse_end}} =
      parse_ref(ref)

    book_start_number = book_number(book_start, bible)
    book_end_number = book_number(book_end, bible)

    IO.inspect(book_start_number)
    IO.inspect(book_end_number)

    {:ok, statement} =
      Exqlite.Sqlite3.prepare(
        bible,
        "SELECT text FROM verses WHERE (book_number, chapter, verse) >= (?, ?, ?) AND (book_number, chapter, verse) <= (?, ?, ?) ORDER BY book_number, chapter, verse"
      )

    :ok =
      Exqlite.Sqlite3.bind(bible, statement, [
        book_start_number,
        chapter_start,
        verse_start,
        book_end_number,
        chapter_end,
        verse_end
      ])

    verses =
      Stream.map(
        String.split(
          Regex.replace(
            @embedded_tags_to_be_removed,
            Enum.join(
              Stream.unfold(
                nil,
                fn nil ->
                  case Exqlite.Sqlite3.step(bible, statement) do
                    {:row, [verse]} -> {verse, nil}
                    :done -> nil
                  end
                end
              ),
              " "
            ),
            ""
          ),
          "<pb/>",
          trim: true
        ),
        &String.trim(&1)
      )

    :ok = Exqlite.Sqlite3.release(bible, statement)

    {:reply, verses, bibles}
  end

  @ref_regex ~r/^\s*(?<book>[[:alnum:]][[:alnum:]\s]*[[:alnum:]])\s*(?<chapter_start>[[:digit:]]+)\s*(:\s*(?<verse_start>\d+)\s*(-\s*((?<chapter_end>\d+)\s*:\s*)?(?<verse_end>\d+|end)\s*)?)?$/iu

  defp book_number(book, bible) do
    {:ok, statement} =
      Exqlite.Sqlite3.prepare(
        bible,
        "SELECT book_number FROM books WHERE UPPER(short_name) = UPPER(?1) OR UPPER(long_name) = UPPER(?1)"
      )

    :ok = Exqlite.Sqlite3.bind(bible, statement, [book])
    {:row, [book_num]} = Exqlite.Sqlite3.step(bible, statement)
    :ok = Exqlite.Sqlite3.release(bible, statement)
    book_num
  end

  defp parse_ref(ref) do
    case Regex.named_captures(@ref_regex, ref) do
      %{
        "book" => book,
        "chapter_start" => chapter_start,
        "verse_start" => "",
        "chapter_end" => "",
        "verse_end" => ""
      } ->
        {{book, chapter_start, 1}, {book, chapter_start, :end}}

      %{
        "book" => book,
        "chapter_start" => chapter_start,
        "verse_start" => verse_start,
        "chapter_end" => "",
        "verse_end" => ""
      } ->
        {{book, chapter_start, verse_start}, {book, chapter_start, verse_start}}

      %{
        "book" => book,
        "chapter_start" => chapter_start,
        "verse_start" => verse_start,
        "chapter_end" => "",
        "verse_end" => verse_end
      } ->
        {{book, chapter_start, verse_start}, {book, chapter_start, verse_end}}

      %{
        "book" => book,
        "chapter_start" => chapter_start,
        "verse_start" => verse_start,
        "chapter_end" => chapter_end,
        "verse_end" => verse_end
      } ->
        {{book, chapter_start, verse_start}, {book, chapter_end, verse_end}}
    end
  end
end
