defmodule AshCms.Live.Components.PropertiesPanel do
  @moduledoc """
  LiveComponent that renders the Properties Panel for the currently selected block.

  Automatically generates form fields based on the block's `props_schema`.

  Supported field types:
  - `string` — text input
  - `richtext` — contenteditable rich text
  - `color` — color picker + hex input
  - `boolean` — toggle
  - `select` — dropdown with options list
  - `media` — opens the MediaPicker modal
  - `code` — inline Monaco editor
  """

  use Phoenix.LiveComponent

  import Phoenix.HTML, only: [raw: 1]

  @impl true
  def mount(socket), do: {:ok, socket}

  @impl true
  def update(%{block: block, components: components, site_id: site_id}, socket) do
    schema = get_props_schema(block, components)

    {:ok,
     socket
     |> assign(:block, block)
     |> assign(:schema, schema)
     |> assign(:site_id, site_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ash-cms-props-panel">
      <div class="ash-cms-props-header">
        <h3 class="ash-cms-props-title"><%= block_type_name(@block) %></h3>
        <span class="ash-cms-props-type"><%= @block["type"] %></span>
      </div>

      <div class="ash-cms-props-fields">
        <%= for {key, field_schema} <- Enum.sort_by(@schema, fn {k, _} -> k end) do %>
          <div class="ash-cms-prop-field">
            <label class="ash-cms-prop-label">
              <%= field_schema["label"] || key %>
            </label>
            <.prop_field
              block_id={@block["id"]}
              field_key={key}
              value={@block["props"][key]}
              schema={field_schema}
              myself={@myself}
            />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ── Field function components ────────────────────────────────────────────────
  # Each clause pattern-matches on schema["type"] via a guard on @schema.

  attr :block_id, :string, required: true
  attr :field_key, :string, required: true
  attr :value, :any, default: nil
  attr :schema, :map, required: true
  attr :myself, :any, required: true

  defp prop_field(%{schema: %{"type" => "string"}} = assigns) do
    ~H"""
    <input
      type="text"
      class="ash-cms-prop-input"
      value={@value || ""}
      placeholder={@schema["placeholder"] || ""}
      phx-blur="update_prop"
      phx-value-block_id={@block_id}
      phx-value-key={@field_key}
      phx-value-value={@value || ""}
      phx-debounce="300"
      phx-target={@myself}
    />
    """
  end

  defp prop_field(%{schema: %{"type" => "richtext"}} = assigns) do
    ~H"""
    <div
      class="ash-cms-prop-richtext"
      contenteditable="true"
      phx-hook="AshCMSRichText"
      id={"richtext-#{@block_id}-#{@field_key}"}
      data-block-id={@block_id}
      data-key={@field_key}
      phx-update="ignore"
    ><%= raw(@value || "") %></div>
    """
  end

  defp prop_field(%{schema: %{"type" => "color"}} = assigns) do
    ~H"""
    <div class="ash-cms-prop-color-wrapper">
      <input
        type="color"
        class="ash-cms-prop-color"
        value={@value || "#000000"}
        phx-change="update_prop"
        phx-value-block_id={@block_id}
        phx-value-key={@field_key}
        phx-target={@myself}
      />
      <input
        type="text"
        class="ash-cms-prop-color-text"
        value={@value || "#000000"}
        phx-blur="update_prop"
        phx-value-block_id={@block_id}
        phx-value-key={@field_key}
        phx-value-value={@value || "#000000"}
        phx-debounce="300"
        phx-target={@myself}
      />
    </div>
    """
  end

  defp prop_field(%{schema: %{"type" => "boolean"}} = assigns) do
    ~H"""
    <label class="ash-cms-prop-toggle">
      <input
        type="checkbox"
        class="ash-cms-toggle-input"
        checked={@value == true}
        phx-change="update_prop"
        phx-value-block_id={@block_id}
        phx-value-key={@field_key}
        phx-value-value={if @value == true, do: "false", else: "true"}
        phx-target={@myself}
      />
      <span class="ash-cms-toggle-track"></span>
    </label>
    """
  end

  defp prop_field(%{schema: %{"type" => "select", "options" => options}} = assigns) do
    assigns = assign(assigns, :options, options)

    ~H"""
    <select
      class="ash-cms-prop-select"
      phx-change="update_prop"
      phx-value-block_id={@block_id}
      phx-value-key={@field_key}
      phx-target={@myself}
    >
      <%= for opt <- @options do %>
        <option value={"#{opt}"} selected={to_string(@value) == to_string(opt)}>
          <%= opt %>
        </option>
      <% end %>
    </select>
    """
  end

  defp prop_field(%{schema: %{"type" => "media"}} = assigns) do
    ~H"""
    <div class="ash-cms-prop-media">
      <%= if @value && @value != "" do %>
        <img src={@value} class="ash-cms-prop-media-preview" />
        <button
          class="ash-cms-btn-xs"
          phx-click="open_media_picker"
          phx-value-target={"#{@block_id}:#{@field_key}"}
          phx-target={@myself}
        >Change</button>
        <button
          class="ash-cms-btn-xs ash-cms-btn-ghost"
          phx-click="update_prop"
          phx-value-block_id={@block_id}
          phx-value-key={@field_key}
          phx-value-value=""
          phx-target={@myself}
        >Remove</button>
      <% else %>
        <button
          class="ash-cms-prop-media-btn"
          phx-click="open_media_picker"
          phx-value-target={"#{@block_id}:#{@field_key}"}
          phx-target={@myself}
        >
          + Choose Media
        </button>
      <% end %>
    </div>
    """
  end

  defp prop_field(%{schema: %{"type" => "code"}} = assigns) do
    ~H"""
    <div
      id={"code-#{@block_id}-#{@field_key}"}
      class="ash-cms-prop-code-editor"
      phx-hook="AshCMSInlineMonaco"
      data-block-id={@block_id}
      data-key={@field_key}
      data-language={@schema["language"] || "html"}
      data-content={@value || ""}
      phx-update="ignore"
    ></div>
    """
  end

  # Fallback — render as a string input
  defp prop_field(assigns) do
    ~H"""
    <input
      type="text"
      class="ash-cms-prop-input"
      value={@value || ""}
      phx-blur="update_prop"
      phx-value-block_id={@block_id}
      phx-value-key={@field_key}
      phx-value-value={@value || ""}
      phx-debounce="300"
      phx-target={@myself}
    />
    """
  end

  # ── Events ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("update_prop", %{"block_id" => block_id, "key" => key} = params, socket) do
    value = params["value"] || ""
    send(self(), {:update_block_prop, block_id, key, value})
    {:noreply, socket}
  end

  def handle_event("open_media_picker", %{"target" => target}, socket) do
    send(self(), {:open_media_picker, target})
    {:noreply, socket}
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp get_props_schema(block, components) do
    type = block["type"]

    case AshCms.Blocks.find(type) do
      nil ->
        case Enum.find(components, &(&1.slug == type)) do
          nil -> %{}
          comp -> comp.props_schema || %{}
        end

      block_def ->
        block_def.props_schema
    end
  end

  defp block_type_name(block) do
    case AshCms.Blocks.find(block["type"]) do
      nil -> block["type"] |> String.split("_") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
      def -> def.name
    end
  end
end
