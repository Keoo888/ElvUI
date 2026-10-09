[![Game Version](https://img.shields.io/badge/wow-3.3.5-blue.svg)](https://github.com/ElvUI-WotLK)

# ElvUI for WoW 3.3.5a (Warmane)

A build of [ElvUI-WotLK](https://github.com/ElvUI-WotLK/ElvUI) — the Wrath of the Lich King
backport of ElvUI by Elv and Bunny — adjusted for the private-server client. The base is upstream
`master` at `58ea24f7`, ten commits past the 6.09 release the addon is versioned as; `ElvUI_OptionsUI`
is exactly as upstream shipped it, so every option you already know is where you expect it.

## What is different here

Two things: correctness on this specific client, and the amount of work the interface does per frame.

Some code paths in ElvUI assume an API that a 3.3.5a client does not have, so they either throw an
error or silently never run. This build fixes those: the offline/connected state of group frames is
driven by the roster events the client actually delivers instead of `UNIT_CONNECTION`, the profile
import and distribution dialogs no longer call a retail-only edit-box method, nameplate aura stacks
track the combat-log sub-event this client emits, skin helpers stop aborting a whole skin pass when a
named frame does not exist, and the experience bar no longer feeds a nil maximum into the widget at
load.

The rest is the runtime audit. Health bars, aura icons, cooldown swipes, nameplate glows, group unit
tokens and combat-log lookups were being rewritten or re-resolved many times per second with the same
values, and unit events were filtered only after a client call per registered frame. Each of those
places now asks whether anything actually changed before touching the widget, and each one carries an
inline `--! audit perf` comment saying what it was doing, how often it ran, and why the new form is
equivalent — so a future change can be checked against the reason rather than against guesswork. A few
upstream defects were found along the way and fixed, including two error messages that could never
print and a nameplate channel bar that displayed the wrong number where the cast delay belongs.

Nothing here changes how the addon looks or is configured by default. Layout, movers, the installer
and the settings tree are upstream's.

## Install

Put the `ElvUI` and `ElvUI_OptionsUI` folders into `Interface/AddOns/` of your 3.3.5a client and
restart. Both addons must be enabled. `/elvui` or `/ec` opens the options window — both are registered
unconditionally and route to the same handler. To see what this build was about: `/console scriptProfile 1`,
then `/cpuimpact` for ElvUI's average cost per frame and `/cpuusage UnitFrames` for the costliest
functions inside one module. If you are coming from another ElvUI build, re-log once after installing
so profiles load cleanly.

## Credits

ElvUI and ElvUI_OptionsUI are the work of Elv and Bunny, and the 3.3.5a backport is the work of the
ElvUI-WotLK team; oUF is p3lim's, and the bundled libraries keep their own authors' notices. This
build only changes what is described above — please report upstream-inherited problems to
ElvUI-WotLK, and anything specific to this build to me.

Made by Keoo for Warmane. Feedback and bug reports: [discord.gg/sKpJbUrsvR](https://discord.gg/sKpJbUrsvR)
