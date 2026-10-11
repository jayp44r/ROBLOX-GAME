# Toca World

A cozy Toca Boca style bedroom with a character creator.

**Install:** open your place in Roblox Studio, then in Roblox Claude type `/toca`.
(No Claude? Open `InstallTocaWorld.lua`, copy all of it, paste it into Studio's **Command Bar** and press Enter.)

Then press **Play**.

## What's inside

- **Character creator**: tap ✨ (top-left) or walk up to the vanity mirror. Pick skin, hair, hair colour, eyes, top, bottom and hats, or tap ⭐ Styles for Soft Indie, Y2K Grunge, Pastel Gamer, Preppy, Cottagecore and Alien Pop. 🎲 shuffles, ↺ undoes. Looks save between visits once the game is published.
- **Bedroom**: pink curtains, window to the garden, bed with a teddy and flower pillow, desk with laptop and frog plush, bookshelf, vanity, watermelon pouf, bean bag, fairy lights and a paper lantern.
- **Secrets**:
  - A Crumpet hides behind the wobbly book on the bookshelf. Finding it unlocks the **Crumpet Pal** hat.
  - The light switch on the left wall changes the mood: Sunny Morning, Golden Hour, Dreamy Night, Disco Party.
  - The bed is a trampoline.
  - The shuffle button sometimes gives a super rare look.

## Where things go in Explorer

- `Workspace > TocaWorld` (the bedroom and garden)
- `ReplicatedStorage > TocaOptions` (all the creator choices) and `TocaRemotes`
- `ServerScriptService > TocaServer`
- `StarterPlayer > StarterPlayerScripts > TocaCreatorClient` (the creator screen)

The installer also turns off other spawn points and sets **Load Character Appearance** off so everyone starts plain and makes their own look.

To change the scripts, edit `src/` and run `python3 build.py`.
