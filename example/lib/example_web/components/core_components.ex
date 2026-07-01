defmodule ExampleWeb.CoreComponents do
  @moduledoc """
  Core UI components for the Example application.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :flash, :map, required: true
  attr :kind, :atom, values: [:info, :error]
  attr :rest, :global

  def flash(assigns) do
    assigns = assign_new(assigns, :kind, fn -> :info end)

    ~H"""
    <div
      :if={msg = @flash[@kind]}
      id={@id}
      role="alert"
      class={[
        "flash",
        @kind == :info && "flash-info",
        @kind == :error && "flash-error"
      ]}
      {@rest}
    >
      <p><%= msg %></p>
      <button type="button" phx-click={JS.hide(to: "##{@id}")}>✕</button>
    </div>
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} style="position: fixed; top: 16px; right: 16px; z-index: 9999; display: flex; flex-direction: column; gap: 8px;">
      <.flash id="client-error" kind={:error} flash={@flash} />
      <.flash id="server-error" kind={:error} flash={@flash} />
      <.flash id="info" kind={:info} flash={@flash} />
    </div>
    """
  end
end
