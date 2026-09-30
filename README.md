<div align="center">
    <img src="Glacier/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width=200 height=200>
    <h1>Glacier</h1>
</div>

Glacier is a menu bar manager for macOS. It hides and shows menu bar items, lets you arrange them, and can display hidden items in a separate bar.

> [!NOTE]
> **Disclaimer: this is a fork.**
> Glacier is an independent fork of [Ice](https://github.com/jordanbaird/Ice) by Jordan Baird and is not affiliated with or endorsed by the original author.
> It adds support for macOS 27, fixes for several stability issues and its own name and bundle identifier (`de.nlmyr.glacier`).
> Settings, hotkeys and permissions are not shared with Ice, so they have to be set up again.
> Automatic updates are disabled, builds are distributed manually.
> The software is provided as is, without warranty of any kind. Please do not report problems with Glacier to the original project.

## Requirements

- macOS 27
- Xcode 27 to build

## Build

Open `Glacier.xcodeproj` in Xcode and run the `Glacier` scheme, or build from the command line:

```sh
xcodebuild -project Glacier.xcodeproj -scheme Glacier -configuration Debug build
```

`Scripts/install.sh` builds a signed release and installs it into `~/Applications`.

The macOS 27 logic can be unit tested with:

```sh
swift test
```

## Features

- Hide menu bar items in a hidden and an always-hidden section
- Show hidden items on hover, click, scroll or swipe, or with hotkeys
- Automatically rehide items
- Drag and drop interface to arrange individual items
- Show hidden items in a separate bar (for example on MacBooks with a notch)
- Search menu bar items
- Menu bar appearance: tint, shadow, border and custom shapes
- Menu bar item spacing
- Launch at login

## Credits

Glacier is based on [Ice](https://github.com/jordanbaird/Ice) by Jordan Baird, licensed under the GPL-3.0.

Copyright (C) 2025 Jordan Baird

Copyright (C) 2026 Noel Mayr

## License

Glacier is available under the [GPL-3.0 license](LICENSE).
