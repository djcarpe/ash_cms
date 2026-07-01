defmodule AshCms.Changes.SlugifyIfBlank do
  @moduledoc """
  Ash change that auto-generates a slug from a source attribute if the slug
  attribute is blank or not provided.

  Usage in an action:

      change AshCms.Changes.SlugifyIfBlank, attribute: :slug, source: :name
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    attr = opts[:attribute] || :slug
    source = opts[:source] || :name

    case Ash.Changeset.get_attribute(changeset, attr) do
      nil ->
        value = Ash.Changeset.get_attribute(changeset, source) || ""
        Ash.Changeset.change_attribute(changeset, attr, slugify(value))

      "" ->
        value = Ash.Changeset.get_attribute(changeset, source) || ""
        Ash.Changeset.change_attribute(changeset, attr, slugify(value))

      _existing ->
        changeset
    end
  end

  defp slugify(str) do
    str
    |> String.downcase()
    |> String.replace(~r/[^\w\s\-]/, "")
    |> String.replace(~r/[\s_]+/, "-")
    |> String.replace(~r/^-+|-+$/, "")
    |> case do
      "" -> "page-#{System.unique_integer([:positive])}"
      slug -> slug
    end
  end
end
