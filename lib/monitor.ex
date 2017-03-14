defmodule Monitor do
  use GenServer
  import Github

    def start_link do
      GenServer.start_link(__MODULE__, %{:pushed_at => :nil, :posts => [], :initialized => false}, name: __MODULE__)
    end

    def get_posts do
      GenServer.call(__MODULE__, :get_posts)
    end

    def refresh do
      GenServer.cast(__MODULE__, :check_last_updated)
    end

    @doc """
    Start the blog monitor
    """
    def init(state) do
      IO.puts "[info] Started Github blog monitor"
      GenServer.cast(__MODULE__, :check_last_updated)
      {:ok, state}
    end


    def handle_cast(:check_last_updated, state) do
      IO.puts "[info] Checking last updated..."
      case Github.get()
        |> decode()
        |> Map.get("pushed_at", "")
        |> check_last_updated(state.pushed_at)
      do
        :gt ->
          GenServer.cast(__MODULE__, :get_posts)
          reschedule()
          {:noreply, Map.put(state, :active_fetching_post, true)}
        _ ->
          IO.puts "[info] Already have the latest posts"
          reschedule()
          {:noreply, state}
      end
    end

    def handle_call(:get_posts, _from, %{active_fetching_post: true} = state) do
      {:reply, {:error, "Not loaded yet"}, state}
    end
    def handle_call(:get_posts, _from, %{posts: posts} = state) do
      {:reply, posts, state}
    end

    def handle_cast(:get_posts, state) do
      IO.puts "[info] Getting posts..."
      posts =
        get("/contents/posts")
        |> decode()
        |> parse_posts()

      Enum.map(posts, fn post -> Map.get(post, "title") |> IO.inspect end)

      {:ok, pushed_at, _offset} =
        get()
        |> decode()
        |> Map.get("pushed_at", "")
        |> DateTime.from_iso8601()

      state = state
        |> Map.put(:pushed_at, pushed_at)
        |> Map.put(:posts, posts)
        |> Map.put(:active_fetching_post, false)

      {:noreply, state}
    end

    def reschedule(time \\ 3 * 60 * 1000) do
      Process.send_after(self(), :check_last_updated, time)
    end
end
