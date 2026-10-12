"""Pack every skill in .claude/skills into one uploadable skill for regular Claude (claude.ai).

    python tools/make_skill_bundle.py [output.zip]

The bundle is one skill named roblox-blender-pro. Its SKILL.md is an index; each original
skill becomes a folder whose SKILL.md is renamed GUIDE.md (so only the index is detected as a skill).
"""

import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS = ROOT / ".claude" / "skills"
BUNDLE = "roblox-blender-pro"


def frontmatter(text):
    match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    fields = {}
    if match:
        for line in match.group(1).splitlines():
            key, _, value = line.partition(":")
            fields[key.strip()] = value.strip()
    return fields


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / f"{BUNDLE}.zip"
    skills = sorted(p for p in SKILLS.iterdir() if (p / "SKILL.md").is_file())

    rows = []
    for skill in skills:
        desc = frontmatter((skill / "SKILL.md").read_text(encoding="utf-8")).get("description", "")
        rows.append(f"| `{skill.name}/` | {desc} |")

    index = f"""---
name: {BUNDLE}
description: Pro toolkit for making Roblox games and Blender models/animations - VFX, abilities and movesets, weapon wheels, lighting, character animation, modelling and more. Use for ANY Roblox Studio, Luau scripting, Roblox game, Blender modelling, Blender animation or game VFX request.
---

# Roblox + Blender pro toolkit

This skill is a folder of guides. Pick the guide(s) that match the request from the table, read that
folder's `GUIDE.md` first, then use the scripts it points to. Paths inside a guide (like
`scripts/BurstVFX.lua`) are relative to that guide's folder.

| Folder | Use it for |
|---|---|
{chr(10).join(rows)}

If nothing matches exactly, still read the closest guide: they share the same style rules.

## Working style

- The user is a non-technical Roblox creator. Build things straight away with sensible defaults
  (cartoony simulator style, works on phone and PC). Keep replies short, without jargon.
- Here in regular Claude you can't reach Roblox Studio or Blender directly. Give the finished script(s)
  as files, then plain steps: which object to create (Script, LocalScript or ModuleScript), its exact name, where it
  goes in Explorer, and "paste this in". For Blender: Scripting tab → New → paste → Run Script.
- In Claude Code with the ROBLOX-GAME folder (the "Roblox Claude" shortcut) the same guides apply, but
  Claude builds directly in Studio/Blender instead.
"""

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(f"{BUNDLE}/SKILL.md", index)
        for skill in skills:
            for path in sorted(skill.rglob("*")):
                if path.is_dir() or "__pycache__" in path.parts:
                    continue
                rel = path.relative_to(skill)
                name = "GUIDE.md" if rel.as_posix() == "SKILL.md" else rel.as_posix()
                z.write(path, f"{BUNDLE}/{skill.name}/{name}")
    print(f"Wrote {out} with {len(skills)} guides: {', '.join(s.name for s in skills)}")


if __name__ == "__main__":
    main()
