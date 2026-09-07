#!/usr/bin/env python3
"""Assemble the landing page from the skill's base and this page's parts.

Two outputs from one set of sources: index.html, a whole document to open
locally, and artifact.html, the same page as a body fragment for publishing.
"""
import base64
from pathlib import Path

SKILL = Path.home() / ".claude/skills/meric-frontend"
HERE = Path(__file__).parent

base_css = (SKILL / "base.css").read_text()
base_css = base_css.replace("--paper: #c1cad9;", "--paper: #ccd2dc;")
base_css = base_css.replace("--ink: #2a3241;", "--ink: #1f2430;")
base_css = base_css.replace("--accent: #0a84ff;", "--accent: #ff9f0a;")
for stale in ("          /* #d1d9e5 */", "   /* #dce2ec */", "   /* #1f5cc9 */"):
    base_css = base_css.replace(stale, "")

body = (HERE / "_body.html").read_text()
for name in ("appearance", "agents"):
    data = base64.b64encode((HERE / f"img/{name}.jpg").read_bytes()).decode()
    body = body.replace(f"IMG_{name.upper()}", f"data:image/jpeg;base64,{data}")

head = """<title>StayUp</title>
<meta name="description" content="A macOS menu bar app that keeps your Mac awake with the lid closed while an agent is working, and lets it sleep the second it stops.">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Inter+Tight:wght@500;600&family=Instrument+Sans:wght@500;600&display=swap" rel="stylesheet">
<script>document.documentElement.classList.add("js");</script>
<style>
""" + base_css + "\n" + (HERE / "_page.css").read_text() + "</style>"

script = "\n<script>\n" + (SKILL / "base.js").read_text() + "\n" + (HERE / "_page.js").read_text() + "\n</script>\n"

(HERE / "artifact.html").write_text(head + "\n" + body + script)
(HERE / "index.html").write_text(
    '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
    '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
    + head + "\n</head>\n<body>\n" + body + script + "</body>\n</html>\n"
)
for f in ("index.html", "artifact.html"):
    print(f, (HERE / f).stat().st_size // 1024, "KB")
