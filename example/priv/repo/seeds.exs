#!/usr/bin/env elixir
# AshCms Example — Seed data
#
# Run with: mix run priv/repo/seeds.exs
# Or reset and reseed: mix ash.reset

alias Example.CMS
alias Example.CMS.{Site, Page, Component, Layout}

IO.puts("🌱 Seeding AshCms demo data...")

# ── Create the demo site ──────────────────────────────────────────────────────

{:ok, site} =
  Ash.create(Site, %{
    name: "Demo Site",
    slug: "demo",
    domain: "localhost",
    description: "A demo CMS site built with AshCms",
    css_url: "/assets/app.css",
    custom_css: """
    :root {
      --brand: #6366f1;
      --brand-hover: #4f46e5;
    }
    .demo-highlight { color: var(--brand); }
    """
  }, domain: CMS)

IO.puts("✓ Created site: #{site.name} (#{site.slug})")

# ── Create a default layout ───────────────────────────────────────────────────

{:ok, layout} =
  Ash.create(Layout, %{
    name: "Default Layout",
    slug: "default",
    description: "Main layout with header and footer",
    is_default: true,
    site_id: site.id,
    template: """
    <header style="background: #1a1a2e; color: white; padding: 16px 32px; display: flex; justify-content: space-between; align-items: center;">
      <a href="/" style="color: white; font-weight: 700; font-size: 1.25rem; text-decoration: none;">
        <%= @site.name %>
      </a>
      <nav style="display: flex; gap: 24px;">
        <a href="/" style="color: rgba(255,255,255,0.8); text-decoration: none;">Home</a>
        <a href="/about" style="color: rgba(255,255,255,0.8); text-decoration: none;">About</a>
        <a href="/blog" style="color: rgba(255,255,255,0.8); text-decoration: none;">Blog</a>
      </nav>
    </header>

    <main>
      <%= @inner_content %>
    </main>

    <footer style="background: #0f0f1a; color: rgba(255,255,255,0.6); padding: 40px 32px; text-align: center; margin-top: 64px;">
      <p>© 2025 <%= @site.name %>. Built with <a href="https://ash-hq.org" style="color: #6366f1;">AshCms</a>.</p>
    </footer>
    """
  }, domain: CMS)

IO.puts("✓ Created layout: #{layout.name}")

# ── Create a custom "Feature Card" component ──────────────────────────────────

{:ok, feature_card} =
  Ash.create(Component, %{
    name: "Feature Card",
    slug: "feature_card",
    description: "A card highlighting a feature with icon, title, and description",
    icon: "star",
    category: "content",
    site_id: site.id,
    props_schema: %{
      "icon" => %{"type" => "string", "label" => "Icon (emoji or text)"},
      "title" => %{"type" => "string", "label" => "Title"},
      "description" => %{"type" => "string", "label" => "Description"},
      "link" => %{"type" => "string", "label" => "Link URL"},
      "link_text" => %{"type" => "string", "label" => "Link Text"}
    },
    default_props: %{
      "icon" => "⚡",
      "title" => "Feature Title",
      "description" => "A short description of this amazing feature.",
      "link" => "#",
      "link_text" => "Learn more"
    },
    template: """
    <div style="background: white; border: 1px solid #e2e8f0; border-radius: 12px; padding: 28px; box-shadow: 0 1px 3px rgba(0,0,0,.08);">
      <div style="font-size: 2.5rem; margin-bottom: 16px;"><%= @props["icon"] %></div>
      <h3 style="font-size: 1.125rem; font-weight: 700; margin-bottom: 8px; color: #0f172a;"><%= @props["title"] %></h3>
      <p style="color: #64748b; font-size: 0.9375rem; line-height: 1.6; margin-bottom: 16px;"><%= @props["description"] %></p>
      <%= if @props["link"] && @props["link"] != "" do %>
        <a href="<%= @props["link"] %>" style="color: #6366f1; font-weight: 600; font-size: 0.875rem; text-decoration: none;">
          <%= @props["link_text"] || "Learn more" %> →
        </a>
      <% end %>
    </div>
    """
  }, domain: CMS)

IO.puts("✓ Created component: #{feature_card.name}")

# ── Create a "Testimonial" component ─────────────────────────────────────────

{:ok, _testimonial} =
  Ash.create(Component, %{
    name: "Testimonial",
    slug: "testimonial",
    description: "A customer testimonial quote card",
    icon: "chat-bubble-left",
    category: "content",
    site_id: site.id,
    props_schema: %{
      "quote" => %{"type" => "string", "label" => "Quote"},
      "author" => %{"type" => "string", "label" => "Author Name"},
      "role" => %{"type" => "string", "label" => "Author Role/Company"},
      "avatar_url" => %{"type" => "media", "label" => "Author Photo"}
    },
    default_props: %{
      "quote" => "This product changed everything for us. Truly remarkable.",
      "author" => "Jane Smith",
      "role" => "CEO, Acme Corp",
      "avatar_url" => ""
    },
    template: """
    <div style="background: #f8fafc; border-left: 4px solid #6366f1; border-radius: 8px; padding: 24px 28px; margin: 16px 0;">
      <p style="font-size: 1.0625rem; color: #334155; font-style: italic; line-height: 1.7; margin-bottom: 16px;">
        "<%= @props["quote"] %>"
      </p>
      <div style="display: flex; align-items: center; gap: 12px;">
        <%= if @props["avatar_url"] && @props["avatar_url"] != "" do %>
          <img src="<%= @props["avatar_url"] %>" style="width: 40px; height: 40px; border-radius: 50%; object-fit: cover;" />
        <% end %>
        <div>
          <div style="font-weight: 600; color: #0f172a; font-size: 0.9375rem;"><%= @props["author"] %></div>
          <div style="color: #64748b; font-size: 0.8125rem;"><%= @props["role"] %></div>
        </div>
      </div>
    </div>
    """
  }, domain: CMS)

IO.puts("✓ Created component: Testimonial")

# ── Create the Home page ──────────────────────────────────────────────────────

home_content = %{
  "version" => "1",
  "blocks" => [
    %{
      "id" => "b1",
      "type" => "hero",
      "order" => 0,
      "props" => %{
        "title" => "Welcome to AshCms Demo",
        "subtitle" => "A full-featured CMS built on Ash Framework with drag & drop editing",
        "button_text" => "Explore the Editor",
        "button_url" => "/cms",
        "background_color" => "#1a1a2e",
        "text_color" => "#ffffff",
        "height" => "large",
        "align" => "center"
      },
      "children" => []
    },
    %{
      "id" => "b2",
      "type" => "text",
      "order" => 1,
      "props" => %{
        "content" => """
        <h2 style="text-align: center; font-size: 2rem; font-weight: 700; margin-bottom: 16px;">
          Build beautiful pages without code
        </h2>
        <p style="text-align: center; color: #64748b; max-width: 600px; margin: 0 auto;">
          AshCms gives you a powerful drag-and-drop editor alongside a professional
          code editor — so designers and developers can both work the way they prefer.
        </p>
        """,
        "css_class" => "py-16 px-4"
      },
      "children" => []
    },
    %{
      "id" => "b3",
      "type" => "columns",
      "order" => 2,
      "props" => %{"count" => 3, "gap" => "medium", "css_class" => "max-w-5xl mx-auto px-4 pb-16"},
      "children" => [
        %{
          "id" => "b3-1",
          "type" => "feature_card",
          "order" => 0,
          "props" => %{
            "icon" => "🎨",
            "title" => "Drag & Drop Editor",
            "description" => "Visual block editor with live preview. Add, remove, and reorder content blocks instantly.",
            "link" => "/cms",
            "link_text" => "Open editor"
          },
          "children" => []
        },
        %{
          "id" => "b3-2",
          "type" => "feature_card",
          "order" => 1,
          "props" => %{
            "icon" => "💻",
            "title" => "Code Editor Mode",
            "description" => "Write HEEx templates directly in Monaco (VS Code engine) with live preview.",
            "link" => "/cms",
            "link_text" => "Try it"
          },
          "children" => []
        },
        %{
          "id" => "b3-3",
          "type" => "feature_card",
          "order" => 2,
          "props" => %{
            "icon" => "⚡",
            "title" => "Real-time Updates",
            "description" => "Full Phoenix LiveView integration. Publish a change — all visitors see it instantly via PubSub.",
            "link" => "#",
            "link_text" => "Learn more"
          },
          "children" => []
        }
      ]
    },
    %{
      "id" => "b4",
      "type" => "testimonial",
      "order" => 3,
      "props" => %{
        "quote" => "AshCms made it trivial to add a fully-featured CMS to our Ash application. The drag-and-drop editor is a joy to use.",
        "author" => "Alex Chen",
        "role" => "Full-stack Developer",
        "avatar_url" => ""
      },
      "children" => []
    },
    %{
      "id" => "b5",
      "type" => "button",
      "order" => 4,
      "props" => %{
        "text" => "Start Building →",
        "url" => "/cms",
        "variant" => "primary",
        "size" => "large",
        "align" => "center",
        "open_in_new_tab" => false
      },
      "children" => []
    },
    %{
      "id" => "b6",
      "type" => "spacer",
      "order" => 5,
      "props" => %{"height" => "64", "responsive_hidden" => false},
      "children" => []
    }
  ]
}

{:ok, home_page} =
  Ash.create(Page, %{
    title: "Home",
    slug: "home",
    description: "Welcome to AshCms Demo — A full-featured CMS built on Ash Framework",
    content: home_content,
    editor_mode: :visual,
    site_id: site.id,
    layout_id: layout.id,
    sort_order: 0
  }, domain: CMS)

{:ok, home_page} = Ash.update(home_page, %{}, action: :publish, domain: CMS)
IO.puts("✓ Created & published page: #{home_page.title} (/#{home_page.slug})")

# ── Create the About page ─────────────────────────────────────────────────────

about_content = %{
  "version" => "1",
  "blocks" => [
    %{
      "id" => "a1",
      "type" => "hero",
      "order" => 0,
      "props" => %{
        "title" => "About AshCms",
        "subtitle" => "Open-source CMS extension for the Ash Framework",
        "button_text" => "",
        "background_color" => "#0f172a",
        "text_color" => "#e2e8f0",
        "height" => "medium",
        "align" => "center"
      },
      "children" => []
    },
    %{
      "id" => "a2",
      "type" => "text",
      "order" => 1,
      "props" => %{
        "content" => """
        <div style="max-width: 720px; margin: 0 auto;">
          <h2>What is AshCms?</h2>
          <p>
            AshCms is a full-featured Content Management System extension for the
            <a href="https://ash-hq.org">Ash Framework</a>. It gives Elixir developers
            a production-ready CMS that integrates seamlessly with their existing Ash domains.
          </p>

          <h3>Key Features</h3>
          <ul>
            <li><strong>Visual editor</strong> — drag-and-drop block-based page editing</li>
            <li><strong>Code editor</strong> — Monaco-powered HEEx template editing</li>
            <li><strong>Custom components</strong> — define reusable blocks in HEEx</li>
            <li><strong>Distributed routing</strong> — <code>Group</code> library for cluster-wide page registry</li>
            <li><strong>Real-time</strong> — LiveView + PubSub for instant page updates</li>
            <li><strong>Media library</strong> — local or S3 storage</li>
            <li><strong>Any data layer</strong> — SQLite, Postgres, or any Ash data layer</li>
            <li><strong>Igniter installer</strong> — one-command setup</li>
          </ul>

          <h3>How it works</h3>
          <p>
            Each published page is managed by a <code>PageServer</code> GenServer registered in
            the <code>Group</code> distributed process registry. The router's catch-all route
            looks up the current URL in this registry to find the correct page server, then
            renders the page content using LiveView — with full PubSub support for live updates.
          </p>
        </div>
        """,
        "css_class" => "py-12 px-6"
      },
      "children" => []
    }
  ]
}

{:ok, about_page} =
  Ash.create(Page, %{
    title: "About",
    slug: "about",
    description: "About AshCms — the open-source CMS extension for Ash Framework",
    content: about_content,
    editor_mode: :visual,
    site_id: site.id,
    layout_id: layout.id,
    sort_order: 1
  }, domain: CMS)

{:ok, about_page} = Ash.update(about_page, %{}, action: :publish, domain: CMS)
IO.puts("✓ Created & published page: #{about_page.title} (/#{about_page.slug})")

# ── Create a Blog landing page (code mode demo) ───────────────────────────────

blog_template = """
<section style="max-width: 900px; margin: 0 auto; padding: 48px 24px;">
  <h1 style="font-size: 2.5rem; font-weight: 800; margin-bottom: 8px;">Blog</h1>
  <p style="color: #64748b; margin-bottom: 40px;">
    Thoughts on Elixir, Ash Framework, and building great software.
  </p>

  <div style="display: grid; gap: 24px;">
    <article style="border: 1px solid #e2e8f0; border-radius: 12px; padding: 24px; background: white;">
      <div style="font-size: 0.8125rem; color: #64748b; margin-bottom: 8px;">June 28, 2025</div>
      <h2 style="font-size: 1.375rem; font-weight: 700; margin-bottom: 8px;">
        <a href="#" style="color: #0f172a; text-decoration: none;">
          Building a CMS with Ash Framework
        </a>
      </h2>
      <p style="color: #475569; line-height: 1.6;">
        How we built AshCms — a full-featured content management system
        using Ash, Phoenix LiveView, and the Group distributed registry.
      </p>
      <a href="#" style="color: #6366f1; font-weight: 600; font-size: 0.875rem; text-decoration: none; margin-top: 12px; display: inline-block;">
        Read more →
      </a>
    </article>

    <article style="border: 1px solid #e2e8f0; border-radius: 12px; padding: 24px; background: white;">
      <div style="font-size: 0.8125rem; color: #64748b; margin-bottom: 8px;">June 20, 2025</div>
      <h2 style="font-size: 1.375rem; font-weight: 700; margin-bottom: 8px;">
        <a href="#" style="color: #0f172a; text-decoration: none;">
          Real-time Pages with Phoenix PubSub
        </a>
      </h2>
      <p style="color: #475569; line-height: 1.6;">
        Using Phoenix PubSub and LiveView to broadcast page updates to all
        connected visitors instantly — no page reload required.
      </p>
      <a href="#" style="color: #6366f1; font-weight: 600; font-size: 0.875rem; text-decoration: none; margin-top: 12px; display: inline-block;">
        Read more →
      </a>
    </article>
  </div>
</section>
"""

{:ok, blog_page} =
  Ash.create(Page, %{
    title: "Blog",
    slug: "blog",
    description: "The AshCms blog — Elixir, Ash Framework, and web development",
    template: blog_template,
    editor_mode: :code,
    site_id: site.id,
    layout_id: layout.id,
    sort_order: 2
  }, domain: CMS)

{:ok, blog_page} = Ash.update(blog_page, %{}, action: :publish, domain: CMS)
IO.puts("✓ Created & published page: #{blog_page.title} (/#{blog_page.slug}) [code mode]")

IO.puts("""

🎉 Demo data seeded successfully!

Visit the demo:
  → Home page:  http://localhost:4000/demo/home
  → About page: http://localhost:4000/demo/about
  → Blog page:  http://localhost:4000/demo/blog
  → CMS Admin:  http://localhost:4000/cms
""")
