defmodule GithubBlogCmsTest do
  use ExUnit.Case, async: true
  doctest GithubBlogCms

  # No need to make the response for each test clause
  @response GithubBlogCms.get()

  test "API call to GitHub repo" do
    assert @response.status_code == 200
  end

  test "posts directory exists" do
    %HTTPotion.Response{:status_code => status_code} = GithubBlogCms.get("/contents/posts")
    assert status_code == 200
  end

  test "check_last_updated" do
    result =
      GithubBlogCms.decode(@response)
      |> Map.get("updated_at", "")
      |> GithubBlogCms.check_last_updated(DateTime.utc_now())
    assert result == :lt
  end
end
