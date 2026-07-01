defmodule Example.CMS do
  @moduledoc """
  The CMS Ash domain for the example application.

  Contains all CMS resources and wires up AshCms extensions.
  """

  use Ash.Domain, extensions: [AshCms.DomainExtension]

  ash_cms do
    pubsub_server Example.PubSub
    endpoint ExampleWeb.Endpoint
    media_storage :local
    upload_dir "priv/static/uploads"

    site "Demo Site" do
      slug "demo"
      domain "localhost"
      css_url "/assets/app.css"
    end
  end

  resources do
    resource Example.CMS.Site
    resource Example.CMS.Page
    resource Example.CMS.Component
    resource Example.CMS.Layout
    resource Example.CMS.Media
  end
end
