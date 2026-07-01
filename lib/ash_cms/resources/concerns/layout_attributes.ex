defmodule AshCms.Resource.LayoutAttributes do
  @moduledoc """
  Mixin for CMS Layout resources. A Layout wraps page content with
  a header, footer, navigation, etc.

  ## Template

  The template is a HEEx fragment. Use `<%= @inner_content %>` where the
  page content should be rendered:

      <header>...</header>
      <main class="container mx-auto py-8">
        <%= @inner_content %>
      </main>
      <footer>...</footer>

  ## Available assigns
  - `@inner_content` — the rendered page content
  - `@page` — the current page record
  - `@site` — the current site record
  """

  defmacro __using__(_opts) do
    quote do
      attributes do
        uuid_primary_key :id

        attribute :name, :string do
          allow_nil? false
          constraints min_length: 1, max_length: 100
        end

        attribute :slug, :string do
          allow_nil? false
          constraints min_length: 1, max_length: 100,
                      match: ~r/^[a-z0-9_\-]+$/
        end

        attribute :description, :string do
          allow_nil? true
        end

        attribute :template, :string do
          allow_nil? false
          default """
          <main class="ash-cms-page">
            <%= @inner_content %>
          </main>
          """
          description "HEEx template wrapping page content. Use @inner_content for the page."
        end

        attribute :is_default, :boolean do
          default false
          description "Whether this is the default layout for new pages"
        end

        create_timestamp :inserted_at
        update_timestamp :updated_at
      end

      identities do
        identity :unique_slug_per_site, [:site_id, :slug]
      end

      actions do
        defaults [:read, :destroy]

        create :create do
          primary? true
          accept [:name, :slug, :description, :template, :is_default, :site_id]
          change {AshCms.Changes.SlugifyIfBlank, attribute: :slug, source: :name}
        end

        update :update do
          primary? true
          accept [:name, :description, :template, :is_default]
        end

        read :for_site do
          argument :site_id, :uuid, allow_nil?: true
          prepare AshCms.Preparations.ForSite
        end
      end
    end
  end
end
