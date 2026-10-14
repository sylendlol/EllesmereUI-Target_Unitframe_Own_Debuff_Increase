# EllesmereUI – Target Own Debuffs

A small companion add-on for **EllesmereUI Unit Frames** (WoW Forever beta, Interface 16001, EllesmereUI 9.4).

Your own debuffs on the **target frame** get a larger icon. Every other debuff — other players', NPCs', boss and zone effects — keeps showing at the normal *Debuff Size*, so nothing disappears from the frame.

No EllesmereUI file is modified.

## Features

- **Enlarge Own Debuffs** – debuffs cast by you or your pet use their own, larger icon size.
- **Own Debuff Size** – 12–64 px.
- **Own Debuffs On Separate Row** – your debuffs fill their own row nearest the frame; the others start on a new row (Show All filter only).
- **Scale Text With Size** – the timer and stack text grow with the icon.
- **Own Debuff Max** – cap for your debuffs (0 = same as Debuff Max). Your debuffs and the others are counted separately.
- Border, timer font, colors, dispel ring and every other look follow the target's normal debuff settings.
- Settings are stored in the EllesmereUI Unit Frames profile (they follow profile switches).

## Where

*Unit Frames > Main Frames > Target*, section **OWN DEBUFFS** (right after BUFFS AND DEBUFFS).

## Supported Target Debuff Filter modes

| Mode | Behavior |
|---|---|
| Show All | Your debuffs large, everything else normal size. |
| Own Only | Only your debuffs, shown large. |
| Important or Own | Your debuffs large, important debuffs from others normal size. |
| Important / Important Own / Only Tracked Auras | Not changed (the add-on stays inactive). |

## Notes

- "Own" uses the game's own filter: debuffs from **you or your pet**.
- The options preview frame does not show the larger icons; check on a real target.
- `/euitod` prints a status line (mode, active, size) for troubleshooting.
