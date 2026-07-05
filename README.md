# Vapor Mod Overlay
This is an attempt at a very basic sort of Mod Loader for [Valve's Steam Client](https://steampowered.com/) on GNU/Linux systems that uses OverlayFS

Written in BASH over the course of a couple of hourse using rudimentary knowledge of OverlayFS

This was inspired by a bug in [Portal 2 VR](https://github.com/Gistix/portal2vr) that required the mod to be disabled temporarily to bypass a crash.

And like a completely normal and sane individual with nothing at all wrong with them, I decided that the best and simplest course of action was obviously to write this so I can toggle the mod off/on with an environment variable in the Launch Options. Makes sense, right? ... r-right?

> [!CAUTION]
> - There is **NO** garauntee that this will be perfect or functional. Your files are **YOUR** responsibility. This does not come with a warranty.
> - This is **NOT** intended to and will **NOT** work with non-steam games that you've added to Steam.
> - Good Luck.

## How Does It Work?
When correctly configured...

The script will: 
- Rename your game's folder in your Steam Library to `FOLDER_NAME.vanilla`
- Mount the game directory to it's normal location with specified mod folders overlayed
- Launch the game
- Undo all of the above after the game exits (ideally)

> [!WARNING]
> If the script ever fails to do this, you may need to manually restore your game directory afterwards.
> 
> It shouldn't, in theory, but it's not impossible for this to happen.

## How Do I Use This?
With `vapor-mod-overlay` stored in your `$PATH` go to the steam game you'd like to use it on and do the following in the Launch Options:
```bash
vapor-mod-overlay -- %command%
```

Launch the game, and exit.

Locate the game directory under `$XDG_DATA_HOME/.local/share/vapor-mod-overlay/mods/GAME`

Store the files intended to be placed into the game folder in a folder for your mod.

EXAMPLE:

```
vapor-mod-overlay
|_mods/
  |_620 - Portal 2/
     |_ portal2vr-v0.1.5
```

Then set your launch options like so:
```
vapor-mod-overlay MOD_FOLDER_NAME -- %command%
```

You can specify multiple mod folder names.

## What are Uppers?
When OverlayFS is used, the "Upper" holds changes that get made to underlying files.

When you use one mod, an upper named after the mod folder will be used for your convenience.

When you use more than one mod, a sha256sum of your mod folders will be used, to ensure that the upper applies for your exact mod set and load order.

These store changes made to the game folder at run time, which... some games do to themselves.

You can find these at
```
~/.local/share/vapor-mod-overlay/overlayfs/GAME/upper
```

## FEATURES

### Variables
There are a few environment variables that you can use:

#### `VAPOR_DONT`
If set to `on`, `1`, or `true` then Vapor Mod Overlay will do... *nothing* and just launch the game as if it weren't involved.

This is useful if you'd like to quickly disable all your mods without making big changes to your Launch Options.

#### `VAPOR_LOGGING`
If set to `on`, `1`, or `true`, enables logging to disk.

#### `VAPOR_DEBUG`
Will enable logging Launch Options and Environment Variables for the game if set to any value.

Also requires `VAPOR_LOGGING` to be set to an active value.

#### `VAPOR_UNIVERSAL_UPPER`
If set to `on`, `1`, or `true`...

Will use the "UNIVERSAL" directory for your game as an upper directory for storing changes made to the game directory.

You probably don't want to do this.

### Launch Arguments

If a mod folder contains `VAPOR_LAUNCH_OPTIONS_APPEND.txt` and/or `VAPOR_OPTIONS_PREPEND.txt`, you can place one argument per line to be passed to the game after/before `%command%`

This is useful for mods that require certain launch options.


### Environment Variables

From v0.0.2 onwards, if a mod folder contains `VAPOR_ENVIRONMENT.txt` you can place one variable per line to be added as an environment varabile

Example:
```bash
MANGOHUD=1
PROTON_LOG=1
```

### Mod Info

If a mod folder contains `VAPOR_INFO.txt` it will be displayed below a mod name as a description in `vapor-mod-overlay -l` output.

This is a great idea to make use of if you need to load mods in a specific order or want to document any conflicts, what it does, or where it came from.

## Tested Distros

This has been tested on
- [Nobara Linux](https://nobaraproject.org/)

## Tested Mods

### [Portal 2 VR](https://github.com/Gistix/portal2vr)
Portal 2 VR was actually the inspiration for this utility due to its [Issue #125](https://github.com/Gistix/portal2vr/issues/125) which was unsolved at the time of writing in which a certain segment of the game must be played **without** the mod installed to avoid a game crash

## Why "Vapor Mod Overlay" as a name?
IDK, I guess your mods are like vapor now?

In seriousness, it's a pun on "Steam" because it's intended to be used with Steam, but prefixing *any* variable it used with "STEAM_" seemed like a bad and unwise decision.
