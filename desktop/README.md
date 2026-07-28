# Claude Desktop propagation

Claude Desktop has three surfaces. Only one has hooks — the other two get
**derivados**: lossy, hand-maintained paraphrases of the ruleset. Full
fidelity (compact re-injection, per-turn anchor, subagent coverage, loud
failure marker) exists ONLY where hooks run.

| Surface | Channel | Fidelity |
|---|---|---|
| Code (tab or CLI) | the 3 hooks (`../install.sh`) | full — nothing else to do |
| Chat | Style + profile + Project instructions | static, drifts in long sessions |
| Cowork | skill (+ CLAUDE.md if the test passes) | model-invoked, partial |

## Code

Run the installer. The Code tab reads the same `settings.json` as the CLI —
no extra steps. If a session ever shows `FLINT HOOK ERROR`, the clone moved
or Python left the PATH; re-run `./install.sh`.

## Chat

UI paths verified 2026-07-28 (Claude for Mac). Anthropic moves this menu;
when a path is gone, the artifact still applies — find the equivalent field.

1. **Instructions for Claude** (account-wide, the only always-on channel):
   your initials, bottom-left → `Settings` → `General` → `Profile` →
   `Instructions for Claude` → paste [`chat/profile.md`](chat/profile.md)
   (fits the 1,500-char budget).
2. **Style** (prose layer, per chat): in any chat, `+` next to the prompt
   input → hover `Use style` → `Create & edit styles` → `Create custom style`
   → `Describe style instead` → paste [`chat/style.md`](chat/style.md) →
   `Create style`. A Style applies to the chat you select it in — every new
   chat starts back on `Normal`. Account-wide coverage comes from step 1.
3. **Projects** (dev work): inside the Project → `Set project instructions` →
   paste [`chat/project-instructions.md`](chat/project-instructions.md) — the
   ruleset verbatim (fits the ~8,000-char budget).

## Cowork

Cowork does not read a local skills directory — no `~/.claude/skills`
symlink, no folder sync. Skills are uploaded as a ZIP, per account.

1. **Skill**: package [`cowork/`](cowork/) as a ZIP whose top-level entry is a
   directory named `flint` containing `SKILL.md`:

   ```sh
   rm -rf /tmp/flintpkg && mkdir -p /tmp/flintpkg/flint
   cp desktop/cowork/SKILL.md /tmp/flintpkg/flint/
   (cd /tmp/flintpkg && zip -qr ~/Desktop/flint-skill.zip flint)
   ```

   Then in Cowork: `Customize` in the left sidebar → `Skills` → `+` →
   `Create skill` → `Upload a skill` → pick the ZIP → leave the toggle on.

2. **CLAUDE.md channel**: run the marker test in
   [`cowork/claude-md-snippet.md`](cowork/claude-md-snippet.md); paste the
   snippet only if the test passes. Last run 2026-07-28 (Claude for Mac,
   macOS 26.6): **no marker** — Cowork did not read the file, so the skill
   was the only working channel on that machine.

## Re-sync checklist (every ruleset release)

Derivados do not update themselves. After ANY edit to `flint.md`:

- [ ] `chat/project-instructions.md` — regenerate (header + verbatim ruleset)
- [ ] `cowork/SKILL.md` — regenerate (frontmatter + verbatim ruleset)
- [ ] `chat/style.md` — re-derive if a PROSE rule changed
- [ ] `chat/profile.md` — re-derive if a core rule changed; keep ≤ 1,500 chars
- [ ] `cowork/claude-md-snippet.md` — re-derive if a core rule changed
- [ ] `sh test/test.sh` — budget guards + canary tokens must pass
