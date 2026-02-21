#!/bin/bash
# =============================================================================
# Migration script: converts raw markdown course into Astro Starlight docs
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/src/content/docs"
SCAFFOLDS_DIR="$REPO_ROOT/public/scaffolds"

echo "=== Linux Mastery Course → Starlight Migration ==="
echo "Repo root: $REPO_ROOT"

# Clean previous migration
rm -rf "$DOCS_DIR" "$SCAFFOLDS_DIR"
mkdir -p "$DOCS_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Helper: convert underscore-separated lab filename to hyphenated slug
#   lab_01_ubuntu_vm_setup.md → lab-01-ubuntu-vm-setup.md
# ─────────────────────────────────────────────────────────────────────────────
slugify_lab() {
  echo "$1" | sed 's/_/-/g'
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper: strip navigation lines from content
#   Removes lines matching prev/next patterns at top (line ~5) and bottom
# ─────────────────────────────────────────────────────────────────────────────
strip_nav() {
  sed -E \
    -e '/^\[← Previous Week\]/d' \
    -e '/^\[Next Week →\]/d' \
    -e '/^\[← Previous Week\].*\[Next Week →\]/d' \
    -e '/^\[← Back to Week [0-9]+ README\]/d' \
    -e '/^\[Back to Week [0-9]+ README\]/d'
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper: rewrite internal links in README (now index.md)
#   labs/lab_01_foo.md  → ./lab-01-foo
#   labs/lab_01_foo.sh  → /linux-mastery-course/scaffolds/week-NN/lab_01_foo.sh
#   [labs/](labs/)      → (remove or leave as-is — we'll adjust the text)
# ─────────────────────────────────────────────────────────────────────────────
rewrite_readme_links() {
  local week_num="$1"
  sed -E \
    -e "s|\(labs/(lab_[0-9]+_[^)]+)\.md\)|(\./$(echo '\1' | sed 's/_/-/g'))|g" \
    -e "s|\(labs/(lab_[0-9]+_[^)]+\.sh)\)|(/linux-mastery-course/scaffolds/week-${week_num}/\1)|g" \
    -e 's|\[labs/\]\(labs/\)|the labs on this page|g'
}

# Actually, the sed backreference approach for slugifying inside sed is tricky.
# Let's use a perl one-liner instead for the .md link rewriting.
rewrite_readme_links_perl() {
  local week_num="$1"
  perl -pe '
    # Rewrite labs/lab_NN_name.md → ./lab-NN-name (slug, no extension)
    s{\(labs/(lab_\d+_[^)]+)\.md\)}{
      my $slug = $1;
      $slug =~ s/_/-/g;
      "(./". $slug .")";
    }ge;
    # Rewrite labs/lab_NN_name.sh → scaffold download link
    s{\(labs/(lab_\d+_[^)]+\.sh)\)}{(/linux-mastery-course/scaffolds/week-'"$week_num"'/$1)}g;
    # Rewrite bare "labs/" directory link
    s{\[labs/\]\(labs/\)}{the labs on this page}g;
  '
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper: rewrite links in lab files
#   ../README.md → ./
# ─────────────────────────────────────────────────────────────────────────────
rewrite_lab_links() {
  sed -E 's|\(\.\.\/README\.md\)|(./)|g'
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Create homepage
# ─────────────────────────────────────────────────────────────────────────────
echo "Creating homepage..."
cat > "$DOCS_DIR/index.md" << 'HOMEPAGE'
---
title: Linux Mastery
description: A 17-week hands-on course from zero to production Linux.
template: splash
hero:
  title: Linux Mastery
  tagline: From zero to production — a 17-week hands-on course covering the shell, scripting, networking, services, databases, and containers.
  actions:
    - text: Start Week 1
      link: /linux-mastery-course/week-01/
      icon: right-arrow
      variant: primary
    - text: View on GitHub
      link: https://github.com/thefairweathers/linux-mastery-course
      icon: external
      variant: minimal
---

import { Card, CardGrid } from '@astrojs/starlight/components';

## What You'll Build

<CardGrid>
  <Card title="Shell & Filesystem" icon="terminal">
    Master the command line, navigate filesystems, process text with pipes and filters.
  </Card>
  <Card title="System Administration" icon="setting">
    Manage users, packages, processes, storage, networking, and systemd services.
  </Card>
  <Card title="Server Infrastructure" icon="rocket">
    Configure nginx, reverse proxies, DNS, PostgreSQL, and Flask APIs.
  </Card>
  <Card title="Containers & Compose" icon="puzzle">
    Write Dockerfiles, optimize builds, and deploy multi-service stacks with Docker Compose.
  </Card>
</CardGrid>

## Course Structure

| Weeks | Focus |
|-------|-------|
| 01–04 | **Foundations** — Shell, filesystem, text processing, pipes |
| 05–07 | **System Essentials** — Users, packages, processes |
| 08 | **Scripting** — Bash fundamentals |
| 09–11 | **Infrastructure** — Networking, storage, systemd |
| 12–13 | **Services** — Web servers, databases, three-tier apps |
| 14 | **Advanced Scripting** — Automation patterns |
| 15–17 | **Containers** — Docker, Dockerfiles, Compose, capstone |

## Prerequisites

- **macOS** with Parallels Desktop
- **16 GB RAM** recommended
- **80 GB free disk space**
- **No prior Linux experience required**
HOMEPAGE

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Migrate week READMEs
# ─────────────────────────────────────────────────────────────────────────────
echo "Migrating week READMEs..."

for week_dir in "$REPO_ROOT"/week-[0-9][0-9]; do
  week_name=$(basename "$week_dir")
  week_num="${week_name#week-}"

  mkdir -p "$DOCS_DIR/$week_name"

  # Extract title from first # heading
  title=$(grep -m1 '^# ' "$week_dir/README.md" | sed 's/^# //')

  # Build the file: front matter + transformed content
  {
    echo "---"
    echo "title: \"$title\""
    echo "sidebar:"
    echo "  order: 0"
    echo "---"
    echo ""
    # Skip the first heading line (it's now in front matter title)
    # Also strip nav lines and rewrite links
    tail -n +2 "$week_dir/README.md" \
      | strip_nav \
      | rewrite_readme_links_perl "$week_num"
  } > "$DOCS_DIR/$week_name/index.md"

  echo "  ✓ $week_name/index.md — $title"
done

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Migrate lab .md files
# ─────────────────────────────────────────────────────────────────────────────
echo "Migrating lab files..."

lab_count=0
for week_dir in "$REPO_ROOT"/week-[0-9][0-9]; do
  week_name=$(basename "$week_dir")

  # Find lab .md files
  order=1
  for lab_file in "$week_dir"/labs/lab_[0-9][0-9]_*.md; do
    [ -f "$lab_file" ] || continue

    lab_basename=$(basename "$lab_file")
    # Convert lab_01_ubuntu_vm_setup.md → lab-01-ubuntu-vm-setup.md
    slug_name=$(slugify_lab "$lab_basename")

    # Extract title
    title=$(grep -m1 '^# ' "$lab_file" | sed 's/^# //')

    {
      echo "---"
      echo "title: \"$title\""
      echo "sidebar:"
      echo "  order: $order"
      echo "---"
      echo ""
      tail -n +2 "$lab_file" \
        | strip_nav \
        | rewrite_lab_links
    } > "$DOCS_DIR/$week_name/$slug_name"

    echo "  ✓ $week_name/$slug_name — $title"
    order=$((order + 1))
    lab_count=$((lab_count + 1))
  done
done

echo "  Migrated $lab_count lab files"

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Copy scaffold files
# ─────────────────────────────────────────────────────────────────────────────
echo "Copying scaffold files..."

scaffold_count=0
for week_dir in "$REPO_ROOT"/week-[0-9][0-9]; do
  week_name=$(basename "$week_dir")
  labs_dir="$week_dir/labs"

  [ -d "$labs_dir" ] || continue

  for f in "$labs_dir"/*; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")

    # Skip .md files (those become pages)
    case "$fname" in
      *.md) continue ;;
    esac

    mkdir -p "$SCAFFOLDS_DIR/$week_name"
    cp "$f" "$SCAFFOLDS_DIR/$week_name/$fname"
    scaffold_count=$((scaffold_count + 1))
    echo "  ✓ scaffolds/$week_name/$fname"
  done
done

echo "  Copied $scaffold_count scaffold files"

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
readme_count=$(find "$DOCS_DIR" -name 'index.md' -not -path "$DOCS_DIR/index.md" | wc -l | tr -d ' ')
total_pages=$((1 + readme_count + lab_count))

echo ""
echo "=== Migration Complete ==="
echo "  Homepage:  1"
echo "  Lessons:   $readme_count"
echo "  Labs:      $lab_count"
echo "  Scaffolds: $scaffold_count"
echo "  Total pages: $total_pages"
