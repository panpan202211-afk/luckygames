# Lucky Games

A colorful match-3 game built with Flutter:

- 3 difficulty maps with 10 levels each: Easy, Hard, and Hell
- 5 unique candy designs
- Animated swaps, matches, cascades, and combos
- Moves, 10x target scores, stars, and persistent level progression
- Distinct map mechanics: power combos, breakable ice, and a star bomb timer

## Run locally

```bash
flutter run
```

Flutter is installed at `D:\SDK\flutter` and added to the user PATH. Open a new terminal before using the `flutter` command.

On Windows, double-click `run_web.bat` to preview the game in Chrome. Building the iOS version requires macOS with Xcode.

## Airbridge attribution

The official Airbridge Flutter SDK is configured from the root-level `airbridge.json` file. On iOS 14 and later, the app requests App Tracking Transparency permission and does not initialize or start Airbridge unless the user grants permission. On older iOS versions and Android, platform-specific startup behavior applies.

Set the credentials from Airbridge Dashboard **Settings > Tokens**:

```json
{
  "appName": "YOUR_AIRBRIDGE_APP_NAME",
  "appToken": "YOUR_AIRBRIDGE_APP_SDK_TOKEN",
  "autoStartTrackingEnabled": false
}
```

Use the **App SDK Token**, not an Airbridge API token. Placeholder or empty credentials safely disable attribution until configured.

Gighub

git add .
git commit -m "1.0.9"
git push
