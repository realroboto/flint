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

1. **Style** (prose layer, all chats): Chat → style picker → Create custom
   style → paste the block from [`chat/style.md`](chat/style.md).
2. **Profile instructions** (global): Settings → Profile → paste
   [`chat/profile.md`](chat/profile.md) (fits the 1,500-char budget).
3. **Projects** (dev work): Project → instructions → paste
   [`chat/project-instructions.md`](chat/project-instructions.md) — the
   ruleset verbatim (fits the ~8,000-char budget).

## Cowork

1. **Skill**: symlink [`cowork/`](cowork/) into the shared store as
   `~/.claude/skills/flint` (directory containing `SKILL.md`):

   ```sh
   ln -s "$(pwd)/desktop/cowork" ~/.claude/skills/flint
   ```

2. **CLAUDE.md channel**: run the marker test in
   [`cowork/claude-md-snippet.md`](cowork/claude-md-snippet.md); paste the
   snippet only if the test passes.

## Re-sync checklist (every ruleset release)

Derivados do not update themselves. After ANY edit to `flint.md`:

- [ ] `chat/project-instructions.md` — regenerate (header + verbatim ruleset)
- [ ] `cowork/SKILL.md` — regenerate (frontmatter + verbatim ruleset)
- [ ] `chat/style.md` — re-derive if a PROSE rule changed
- [ ] `chat/profile.md` — re-derive if a core rule changed; keep ≤ 1,500 chars
- [ ] `cowork/claude-md-snippet.md` — re-derive if a core rule changed
- [ ] `sh test/test.sh` — budget guards + canary tokens must pass
