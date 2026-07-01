defmodule AshCms do
  @moduledoc """
  AshCms — a full-featured Content Management System extension for the Ash Framework.

  ## Features

  - Drag-and-drop visual page editor (Wix/BeaconCMS-style)
  - Live code editor with Monaco (VS Code engine) and real-time preview
  - User-defined reusable components
  - Full Phoenix LiveView lifecycle and PubSub integration
  - Distributed page registry via the `Group` library
  - S3-compatible media management
  - Single catch-all router endpoint installed via Igniter
  - Works with any Ash data layer (SQLite, Postgres, etc.)

  ## Setup

      mix igniter.install ash_cms

  ## Manual setup

  1. Add to `config.exs`:

         config :ash_cms,
           site_resource: MyApp.CMS.Site,
           page_resource: MyApp.CMS.Page,
           component_resource: MyApp.CMS.Component,
           layout_resource: MyApp.CMS.Layout,
           media_resource: MyApp.CMS.Media,
           domain: MyApp.CMS,
           endpoint: MyAppWeb.Endpoint,
           pubsub_server: MyApp.PubSub

  2. Create CMS resources using the provided attribute/action mixins.

  3. In your Phoenix router:

         use AshCms.Router
         # at the END of your router file:
         ash_cms_routes()

  4. Add `AshCms.CMSSupervisor` to your application supervision tree.
  """

  @doc "The configured Ash domain containing CMS resources."
  def domain, do: Application.fetch_env!(:ash_cms, :domain)

  @doc "The configured Site resource module."
  def site_resource, do: Application.fetch_env!(:ash_cms, :site_resource)

  @doc "The configured Page resource module."
  def page_resource, do: Application.fetch_env!(:ash_cms, :page_resource)

  @doc "The configured Component resource module."
  def component_resource, do: Application.fetch_env!(:ash_cms, :component_resource)

  @doc "The configured Layout resource module."
  def layout_resource, do: Application.fetch_env!(:ash_cms, :layout_resource)

  @doc "The configured Media resource module."
  def media_resource, do: Application.fetch_env!(:ash_cms, :media_resource)

  @doc "The configured Phoenix endpoint module."
  def endpoint, do: Application.fetch_env!(:ash_cms, :endpoint)

  @doc "The configured Phoenix PubSub server name."
  def pubsub_server, do: Application.fetch_env!(:ash_cms, :pubsub_server)

  @doc "PubSub topic for a specific page."
  def page_topic(page_id), do: "ash_cms:page:#{page_id}"

  @doc "PubSub topic for all pages within a site."
  def site_topic(site_id), do: "ash_cms:site:#{site_id}"

  @doc "PubSub topic for global CMS events."
  def global_topic, do: "ash_cms:global"

  @doc "Broadcast a page update event via PubSub."
  def broadcast_page_update(page) do
    server = pubsub_server()
    Phoenix.PubSub.broadcast(server, page_topic(page.id), {:page_updated, page})
    Phoenix.PubSub.broadcast(server, site_topic(page.site_id), {:page_updated, page})
  end

  @doc "Broadcast a page published event via PubSub."
  def broadcast_page_published(page) do
    server = pubsub_server()
    Phoenix.PubSub.broadcast(server, page_topic(page.id), {:page_published, page})
    Phoenix.PubSub.broadcast(server, site_topic(page.site_id), {:page_published, page})
  end

  @doc "Broadcast a page unpublished event via PubSub."
  def broadcast_page_unpublished(page) do
    server = pubsub_server()
    Phoenix.PubSub.broadcast(server, page_topic(page.id), {:page_unpublished, page})
    Phoenix.PubSub.broadcast(server, site_topic(page.site_id), {:page_unpublished, page})
  end

  @doc "Broadcast a component update event via PubSub."
  def broadcast_component_update(component) do
    server = pubsub_server()
    Phoenix.PubSub.broadcast(server, global_topic(), {:component_updated, component})
    if component.site_id do
      Phoenix.PubSub.broadcast(server, site_topic(component.site_id), {:component_updated, component})
    end
  end
end
