#!/usr/bin/env python3
"""Insert a newly-added managed repo into README.md's hand-maintained
inventory: the "## Repositories" bulleted list (all categories -- this
part is enforced by scripts/readme-check.sh) and, best-effort, the
"Directory Structure" tree diagram (module/config categories only,
where there's a reliable anchor line and a natural per-repo path).

Called from scripts/add-repo.sh as:
    update-readme.py <repo> <path> <category> <summary>

Safe to call on a repo/link that's already present (no-op, not a
duplicate insert).
"""
import re
import sys

CATEGORY_HEADING = {
    "top-level": "### Core",
    "module": "### Modules",
    "shared": "### Shared",
    "config": "### Config",
}

# Anchors for the best-effort tree-diagram insertion: the basename that
# marks the terminal (└──) line of each block. Matched structurally
# (indent + "└── " + this token), not as a hardcoded full line, so a
# mistyped/stale literal string can't silently stop matching.
TREE_ANCHOR_TOKEN = {
    "module": "xcode/",
    "config": "zsh/",
}


def update_bullet_list(text, repo, category):
    link = f"- [{repo}](https://github.com/smeltery/{repo})"
    if link in text:
        return text, False

    heading = CATEGORY_HEADING.get(category)
    if not heading or heading not in text:
        print(
            f"warning: no README heading for category '{category}' -- "
            f"add '{link}' to README.md by hand",
            file=sys.stderr,
        )
        return text, False

    start = text.index(heading) + len(heading)
    next_heading = text.find("\n\n#", start)
    if next_heading == -1:
        # last section in the file
        return text.rstrip("\n") + "\n" + link + "\n", True
    return text[:next_heading] + "\n" + link + text[next_heading:], True


def update_tree(text, path, category, summary):
    token = TREE_ANCHOR_TOKEN.get(category)
    if not token:
        return text, False

    basename = path.rstrip("/").rsplit("/", 1)[-1]
    if any(f"├── {basename}/" in line for line in text.splitlines()):
        return text, False  # already present

    lines = text.splitlines(keepends=True)
    anchor_idx = None
    indent = None
    for i, line in enumerate(lines):
        # indent can include tree-continuation characters (│), not just
        # whitespace -- e.g. "│   └── xcode/" for a nested block.
        m = re.match(r"^([│\s]*)└──\s+" + re.escape(token), line)
        if m:
            anchor_idx, indent = i, m.group(1)
            break

    if anchor_idx is None:
        return text, False

    label = re.sub(r"\s+", " ", summary).strip()
    if len(label) > 40:
        label = label[:39].rsplit(" ", 1)[0] + "..."
    padding = " " * max(1, 20 - len(f"{basename}/"))
    new_line = f"{indent}├── {basename}/{padding}# {label}\n"

    lines.insert(anchor_idx, new_line)
    return "".join(lines), True


def main():
    repo, path, category, summary = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

    with open("README.md") as f:
        text = f.read()

    text, bullet_changed = update_bullet_list(text, repo, category)
    text, tree_changed = update_tree(text, path, category, summary)

    if bullet_changed or tree_changed:
        with open("README.md", "w") as f:
            f.write(text)


if __name__ == "__main__":
    main()
