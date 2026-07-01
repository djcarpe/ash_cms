defmodule AshCms.Blocks do
  @moduledoc """
  Built-in block type definitions for the CMS visual editor.

  Each block type defines:
  - `type` — unique string identifier used in the content AST
  - `name` — display name in the component palette
  - `icon` — Heroicons icon name
  - `category` — grouping in the palette (layout | content | media | interactive)
  - `default_props` — default property values for new instances
  - `props_schema` — JSON schema describing configurable props (drives Properties Panel)
  - `render/2` — renders the block as safe HTML given props and context

  ## Adding custom blocks

  Register custom block types at application startup:

      AshCms.Blocks.register(%{
        type: "my_card",
        name: "Card",
        icon: "credit-card",
        category: "content",
        default_props: %{"title" => "Card Title", "body" => ""},
        props_schema: %{
          "title" => %{"type" => "string", "label" => "Title"},
          "body" => %{"type" => "richtext", "label" => "Body"}
        }
      })
  """

  @builtin_blocks [
    %{
      type: "hero",
      name: "Hero Banner",
      icon: "star",
      category: "layout",
      default_props: %{
        "title" => "Welcome to Our Site",
        "subtitle" => "A beautiful website built with AshCms",
        "button_text" => "Get Started",
        "button_url" => "#",
        "background_color" => "#1a1a2e",
        "text_color" => "#ffffff",
        "height" => "large",
        "align" => "center"
      },
      props_schema: %{
        "title" => %{"type" => "string", "label" => "Title"},
        "subtitle" => %{"type" => "string", "label" => "Subtitle"},
        "button_text" => %{"type" => "string", "label" => "Button Text"},
        "button_url" => %{"type" => "string", "label" => "Button URL"},
        "background_color" => %{"type" => "color", "label" => "Background Color"},
        "text_color" => %{"type" => "color", "label" => "Text Color"},
        "height" => %{"type" => "select", "label" => "Height",
                      "options" => ["small", "medium", "large", "full"]},
        "align" => %{"type" => "select", "label" => "Alignment",
                     "options" => ["left", "center", "right"]}
      }
    },
    %{
      type: "text",
      name: "Rich Text",
      icon: "document-text",
      category: "content",
      default_props: %{
        "content" => "<p>Start writing your content here...</p>",
        "css_class" => "prose prose-lg max-w-4xl mx-auto py-8 px-4"
      },
      props_schema: %{
        "content" => %{"type" => "richtext", "label" => "Content"},
        "css_class" => %{"type" => "string", "label" => "CSS Classes"}
      }
    },
    %{
      type: "image",
      name: "Image",
      icon: "photo",
      category: "media",
      default_props: %{
        "src" => "",
        "alt" => "",
        "caption" => "",
        "width" => "full",
        "align" => "center",
        "css_class" => ""
      },
      props_schema: %{
        "src" => %{"type" => "media", "label" => "Image", "accept" => "image/*"},
        "alt" => %{"type" => "string", "label" => "Alt Text"},
        "caption" => %{"type" => "string", "label" => "Caption"},
        "width" => %{"type" => "select", "label" => "Width",
                     "options" => ["auto", "full", "half", "quarter"]},
        "align" => %{"type" => "select", "label" => "Alignment",
                     "options" => ["left", "center", "right"]},
        "css_class" => %{"type" => "string", "label" => "CSS Classes"}
      }
    },
    %{
      type: "video",
      name: "Video",
      icon: "video-camera",
      category: "media",
      default_props: %{
        "src" => "",
        "type" => "url",
        "poster" => "",
        "autoplay" => false,
        "loop" => false,
        "muted" => true,
        "controls" => true,
        "css_class" => ""
      },
      props_schema: %{
        "src" => %{"type" => "string", "label" => "Video URL or upload"},
        "type" => %{"type" => "select", "label" => "Source Type",
                    "options" => ["url", "youtube", "vimeo", "upload"]},
        "poster" => %{"type" => "media", "label" => "Poster Image"},
        "autoplay" => %{"type" => "boolean", "label" => "Autoplay"},
        "loop" => %{"type" => "boolean", "label" => "Loop"},
        "muted" => %{"type" => "boolean", "label" => "Muted"},
        "controls" => %{"type" => "boolean", "label" => "Show Controls"},
        "css_class" => %{"type" => "string", "label" => "CSS Classes"}
      }
    },
    %{
      type: "columns",
      name: "Columns",
      icon: "view-columns",
      category: "layout",
      default_props: %{
        "count" => 2,
        "gap" => "medium",
        "css_class" => ""
      },
      props_schema: %{
        "count" => %{"type" => "select", "label" => "Columns",
                     "options" => [2, 3, 4]},
        "gap" => %{"type" => "select", "label" => "Gap",
                   "options" => ["none", "small", "medium", "large"]},
        "css_class" => %{"type" => "string", "label" => "CSS Classes"}
      }
    },
    %{
      type: "divider",
      name: "Divider",
      icon: "minus",
      category: "layout",
      default_props: %{
        "style" => "solid",
        "color" => "#e5e7eb",
        "thickness" => "1",
        "margin" => "medium"
      },
      props_schema: %{
        "style" => %{"type" => "select", "label" => "Style",
                     "options" => ["solid", "dashed", "dotted"]},
        "color" => %{"type" => "color", "label" => "Color"},
        "thickness" => %{"type" => "select", "label" => "Thickness",
                         "options" => ["1", "2", "4"]},
        "margin" => %{"type" => "select", "label" => "Vertical Margin",
                      "options" => ["none", "small", "medium", "large"]}
      }
    },
    %{
      type: "button",
      name: "Button",
      icon: "cursor-arrow-rays",
      category: "interactive",
      default_props: %{
        "text" => "Click Me",
        "url" => "#",
        "variant" => "primary",
        "size" => "medium",
        "align" => "center",
        "open_in_new_tab" => false
      },
      props_schema: %{
        "text" => %{"type" => "string", "label" => "Button Text"},
        "url" => %{"type" => "string", "label" => "URL"},
        "variant" => %{"type" => "select", "label" => "Style",
                       "options" => ["primary", "secondary", "outline", "ghost"]},
        "size" => %{"type" => "select", "label" => "Size",
                    "options" => ["small", "medium", "large"]},
        "align" => %{"type" => "select", "label" => "Alignment",
                     "options" => ["left", "center", "right"]},
        "open_in_new_tab" => %{"type" => "boolean", "label" => "Open in New Tab"}
      }
    },
    %{
      type: "html",
      name: "Custom HTML",
      icon: "code-bracket",
      category: "content",
      default_props: %{
        "content" => "<div>\n  <!-- Custom HTML here -->\n</div>",
        "css_class" => ""
      },
      props_schema: %{
        "content" => %{"type" => "code", "label" => "HTML Content", "language" => "html"},
        "css_class" => %{"type" => "string", "label" => "Wrapper CSS Classes"}
      }
    },
    %{
      type: "spacer",
      name: "Spacer",
      icon: "arrows-up-down",
      category: "layout",
      default_props: %{"height" => "48", "responsive_hidden" => false},
      props_schema: %{
        "height" => %{"type" => "select", "label" => "Height (px)",
                      "options" => ["16", "24", "32", "48", "64", "96", "128"]},
        "responsive_hidden" => %{"type" => "boolean", "label" => "Hide on Mobile"}
      }
    }
  ]

  @registry_key :ash_cms_custom_blocks

  @doc "Return all built-in block type definitions."
  def builtin, do: @builtin_blocks

  @doc "Register a custom block type at runtime."
  def register(block_def) when is_map(block_def) do
    existing = :persistent_term.get(@registry_key, [])
    :persistent_term.put(@registry_key, [block_def | existing])
  end

  @doc "Return all block types (built-in + custom)."
  def all do
    custom = :persistent_term.get(@registry_key, [])
    @builtin_blocks ++ custom
  end

  @doc "Return all block types grouped by category."
  def grouped do
    all()
    |> Enum.group_by(& &1.category)
    |> Enum.sort_by(fn {cat, _} ->
      Enum.find_index(~w(layout content media interactive custom), &(&1 == cat)) || 99
    end)
  end

  @doc "Find a block type definition by type string."
  def find(type) do
    Enum.find(all(), &(&1.type == type))
  end

  @doc "Generate a new block map with default props for the given type."
  def new_block(type) do
    case find(type) do
      nil ->
        {:error, :unknown_type}

      block_def ->
        {:ok,
         %{
           "id" => generate_id(),
           "type" => type,
           "order" => 0,
           "props" => block_def.default_props,
           "children" => []
         }}
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
