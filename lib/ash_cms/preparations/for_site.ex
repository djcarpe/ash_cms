defmodule AshCms.Preparations.ForSite do
  use Ash.Resource.Preparation

  # Returns records that are global (no site_id) OR belong to the given site.
  def prepare(query, _opts, _context) do
    case Ash.Query.get_argument(query, :site_id) do
      nil ->
        query

      id ->
        Ash.Query.filter(query, is_nil(site_id) or site_id == ^id)
    end
  end
end
