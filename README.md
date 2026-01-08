<h1><img src="https://raw.github.com/citadelgrad/ShiftIt/master/artwork/ShiftIt.png" width="72" height="72" valign="middle"/>ShiftIt</h1>

*Managing window size and position in macOS*

## About

ShiftIt is an application for macOS that allows you to quickly manipulate window position and size using keyboard shortcuts. It is a full featured window organizer for macOS.

This is a modernized fork of the original [ShiftIt](https://github.com/fikovnik/ShiftIt) by Filip Krikava, updated with:
- **Sparkle 2.8** for secure auto-updates (EdDSA signing)
- **Swift 6** modernization
- **macOS 14.6+ (Sonoma)** support
- **Ultrawide monitor support** - divide screen by 3 or 6
- Modern keyboard shortcut recording

License: [GNU General Public License v3](http://www.gnu.org/licenses/gpl.html)

## Download

A binary build for macOS 14.6+ is available in [releases](https://github.com/citadelgrad/ShiftIt/releases).

## Requirements

* **macOS 14.6 (Sonoma) or later**
* Apple Silicon or Intel Mac

## Installation

1. Download the latest release from the [releases page](https://github.com/citadelgrad/ShiftIt/releases)
2. Unzip and drag ShiftIt.app to your Applications folder
3. On first launch, right-click the app and select "Open" to bypass Gatekeeper
4. Grant Accessibility permissions when prompted (required for window management)

## User Guide

ShiftIt installs itself in the menu bar (optionally it can be completely hidden). It provides a set of actions that manipulate window positions and sizes.

![Screenshot Menu](https://raw.github.com/citadelgrad/ShiftIt/master/docs/schreenshot-menu.png)

### Available Actions

| Action | Default Shortcut | Description |
|--------|------------------|-------------|
| Left | ⌃⌥⌘ ← | Move window to left half |
| Right | ⌃⌥⌘ → | Move window to right half |
| Top | ⌃⌥⌘ ↑ | Move window to top half |
| Bottom | ⌃⌥⌘ ↓ | Move window to bottom half |
| Top Left | ⌃⌥⌘ 1 | Move window to top-left quarter |
| Top Right | ⌃⌥⌘ 2 | Move window to top-right quarter |
| Bottom Left | ⌃⌥⌘ 3 | Move window to bottom-left quarter |
| Bottom Right | ⌃⌥⌘ 4 | Move window to bottom-right quarter |
| Maximize | ⌃⌥⌘ M | Maximize window |
| Center | ⌃⌥⌘ C | Center window |
| Full Screen | ⌃⌥⌘ F | Toggle full screen |

### Ultrawide Monitor Support

ShiftIt includes special actions for ultrawide monitors:
- **Divide by 3** - Split screen into thirds
- **Divide by 6** - Split screen into sixths

## FAQ

##### How do I turn on/off window size cycling with multiple hotkey presses?

If this feature is on, snapping to the left side of the screen (and top, bottom, and right sides) will resize the window to half of the screen. If the window is then snapped to the same side of the screen, it will resize to one third of the screen, and then two thirds of the screen.

To turn the feature on:
```sh
defaults write org.shiftitapp.ShiftIt multipleActionsCycleWindowSizes YES
```

To turn it off:
```sh
defaults write org.shiftitapp.ShiftIt multipleActionsCycleWindowSizes NO
```

##### I disabled the "Show Icon in Menu Bar" in the preferences, how can I get it back?

Launch the application again. It will open the preference dialog.

##### I pressed a shortcut, but nothing happened, why?

Make sure ShiftIt has Accessibility permissions. Go to **System Settings** → **Privacy & Security** → **Accessibility** and ensure ShiftIt is enabled.

##### How to repair Accessibility API permissions?

Go to **System Settings** → **Privacy & Security** → **Accessibility**, find ShiftIt in the list, and toggle it off then on again. If ShiftIt is not in the list, click the + button and add it from your Applications folder.

## Development

### Local Build

To build ShiftIt locally, clone the repository and run:

```sh
cd ShiftIt
xcodebuild -target ShiftIt -configuration Release
```

The built app will be at `ShiftIt/build/Release/ShiftIt.app`.

### Making a Release

A release script is provided that handles building, signing, and updating the appcast:

```sh
./release/build-release.sh
```

This script will:
1. Build ShiftIt in Release configuration
2. Create a zip archive
3. Sign with EdDSA (reads key from macOS Keychain)
4. Update `release/appcast.xml` with the signature and file size

#### Prerequisites

- EdDSA signing key in macOS Keychain (generated with Sparkle's `generate_keys` tool)
- Xcode command line tools

#### Environment Variables (for fabfile.py)

If using the legacy fabric-based release system:

```sh
export SHIFTIT_GITHUB_USER=citadelgrad
export SHIFTIT_GITHUB_REPO=ShiftIt
export SHIFTIT_GITHUB_TOKEN=~/.shiftit/github.token  # your personal access token
```

### Project Structure

```
ShiftIt/
├── ShiftIt/                 # Main application source
│   ├── ShiftIt.xcodeproj   # Xcode project
│   ├── bin/                # Sparkle signing tools
│   └── Sparkle.framework/  # Auto-update framework
├── release/                # Release assets
│   ├── appcast.xml        # Sparkle update feed
│   ├── release-notes-*.html
│   └── build-release.sh   # Release build script
└── artwork/               # Icons and graphics
```

## Credits

- Original ShiftIt by [Aravindkumar Rajendiran](http://code.google.com/p/shiftit/)
- Rewritten by [Filip Krikava](https://github.com/fikovnik)
- Modernized by [citadelgrad](https://github.com/citadelgrad)

## Alternatives

If you prefer a more customizable solution, consider [Hammerspoon](http://hammerspoon.org) with the [ShiftIt Spoon](https://github.com/peterklijn/hammerspoon-shiftit).
