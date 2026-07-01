defmodule Example.CMS.Site do
  @moduledoc "CMS Site resource — stores registered sites with their config."

  use Ash.Resource,
    domain: Example.CMS,
    data_layer: AshSqlite.DataLayer

  use AshCms.Resource.SiteAttributes

  sqlite do
    table "cms_sites"
    repo Example.Repo
  end

  relationships do
    has_many :pages, Example.CMS.Page
    has_many :components, Example.CMS.Component
    has_many :layouts, Example.CMS.Layout
    has_many :media, Example.CMS.Media
  end
end
