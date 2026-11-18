#!/usr/bin/env python3
"""Tooling for the LANCommander.Servers monorepo. Standard library only.

Every image lives in Servers/<Name>/. <Name> is the PascalCase directory name; it is also the
prefix of the image's release tags (<Name>/v<version>) and of its issue label (server:<Name>).

Commands:
  list                         JSON list of every image (name, image, title, ...)
  changed <base> <head>        JSON {"build": [...], "docs": [...]} of images touched between two commits
  release <tag>                JSON build entry for a release tag such as CounterStrikeSource/v1.0.0
  dispatch <names> <version>   JSON build entries for a manual run (names: comma separated, or "all")
  check                        validate the layout of every Servers/<Name>/ (exit 1 on problems)
  hub-readme <name> <ref>      print README.md with relative links made absolute, for Docker Hub
  generate [--check]           regenerate the issue template server list and the README index
"""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVERS = ROOT / "Servers"
REPO_URL = "https://github.com/LANCommander/LANCommander.Servers"

# Files that never change what goes into an image. Changes to only these don't rebuild it.
DOC_PATTERNS = [re.compile(p) for p in (r"^README\.md$", r"^Documentation/", r"^compose\.yml$")]

REQUIRED_FILES = ["Dockerfile", "README.md", "compose.yml", "server.json"]
ISSUE_TEMPLATE = ROOT / ".github" / "ISSUE_TEMPLATE" / "server-issue.yml"
INDEX_README = ROOT / "README.md"


def label_value(dockerfile_text, key):
    m = re.search(re.escape(key) + r'="((?:[^"\\]|\\.)*)"', dockerfile_text)
    return m.group(1) if m else None


def short(text, limit=100):
    """Docker Hub's short description holds at most 100 characters."""
    if len(text) <= limit:
        return text
    return text[: limit - 1].rsplit(" ", 1)[0].rstrip(",;:(-") + "…"


def load(name):
    d = SERVERS / name
    if not (d / "Dockerfile").is_file():
        return None
    meta = json.loads((d / "server.json").read_text()) if (d / "server.json").is_file() else {}
    df = (d / "Dockerfile").read_text()
    title = label_value(df, "org.opencontainers.image.title")
    game = label_value(df, "app.lancommander.server.game.title")
    kind = label_value(df, "app.lancommander.server.kind")
    if not game and title:
        game = re.sub(r"\s+(Dedicated |Game |Multiplayer )?Server$", "", title)
    return {
        "name": name,
        "image": meta.get("image"),
        "tagSuffixes": meta.get("tagSuffixes", [""]),
        "title": title,
        "description": label_value(df, "org.opencontainers.image.description"),
        "shortDescription": short(label_value(df, "org.opencontainers.image.description") or ""),
        "game": game or name,
        "kind": kind or ("base" if meta.get("base") else "game"),
        "base": bool(meta.get("base")),
        "context": f"Servers/{name}",
    }


def all_names():
    return sorted((p.name for p in SERVERS.iterdir() if p.is_dir()), key=str.lower)


def all_servers():
    return [s for s in (load(n) for n in all_names()) if s]


def emit(obj):
    print(json.dumps(obj, separators=(",", ":")))


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], check=True, capture_output=True, text=True).stdout


def cmd_changed(base, head):
    if not base or set(base) == {"0"}:
        # New branch or first push: nothing to compare against, so check every image.
        files = [f"Servers/{n}/Dockerfile" for n in all_names()]
    else:
        try:
            files = git("diff", "--name-only", f"{base}...{head}").splitlines()
        except subprocess.CalledProcessError:
            # base isn't in the history (force push): fall back to the head commit's own changes.
            files = git("diff-tree", "--no-commit-id", "--name-only", "-r", "-m", head).splitlines()
    build, docs = set(), set()
    for f in files:
        parts = f.split("/", 2)
        if len(parts) < 3 or parts[0] != "Servers":
            continue
        name, rest = parts[1], parts[2]
        if not (SERVERS / name / "Dockerfile").is_file():
            continue  # deleted, or a docs-only directory
        if rest == "README.md":
            docs.add(name)
        if not any(p.search(rest) for p in DOC_PATTERNS):
            build.add(name)
    by_name = {s["name"]: s for s in all_servers()}
    emit({"build": [by_name[n] for n in sorted(build)], "docs": [by_name[n] for n in sorted(docs)]})


def cmd_release(tag):
    m = re.fullmatch(r"([A-Za-z0-9]+)/v(.+)", tag)
    if not m:
        sys.exit(f"Tag '{tag}' is not <Server>/v<version>")
    s = load(m.group(1))
    if not s:
        sys.exit(f"No image in Servers/{m.group(1)}/ for tag '{tag}'")
    emit([{**s, "version": m.group(2)}])


def cmd_dispatch(names, version):
    wanted = all_names() if names.strip() == "all" else [n.strip() for n in names.split(",") if n.strip()]
    out = []
    for n in wanted:
        s = load(n)
        if not s:
            sys.exit(f"No image in Servers/{n}/")
        out.append({**s, "version": version})
    emit(out)


def compose_block(readme):
    for m in re.finditer(r"^```ya?ml\n(.*?)^```", readme, re.S | re.M):
        if re.search(r"^services:", m.group(1), re.M):
            return m.group(1)
    return None


def cmd_check():
    problems = []
    images = {}
    for name in all_names():
        d = SERVERS / name
        if not (d / "Dockerfile").is_file():
            extra = [p.name for p in d.iterdir() if p.name != "Documentation"]
            if extra:
                problems.append(f"{name}: no Dockerfile, so it may only hold Documentation/ (found {extra})")
            continue
        if not re.fullmatch(r"[A-Z][A-Za-z0-9]*", name):
            problems.append(f"{name}: directory name must be PascalCase letters and digits")
        for f in REQUIRED_FILES:
            if not (d / f).is_file():
                problems.append(f"{name}: missing {f}")
        for stray in (".github", "LICENSE"):
            if (d / stray).exists():
                problems.append(f"{name}: {stray} belongs at the repository root")
        s = load(name)
        if not s["image"] or not re.fullmatch(r"lancommander/[a-z0-9][a-z0-9._-]*", s["image"]):
            problems.append(f"{name}: server.json needs \"image\": \"lancommander/<name>\"")
        elif s["image"] in images:
            problems.append(f"{name}: image {s['image']} is also used by {images[s['image']]}")
        else:
            images[s["image"]] = name
        if not s["title"]:
            problems.append(f"{name}: Dockerfile has no org.opencontainers.image.title label")
        if not s["description"]:
            problems.append(f"{name}: Dockerfile has no org.opencontainers.image.description label")
        if not (d / "README.md").is_file() or not (d / "compose.yml").is_file():
            continue
        readme = (d / "README.md").read_text()
        compose = (d / "compose.yml").read_text()
        block = compose_block(readme)
        if block is None:
            problems.append(f"{name}: README.md has no compose example (a yaml block with services:)")
        elif block.strip() != compose.strip():
            problems.append(f"{name}: the README compose example differs from compose.yml")
        if s["image"] and not re.search(rf"image:\s*{re.escape(s['image'])}(:|\s|$)", compose):
            problems.append(f"{name}: compose.yml doesn't use {s['image']}")
        if len(readme.encode()) > 25000:
            problems.append(f"{name}: README.md is over Docker Hub's 25,000 byte limit")
    problems += generate(check=True)
    for p in problems:
        print(p)
    if problems:
        sys.exit(1)
    print(f"OK: {len(images)} images")


def cmd_hub_readme(name, ref):
    """README with relative links/images pointed at GitHub, since Docker Hub can't resolve them."""
    text = (SERVERS / name / "README.md").read_text()
    blob = f"{REPO_URL}/blob/{ref}/Servers/{name}/"
    raw = f"https://raw.githubusercontent.com/LANCommander/LANCommander.Servers/{ref}/Servers/{name}/"

    def fix(m):
        bang, label, target = m.group(1), m.group(2), m.group(3)
        if re.match(r"^([a-z]+:|#|/)", target):
            return m.group(0)
        return f"{bang}[{label}]({(raw if bang else blob) + target})"

    print(re.sub(r"(!?)\[([^\]]*)\]\(([^)\s]+)\)", fix, text), end="")


def replace_generated(text, key, body):
    # Markers: "<!-- BEGIN GENERATED key ... -->" in Markdown, "# BEGIN GENERATED key ..." in YAML.
    pat = re.compile(rf"((?:<!--|#) BEGIN GENERATED {key}\b[^\n]*\n)(?:.*?\n)??([ \t]*(?:<!--|#) END GENERATED {key}\b)", re.S)
    if not pat.search(text):
        raise SystemExit(f"Generated block '{key}' markers not found")
    return pat.sub(lambda m: m.group(1) + body + "\n" + m.group(2), text, count=1)


def generate(check=False):
    servers = all_servers()
    games = [s for s in servers if not s["base"]]
    bases = [s for s in servers if s["base"]]
    changed = []

    options = "\n".join(f"        - {s['name']}" for s in servers)
    rows = ["| Server | Image | Directory |", "|---|---|---|"]
    for s in games:
        rows.append(f"| {s['game']} | [`{s['image']}`](https://hub.docker.com/r/{s['image']}) | [`Servers/{s['name']}`](Servers/{s['name']}) |")
    base_rows = ["| Base image | Image | Directory |", "|---|---|---|"]
    for s in bases:
        base_rows.append(f"| {s['title']} | [`{s['image']}`](https://hub.docker.com/r/{s['image']}) | [`Servers/{s['name']}`](Servers/{s['name']}) |")

    for path, key, body in (
        (ISSUE_TEMPLATE, "servers", options),
        (INDEX_README, "bases", "\n".join(base_rows)),
        (INDEX_README, "servers", "\n".join(rows)),
    ):
        old = path.read_text()
        new = replace_generated(old, key, body)
        if new != old:
            changed.append(f"{path.relative_to(ROOT)} is out of date: run scripts/servers.py generate")
            if not check:
                path.write_text(new)
    return changed if check else []


def main(argv):
    if not argv:
        sys.exit(__doc__)
    cmd, args = argv[0], argv[1:]
    if cmd == "list":
        emit(all_servers())
    elif cmd == "changed" and len(args) == 2:
        cmd_changed(*args)
    elif cmd == "release" and len(args) == 1:
        cmd_release(*args)
    elif cmd == "dispatch" and len(args) == 2:
        cmd_dispatch(*args)
    elif cmd == "check":
        cmd_check()
    elif cmd == "hub-readme" and len(args) == 2:
        cmd_hub_readme(*args)
    elif cmd == "generate":
        generate(check="--check" in args)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
