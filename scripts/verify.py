#!/usr/bin/env python3
"""Structural verification suite for the evolve skill repository.

Checks plugin metadata, SKILL.md frontmatter, version consistency across
files, and repo-relative links in the READMEs. Stdlib only — no third-party
dependencies (repo red line). Exit code 0 = all green.

Usage: python scripts/verify.py
"""

import json
import re
import shutil
import subprocess
import sys
import tempfile
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

for tpl in ("evolve-log.md", "lessons.md", "evolve-report.md", "epics.md"):
    check(f"template exists: docs/templates/{tpl}",
          (ROOT / "docs" / "templates" / tpl).exists())

# Epic escalation: rounds graduate targets they demonstrably cannot close
# into docs/epics.md proposals and NEVER execute them (user review gate).
# Wiring checks — prose rules cannot be executed (E8), so pin the wiring.
check("SKILL.md defines the Epic escalation standard with its review gate",
      "## Epic escalation" in skill and "docs/epics.md" in skill
      and "NEVER execute epics" in skill
      and "(f)" in skill)
check("READMEs surface the epic review gate",
      "docs/epics.md" in readme_en.read_text(encoding="utf-8")
      and "docs/epics.md" in readme_zh.read_text(encoding="utf-8"))

# The evolve-log template must teach the CURRENT result vocabulary — a
# template still showing the legacy 'result(green|red, ...)' form breeds
# logs the anti-gaming rules (and the circuit breaker) cannot read.
tpl_log = (ROOT / "docs" / "templates" / "evolve-log.md").read_text(encoding="utf-8")
check("evolve-log template shows the anti-gaming result vocabulary",
      "green+progress" in tpl_log and "green+no-progress" in tpl_log
      and "blocked" in tpl_log and "interrupted" in tpl_log
      and "result(green|" not in tpl_log)

# A manual install that follows the READMEs verbatim ships only SKILL.md, but
# SKILL.md's profiling step expects the starter templates to sit next to it
# ("copy them when present"). The install instruction must cover the
# templates too — otherwise every README-guided manual install is silently
# degraded (hit live 2026-09-05: the installer had to infer the templates
# from SKILL.md's own text). Wiring check — an instruction cannot be executed;
# anchored to the instruction line so a templates mention elsewhere in the
# README (the profiling section) cannot mask it. The prefix includes the
# colon: a future `**Manual <something>:**` line above the real install
# instruction must not capture the first match (inspector mutant (e), #15).
def manual_install_line(text):
    for line in text.splitlines():
        if line.startswith("**Manual:**") or line.startswith("**手动安装：**"):
            return line
    return ""

check("READMEs' manual-install copies the starter templates, not just SKILL.md",
      all("docs/templates" in manual_install_line(r.read_text(encoding="utf-8"))
          for r in (readme_en, readme_zh)))

check("CI workflow exists", (ROOT / ".github" / "workflows" / "verify.yml").exists())
check("autonomous driver exists", (ROOT / "scripts" / "auto-evolve.sh").exists())

# --- autonomous driver: circuit breaker -------------------------------------
# The stop rules (no-progress breaker + converged header) live in breaker.sh,
# sourced by the driver — one source of truth. Structural checks below pin
# the wiring; the fixture probes above them pin the BEHAVIOR (T4f: substring
# probes on the driver source passed mutation testing only 2/6 before).

driver = (ROOT / "scripts" / "auto-evolve.sh").read_text(encoding="utf-8")
bash_bin = shutil.which("bash")
breaker_path = ROOT / "scripts" / "breaker.sh"
check("breaker.sh exists", breaker_path.exists())
breaker = breaker_path.read_text(encoding="utf-8") if breaker_path.exists() else ""

check("driver sources breaker.sh and calls should_stop (single stop-rule source)",
      'source "$(dirname "$0")/breaker.sh"' in driver
      and 'should_stop "$LOG"' in driver)

if bash_bin:
    # Substring checks cannot see a syntax error; parse both scripts for real.
    for sh in ("scripts/auto-evolve.sh", "scripts/breaker.sh"):
        parsed = subprocess.run(["bash", "-n", (ROOT / sh).as_posix()],
                                capture_output=True, text=True)
        check(f"bash -n parses {sh}", parsed.returncode == 0,
              parsed.stderr.strip()[:120])

check("circuit breaker selects round lines, not the file tail",
      bool(re.search(r"grep -E '\^#\[0-9\]\+ \\\|'", breaker))
      and '"$log" | tail -n 3' in breaker
      and "tail -n 5" not in breaker)
check("circuit breaker counts the result FIELD, not a line substring",
      "awk -F' [|] '" in breaker
      and "/^result\\(green\\+no-progress/" in breaker
      and "tail -n 3" in breaker and "-eq 3" in breaker and "streak" not in breaker)

# Behavioral probes: run scripts/breaker.sh against fixture logs and assert
# the stop/continue decision itself. Fixtures encode the T1e bug shape (a
# run-summary block following the rounds) and the vocabulary rules.
def breaker_probe(log_text):
    """Run breaker.sh on a fixture log; return (exit_code, reason)."""
    with tempfile.TemporaryDirectory() as td:
        fixture = Path(td) / "evolve-log.md"
        fixture.write_text(log_text, encoding="utf-8", newline="\n")
        proc = subprocess.run(
            ["bash", breaker_path.as_posix(), fixture.as_posix()],
            capture_output=True, text=True, encoding="utf-8", errors="replace")
        return proc.returncode, proc.stdout.strip()

def fixture_log(rounds, status="active", tail="", note="notes",
                target="target", checks=40):
    """Real-format log: title, header block, ## Rounds section, optional
    ## Run summary block — mirroring docs/evolve-log.md and the template
    (a bare list of round lines would not exercise heading interference).
    `note` applies to every round: a string, or a per-round list. Literals
    vary per round (findings/actions/checks/diff) the way real logs do, so
    a full-literal matcher cannot pass vacuously (P13, #12). `target` is
    free-form and may contain ' | ' (G2, #12)."""
    notes = [note] * len(rounds) if isinstance(note, str) else list(note)
    assert len(notes) == len(rounds)
    lines = [
        "# evolve log — fixture",
        "",
        "- verify: python -c pass",
        f"- rounds done: {len(rounds)}",
        f"- status: {status}",
        "",
        "## Rounds",
        "",
    ]
    lines += [f"#{n} | {target} | findings({1 + n % 3}) | actions({n % 2}) | "
              f"result({r}, {checks + n} checks) | diff(~{30 + n}) | {nt}"
              for n, (r, nt) in enumerate(zip(rounds, notes), 1)]
    lines += ["", "## Run summary", "", tail] if tail else []
    return "\n".join(lines) + "\n"

if not bash_bin:
    check("breaker fixtures: bash available to run behavioral probes",
          False, "bash not on PATH (git-bash on Windows / any POSIX CI)")

if bash_bin:
    NP, PR = "green+no-progress", "green+progress"
    SUMMARY_NP = ("- result vocabulary: green+progress / green+no-progress /"
                  " red / blocked / interrupted — a result(green+no-progress"
                  " round earns no progress")  # summary text mentions the word
    CASES = [
        ("fires on 3 consecutive no-progress rounds",
         fixture_log([PR, PR, NP, NP, NP], tail=SUMMARY_NP), 0, "no-progress"),
        ("does not fire when a no-progress-mentioning run summary trails healthy rounds",
         fixture_log([PR, PR, PR, PR, PR], tail=SUMMARY_NP), 1, ""),
        ("does not fire when only 2 of the last 3 rounds are no-progress",
         fixture_log([PR, PR, PR, NP, NP]), 1, ""),
        ("does not fire when early no-progress rounds precede healthy ones (tail window, not cumulative)",
         fixture_log([NP, NP, NP, PR, PR]), 1, ""),
        ("fires when 4+ consecutive rounds are no-progress (count is on the tail window)",
         fixture_log([NP, NP, NP, NP]), 0, "no-progress"),
        ("does not fire with fewer than 3 rounds, all no-progress",
         fixture_log([NP, NP]), 1, ""),
        ("does not fire on legacy result(green, ...) vocabulary rows",
         fixture_log(["green, 40 checks"] * 3), 1, ""),
        ("does not fire on a header-only log with zero rounds",
         fixture_log([]), 1, ""),
        ("does not fire on 'converged' in a round note while the header is active",
         fixture_log([PR, PR], note="pool converged after refresh"), 1, ""),
        ("does not fire on 'status: converged' quoted in a round note",
         fixture_log([PR, PR], note="considered status: converged, kept active"), 1, ""),
        ("does not fire when the 3-round window boundary cuts a no-progress run",
         fixture_log([PR, NP, NP, NP, PR]), 1, ""),
        ("does not fire on last-3 blocked rounds (only no-progress breaks)",
         fixture_log(["blocked"] * 3), 1, ""),
        ("does not fire on last-3 red rounds (only no-progress breaks)",
         fixture_log(["red"] * 3), 1, ""),
        ("does not fire when progress rounds merely QUOTE the no-progress word in notes",
         fixture_log([PR, PR, PR],
                     note=["notes quote `result(green+no-progress` rows"] * 3), 1, ""),
        ("does not fire when notes mention it after a plain space (no pipe column)",
         fixture_log([PR, PR, PR],
                     note=["saw result(green+no-progress rows earlier"] * 3), 1, ""),
        ("does not fire when notes quote the anchored pattern verbatim, pipe included",
         fixture_log([PR, PR, PR],
                     note=["breaker greps ' | result(green+no-progress' per #12"] * 3), 1, ""),
        ("does not fire on an ACTIVE status whose suffix mentions convergence",
         fixture_log([PR, PR, PR],
                     status="active — pool converged, retrospective pending"), 1, ""),
        ("fires when the TARGET contains a pipe (result column shifts right)",
         fixture_log([NP, NP, NP], target="T4f (mutation | behavioral)"),
         0, "no-progress"),
        ("does not fire when a TARGET mimics the result prefix without the full shape",
         fixture_log([PR, PR, PR],
                     target="result(green+no-progress probe — fake shape"), 1, ""),
        ("fires on genuine no-progress rounds even when the TARGET starts result(-shaped",
         fixture_log([NP, NP, NP], target="result(field) parsing fix"),
         0, "no-progress"),
        ("fires when the TARGET merely CONTAINS result( mid-string",
         fixture_log([NP, NP, NP], target="count result( fields correctly"),
         0, "no-progress"),
        ("does not fire on healthy rounds whose TARGET fakes the FULL result shape",
         fixture_log([PR, PR, PR],
                     target="result(green+no-progress, fake) probe"), 1, ""),
        ("fires on genuine no-progress rounds whose TARGET fakes the FULL result shape",
         fixture_log([NP, NP, NP],
                     target="result(green+no-progress, fake) probe"),
         0, "no-progress"),
        ("fires when a pipe-shifted TARGET segment starts result(-shaped",
         fixture_log([NP, NP, NP],
                     target="T4f | result(field) parsing fix"),
         0, "no-progress"),
        ("fires when a pipe-shifted TARGET segment merely CONTAINS the result shape",
         fixture_log([NP, NP, NP],
                     target="T4f | see result(green+no-progress, fake) inline"),
         0, "no-progress"),
        ("fires on a converged header even when rounds are healthy",
         fixture_log([PR, PR, PR], status="converged"), 0, "converged"),
        ("fires on a converged header that carries a suffix note",
         fixture_log([PR, PR, PR], status="converged — all targets clean"),
         0, "converged"),
    ]
    for name, text, want_rc, want_reason in CASES:
        rc, reason = breaker_probe(text)
        check(f"breaker behavior: {name}",
              rc == want_rc and reason == want_reason,
              f"exit {rc} ({reason!r}), want {want_rc} ({want_reason!r})")

# The driver runs under `set -euo pipefail`: an unguarded `claude -p`
# non-zero exit (rate limit, crashed session) kills the driver before the
# breaker can run. The invocation must sit in an errexit-safe guard, and
# persistently failing sessions must abort the run instead of silently
# burning the remaining rounds.
check("driver survives a failed round session instead of dying under set -e",
      bool(re.search(r'if \(cd "\$PROJECT" && claude -p', driver))
      and driver.count("failures=0") >= 2 and "-ge 3" in driver)

# T1g: a headless session cannot see the driver's loop counter — unless the
# driver SAYS it, the mandatory final-round retrospective silently never
# happens (proved live: run #8–#12 ended on a normal round, not a
# retrospective). The prompt must state the position in every round and
# switch the final round to retrospective instructions. Wiring check — the
# prompt itself cannot be executed without launching claude.
check("driver tells each session its run position (final round → retrospective)",
      'POSITION="This is driver round $i of $N."' in driver
      and "$POSITION Step 0" in driver
      and '-eq "$N"' in driver
      and "run the RETROSPECTIVE" in driver)

# A non-numeric or zero <rounds> must fail loudly at startup: bash
# arithmetic evaluates an identifier like '--danger' to 0, so a swapped
# argument list would silently run zero rounds. The guard must be negated
# (reject-inverted mutants pass a plain 'if [[ ... ]]') and an explicitly
# empty <rounds> must reach it, not fall through to the default.
check("driver validates <rounds> as a positive integer",
      'if ! [[ "$N" =~ ' in driver and "[1-9][0-9]*$" in driver
      and "N=${2-5}" in driver)

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

# The epics register template must carry the review gate and the family
# placeholder convention — a template teaching `&lt;`-escaped placeholders,
# or missing the never-execute gate, breeds copies that drift from the
# protocol (the other data-file templates get their vocabulary pinned the
# same way).
tpl_epics = (ROOT / "docs" / "templates" / "epics.md").read_text(encoding="utf-8")
check("epics template pins the review gate + family placeholder convention",
      "NEVER execute epics" in tpl_epics
      and "proposed|approved|rejected|done" in tpl_epics
      and "<project name>" in tpl_epics
      and "&lt;" not in tpl_epics
      and "only by user review" in tpl_epics
      and "At most one new proposal per round" in tpl_epics)

# --- lessons library ---------------------------------------------------------
# The retrospective step re-checks every lesson and bumps `verified`
# counters; a row whose verified column drifts out of integer format (or a
# library that loses the 5-column template) rots silently — SKILL.md says
# the library must not rot, so the suite guards the structure.
lessons_text = (ROOT / "docs" / "lessons.md").read_text(encoding="utf-8")
check("lessons.md declares the 5-column entry template",
      "| id | lesson | how to apply | source | verified |" in lessons_text)
lesson_rows = [l for l in lessons_text.splitlines() if re.match(r"^\| E\d+ \|", l)]
check("lessons.md verified counters are integers",
      bool(lesson_rows)
      and all(re.search(r"\|\s*\d+\s*\|\s*$", l) for l in lesson_rows),
      f"{sum(1 for l in lesson_rows if not re.search(r'\\|\\s*\\d+\\s*\\|\\s*$', l))} malformed rows")

# --- summary ----------------------------------------------------------------

print(f"\n{checks - len(failures)}/{checks} checks passed")
if failures:
    print("FAILED: " + ", ".join(failures))
    sys.exit(1)
