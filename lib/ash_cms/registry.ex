defmodule AshCms.Registry do
  @moduledoc """
  Distributed page registry backed by the `Group` library.

  Pages are registered under the key `"{site_slug}/{page_slug}"` when published,
  and unregistered when unpublished or deleted. The Group registry is cluster-wide,
  so page lookups work across all nodes.

  ## Key format

  - `"site:my-site/page:about"` — standard site+page key
  - `"domain:mysite.com/page:about"` — domain-based lookup

  ## Usage

      # Register a page (called from PageServer)
      AshCms.Registry.register(page, site)

      # Look up a page by site slug and page slug
      case AshCms.Registry.lookup_by_slug("my-site", "about") do
        {pid, meta} -> render_page(pid, meta)
        nil -> {:error, :not_found}
      end

      # Look up by domain
      case AshCms.Registry.lookup_by_domain("mysite.com", "about") do
        {pid, meta} -> render_page(pid, meta)
        nil -> {:error, :not_found}
      end
  """

  @registry_name AshCms.Registry

  @doc "Register the calling process as the server for a published page."
  def register(%{slug: page_slug} = page, %{slug: site_slug} = site) do
    meta = %{
      page_id: page.id,
      site_id: page.site_id,
      page_slug: page_slug,
      site_slug: site_slug,
      domain: site.domain,
      layout_id: Map.get(page, :layout_id)
    }

    key = site_key(site_slug, page_slug)
    Group.register(@registry_name, key, meta)

    if site.domain do
      domain_key = domain_key(site.domain, page_slug)
      Group.register(@registry_name, domain_key, meta)
    end

    :ok
  end

  @doc "Unregister the calling process as the server for a page."
  def unregister(%{slug: page_slug}, %{slug: site_slug, domain: domain}) do
    Group.unregister(@registry_name, site_key(site_slug, page_slug))

    if domain do
      Group.unregister(@registry_name, domain_key(domain, page_slug))
    end

    :ok
  end

  @doc "Look up a page server by site slug and page slug."
  def lookup_by_slug(site_slug, page_slug) do
    Group.lookup(@registry_name, site_key(site_slug, page_slug))
  end

  @doc "Look up a page server by hostname and page slug."
  def lookup_by_domain(host, page_slug) do
    Group.lookup(@registry_name, domain_key(host, page_slug))
  end

  @doc "List all registered pages for a site."
  def list_site_pages(site_slug) do
    Group.members(@registry_name, "site:#{site_slug}/")
  end

  @doc "Monitor lifecycle events for a pattern (e.g. all pages on a site)."
  def monitor(pattern), do: Group.monitor(@registry_name, pattern)

  @doc "Stop monitoring a pattern."
  def demonitor(pattern), do: Group.demonitor(@registry_name, pattern)

  defp site_key(site_slug, page_slug), do: "site:#{site_slug}/page:#{page_slug}"
  defp domain_key(domain, page_slug), do: "domain:#{domain}/page:#{page_slug}"
end
