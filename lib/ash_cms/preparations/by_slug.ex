defmodule AshCms.Preparations.BySlug do
  use Ash.Resource.Preparation

  def prepare(query, _opts, _context) do
    slug = Ash.Query.get_argument(query, :slug)
    query = Ash.Query.filter(query, slug == ^slug)

    case Ash.Query.get_argument(query, :site_id) do
      nil -> query
      site_id -> Ash.Query.filter(query, site_id == ^site_id)
    end
  end
end
