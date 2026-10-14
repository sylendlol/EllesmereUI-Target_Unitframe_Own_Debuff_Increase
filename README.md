# EllesmereUI-Target_Unitframe_Own_Debuff_Increase
<img width="1312" height="955" alt="{CC9B68A2-F69B-4BEF-B112-94D4F61895CB}" src="https://github.com/user-attachments/assets/e61b7af7-d4da-4eb0-924d-62bedc7bd620" />

Everything else stays visible. Debuffs from other players, NPCs and bosses, and zone or environment effects, keep showing at the normal Debuff Size. Nothing is hidden and nothing is shown twice.

No EllesmereUI file is modified. The add-on hooks into EllesmereUI from the outside, so you can install or remove it at any time.

Features
Larger icons for your debuffs. Debuffs cast by you or your pet get their own icon size on the target frame.
All other debuffs stay. Other players' debuffs, NPC and boss debuffs, and zone effects keep the normal size.
Separate row (optional). Your debuffs fill their own row nearest the frame, and the rest start on a new row.
Scaled text. The timer and stack text grow along with the larger icon.
Own cap. You can set a separate maximum for your debuffs.
Same look as EllesmereUI. The border, fonts, colors, dispel-type ring and timer settings follow the target's normal debuff settings. Only the size changes.
Follows your profiles. Settings are stored in the EllesmereUI Unit Frames profile, so they switch with your profiles.
Requirements
	
Game	WoW Forever beta (Interface 16001); the TOC also lists the 12.x retail interfaces
EllesmereUI	9.4 or newer (tested with 9.4 and 9.5.4)
Required modules	EllesmereUI, EllesmereUIUnitFrames

The add-on depends on EllesmereUI's 12.1 aura containers (AuraKit). It does nothing on clients where EllesmereUI's client gate blocks those modules.

Installation
Download this repository (green Code button → Download ZIP), or grab a release.
Extract the folder into your AddOns directory and make sure the folder is named exactly EllesmereUI_TargetOwnDebuffs:
   World of Warcraft\_classic_beta_\Interface\AddOns\EllesmereUI_TargetOwnDebuffs\
       EllesmereUI_TargetOwnDebuffs.toc
       TargetOwnDebuffs.lua
       TargetOwnDebuffs_Options.lua
Restart the game or type /reload.
Settings

Open EllesmereUI → Unit Frames → Main Frames, select Target, and scroll to the OWN DEBUFFS section (right after Buffs and Debuffs).

Option	Default	Description
Enlarge Own Debuffs	On	Turns the feature on or off.
Own Debuff Size	30	Icon size of your debuffs (12–64 px).
Own Debuffs On Separate Row	On	Your debuffs get their own row(s); the rest start on a new row. Show All filter only.
Scale Text With Size	On	Timer and stack text scale with the icon.
Own Debuff Max	0	Maximum number of your debuffs. 0 = same as Debuff Max. Your debuffs and the others are counted separately.
Supported Target Debuff Filter modes
Target Debuff Filter	Result
Show All	Your debuffs large, every other debuff at normal size.
Own Only	Only your debuffs, shown large.
Important or Own	Your debuffs large, important debuffs from others at normal size.
Important / Important Own / Only Tracked Auras	Not changed (the add-on stays inactive).
Slash command
Command	Description
/euitod	Prints a status line (filter mode, active, size, separate row) for troubleshooting.
How it works

EllesmereUI draws the target's debuffs in one aura container, split into filter groups. This add-on:

Adds a group for your debuffs. It adds one extra group with the game's HARMFUL|PLAYER filter (you or your pet) and a larger copy of EllesmereUI's debuff style. The group is laid out first.
Narrows the Show All group. In Show All mode, EllesmereUI's catch-all group is narrowed to HARMFUL|!PLAYER. Every debuff matches exactly one of the two groups, so the full list is kept.
Takes over in own modes. In Own Only and Important or Own modes, EllesmereUI's own-debuff group is switched off, and the larger group takes over with the same filter.
Copies the exclusions. It copies EllesmereUI's hidden-debuff rules (Exhaustion/Sated, always-hidden spells, Tracked Auras exclusions), so hidden debuffs stay hidden.
Stays in sync. It re-applies itself after every EllesmereUI aura reload (option changes, profile switches, target changes). When you turn it off, it restores EllesmereUI's original group settings.
Known limitations
Pet debuffs count as yours. The game's filter treats your pet's debuffs as yours, so they are enlarged as well.
No options preview. The preview frame in the options does not show the larger icons; check on a real target.
Early wrapping. EllesmereUI computes the row width from Debuff Size, so large icons wrap to a new row sooner.
Mixed heights. With Separate Row turned off, large and normal icons share a row.
Tracked Auras in own modes. In Own Only / Important or Own, Tracked Auras entries marked as "mine" keep the normal size.
EllesmereUI updates. The add-on relies on EllesmereUI internals. A future EllesmereUI update may need a matching update here. If it stops working, /euitod shows whether the target debuff container was found.
