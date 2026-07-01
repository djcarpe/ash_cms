defmodule AshCms.Preparations.Published do
  use Ash.Resource.Preparation

  def prepare(query, _opts, _context) do
    query = Ash.Query.filter(query, published == true)

    case Ash.Query.get_argument(query, :site_id) do
      nil -> query
      site_id -> Ash.Query.filter(query, site_id == ^site_id)
    end
  end
end
