defmodule GithubBlogCmsTest do
  use ExUnit.Case, async: true
  doctest Github
  doctest Monitor

  setup_all context do
      {:ok, pid} = Monitor.start_link
      Process.sleep(10000)
      {:ok, monitor: pid, response: Github.get()}
  end

  test "API call to GitHub repo", %{response: response} do
    assert response.status_code == 200
  end

  test "posts directory exists" do
    %HTTPotion.Response{:status_code => status_code} = Github.get("/contents/posts")
    assert status_code == 200
  end

  test "check_last_updated", %{response: response} do
    result =
      Github.decode(response)
      |> Map.get("updated_at", "")
      |> Github.check_last_updated(DateTime.utc_now())
    assert result == :lt
  end

  test "check get posts",  %{monitor: monitor} do
   posts = GenServer.call(monitor, :get_posts)
   assert length(posts) > 0
 end
end
