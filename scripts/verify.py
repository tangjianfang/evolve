#!/usr/bin/env python3
"""Structural verification suite for the evolve skill repository.

Checks plugin metadata, SKILL.md frontmatter, version consistency across
files, and repo-relative links in the READMEs. Stdlib only — no third-party
dependencies (repo red line). Exit code 0 = all green.

Usage: python scripts/verify.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

failures = []
checks = 0


def check(name, ok, detail=""):
    global checks
    checks += 1
    mark = "PASS" if ok else "FAIL"
    print(f"[{mark}] {name}" + (f" — {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


# --- plugin metadata -------------------------------------------------------

plugin = json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))
check("plugin.json parses as JSON", isinstance(plugin, dict))

for field in ("name", "description", "version", "author", "license"):
    check(f"plugin.json has '{field}'", field in plugin)

market = json.loads((ROOT / ".claude-plugin" / "marketplace.json").read_text(encoding="utf-8"))
check("marketplace.json parses as JSON", isinstance(market, dict))

plugins = market.get("plugins", [])
check("marketplace.json lists >=1 plugin", len(plugins) >= 1)
check("marketplace plugin source is './' (self-referencing)",
      bool(plugins) and plugins[0].get("source") == "./")

semver = re.compile(r"^\d+\.\d+\.\d+$")
check("plugin.json version is semver", bool(semver.match(plugin.get("version", ""))))
check("marketplace version matches plugin.json",
      bool(plugins) and plugins[0].get("version") == plugin.get("version"))

changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
versions = re.findall(r"^## \[(\d+\.\d+\.\d+)\]", changelog, re.MULTILINE)
check("CHANGELOG has a version heading", bool(versions))
check("CHANGELOG latest version matches plugin.json",
      bool(versions) and versions[0] == plugin.get("version"),
      f"changelog {versions[0] if versions else '—'} vs plugin {plugin.get('version')}")

# --- skill -----------------------------------------------------------------

skill_path = ROOT / "skills" / plugin.get("name", "evolve") / "SKILL.md"
skill = skill_path.read_text(encoding="utf-8") if skill_path.exists() else ""
check("SKILL.md exists at skills/<name>/SKILL.md", skill_path.exists())

fm = re.match(r"^---\n(.*?)\n---\n", skill, re.DOTALL)
check("SKILL.md frontmatter delimited", fm is not None)

if fm:
    name_m = re.search(r"^name:\s*(\S+)", fm.group(1), re.MULTILINE)
    desc_m = re.search(r"^description:\s*(.+)", fm.group(1), re.MULTILINE)
    check("frontmatter name matches plugin name",
          bool(name_m) and name_m.group(1) == plugin.get("name"))
    desc = desc_m.group(1) if desc_m else ""
    check("description has English trigger", "iterate" in desc.lower())
    check("description has Chinese trigger", "迭代" in desc)

# Ordered lists must number sequentially from 1 (guards against edit-dropped
# or duplicated items, e.g. the #6 crystallization edit duplicating a
# retrospective output). Column-0 `N. ` starts/continues a list; blank and
# indented lines are continuations; any other column-0 line starts a new list.
seq_fail = []
expected = 1
for lineno, line in enumerate(skill.splitlines(), 1):
    item = re.match(r"^(\d+)\.\s", line)
    if item:
        num = int(item.group(1))
        if num != expected:
            seq_fail.append(f"line {lineno}: item {num}, expected {expected}")
        expected = num + 1
    elif not line.strip() or line[0].isspace():
        continue
    else:
        expected = 1
check("SKILL.md ordered lists numbered sequentially", not seq_fail,
      "; ".join(seq_fail[:3]))

# --- docs & links ----------------------------------------------------------

check("LICENSE exists and is MIT",
      (ROOT / "LICENSE").exists()
      and "MIT" in (ROOT / "LICENSE").read_text(encoding="utf-8")[:200])

readme_en = ROOT / "README.md"
readme_zh = ROOT / "README.zh-CN.md"
check("README.md exists", readme_en.exists())
check("README.zh-CN.md exists", readme_zh.exists())
check("READMEs cross-link each other",
      readme_en.exists() and readme_zh.exists()
      and "README.zh-CN.md" in readme_en.read_text(encoding="utf-8")
      and "README.md" in readme_zh.read_text(encoding="utf-8"))

for readme in (readme_en, readme_zh):
    if not readme.exists():
        continue
    for target in re.findall(r"\]\((?!https?://|#)([^)#]+)", readme.read_text(encoding="utf-8")):
        check(f"link resolves: {target} ({readme.name})", (ROOT / target).exists())

for tpl in ("evolve-log.md", "lessons.md", "evolve-report.md"):
    check(f"template exists: docs/templates/{tpl}",
          (ROOT / "docs" / "templates" / tpl).exists())

check("CI workflow exists", (ROOT / ".github" / "workflows" / "verify.yml").exists())
check("autonomous driver exists", (ROOT / "scripts" / "auto-evolve.sh").exists())

# --- autonomous driver: circuit breaker -------------------------------------
# The breaker must stop on 3 consecutive no-progress ROUNDS. Round lines look
# like '#N | target | ... | result(green+no-progress, ...) | ...' — the log's
# file tail can be a run-summary block instead of round lines, and a single
# match inside a tail window is not "3 consecutive" (T1e).

driver = (ROOT / "scripts" / "auto-evolve.sh").read_text(encoding="utf-8")

check("circuit breaker selects round lines, not the file tail",
      bool(re.search(r"grep -E '\^#\[0-9\]\+ \\\|'", driver))
      and "tail -n 5" not in driver)
check("circuit breaker fires only when the last 3 round lines are all no-progress",
      "grep -c 'result(green+no-progress'" in driver and "tail -n 3" in driver
      and "-eq 3" in driver and "streak" not in driver)

# The round-line pattern must actually work on the real log: it has to select
# exactly as many lines as the header's 'rounds done' counter claims (also
# guards the E4 counter-sum discipline).
evolve_log = ROOT / "docs" / "evolve-log.md"
log_text = evolve_log.read_text(encoding="utf-8")
round_lines = re.findall(r"^#\d+ \|", log_text, re.MULTILINE)
done_m = re.search(r"^- rounds done:\s*(\d+)", log_text, re.MULTILINE)
check("round lines in evolve-log match header 'rounds done'",
      bool(done_m) and len(round_lines) == int(done_m.group(1)),
      f"{len(round_lines)} round lines vs rounds done {done_m.group(1) if done_m else '—'}")

# --- summary ----------------------------------------------------------------

print(f"\n{checks - len(failures)}/{checks} checks passed")
if failures:
    print("FAILED: " + ", ".join(failures))
    sys.exit(1)
