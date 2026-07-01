defmodule Example.CMS.Layout do
  @moduledoc "CMS Layout resource — wraps page content with header/footer/nav."

  use Ash.Resource,
    domain: Example.CMS,
    data_layer: AshSqlite.DataLayer

  use AshCms.Resource.LayoutAttributes

  sqlite do
    table "cms_layouts"
    repo Example.Repo
  end

  relationships do
    belongs_to :site, Example.CMS.Site,
      allow_nil?: true,
      attribute_writable?: true
  end
end
