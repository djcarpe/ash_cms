defmodule AshCms.Changes.NormalizeDomain do
  @moduledoc "Strips protocol prefix and trailing slash from domain attributes."

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :domain) do
      nil -> changeset
      "" -> changeset
      domain ->
        normalized =
          domain
          |> String.replace(~r/^https?:\/\//, "")
          |> String.trim_trailing("/")
          |> String.downcase()

        Ash.Changeset.change_attribute(changeset, :domain, normalized)
    end
  end
end
