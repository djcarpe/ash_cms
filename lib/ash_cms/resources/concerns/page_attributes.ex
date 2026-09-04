defmodule AshCms.Resource.PageAttributes do
  @moduledoc """
  Mixin providing all attributes, actions, and validations for a CMS Page resource.

      defmodule MyApp.CMS.Page do
        use Ash.Resource,
          domain: MyApp.CMS,
          data_layer: AshSqlite.DataLayer

        use AshCms.Resource.PageAttributes

        sqlite do
          table "cms_pages"
          repo MyApp.Repo
        end

        relationships do
          belongs_to :site, MyApp.CMS.Site, allow_nil?: false
          belongs_to :layout, MyApp.CMS.Layout, allow_nil?: true
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      attributes do
        uuid_primary_key :id

        attribute :title, :string do
          allow_nil? false
          constraints min_length: 1, max_length: 255
        end

        attribute :slug, :string do
          allow_nil? false
          description "URL path for this page, e.g. 'about' or 'blog/first-post'"
          constraints min_length: 1, max_length: 500
        end

        attribute :description, :string do
          allow_nil? true
          description "Meta description for SEO"
        end

        attribute :content, :map do
          default %{"version" => "1", "blocks" => []}
          description "Page content as a block AST (visual mode)"
        end

        attribute :template, :string do
          allow_nil? true
          description "Raw HEEx template (code mode). Overrides content when set."
        end

        attribute :editor_mode, :atom do
          constraints one_of: [:visual, :code]
          default :visual
          description "Which editor was last used for this page"
        end

        attribute :published, :boolean do
          default false
        end

        attribute :published_at, :utc_datetime do
          allow_nil? true
        end

        attribute :meta_title, :string do
          allow_nil? true
        end

        attribute :meta_description, :string do
          allow_nil? true
        end

        attribute :og_image_url, :string do
          allow_nil? true
        end

        attribute :custom_css, :string do
          allow_nil? true
          description "Page-level CSS overrides"
        end

        attribute :custom_js, :string do
          allow_nil? true
          description "Page-level JS appended before </body>"
        end

        attribute :sort_order, :integer do
          default 0
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
          accept [:title, :slug, :description, :content, :template, :editor_mode,
                  :meta_title, :meta_description, :og_image_url, :custom_css,
                  :custom_js, :sort_order, :site_id, :layout_id]

          change {AshCms.Changes.SlugifyIfBlank, attribute: :slug, source: :title}
        end

        update :update do
          primary? true
          accept [:title, :slug, :description, :content, :template, :editor_mode,
                  :meta_title, :meta_description, :og_image_url, :custom_css,
                  :custom_js, :sort_order, :layout_id]
        end

        update :publish do
          require_atomic? false
          accept []
          change set_attribute(:published, true)
          change set_attribute(:published_at, &DateTime.utc_now/0)
          change after_action(fn changeset, record, _ctx ->
            AshCms.PageServer.start_or_update(record)
            AshCms.broadcast_page_published(record)
            {:ok, record}
          end)
        end

        update :unpublish do
          require_atomic? false
          accept []
          change set_attribute(:published, false)
          change after_action(fn changeset, record, _ctx ->
            AshCms.PageServer.stop(record)
            AshCms.broadcast_page_unpublished(record)
            {:ok, record}
          end)
        end

        update :update_content do
          require_atomic? false
          description "Update the visual blocks content"
          accept [:content]

          change after_action(fn _changeset, record, _ctx ->
            if record.published, do: AshCms.PageServer.start_or_update(record)
            AshCms.broadcast_page_update(record)
            {:ok, record}
          end)
        end

        update :update_template do
          require_atomic? false
          description "Update the raw HEEx template"
          accept [:template, :editor_mode]

          change after_action(fn _changeset, record, _ctx ->
            if record.published, do: AshCms.PageServer.start_or_update(record)
            AshCms.broadcast_page_update(record)
            {:ok, record}
          end)
        end

        read :by_site do
          argument :site_id, :uuid, allow_nil?: false
          prepare AshCms.Preparations.BySite
        end

        read :published do
          argument :site_id, :uuid, allow_nil?: true
          prepare AshCms.Preparations.Published
        end

        read :by_slug do
          argument :slug, :string, allow_nil?: false
          argument :site_id, :uuid, allow_nil?: true
          get? true
          prepare AshCms.Preparations.BySlug
        end
      end
    end
  end
end
