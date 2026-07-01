defmodule AshCms.CMSSupervisor do
  @moduledoc """
  Application supervisor that starts page servers for all currently published pages.

  Add this to your application's supervision tree:

      children = [
        MyApp.Repo,
        MyAppWeb.Endpoint,
        AshCms.CMSSupervisor
      ]

  On startup it loads all published pages from the configured domain and
  starts one `AshCms.PageServer` per page. As pages are published/unpublished
  at runtime, the `AshCms.PageServer` module manages starting/stopping servers
  dynamically via `AshCms.PageSupervisor` (a `DynamicSupervisor` started by
  `AshCms.Application`).
  """

  use GenServer

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Defer startup until after the application is fully running
    Process.send_after(self(), :start_page_servers, 500)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:start_page_servers, state) do
    start_all_published_pages()
    {:noreply, state}
  end

  defp start_all_published_pages do
    page_mod = AshCms.page_resource()
    domain = AshCms.domain()

    pages =
      page_mod
      |> Ash.Query.for_read(:published, %{})
      |> Ash.Query.load([:site, :layout])
      |> Ash.read!(domain: domain)

    Logger.info("[AshCms.CMSSupervisor] Starting #{length(pages)} page server(s)")

    Enum.each(pages, fn page ->
      case DynamicSupervisor.start_child(AshCms.PageSupervisor, {AshCms.PageServer, page}) do
        {:ok, _pid} ->
          Logger.debug("[AshCms.CMSSupervisor] Started server for #{page.site.slug}/#{page.slug}")

        {:error, reason} ->
          Logger.warning("[AshCms.CMSSupervisor] Failed to start server for page #{page.id}: #{inspect(reason)}")
      end
    end)
  end
end
