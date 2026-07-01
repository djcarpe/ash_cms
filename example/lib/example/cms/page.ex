defmodule Example.CMS.Page do
  @moduledoc "CMS Page resource — stores pages with their block content."

  use Ash.Resource,
    domain: Example.CMS,
    data_layer: AshSqlite.DataLayer

  use AshCms.Resource.PageAttributes

  sqlite do
    table "cms_pages"
    repo Example.Repo
  end

  relationships do
    belongs_to :site, Example.CMS.Site,
      allow_nil?: false,
      attribute_writable?: true

    belongs_to :layout, Example.CMS.Layout,
      allow_nil?: true,
      attribute_writable?: true
  end
end
