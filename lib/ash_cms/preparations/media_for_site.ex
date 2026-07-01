defmodule AshCms.Preparations.MediaForSite do
  use Ash.Resource.Preparation

  def prepare(query, _opts, _context) do
    site_id = Ash.Query.get_argument(query, :site_id)
    folder = Ash.Query.get_argument(query, :folder)

    query = Ash.Query.filter(query, site_id == ^site_id)

    case folder do
      nil -> query
      f -> Ash.Query.filter(query, folder == ^f)
    end
  end
end
