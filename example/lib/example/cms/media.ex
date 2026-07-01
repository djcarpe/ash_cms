defmodule Example.CMS.Media do
  @moduledoc "CMS Media resource — tracks uploaded files (local or S3)."

  use Ash.Resource,
    domain: Example.CMS,
    data_layer: AshSqlite.DataLayer

  use AshCms.Resource.MediaAttributes

  sqlite do
    table "cms_media"
    repo Example.Repo
  end

  relationships do
    belongs_to :site, Example.CMS.Site,
      allow_nil?: false,
      attribute_writable?: true
  end
end
