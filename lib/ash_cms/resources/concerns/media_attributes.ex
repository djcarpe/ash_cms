defmodule AshCms.Resource.MediaAttributes do
  @moduledoc """
  Mixin for CMS Media resources. Handles uploaded files with S3 or local storage.

  Configure storage in your domain:

      ash_cms do
        media_storage :s3
        s3_bucket "my-cms-assets"
        s3_prefix "media"
      end
  """

  defmacro __using__(_opts) do
    quote do
      attributes do
        uuid_primary_key :id

        attribute :name, :string do
          allow_nil? false
          description "Human-readable filename"
        end

        attribute :filename, :string do
          allow_nil? false
          description "Original upload filename"
        end

        attribute :content_type, :string do
          allow_nil? false
          description "MIME type, e.g. 'image/jpeg'"
        end

        attribute :size, :integer do
          allow_nil? false
          description "File size in bytes"
        end

        attribute :url, :string do
          allow_nil? false
          description "Public URL for this media file"
        end

        attribute :storage_path, :string do
          allow_nil? false
          description "S3 key or local filesystem path"
        end

        attribute :storage_backend, :atom do
          constraints one_of: [:local, :s3]
          default :local
        end

        attribute :metadata, :map do
          default %{}
          description "Extra metadata: image width/height, duration, alt text, etc."
        end

        attribute :alt_text, :string do
          allow_nil? true
          description "Accessibility alt text for images"
        end

        attribute :folder, :string do
          allow_nil? true
          default "/"
          description "Virtual folder path for organization"
        end

        create_timestamp :inserted_at
        update_timestamp :updated_at
      end

      actions do
        defaults [:read, :destroy]

        create :create do
          primary? true
          accept [:name, :filename, :content_type, :size, :url, :storage_path,
                  :storage_backend, :metadata, :alt_text, :folder, :site_id]
        end

        update :update do
          primary? true
          accept [:name, :alt_text, :folder, :metadata]
        end

        read :for_site do
          argument :site_id, :uuid, allow_nil?: false
          argument :folder, :string, allow_nil?: true
          prepare AshCms.Preparations.MediaForSite
        end

        read :images do
          argument :site_id, :uuid, allow_nil?: false
          prepare AshCms.Preparations.MediaImages
        end
      end
    end
  end
end
