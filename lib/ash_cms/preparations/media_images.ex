defmodule AshCms.Preparations.MediaImages do
  use Ash.Resource.Preparation

  def prepare(query, _opts, _context) do
    id = Ash.Query.get_argument(query, :site_id)
    Ash.Query.filter(query, site_id == ^id and like(content_type, "image/%"))
  end
end
