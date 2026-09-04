# `igniter` is an optional dependency, so this installer cannot be compiled
# unconditionally: in an environment that does not pull it in - notably
# MIX_ENV=prod, where a release does not want a code-generation tool - the
# `use Igniter.Mix.Task` below fails the whole ash_cms compile.
if Code.ensure_loaded?(Igniter.Mix.Task) do
  defmodule Mix.Tasks.AshCms.Install do
    @moduledoc """
    Installs AshCms into a Phoenix + Ash application.

        mix igniter.install ash_cms

    What this task does:

    1. Creates the CMS Ash resource modules in `lib/my_app/cms/`
    2. Creates a CMS Ash domain
    3. Configures `:ash_cms` in `config/config.exs`
    4. Adds `AshCms.CMSSupervisor` to the application supervision tree
    5. Adds `ash_cms_routes()` and `ash_cms_admin_routes()` to the Phoenix router
    6. Generates migration files (for Ecto-based data layers)
    7. Prints next steps for asset setup
    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :ash_cms,
        adds_deps: [
          {:ash_cms, "~> 0.1"}
        ],
        installs: [],
        example: "mix igniter.install ash_cms"
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      app_name = Igniter.Project.Application.app_name(igniter)
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      app_module = Igniter.Project.Module.module_name(igniter, "")

      cms_module = Module.concat([app_module, "CMS"])
      site_module = Module.concat([cms_module, "Site"])
      page_module = Module.concat([cms_module, "Page"])
      component_module = Module.concat([cms_module, "Component"])
      layout_module = Module.concat([cms_module, "Layout"])
      media_module = Module.concat([cms_module, "Media"])

      igniter
      |> create_cms_domain(cms_module, [site_module, page_module, component_module, layout_module, media_module])
      |> create_site_resource(site_module, cms_module, app_module)
      |> create_page_resource(page_module, cms_module, app_module, site_module, layout_module)
      |> create_component_resource(component_module, cms_module, app_module, site_module)
      |> create_layout_resource(layout_module, cms_module, app_module, site_module)
      |> create_media_resource(media_module, cms_module, app_module, site_module)
      |> add_config(app_name, cms_module, site_module, page_module, component_module, layout_module, media_module, web_module)
      |> add_supervisor(app_module)
      |> add_router_routes(web_module)
      |> print_next_steps()
    end

    defp create_cms_domain(igniter, cms_module, resource_modules) do
      resources_code =
        resource_modules
        |> Enum.map_join("\n      ", &"resource #{inspect(&1)}")

      Igniter.Project.Module.create_module(igniter, cms_module, """
      use Ash.Domain, extensions: [AshCms.DomainExtension]

      ash_cms do
        pubsub_server #{inspect(Module.concat([elem(Module.split(cms_module), 0), "PubSub"]))}
        endpoint #{inspect(Module.concat([elem(Module.split(cms_module), 0), "Web.Endpoint"]))}
      end

      resources do
        #{resources_code}
      end
      """)
    end

    defp create_site_resource(igniter, site_module, cms_module, app_module) do
      repo = Module.concat([app_module, "Repo"])

      Igniter.Project.Module.create_module(igniter, site_module, """
      use Ash.Resource,
        domain: #{inspect(cms_module)},
        data_layer: AshSqlite.DataLayer

      use AshCms.Resource.SiteAttributes

      sqlite do
        table "cms_sites"
        repo #{inspect(repo)}
      end

      relationships do
        has_many :pages, #{inspect(Module.concat([cms_module, "Page"]))}
        has_many :components, #{inspect(Module.concat([cms_module, "Component"]))}
        has_many :layouts, #{inspect(Module.concat([cms_module, "Layout"]))}
        has_many :media, #{inspect(Module.concat([cms_module, "Media"]))}
      end
      """)
    end

    defp create_page_resource(igniter, page_module, cms_module, app_module, site_module, layout_module) do
      repo = Module.concat([app_module, "Repo"])

      Igniter.Project.Module.create_module(igniter, page_module, """
      use Ash.Resource,
        domain: #{inspect(cms_module)},
        data_layer: AshSqlite.DataLayer

      use AshCms.Resource.PageAttributes

      sqlite do
        table "cms_pages"
        repo #{inspect(repo)}
      end

      relationships do
        belongs_to :site, #{inspect(site_module)}, allow_nil?: false, attribute_writable?: true
        belongs_to :layout, #{inspect(layout_module)}, allow_nil?: true, attribute_writable?: true
      end
      """)
    end

    defp create_component_resource(igniter, component_module, cms_module, app_module, site_module) do
      repo = Module.concat([app_module, "Repo"])

      Igniter.Project.Module.create_module(igniter, component_module, """
      use Ash.Resource,
        domain: #{inspect(cms_module)},
        data_layer: AshSqlite.DataLayer

      use AshCms.Resource.ComponentAttributes

      sqlite do
        table "cms_components"
        repo #{inspect(repo)}
      end

      relationships do
        belongs_to :site, #{inspect(site_module)}, allow_nil?: true, attribute_writable?: true
      end
      """)
    end

    defp create_layout_resource(igniter, layout_module, cms_module, app_module, site_module) do
      repo = Module.concat([app_module, "Repo"])

      Igniter.Project.Module.create_module(igniter, layout_module, """
      use Ash.Resource,
        domain: #{inspect(cms_module)},
        data_layer: AshSqlite.DataLayer

      use AshCms.Resource.LayoutAttributes

      sqlite do
        table "cms_layouts"
        repo #{inspect(repo)}
      end

      relationships do
        belongs_to :site, #{inspect(site_module)}, allow_nil?: true, attribute_writable?: true
      end
      """)
    end

    defp create_media_resource(igniter, media_module, cms_module, app_module, site_module) do
      repo = Module.concat([app_module, "Repo"])

      Igniter.Project.Module.create_module(igniter, media_module, """
      use Ash.Resource,
        domain: #{inspect(cms_module)},
        data_layer: AshSqlite.DataLayer

      use AshCms.Resource.MediaAttributes

      sqlite do
        table "cms_media"
        repo #{inspect(repo)}
      end

      relationships do
        belongs_to :site, #{inspect(site_module)}, allow_nil?: false, attribute_writable?: true
      end
      """)
    end

    defp add_config(igniter, app_name, cms_module, site_module, page_module, component_module, layout_module, media_module, web_module) do
      endpoint = Module.concat([web_module, "Endpoint"])
      pubsub = Module.concat([app_name |> to_string() |> Macro.camelize(), "PubSub"])

      Igniter.Project.Config.configure(igniter, "config.exs", :ash_cms, [],
        """
        domain: #{inspect(cms_module)},
        site_resource: #{inspect(site_module)},
        page_resource: #{inspect(page_module)},
        component_resource: #{inspect(component_module)},
        layout_resource: #{inspect(layout_module)},
        media_resource: #{inspect(media_module)},
        endpoint: #{inspect(endpoint)},
        pubsub_server: #{inspect(pubsub)},
        media_storage: :local,
        upload_dir: "priv/static/uploads"
        """
      )
    end

    defp add_supervisor(igniter, app_module) do
      Igniter.Project.Application.add_new_child(
        igniter,
        {AshCms.CMSSupervisor, []},
        after: fn
          {Ecto.Adapters.SQL.Sandbox, _} -> true
          _ -> false
        end
      )
    end

    defp add_router_routes(igniter, web_module) do
      router_module = Module.concat([web_module, "Router"])

      igniter
      |> Igniter.Libs.Phoenix.add_scope_to_router(
        router_module,
        "/cms",
        "ash_cms_admin_routes(\"/cms\")",
        pipe_through: :browser
      )
      |> Igniter.Libs.Phoenix.append_to_scope(
        router_module,
        "/",
        "ash_cms_routes()",
        pipe_through: :browser
      )
    end

    defp print_next_steps(igniter) do
      Igniter.add_notice(igniter, """
      ╔══════════════════════════════════════════════════════════╗
      ║               AshCms installed successfully!             ║
      ╚══════════════════════════════════════════════════════════╝

      Next steps:

      1. Run migrations:
         mix ash.migrate

      2. Add CMS JavaScript hooks to your app.js:

           import { AshCmsHooks } from "../../deps/ash_cms/priv/static/ash_cms.js"

           let liveSocket = new LiveSocket("/live", Socket, {
             hooks: { ...AshCmsHooks, ...Hooks }
           })

      3. Add CMS CSS to your app.css:

           @import "../../deps/ash_cms/priv/static/ash_cms.css";

      4. Start the server and visit /cms to manage your CMS.

      5. Optional — configure S3 media storage in config/config.exs:

           config :ash_cms,
             media_storage: :s3,
             s3_bucket: "my-bucket",
             s3_prefix: "cms/media"

           # Also configure ex_aws:
           config :ex_aws,
             access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}],
             secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}]
      """)
    end
  end
end
