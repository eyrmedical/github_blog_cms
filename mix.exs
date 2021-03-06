defmodule GithubBlogCms.Mixfile do
  use Mix.Project

  def project do
    [app: :github_blog_cms,
     version: "0.1.7",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger, :httpotion, :poison, :earmark]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [ {:httpotion, "~> 3.0.2"},
      {:poison, "~> 2.0"},
      {:earmark, "~> 1.1"},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end
end
