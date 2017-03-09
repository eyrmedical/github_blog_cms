defmodule GithubBlogCms do
  use GenServer
  use HTTPotion.Base
  require Earmark

  @api_url Application.get_env(:github_blog_cms, :api_url, "https://api.github.com")
  @client_id Application.get_env(:github_blog_cms, :client_id)
  @client_secret Application.get_env(:github_blog_cms, :client_secret)
  @repository Application.get_env(:github_blog_cms, :repository, "blog")
  @user Application.get_env(:github_blog_cms, :user, "eyrmedical")

  @moduledoc """
  Documentation for GithubBlogCms.
  """


  @doc """
  HTTP request to Github repo from config
  """
  @spec get(String.t()) :: %HTTPotion.Response{}
  def get(path \\ "") do
    get_url(path)
    # GitHub requires a User-Agent header
    |> HTTPotion.get([headers: ["User-Agent": @user]])
  end


  # Format the URL
  @spec get_url(String.t()) :: String.t()
  defp get_url(path \\ "") do
    @api_url <> "/repos/" <> @user <> "/" <> @repository <> path <> "?client_id=#{@client_id}&client_secret=#{@client_secret}"
  end


  @doc """
  Decode JSON
  """
  @spec decode(%HTTPotion.Response{}) :: {:ok, %{}}
  def decode(%HTTPotion.Response{:status_code => 200, :body => body}) do
    Poison.decode!(body)
  end
  def decode(_), do: {:error, :invalid_response}


  @doc """
  Parse posts
  """
  @spec parse_posts([]) :: {:ok, []}
  def parse_posts(posts) when is_list(posts) do
    posts
    |> Enum.map(fn post -> "/contents/posts/" <> post["name"] end)
    |> Enum.map(fn path -> get(path) |> decode() end)
    |> Enum.map(fn post -> parse_post(post) end)
    |> Enum.filter(fn post -> post != :error end)
  end
  defp parse_post(%{"content" => content, "name" => filename}) do
    try do
      post = Base.decode64!(content, ignore: :whitespace)

      # Extract frontmatter (everything before first ---)
      [frontmatter, post] = Regex.split(~r/(^)(\X*)---/,  post, include_captures: true, trim: true)
        |> Enum.map(&String.trim(&1))

      frontmatter = Regex.replace(~r/---/, frontmatter, "")
      post = Earmark.as_html!(post)

      post = Regex.split(~r/\n/, frontmatter, trim: true)
        |> Enum.map(&Regex.split(~r/:\s|:/, &1, trim: true) |> List.to_tuple)
        |> Enum.into(%{"post" => post, "filename" => filename})


      date_from_frontmatter = Map.get(post, "date")
      date_from_filename = Regex.run(~r/....-..-../, filename) |> List.to_string

      case Date.from_iso8601(date_from_frontmatter || date_from_filename) do
        {:ok, date} -> Map.put(post, "date", date)
        _ -> Map.put(post, "date", Calendar.date())
      end
    rescue
      _ -> :error
    end
  end
  defp parse_post(_), do: :error


  @doc """
  Check last updated_date towards a DateTime struct. If it is greater than
  current_date it will trigger getting and parsing posts.
  """
  @spec check_last_updated(String.t(), %DateTime{}) :: atom()
  def check_last_updated(updated_at, current_date) do
    case DateTime.from_iso8601(updated_at) do
      {:ok, updated_at, _offset} -> DateTime.compare(updated_at, current_date)
      _ -> :gt # Default to :gt to trigger getting posts
    end
  end



  def start_link do
    GenServer.start_link(__MODULE__, %{:updated_at => :nil, :posts => []})
  end


  #
  # GENSERVER
  #

  @doc """
  Start the blog monitor
  """
  def init(state) do
    IO.puts "[info] Started blog monitor for https://github.com/#{@user}/#{@repository}"
    handle_cast(:check_last_updated, state)
    {:ok, state}
  end

  def handle_cast(:check_last_updated, state) do
    case get()
      |> decode()
      |> check_last_updated(state.updated_at)
    do
      :gt -> handle_cast(:get_posts, state)
      _ -> IO.puts "[info] Already have the latest posts"
    end

    reschedule()
    {:noreply, state}
  end


  def handle_cast(:get_posts, state) do
    posts =
      get("/contents/posts")
      |> decode()
      |> parse_posts()

    updated_at =
      get()
      |> decode()
      |> Map.get("updated_at")

    state = state
      |> Map.put(:updated_at, updated_at)
      |> Map.put(:posts, posts)

    {:noreply, state}
  end

  def handle_call(:get_posts, _from, state) do
    {:reply, Map.get(state, :posts)}
  end

  def handle_call(:get_updated_at, _from, state) do
    {:reply, Map.get(state, :updated_at)}
  end

  def reschedule(time \\ 10 * 1000) do
    Process.send_after(self(), :check_last_updated, time)
  end

end
