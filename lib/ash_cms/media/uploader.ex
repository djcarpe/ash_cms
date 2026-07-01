defmodule AshCms.Media.Uploader do
  @moduledoc """
  Handles media file uploads for AshCms.

  Supports two storage backends:
  - `:local` — saves files to `priv/static/uploads/` and returns a local URL
  - `:s3` — uploads to an S3-compatible bucket via `ex_aws_s3`

  ## Configuration

      config :ash_cms,
        media_storage: :s3,
        s3_bucket: "my-bucket",
        s3_prefix: "cms/media",
        upload_dir: "priv/static/uploads"   # for :local backend

  ## Usage

      {:ok, url, path} = AshCms.Media.Uploader.upload(binary, "photo.jpg", "image/jpeg")

      # Then persist:
      Ash.create(AshCms.media_resource(), %{
        name: "photo.jpg",
        filename: "photo.jpg",
        content_type: "image/jpeg",
        size: byte_size(binary),
        url: url,
        storage_path: path,
        storage_backend: AshCms.Media.Uploader.backend(),
        site_id: site.id
      }, domain: AshCms.domain())
  """

  @doc "Returns the configured storage backend (:local or :s3)."
  def backend do
    Application.get_env(:ash_cms, :media_storage, :local)
  end

  @doc """
  Upload binary data to the configured storage backend.

  Returns `{:ok, public_url, storage_path}` or `{:error, reason}`.
  """
  def upload(binary, filename, content_type) do
    ext = Path.extname(filename)
    unique_name = "#{generate_id()}#{ext}"

    case backend() do
      :local -> upload_local(binary, unique_name, content_type)
      :s3 -> upload_s3(binary, unique_name, content_type, filename)
    end
  end

  @doc "Delete a stored file by its storage path."
  def delete(storage_path) do
    case backend() do
      :local -> delete_local(storage_path)
      :s3 -> delete_s3(storage_path)
    end
  end

  # ── Local storage ─────────────────────────────────────────────────────────────

  defp upload_local(binary, unique_name, _content_type) do
    upload_dir = Application.get_env(:ash_cms, :upload_dir, "priv/static/uploads")
    File.mkdir_p!(upload_dir)

    path = Path.join(upload_dir, unique_name)
    public_url = "/uploads/#{unique_name}"

    case File.write(path, binary) do
      :ok -> {:ok, public_url, path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete_local(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # ── S3 storage ───────────────────────────────────────────────────────────────

  defp upload_s3(binary, unique_name, content_type, _original_name) do
    with {:ok, bucket} <- get_s3_bucket(),
         prefix = Application.get_env(:ash_cms, :s3_prefix, "ash_cms"),
         key = "#{prefix}/#{unique_name}",
         {:ok, url} <- do_s3_upload(binary, bucket, key, content_type) do
      {:ok, url, key}
    end
  end

  defp do_s3_upload(binary, bucket, key, content_type) do
    if Code.ensure_loaded?(ExAws) && Code.ensure_loaded?(ExAws.S3) do
      result =
        ExAws.S3.put_object(bucket, key, binary, [
          {:content_type, content_type},
          {:acl, :public_read}
        ])
        |> ExAws.request()

      case result do
        {:ok, _response} ->
          region = Application.get_env(:ex_aws, :region, "us-east-1")
          url = "https://#{bucket}.s3.#{region}.amazonaws.com/#{key}"
          {:ok, url}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :ex_aws_not_available}
    end
  end

  defp delete_s3(key) do
    with {:ok, bucket} <- get_s3_bucket() do
      if Code.ensure_loaded?(ExAws) && Code.ensure_loaded?(ExAws.S3) do
        ExAws.S3.delete_object(bucket, key)
        |> ExAws.request()
        |> case do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
      else
        {:error, :ex_aws_not_available}
      end
    end
  end

  defp get_s3_bucket do
    case Application.get_env(:ash_cms, :s3_bucket) do
      nil -> {:error, :s3_bucket_not_configured}
      bucket -> {:ok, bucket}
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.encode16(case: :lower)
  end
end
