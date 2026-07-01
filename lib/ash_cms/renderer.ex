defmodule AshCms.Renderer do
  @moduledoc """
  Renders CMS page content (block AST or raw HEEx template) to safe HTML.

  ## Modes

  - **Visual mode** (`editor_mode: :visual`): Iterates over `content["blocks"]`
    and renders each block using its type definition template.
  - **Code mode** (`editor_mode: :code`): EEx-evaluates the page's `template`
    field, injecting page/site assigns.

  ## Block rendering

  Built-in blocks are rendered via `render_block/2`. Custom components defined
  in the database are looked up and their template is evaluated with the block's
  props as assigns.
  """

  require Logger

  @doc """
  Render a page record to a safe HTML binary.

  `opts` may include:
  - `:components` — list of loaded Component records (avoids extra DB queries)
  - `:site` — the site record (used as assign in templates)
  """
  def render_page(page, opts \\ []) do
    site = opts[:site] || page.site
    components = opts[:components] || []

    html =
      case page.editor_mode do
        :code when not is_nil(page.template) and page.template != "" ->
          render_template(page.template, %{page: page, site: site})

        _ ->
          render_blocks(page.content["blocks"] || [], site, components)
      end

    {:ok, html}
  rescue
    e ->
      Logger.error("[AshCms.Renderer] Failed to render page #{page.id}: #{inspect(e)}")
      {:error, e}
  end

  @doc "Render a list of blocks to HTML."
  def render_blocks(blocks, site, components \\ []) do
    blocks
    |> Enum.sort_by(& &1["order"])
    |> Enum.map_join("\n", &render_block(&1, site, components))
  end

  @doc "Render a single block map to HTML."
  def render_block(%{"type" => type} = block, site, components) do
    props = block["props"] || %{}
    children = block["children"] || []
    child_html = render_blocks(children, site, components)

    cond do
      builtin_type?(type) ->
        render_builtin(type, props, child_html, site)

      custom = find_custom_component(type, components) ->
        render_custom_component(custom, props, child_html, site)

      true ->
        ~s(<div class="ash-cms-unknown-block" data-type="#{type}">Unknown block: #{type}</div>)
    end
  end

  # ── Built-in block renderers ─────────────────────────────────────────────────

  defp render_builtin("hero", props, _children, _site) do
    title = esc(props["title"])
    subtitle = esc(props["subtitle"])
    bg = esc(props["background_color"] || "#1a1a2e")
    color = esc(props["text_color"] || "#ffffff")
    btn_text = esc(props["button_text"])
    btn_url = esc(props["button_url"] || "#")
    height = hero_height(props["height"] || "large")
    align = text_align(props["align"] || "center")

    button_html =
      if btn_text && btn_text != "" do
        ~s(<a href="#{btn_url}" class="ash-cms-hero-btn">#{btn_text}</a>)
      else
        ""
      end

    """
    <section class="ash-cms-hero #{height}" style="background-color: #{bg}; color: #{color}; text-align: #{align};">
      <div class="ash-cms-hero-inner">
        <h1 class="ash-cms-hero-title">#{title}</h1>
        #{if subtitle && subtitle != "", do: ~s(<p class="ash-cms-hero-subtitle">#{subtitle}</p>), else: ""}
        #{button_html}
      </div>
    </section>
    """
  end

  defp render_builtin("text", props, _children, _site) do
    content = props["content"] || ""
    css_class = esc(props["css_class"] || "prose prose-lg max-w-4xl mx-auto py-8 px-4")
    ~s(<div class="ash-cms-text #{css_class}">#{content}</div>)
  end

  defp render_builtin("image", props, _children, _site) do
    src = esc(props["src"] || "")
    alt = esc(props["alt"] || "")
    caption = esc(props["caption"] || "")
    width_class = image_width(props["width"] || "full")
    align_class = image_align(props["align"] || "center")
    css_class = esc(props["css_class"] || "")

    cap_html =
      if caption != "",
        do: ~s(<figcaption class="ash-cms-image-caption">#{caption}</figcaption>),
        else: ""

    """
    <figure class="ash-cms-image #{width_class} #{align_class} #{css_class}">
      <img src="#{src}" alt="#{alt}" />
      #{cap_html}
    </figure>
    """
  end

  defp render_builtin("video", props, _children, _site) do
    src = esc(props["src"] || "")
    video_type = props["type"] || "url"
    poster = esc(props["poster"] || "")
    controls = if props["controls"] != false, do: "controls", else: ""
    autoplay = if props["autoplay"] == true, do: "autoplay", else: ""
    loop = if props["loop"] == true, do: "loop", else: ""
    muted = if props["muted"] != false, do: "muted", else: ""
    css_class = esc(props["css_class"] || "")

    case video_type do
      "youtube" ->
        video_id = extract_youtube_id(src)
        """
        <div class="ash-cms-video ash-cms-video-embed #{css_class}">
          <iframe src="https://www.youtube.com/embed/#{video_id}"
                  frameborder="0" allowfullscreen></iframe>
        </div>
        """

      "vimeo" ->
        video_id = extract_vimeo_id(src)
        """
        <div class="ash-cms-video ash-cms-video-embed #{css_class}">
          <iframe src="https://player.vimeo.com/video/#{video_id}"
                  frameborder="0" allowfullscreen></iframe>
        </div>
        """

      _ ->
        """
        <div class="ash-cms-video #{css_class}">
          <video src="#{src}" poster="#{poster}" #{controls} #{autoplay} #{loop} #{muted}></video>
        </div>
        """
    end
  end

  defp render_builtin("columns", props, children, _site) do
    count = props["count"] || 2
    gap_class = column_gap(props["gap"] || "medium")
    css_class = esc(props["css_class"] || "")
    cols_class = "ash-cms-cols ash-cms-cols-#{count} #{gap_class} #{css_class}"

    ~s(<div class="#{cols_class}">#{children}</div>)
  end

  defp render_builtin("divider", props, _children, _site) do
    style = esc(props["style"] || "solid")
    color = esc(props["color"] || "#e5e7eb")
    thickness = esc(props["thickness"] || "1")
    margin_class = divider_margin(props["margin"] || "medium")

    ~s(<hr class="ash-cms-divider #{margin_class}" style="border-style: #{style}; border-color: #{color}; border-top-width: #{thickness}px;" />)
  end

  defp render_builtin("button", props, _children, _site) do
    text = esc(props["text"] || "Button")
    url = esc(props["url"] || "#")
    variant = esc(props["variant"] || "primary")
    size_class = button_size(props["size"] || "medium")
    align_class = button_align(props["align"] || "center")
    target = if props["open_in_new_tab"] == true, do: ~s(target="_blank" rel="noopener"), else: ""

    """
    <div class="ash-cms-button-wrapper #{align_class}">
      <a href="#{url}" #{target} class="ash-cms-btn ash-cms-btn-#{variant} #{size_class}">#{text}</a>
    </div>
    """
  end

  defp render_builtin("html", props, _children, _site) do
    content = props["content"] || ""
    css_class = esc(props["css_class"] || "")
    ~s(<div class="ash-cms-html #{css_class}">#{content}</div>)
  end

  defp render_builtin("spacer", props, _children, _site) do
    height = esc(props["height"] || "48")
    hidden_class = if props["responsive_hidden"] == true, do: "hidden md:block", else: ""
    ~s(<div class="ash-cms-spacer #{hidden_class}" style="height: #{height}px;"></div>)
  end

  defp render_builtin(type, _props, _children, _site) do
    ~s(<div class="ash-cms-unknown-block" data-type="#{type}">Unknown built-in: #{type}</div>)
  end

  # ── Custom component rendering ────────────────────────────────────────────────

  defp render_custom_component(component, props, _child_html, site) do
    merged_props = Map.merge(component.default_props || %{}, props)
    render_template(component.template, %{props: merged_props, site: site})
  end

  defp render_template(template, assigns) do
    EEx.eval_string(template, assigns: assigns)
  rescue
    e ->
      Logger.error("[AshCms.Renderer] Template error: #{inspect(e)}")
      ~s(<div class="ash-cms-template-error">Template error: #{inspect(e)}</div>)
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp builtin_type?(type), do: type in ~w(hero text image video columns divider button html spacer)

  defp find_custom_component(type, components) do
    Enum.find(components, &(&1.slug == type))
  end

  defp esc(nil), do: ""
  defp esc(s) when is_binary(s), do: Phoenix.HTML.html_escape(s) |> Phoenix.HTML.safe_to_string()
  defp esc(v), do: esc(to_string(v))

  defp hero_height("small"), do: "ash-cms-hero-sm"
  defp hero_height("large"), do: "ash-cms-hero-lg"
  defp hero_height("full"), do: "ash-cms-hero-full"
  defp hero_height(_), do: "ash-cms-hero-md"

  defp text_align("left"), do: "left"
  defp text_align("right"), do: "right"
  defp text_align(_), do: "center"

  defp image_width("half"), do: "ash-cms-img-half"
  defp image_width("quarter"), do: "ash-cms-img-quarter"
  defp image_width("auto"), do: "ash-cms-img-auto"
  defp image_width(_), do: "ash-cms-img-full"

  defp image_align("left"), do: "ash-cms-align-left"
  defp image_align("right"), do: "ash-cms-align-right"
  defp image_align(_), do: "ash-cms-align-center"

  defp column_gap("none"), do: "ash-cms-gap-none"
  defp column_gap("small"), do: "ash-cms-gap-sm"
  defp column_gap("large"), do: "ash-cms-gap-lg"
  defp column_gap(_), do: "ash-cms-gap-md"

  defp divider_margin("none"), do: "ash-cms-my-none"
  defp divider_margin("small"), do: "ash-cms-my-sm"
  defp divider_margin("large"), do: "ash-cms-my-lg"
  defp divider_margin(_), do: "ash-cms-my-md"

  defp button_size("small"), do: "ash-cms-btn-sm"
  defp button_size("large"), do: "ash-cms-btn-lg"
  defp button_size(_), do: "ash-cms-btn-md"

  defp button_align("left"), do: "ash-cms-text-left"
  defp button_align("right"), do: "ash-cms-text-right"
  defp button_align(_), do: "ash-cms-text-center"

  defp extract_youtube_id(url) do
    case Regex.run(~r/(?:v=|youtu\.be\/)([^&\s]+)/, url) do
      [_, id] -> id
      _ -> url
    end
  end

  defp extract_vimeo_id(url) do
    case Regex.run(~r/vimeo\.com\/(\d+)/, url) do
      [_, id] -> id
      _ -> url
    end
  end
end
