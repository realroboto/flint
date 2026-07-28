#!/usr/bin/env python3
"""Remove paragraph hard wraps from a paste-in derivado.

The ruleset (flint.md) is hard-wrapped for the hook payload and for reading in
a repo. The Chat/Cowork artifacts are pasted into GUI textareas that keep the
newlines verbatim, so the wrap survives into the model's context as ragged
lines. This joins wrapped paragraph lines back into one line per paragraph and
leaves everything else alone: frontmatter, HTML comments, headings, fenced
code, lists, tables, quotes, and the Not:/Yes: example pairs.

Usage: python3 tools/unwrap.py FILE [FILE ...]   (rewrites in place)
"""
import re
import sys

# A line that must start its own output line, never appended to the previous.
BREAK = re.compile(r"^(#{1,6} |[-*+] |\d+\. |> |\||```|---\s*$|"
                   r"(Not|Yes|Pattern|Example)[:\s—-])")


def unwrap(text):
    out = []
    fence = False
    frontmatter = text.startswith("---\n")
    comment = False
    for line in text.split("\n"):
        stripped = line.strip()
        if frontmatter:
            out.append(line)
            if len(out) > 1 and stripped == "---":
                frontmatter = False
            continue
        if stripped.startswith("```"):
            fence = not fence
            out.append(line)
            continue
        if "<!--" in line:
            comment = True
        joinable = (not fence and not comment and stripped
                    and not BREAK.match(stripped)
                    and out and out[-1].strip()
                    and not out[-1].strip().startswith("```"))
        if "-->" in line:
            comment = False
        if joinable:
            out[-1] = out[-1].rstrip() + " " + stripped
        else:
            out.append(line)
    return "\n".join(out)


for path in sys.argv[1:]:
    with open(path) as fh:
        src = fh.read()
    with open(path, "w") as fh:
        fh.write(unwrap(src))
