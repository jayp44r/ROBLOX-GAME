"""Joins the scripts in src/ into one InstallTocaWorld.lua that can be run in Roblox Studio."""
from pathlib import Path

here = Path(__file__).parent
src = here / "src"
parts = {
    "TocaOptions": "TocaOptions.lua",
    "TocaServer": "TocaServer.server.lua",
    "TocaCreatorClient": "TocaCreatorClient.client.lua",
}

out = [
    "-- Toca World installer (made by toca-world/build.py, edit the files in src/ instead).",
    "-- Run it once in Roblox Studio (Claude's execute_luau, or paste into the Command Bar).",
    "local SOURCES = {}",
]
for name, file in parts.items():
    text = (src / file).read_text()
    assert "]===]" not in text
    out.append(f"SOURCES.{name} = [===[\n{text}]===]")
out.append((src / "Installer.lua").read_text())
(here / "InstallTocaWorld.lua").write_text("\n".join(out))
print("Wrote InstallTocaWorld.lua")
