# Building a Course Site with Astro Starlight

This guide documents how the Linux Mastery course site was built, so you can replicate the pattern for other courses.

## Overview

The system takes raw markdown course content (organized as `week-NN/README.md` + `week-NN/labs/`) and transforms it into a polished documentation site with:

- Searchable, navigable lesson and lab pages
- Interactive checklists with localStorage persistence
- Per-week progress badges in the sidebar
- Downloadable scaffold files (scripts, Dockerfiles, configs)
- Auto-deploy to GitHub Pages on push

## Architecture

```
your-course/
├── _original/                    # Raw source content (pre-migration)
│   └── week-NN/
│       ├── README.md             # Week lesson
│       └── labs/
│           ├── lab_01_*.md       # Lab instructions
│           └── *.sh, *.py, ...   # Scaffold/starter files
├── src/
│   ├── content.config.ts         # Astro content collection config
│   ├── content/docs/             # Generated: migrated content
│   │   ├── index.mdx             # Homepage (splash page)
│   │   └── week-NN/
│   │       ├── index.md          # Lesson (from README.md)
│   │       └── lab-NN-*.md       # Labs (hyphenated filenames)
│   ├── styles/custom.css         # Course styling + checkbox CSS
│   └── components/Head.astro     # Checkbox persistence + progress JS
├── public/scaffolds/             # Generated: downloadable non-md files
│   └── week-NN/
│       └── *.sh, *.py, ...
├── scripts/migrate.sh            # Transforms _original/ → src/ + public/
├── astro.config.mjs              # Starlight config + sidebar
├── package.json
├── tsconfig.json
└── .github/workflows/deploy.yml  # GitHub Pages deploy
```

## Step 1: Initialize the Project

```bash
mkdir my-course && cd my-course
npm create astro@latest -- --template starlight
```

### package.json

```json
{
  "name": "my-course",
  "type": "module",
  "version": "0.0.1",
  "scripts": {
    "dev": "astro dev",
    "start": "astro dev",
    "build": "astro build",
    "preview": "astro preview",
    "astro": "astro"
  },
  "dependencies": {
    "@astrojs/starlight": "^0.34.0",
    "astro": "^5.7.0",
    "astro-rehype-relative-markdown-links": "^0.18.0",
    "sharp": "^0.33.0"
  }
}
```

### tsconfig.json

```json
{
  "extends": "astro/tsconfigs/strict"
}
```

### src/content.config.ts

**Important:** You must use `docsLoader()` — without it, `.mdx` files won't process component imports and the content layer won't resolve slugs correctly in CI.

```typescript
import { defineCollection } from 'astro:content';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';

export const collections = {
  docs: defineCollection({ loader: docsLoader(), schema: docsSchema() }),
};
```

## Step 2: Configure Astro + Starlight

### astro.config.mjs

Key things to customize per course:

- `site` and `base` — your GitHub Pages URL
- `starlight.title` and `description`
- `sidebar` — one group per week with lesson + lab slugs

```javascript
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import rehypeRelativeMarkdownLinks from 'astro-rehype-relative-markdown-links';

export default defineConfig({
  site: 'https://YOUR_ORG.github.io',
  base: '/my-course',
  markdown: {
    rehypePlugins: [rehypeRelativeMarkdownLinks],
  },
  integrations: [
    starlight({
      title: 'My Course',
      description: 'Course description here.',
      customCss: ['./src/styles/custom.css'],
      components: {
        Head: './src/components/Head.astro',
      },
      sidebar: [
        { label: 'Home', slug: 'index' },
        {
          label: 'Week 01 — Topic Name',
          items: [
            { slug: 'week-01', label: 'Lesson' },
            { slug: 'week-01/lab-01-slug-name' },
            { slug: 'week-01/lab-02-slug-name' },
          ],
        },
        // ... more weeks
      ],
    }),
  ],
});
```

**Sidebar slug rules:**
- `week-NN/index.md` has slug `week-NN`
- `week-NN/lab-01-foo-bar.md` has slug `week-NN/lab-01-foo-bar`
- Slugs must NOT start or end with `/`

## Step 3: Content File Patterns

### Homepage — `src/content/docs/index.mdx`

Must be `.mdx` (not `.md`) if you use component imports like `Card`/`CardGrid`.

```mdx
---
title: My Course
description: Course description.
template: splash
hero:
  title: My Course
  tagline: Course tagline here.
  actions:
    - text: Start Week 1
      link: /my-course/week-01/
      icon: right-arrow
      variant: primary
    - text: View on GitHub
      link: https://github.com/ORG/REPO
      icon: external
      variant: minimal
---

import { Card, CardGrid } from '@astrojs/starlight/components';

<CardGrid>
  <Card title="Topic" icon="terminal">
    Description.
  </Card>
</CardGrid>
```

### Week lesson — `src/content/docs/week-NN/index.md`

```yaml
---
title: "Week 1: Topic Title"
sidebar:
  order: 0
---
```

`order: 0` makes it appear first in the sidebar group.

### Lab page — `src/content/docs/week-NN/lab-01-slug-name.md`

```yaml
---
title: "Lab 1.1: Lab Title"
sidebar:
  order: 1
---
```

Incrementing `order` values (1, 2, 3...) control lab ordering within the week.

### Checklists in content

Standard markdown checkboxes become interactive (persistent via localStorage):

```markdown
## Checklist

- [ ] First item to complete
- [ ] Second item to complete
- [ ] Third item to complete
```

The `Head.astro` component enables them, and `custom.css` styles them.

## Step 4: Custom Styling

### src/styles/custom.css

```css
/* ── Wider content area for tables and code ────────────────────────────── */
:root {
  --sl-content-width: 55rem;
}

/* ── Accent colors (customize per course) ──────────────────────────────── */
:root {
  --sl-color-accent-low: #1a2332;
  --sl-color-accent: #4ec9b0;
  --sl-color-accent-high: #b8e6d8;
}
:root[data-theme='light'] {
  --sl-color-accent-low: #d4f0e8;
  --sl-color-accent: #0d7a5f;
  --sl-color-accent-high: #0a4a3a;
}

/* ── Monospace font ────────────────────────────────────────────────────── */
:root {
  --sl-font-mono: 'JetBrains Mono', 'Fira Code', 'Cascadia Code', ui-monospace,
    'SFMono-Regular', 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace;
}

/* ── Interactive checklists ────────────────────────────────────────────── */
.sl-markdown-content li:has(> input[type='checkbox']) {
  list-style: none;
  margin-left: -1.25em;
}

.sl-markdown-content input[type='checkbox'] {
  cursor: pointer;
  width: 1.1em;
  height: 1.1em;
  margin-right: 0.5em;
  accent-color: var(--sl-color-accent);
  vertical-align: middle;
}

.sl-markdown-content input[type='checkbox']:hover {
  transform: scale(1.15);
}

.sl-markdown-content li:has(> input[type='checkbox']:checked) {
  opacity: 0.7;
  text-decoration: line-through;
  text-decoration-color: var(--sl-color-gray-4);
}

/* ── Progress indicator ────────────────────────────────────────────────── */
#progress-indicator {
  background: var(--sl-color-gray-6);
  border: 1px solid var(--sl-color-gray-5);
  border-radius: 0.5rem;
  padding: 0.75rem 1rem;
  margin-bottom: 1.5rem;
}

.progress-text {
  font-size: 0.875rem;
  color: var(--sl-color-gray-2);
  margin-bottom: 0.375rem;
}

.progress-bar-track {
  height: 0.5rem;
  background: var(--sl-color-gray-5);
  border-radius: 0.25rem;
  overflow: hidden;
}

.progress-bar-fill {
  height: 100%;
  background: var(--sl-color-accent);
  border-radius: 0.25rem;
  transition: width 0.3s ease;
}

/* ── Sidebar week badges ───────────────────────────────────────────────── */
.week-badge {
  font-size: 0.7rem;
  padding: 0.1em 0.4em;
  border-radius: 0.25rem;
  background: var(--sl-color-gray-5);
  color: var(--sl-color-gray-2);
  margin-left: auto;
  font-variant-numeric: tabular-nums;
}

.week-badge.complete {
  background: var(--sl-color-accent);
  color: var(--sl-color-accent-low);
}

nav.sidebar details summary {
  display: flex;
  align-items: center;
  gap: 0.5em;
}

/* ── Tables: horizontal scroll ─────────────────────────────────────────── */
.sl-markdown-content table {
  display: block;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  max-width: 100%;
}

/* ── Code blocks: preserve ASCII art spacing ───────────────────────────── */
.sl-markdown-content pre code {
  font-family: var(--sl-font-mono);
  tab-size: 4;
}
```

## Step 5: Interactive Checkbox + Progress System

### src/components/Head.astro

This component overrides Starlight's default `<Head>` to inject client-side JavaScript that:

1. Makes markdown checkboxes interactive (Starlight renders them disabled by default)
2. Persists checkbox state to `localStorage`
3. Shows a progress bar on pages with checklists
4. Adds completion badges (e.g. "7/11") to sidebar week groups

```astro
---
import type { Props } from '@astrojs/starlight/props';
import Default from '@astrojs/starlight/components/Head.astro';
---

<Default {...Astro.props}><slot /></Default>

<script is:inline>
(function () {
  function hashText(text) {
    var h = 5381;
    for (var i = 0; i < text.length; i++) {
      h = ((h << 5) + h + text.charCodeAt(i)) >>> 0;
    }
    return h.toString(36);
  }

  function getPageKey() {
    return location.pathname.replace(/\/$/, '') || '/';
  }

  function storageKey(checkboxHash) {
    return 'progress:' + getPageKey() + ':' + checkboxHash;
  }

  function initCheckboxes() {
    var checkboxes = document.querySelectorAll(
      '.sl-markdown-content input[type="checkbox"]'
    );
    if (!checkboxes.length) return;

    checkboxes.forEach(function (cb) {
      cb.removeAttribute('disabled');
      cb.style.cursor = 'pointer';

      var label = cb.parentElement ? cb.parentElement.textContent.trim() : '';
      var key = storageKey(hashText(label));

      var saved = localStorage.getItem(key);
      if (saved === 'true') cb.checked = true;
      else if (saved === 'false') cb.checked = false;

      cb.addEventListener('change', function () {
        localStorage.setItem(key, cb.checked ? 'true' : 'false');
        updateProgress();
      });
    });

    updateProgress();
  }

  function updateProgress() {
    var checkboxes = document.querySelectorAll(
      '.sl-markdown-content input[type="checkbox"]'
    );
    if (!checkboxes.length) return;

    var total = checkboxes.length;
    var checked = 0;
    checkboxes.forEach(function (cb) { if (cb.checked) checked++; });

    var bar = document.getElementById('progress-indicator');
    if (!bar) {
      bar = document.createElement('div');
      bar.id = 'progress-indicator';
      bar.setAttribute('role', 'status');
      bar.setAttribute('aria-live', 'polite');
      var content = document.querySelector('.sl-markdown-content');
      if (content) content.insertBefore(bar, content.firstChild);
    }

    var pct = total > 0 ? Math.round((checked / total) * 100) : 0;
    bar.innerHTML =
      '<div class="progress-text">' + checked + ' of ' + total + ' items completed</div>' +
      '<div class="progress-bar-track">' +
      '<div class="progress-bar-fill" style="width:' + pct + '%"></div>' +
      '</div>';
  }

  function updateSidebarBadges() {
    var weekGroups = document.querySelectorAll('nav.sidebar details');
    weekGroups.forEach(function (group) {
      var links = group.querySelectorAll('a[href]');
      var totalItems = 0;
      var checkedItems = 0;

      links.forEach(function (link) {
        var pagePath = new URL(link.href, location.origin).pathname.replace(/\/$/, '') || '/';
        for (var i = 0; i < localStorage.length; i++) {
          var key = localStorage.key(i);
          if (key && key.startsWith('progress:' + pagePath + ':')) {
            totalItems++;
            if (localStorage.getItem(key) === 'true') checkedItems++;
          }
        }
      });

      if (totalItems > 0) {
        var summary = group.querySelector('summary');
        if (summary) {
          var badge = summary.querySelector('.week-badge');
          if (!badge) {
            badge = document.createElement('span');
            badge.className = 'week-badge';
            summary.appendChild(badge);
          }
          badge.textContent = checkedItems + '/' + totalItems;
          if (checkedItems === totalItems) badge.classList.add('complete');
          else badge.classList.remove('complete');
        }
      }
    });
  }

  function init() {
    initCheckboxes();
    updateSidebarBadges();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  document.addEventListener('astro:after-swap', init);
})();
</script>
```

## Step 6: Migration Script

If you have raw content in `_original/` (or a similar directory), adapt `scripts/migrate.sh` to transform it. The key transformations are:

1. **README.md** → `week-NN/index.md` with frontmatter extracted from the `# Heading`
2. **lab_01_name.md** → `lab-01-name.md` (underscores to hyphens)
3. **Non-markdown files** (`.sh`, `.py`, `Dockerfile`, etc.) → `public/scaffolds/week-NN/`
4. **Internal links** rewritten: `labs/lab_01_foo.md` → `./lab-01-foo`
5. **Navigation lines** stripped (prev/next week links)

See `scripts/migrate.sh` in this repo for the full implementation.

## Step 7: GitHub Pages Deployment

### .github/workflows/deploy.yml

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: withastro/action@v5

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

**Important:** Use `withastro/action@v5` (not v3). The v3 action defaults to Node 20, which has content layer issues with Astro 5's slug resolution for `index.md` files.

### GitHub repo settings

Enable GitHub Pages with **Source: GitHub Actions** (not "Deploy from branch") in Settings > Pages.

## Step 8: .gitignore

```
*.swp
*.swo
*~
.DS_Store
.vagrant/
*.log
*.tmp
.env
node_modules/
__pycache__/
*.pyc
.venv/
dist/
.astro/
```

## Gotchas

| Issue | Fix |
|-------|-----|
| `import` line renders as text on homepage | Homepage must be `.mdx`, not `.md` |
| Sidebar slug "week-NN" not found in CI | Use `docsLoader()` in `content.config.ts` and `withastro/action@v5` |
| Checkboxes are disabled/non-interactive | The `Head.astro` component removes the `disabled` attribute at runtime |
| Links between pages broken | Install `astro-rehype-relative-markdown-links` and use relative paths like `./lab-01-foo` |
| Scaffold files not accessible | Put them in `public/scaffolds/` — Astro serves `public/` as static assets |

## Adapting for a New Course

1. Copy the project skeleton (all config files, `src/styles/`, `src/components/`)
2. Update `astro.config.mjs`: change `site`, `base`, `title`, `description`, and `sidebar`
3. Update `src/content/docs/index.mdx`: change hero content and card grid
4. Place your content in `src/content/docs/` following the frontmatter patterns above
5. Put any downloadable files in `public/scaffolds/`
6. Update `.github/workflows/deploy.yml` if needed
7. Push to GitHub — the site deploys automatically
