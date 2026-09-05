defmodule AshCms.Resource.SiteAttributes do
  @moduledoc """
  Mixin providing all attributes, actions, validations, and relationships
  for a CMS Site resource. Include in your own resource module:

      defmodule MyApp.CMS.Site do
        use Ash.Resource,
          domain: MyApp.CMS,
          data_layer: AshSqlite.DataLayer

        use AshCms.Resource.SiteAttributes

        sqlite do
          table "cms_sites"
          repo MyApp.Repo
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      attributes do
        uuid_primary_key :id

        attribute :name, :string do
          allow_nil? false
          constraints min_length: 1, max_length: 255
        end

        attribute :slug, :string do
          allow_nil? false
          constraints min_length: 1, max_length: 100,
                      match: ~r/^[a-z0-9\-]+$/
        end

        attribute :domain, :string do
          allow_nil? true
          description "Hostname this site responds to (e.g. mysite.com)"
        end

        attribute :description, :string do
          allow_nil? true
        end

        attribute :css_url, :string do
          allow_nil? true
          description "URL path to a custom CSS file for this site"
        end

        attribute :js_url, :string do
          allow_nil? true
          description "URL path to a custom JavaScript file for this site"
        end

        attribute :custom_css, :string do
          allow_nil? true
          description "Inline CSS injected into every page header"
        end

        attribute :custom_js, :string do
          allow_nil? true
          description "Inline JS injected into every page footer"
        end

        attribute :meta, :map do
          default %{}
          description "Arbitrary JSON metadata for this site"
        end

        create_timestamp :inserted_at
        update_timestamp :updated_at
      end

      identities do
        identity :unique_slug, [:slug]
        identity :unique_domain, [:domain]
      end

      actions do
        defaults [:read, :destroy]

        create :create do
          primary? true
          accept [:name, :slug, :domain, :description, :css_url, :js_url,
                  :custom_css, :custom_js, :meta]

          change {AshCms.Changes.SlugifyIfBlank, attribute: :slug, source: :name}
          change AshCms.Changes.NormalizeDomain
        end

        update :update do
          require_atomic? false
          primary? true
          accept [:name, :slug, :domain, :description, :css_url, :js_url,
                  :custom_css, :custom_js, :meta]

          change AshCms.Changes.NormalizeDomain
        end
      end
    end
  end
end
