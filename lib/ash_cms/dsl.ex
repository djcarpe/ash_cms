defmodule AshCms.Dsl do
  @moduledoc """
  DSL definitions for the AshCms domain extension.

  Allows domains to declare CMS configuration using the `ash_cms` section.

  ## Example

      defmodule MyApp.CMS do
        use Ash.Domain, extensions: [AshCms.DomainExtension]

        ash_cms do
          pubsub_server MyApp.PubSub
          endpoint MyAppWeb.Endpoint

          site "My Site" do
            slug "main"
            domain "mysite.com"
            css_url "/assets/site.css"
            js_url "/assets/site.js"
          end
        end

        resources do
          resource MyApp.CMS.Site
          resource MyApp.CMS.Page
          resource MyApp.CMS.Component
          resource MyApp.CMS.Layout
          resource MyApp.CMS.Media
        end
      end
  """

  @site %Spark.Dsl.Entity{
    name: :site,
    describe: "Declares a CMS site configuration.",
    examples: [
      """
      site "My Site" do
        slug "main"
        domain "mysite.com"
        css_url "/assets/site.css"
      end
      """
    ],
    target: AshCms.Dsl.Site,
    args: [:name],
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "The human-readable name of the site."
      ],
      slug: [
        type: :string,
        required: false,
        doc: "The URL-safe slug identifying this site. Defaults to a slugified name."
      ],
      domain: [
        type: :string,
        required: false,
        doc: "The domain name for this site (e.g. 'mysite.com')."
      ],
      css_url: [
        type: :string,
        required: false,
        doc: "URL path to the site's main CSS file."
      ],
      js_url: [
        type: :string,
        required: false,
        doc: "URL path to the site's main JavaScript file."
      ],
      custom_css: [
        type: :string,
        required: false,
        doc: "Inline CSS to inject into every page of this site."
      ]
    ]
  }

  @ash_cms %Spark.Dsl.Section{
    name: :ash_cms,
    describe: "Configures the AshCms extension for this domain.",
    examples: [
      """
      ash_cms do
        pubsub_server MyApp.PubSub
        endpoint MyAppWeb.Endpoint

        site "My Site" do
          slug "main"
          domain "mysite.com"
        end
      end
      """
    ],
    schema: [
      pubsub_server: [
        type: :atom,
        required: false,
        doc: "The Phoenix.PubSub server to use for real-time page updates."
      ],
      endpoint: [
        type: :atom,
        required: false,
        doc: "The Phoenix.Endpoint module."
      ],
      media_storage: [
        type: {:one_of, [:local, :s3]},
        default: :local,
        doc: "Where to store uploaded media. :local or :s3."
      ],
      s3_bucket: [
        type: :string,
        required: false,
        doc: "The S3 bucket name for media uploads (when media_storage is :s3)."
      ],
      s3_prefix: [
        type: :string,
        required: false,
        default: "ash_cms",
        doc: "The S3 key prefix for all media uploads."
      ],
      upload_dir: [
        type: :string,
        required: false,
        default: "priv/static/uploads",
        doc: "Local directory for uploaded media (when media_storage is :local)."
      ]
    ],
    entities: [@site]
  }

  def sections, do: [@ash_cms]
end

defmodule AshCms.Dsl.Site do
  @moduledoc "Represents a compile-time site declaration in the domain DSL."

  defstruct [:name, :slug, :domain, :css_url, :js_url, :custom_css]
end
