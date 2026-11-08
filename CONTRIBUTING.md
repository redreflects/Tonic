# Contributing to Tonic

Thanks for helping out! Tonic is a small, private, on-device habit game. Contributions of
all sizes are welcome: bug fixes, new preset habits, new rank themes, accessibility
improvements, and tuning the scoring.

## Getting set up

You need a Mac with **Xcode 27 or later**.

1. Clone the repo and open `Tonic.xcodeproj`.
2. Pick an iPhone simulator and press **Run**. That's it for the simulator.

### Running on your own iPhone

Signing needs your own Apple developer team (a free account works) and an App Group
ID you control. Both live in one git-ignored file so they never end up in a commit:

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Then edit `Config/Local.xcconfig`:

- `DEVELOPMENT_TEAM`: your team ID (Xcode → Settings → Accounts).
- `TONIC_BUNDLE_PREFIX`: a reverse-domain prefix you own, e.g. `com.yourname`.
  The app, widget and App Group IDs are all built from it.

Please don't set the team in Xcode's Signing & Capabilities tab; that writes your team
ID into `project.pbxproj`.

## How the code is organized

| Folder | What's in it |
|---|---|
| `TonicKit/` | The scoring engine as a Swift package with no UI: habit types, weighting, XP, streaks, levels, ranks, quests, achievements, Apple Health mapping. **Most game logic lives here and is unit-tested.** |
| `Tonic/` | The SwiftUI app: onboarding, Today, Progress, Settings, Health sync. Views stay thin and call into TonicKit. |
| `TonicWidget/` | The home-screen and Lock Screen widget. It reads a small snapshot the app saves to the shared App Group. |
| `Config/` | Entitlements, Info.plist pieces, and the shared `Base.xcconfig`. |
| `scripts/` | `test-engine.sh` runs the engine tests; `make-icon.swift` redraws the app icon. |

The engine works by **replaying history**: given your habits and every log, it walks day
by day and computes scores, XP, streaks and events. Editing an old log just means
replaying again, so there's no cached state to get out of sync.

## Running the tests

```bash
./scripts/test-engine.sh
```

This runs the TonicKit test suite (Swift Testing), including a one-year pacing simulation
that prints how fast a typical user levels up. You can also run the `TonicKit` scheme's
tests in Xcode.

**If you change anything in `TonicKit/Sources/TonicKit/Engine/Tuning.swift`, run the
tests and check the pacing output.** The targets are: level 10 in about a month, level 30
in about 6–9 months for a consistent user.

## Common contributions

- **Add a preset habit:** add an entry in `TonicKit/Sources/TonicKit/Presets/PresetLibrary.swift`.
  IDs must be unique and never change once released (logs are stored by ID).
- **Add a rank theme:** add a `RankTheme` in `TonicKit/Sources/TonicKit/Engine/RankTheme.swift`
  with 8 names and 8 SF Symbols, include it in `RankTheme.all`, and give it an icon in
  `Tonic/DesignSystem/BehaviorDisplay.swift` (`RankTheme.symbol`).
- **Add an achievement or quest type:** see `Achievements.swift` and `Quests.swift` in the
  engine. Add a test alongside.
- **Support another Apple Health type:** extend `HealthImport` in TonicKit (with a test),
  then read it in `Tonic/Health/HealthSync.swift`.

## Guidelines

- Keep user data on the device. Tonic has no server, analytics or accounts, and we'd like
  to keep it that way.
- New game logic belongs in TonicKit with tests, not in views.
- Support Dynamic Type and VoiceOver: give icon-only buttons an `accessibilityLabel` that
  names the habit they act on, and check your screen at the largest text size.
- Write comments for the next reader: short and plain.

## Pull requests

1. Fork and create a branch.
2. Make your change, run `./scripts/test-engine.sh`, and try it in the simulator.
3. Open a PR describing what changed and why, with a screenshot for UI changes.

By contributing, you agree your work is released under the project's [MIT License](LICENSE).
