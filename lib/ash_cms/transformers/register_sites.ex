defmodule AshCms.Transformers.RegisterSites do
  @moduledoc """
  Transformer that reads compile-time site declarations from the DSL
  and stores them so they can be seeded into the database at runtime.
  """

  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    sites = Spark.Dsl.Transformer.get_entities(dsl_state, [:ash_cms])
    {:ok, Spark.Dsl.Transformer.set_option(dsl_state, [:ash_cms], :__sites__, sites)}
  end

  def after_compile?, do: false
end
