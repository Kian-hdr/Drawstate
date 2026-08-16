# Drawstate app icon

Drawstate uses Apple's Icon Composer format for the production macOS app icon.

## Design

The energy-flow gauge, battery, and lightning bolt form one transparent foreground layer. Icon Composer applies the system mask, background, lighting, depth, and Liquid Glass treatment. The result supports:

- Default appearance for light system contexts
- Dark appearance for dark system contexts
- Monochrome, clear, and tinted system treatments
- Automatic macOS corner masking and scale behavior

The icon intentionally uses an opaque system background inside the icon shape and transparency outside the mask and around foreground artwork. This follows Apple's guidance: foreground layers may be transparent, while the app icon background should remain opaque.

## Source files

- `Resources/Drawstate.icon`: production Icon Composer package
- `Resources/AppIconAppearances/AppIcon-Foreground-1024.png`: true-alpha foreground source
- `Resources/AppIconAppearances/AppIcon-Light-1024.png`: light reference and fallback artwork
- `Resources/AppIconAppearances/AppIcon-Dark-1024.png`: dark reference artwork
- `Resources/AppIcon-master.png`: repository and documentation preview
- `Resources/AppIcon.iconset`: legacy ICNS source sizes
- `Scripts/generate-app-icons.swift`: deterministic source-art generator

## Regenerating and validating

```sh
./Scripts/generate-app-icons.swift
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
./Scripts/package-app.sh release
```

Open `Resources/Drawstate.icon` in the Icon Composer bundled with Xcode 26 or later before committing an icon change. Verify Default, Dark, and Mono appearances at 1024 pt and at small preview sizes. The package script compiles `Assets.car` and `Drawstate.icns` when the installed toolchain supports Icon Composer; older Xcode builds use the checked-in ICNS fallback.

Do not replace transparent pixels with a checkerboard image, pre-render the outer macOS shape into the Icon Composer foreground, or add baked shadows and gloss that compete with system rendering.

## Apple references

- [App icons, Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer)
- [Icon Composer](https://developer.apple.com/icon-composer/)
