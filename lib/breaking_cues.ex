defmodule BreakingCues do
  use Application

  defp config_dir() do
    base =
      case :os.type() do
        {:unix, _} -> :filename.join(System.get_env("HOME"), ".config")
        {:win32, _} -> System.get_env("APPDATA")
      end

    :filename.join(base, "breaking_cues")
  end

  @impl Application
  def start(_type, _args) do
    # start the application with the viewport
    children = [
      # TextMetrics,
      # {Scenic, [output_viewport_config]},
      Scenic.PubSub,
      # Start the Ecto repository
      # BreakingCues.Repo,
      # Start the Telemetry supervisor
      BreakingCuesWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: BreakingCues.PubSub},
      # Start the Endpoint (http/https)
      BreakingCuesWeb.Endpoint,
      # Start a worker by calling: BreakingCues.Worker.start_link(arg)
      # {BreakingCues.Worker, arg}
      Slides,
      {Psalms, :filename.join(config_dir(), "psalters")},
      {Bibles, :filename.join(config_dir(), "bibles")}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    BreakingCuesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
