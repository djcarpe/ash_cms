defmodule Example.CMS.Component do
  @moduledoc "CMS Component resource — user-defined reusable blocks."

  use Ash.Resource,
    domain: Example.CMS,
    data_layer: AshSqlite.DataLayer

  use AshCms.Resource.ComponentAttributes

  sqlite do
    table "cms_components"
    repo Example.Repo
  end

  relationships do
    belongs_to :site, Example.CMS.Site,
      allow_nil?: true,
      attribute_writable?: true
  end
end
