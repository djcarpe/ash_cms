defmodule AshCms.Resource.ComponentAttributes do
  @moduledoc """
  Mixin for CMS Component resources. Components are user-defined reusable blocks.

  ## Props Schema

  The `props_schema` field is a JSON schema map that describes the component's
  configurable properties. This schema drives the auto-generated Properties Panel
  in the visual editor.

  ### Example props_schema

      %{
        "title" => %{"type" => "string", "label" => "Title", "default" => ""},
        "color" => %{"type" => "color", "label" => "Background Color", "default" => "#ffffff"},
        "show_border" => %{"type" => "boolean", "label" => "Show Border", "default" => false}
      }

  ## Template

  The `template` field is a HEEx fragment. Available assigns:
  - `@props` — the resolved props map
  - `@site` — the current site
  """

  defmacro __using__(_opts) do
    quote do
      attributes do
        uuid_primary_key :id

        attribute :name, :string do
          allow_nil? false
          constraints min_length: 1, max_length: 100
          description "Display name shown in the component palette"
        end

        attribute :slug, :string do
          allow_nil? false
          constraints min_length: 1, max_length: 100,
                      match: ~r/^[a-z0-9_\-]+$/
          description "Identifier used in block type field"
        end

        attribute :description, :string do
          allow_nil? true
        end

        attribute :icon, :string do
          allow_nil? true
          default "squares-2x2"
          description "Heroicon name for the component palette"
        end

        attribute :category, :string do
          allow_nil? false
          default "custom"
          description "Component category: layout | content | media | custom"
        end

        attribute :template, :string do
          allow_nil? false
          description "HEEx template fragment. Use @props.field_name for prop values."
        end

        attribute :props_schema, :map do
          default %{}
          description "JSON schema describing configurable props"
        end

        attribute :default_props, :map do
          default %{}
          description "Default prop values"
        end

        attribute :preview_thumbnail, :string do
          allow_nil? true
          description "URL of a thumbnail image shown in the palette"
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
          accept [:name, :slug, :description, :icon, :category, :template,
                  :props_schema, :default_props, :preview_thumbnail, :site_id]

          change {AshCms.Changes.SlugifyIfBlank, attribute: :slug, source: :name}
          change after_action(fn _changeset, record, _ctx ->
            AshCms.broadcast_component_update(record)
            {:ok, record}
          end)
        end

        update :update do
          primary? true
          accept [:name, :description, :icon, :category, :template,
                  :props_schema, :default_props, :preview_thumbnail]

          change after_action(fn _changeset, record, _ctx ->
            AshCms.broadcast_component_update(record)
            {:ok, record}
          end)
        end

        read :for_site do
          argument :site_id, :uuid, allow_nil?: true
          prepare AshCms.Preparations.ForSite
        end

        read :by_slug do
          argument :slug, :string, allow_nil?: false
          argument :site_id, :uuid, allow_nil?: true
          get? true
          prepare AshCms.Preparations.ComponentBySlug
        end
      end
    end
  end
end
