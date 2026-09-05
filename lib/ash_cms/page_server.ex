defmodule AshCms.PageServer do
  @moduledoc """
  GenServer that caches a published CMS page and registers it in the
  Group-based distributed registry.

  One `PageServer` runs per published page. It:
  1. Holds the page and site in memory for fast lookups
  2. Registers itself in `AshCms.Registry` under the site+page key
  3. Subscribes to PubSub for live page updates
  4. Notifies connected LiveView sockets via PubSub when content changes

  ## Lifecycle

  - Started by `AshCms.CMSSupervisor` on boot for all published pages
  - Started dynamically when a page is published
  - Stopped when a page is unpublished or deleted
  - Restarts automatically if it crashes (supervised)
  """

  use GenServer, restart: :transient

  require Logger

  defstruct [:page, :site, :rendered_content]

  # ── Public API ──────────────────────────────────────────────────────────────

  @doc "Start a page server for the given page (already loaded with its site)."
  def start_link(%{} = page_with_site) do
    GenServer.start_link(__MODULE__, page_with_site)
  end

  @doc "Get the cached page from a running server."
  def get_page(pid), do: GenServer.call(pid, :get_page)

  @doc "Get the cached site from a running server."
  def get_site(pid), do: GenServer.call(pid, :get_site)

  @doc "Reload the page content from the database."
  def reload(pid), do: GenServer.cast(pid, :reload)

  @doc """
  Start or update a page server. Called from page action after_action hooks.
  Safely handles the case where a server already exists.
  """
  def start_or_update(page) do
    page_mod = AshCms.page_resource()
    domain = AshCms.domain()

    full_page =
      page_mod
      |> Ash.get!(page.id, domain: domain, load: [:site, :layout])

    case find_server(full_page) do
      nil ->
        DynamicSupervisor.start_child(
          AshCms.PageSupervisor,
          {AshCms.PageServer, full_page}
        )

      pid ->
        GenServer.cast(pid, {:update_page, full_page})
        {:ok, pid}
    end
  end

  @doc "Stop the server for a page (called when unpublished/deleted)."
  def stop(page) do
    case find_server(page) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(AshCms.PageSupervisor, pid)
    end
  end

  @doc "Find the PID of an existing page server, if any."
  # Matches on the site actually having a slug rather than guarding on
  # `not is_nil(site)`. An unloaded relationship is `%Ash.NotLoaded{}`, which
  # is not nil, so the nil guard sent it here and `site.slug` raised KeyError -
  # making the loading clause below unreachable in exactly the case it exists
  # for. `stop/1` hits this, because unlike `start_or_update/1` it is handed
  # the record straight from the action without a reload.
  def find_server(%{site: %{slug: site_slug}, slug: slug}) do
    case AshCms.Registry.lookup_by_slug(site_slug, slug) do
      {pid, _meta} -> pid
      nil -> nil
    end
  end

  def find_server(%{site_id: _site_id, slug: _slug} = page) do
    page_mod = AshCms.page_resource()

    full_page =
      page_mod
      |> Ash.get!(page.id, domain: AshCms.domain(), load: [:site])

    find_server(full_page)
  end

  # ── GenServer callbacks ──────────────────────────────────────────────────────

  @impl true
  # Same reasoning as `find_server/1`: match on a loaded site, so an unloaded
  # one falls through to the clause that loads it.
  def init(%{site: %{slug: _} = site, slug: _slug} = page) do
    # Subscribe to PubSub updates for this page
    pubsub = AshCms.pubsub_server()
    Phoenix.PubSub.subscribe(pubsub, AshCms.page_topic(page.id))

    # Register in Group registry
    AshCms.Registry.register(page, site)

    Logger.debug("[AshCms.PageServer] Started for #{site.slug}/#{page.slug}")

    {:ok, %__MODULE__{page: page, site: site}}
  end

  def init(page) do
    # Page loaded without site preloaded - load now
    page_mod = AshCms.page_resource()
    full_page = Ash.get!(page_mod, page.id, domain: AshCms.domain(), load: [:site, :layout])
    init(full_page)
  end

  @impl true
  def handle_call(:get_page, _from, state) do
    {:reply, state.page, state}
  end

  def handle_call(:get_site, _from, state) do
    {:reply, state.site, state}
  end

  @impl true
  def handle_cast(:reload, state) do
    page_mod = AshCms.page_resource()
    fresh = Ash.get!(page_mod, state.page.id, domain: AshCms.domain(), load: [:site, :layout])
    {:noreply, %{state | page: fresh, site: fresh.site}}
  end

  def handle_cast({:update_page, page}, state) do
    # Re-register with new metadata in case slug/domain changed
    AshCms.Registry.unregister(state.page, state.site)
    AshCms.Registry.register(page, page.site)
    {:noreply, %{state | page: page, site: page.site}}
  end

  @impl true
  def handle_info({:page_updated, page}, state) do
    {:noreply, %{state | page: page}}
  end

  def handle_info({:page_published, page}, state) do
    {:noreply, %{state | page: page}}
  end

  def handle_info({:page_unpublished, _page}, state) do
    # Unregister and stop
    AshCms.Registry.unregister(state.page, state.site)
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    AshCms.Registry.unregister(state.page, state.site)
    Logger.debug("[AshCms.PageServer] Stopped for #{state.site.slug}/#{state.page.slug}")
    :ok
  end
end
