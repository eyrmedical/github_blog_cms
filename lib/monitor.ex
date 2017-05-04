defmodule Monitor do
    require Logger
    use GenServer
    import Github

    def start_link do
        GenServer.start_link(__MODULE__, %{:pushed_at => :nil, :posts => [], :active_fetching_post => true}, name: __MODULE__)
    end

    def get_posts do
        GenServer.call(__MODULE__, :get_posts)
    end

    def get_post(name) do
        GenServer.call(__MODULE__, {:get_post, name})
    end

    def refresh do
        GenServer.cast(__MODULE__, :check_last_updated)
    end

    @doc """
    Start the blog monitor
    """
    def init(state) do
        Logger.debug "Started Github blog monitor"
        GenServer.cast(__MODULE__, :check_last_updated)
        {:ok, state}
    end

    def handle_info(:check_last_updated, state) do
        GenServer.cast(__MODULE__, :check_last_updated)
        {:noreply, state}
    end

    def handle_cast(:check_last_updated, state) do
        Logger.debug "Checking last updated..."
        case Github.get(:pushed_at) |> check_last_updated(state.pushed_at) do
            :gt ->
                GenServer.cast(__MODULE__, :get_posts)
                reschedule()
                {:noreply, Map.put(state, :active_fetching_post, true)}
                _ ->
                    Logger.info "Already have the latest posts"
                    reschedule()
                    {:noreply, state}
                end
            end


            def handle_call({:get_post, name}, _from, %{active_fetching_post: true} = state) do
                {:reply, [], state}
            end

            def handle_call({:get_post, name}, _from, %{posts: posts} = state) do
                {:reply, Enum.find(posts, :not_found, fn post -> post["filename"] == name end), state}
            end

            def handle_call(:get_posts, _from, %{active_fetching_post: true} = state) do
                {:reply, [], state}
            end
            def handle_call(:get_posts, _from, %{posts: posts} = state) do
                {:reply, posts, state}
            end

            def handle_cast(:get_posts, state) do
                Logger.debug "Getting posts..."

                posts = Github.get(:posts)
                |> Enum.map(fn post -> post["name"] end)
                |> Enum.map(&(Task.async(fn -> get(:post, &1) end)))
                |> Enum.map(&Task.await/1)
                |> Enum.filter(fn post -> post != :error end)

                Enum.map(posts, fn post -> Map.get(post, "title") end)

                {:ok, pushed_at, _offset} =
                    Github.get(:pushed_at)
                    |> DateTime.from_iso8601()

                    state = state
                    |> Map.put(:pushed_at, pushed_at)
                    |> Map.put(:posts, posts)
                    |> Map.put(:active_fetching_post, false)

                    {:noreply, state}
                end

                def reschedule(time \\ 60 * 1000) do
                    Process.send_after(self(), :check_last_updated, time)
                end
            end
