defmodule AshCms.DomainExtension do
  @moduledoc """
  Spark DSL extension that adds `ash_cms do ... end` to Ash domains.

  Add it to your domain:

      defmodule MyApp.CMS do
        use Ash.Domain, extensions: [AshCms.DomainExtension]

        ash_cms do
          pubsub_server MyApp.PubSub
          endpoint MyAppWeb.Endpoint
        end
      end
  """

  use Spark.Dsl.Extension,
    sections: AshCms.Dsl.sections(),
    transformers: [AshCms.Transformers.RegisterSites]
end
