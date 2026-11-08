# Tonic

Level up your life. Tonic is an iOS app that turns your habits into a game: pick the
behaviors you care about, rank them, log your day, and earn XP, streaks, personal
records and ranks as you improve.

Tonic is personal and private. There are no accounts and no servers, and all data stays on your phone.

> **Status:** early development. Onboarding, daily check-ins, the score dashboard,
> celebrations, weekly quests, achievements, character stats, weekly recaps, reminders and a
> home-screen widget all work. Apple Health sync is next.

## How scoring works

Every behavior is one of four types, and each day it gets a quality from 0 to 1:

| Type | Example | How it's scored |
|---|---|---|
| Check | Meditate | Done = 1, not done = 0 |
| Avoid | Alcohol | Clean = 1, slipped = **−2** (slips cost double) |
| Target | Sleep 8h, screen time ≤ 3h | Partial credit toward the target |
| Volume | Study minutes | Credit up to a reference amount, bonus XP beyond it, personal records |

- **Daily Score (−100 to 100):** your behaviors weighted by priority. Rank #1 weighs 2× the last one, and your 2–3 Focus habits get an extra 1.5×. Weights always add up to 1, so a perfect day is 100.
- **XP:** your Daily Score plus compounding bonuses: **+5% per streak day** (up to +100%), **×1.25 Perfect Focus Day**, **combo week** (5 days at 70+), **comeback** and **personal record** bonuses. A slip on any habit cancels every streak bonus for that day, so slipping always costs real XP.
- **Levels:** XP to the next level = `220 × level^0.75`, so each level takes a little longer. **Levels never drop**: a slip can drain XP back to the start of your level, but no further.
- **Streak shields:** earn one every 7-day streak (hold up to 2). A shield covers a missed day automatically. Slips are never shielded.
- **Weekly quests:** three new challenges every Monday, picked from your own habits, each worth bonus XP.
- **Achievements:** 20 badges for milestones like a 30-day streak, a clean month or reaching level 25.
- **Ranks:** every 10 levels, in your choice of theme:

| Levels | Plant | Frat |
|---|---|---|
| 1–9 | Seedling | Potential New Member |
| 10–19 | Sprout | Pledge |
| 20–29 | Sapling | Pledge Class President |
| 30–39 | Bloom | Brother |
| 40–49 | Grove | Philanthropy Chair |
| 50–59 | Evergreen | Social Chair |
| 60–69 | Redwood | Vice President |
| 70+ | Ancient | President |

All of these numbers live in [`Tuning.swift`](TonicKit/Sources/TonicKit/Engine/Tuning.swift).

## Project layout

```
Tonic.xcodeproj      Xcode project for the iOS app
Tonic/               SwiftUI app
  App/               App entry point and settings keys
  Models/            On-device storage (SwiftData)
  Features/          Onboarding, Today (check-ins, celebrations), Progress (charts, records), Settings (manage habits)
  DesignSystem/      Shared views and styling
TonicWidget/         Home-screen and Lock Screen widget
Config/              Entitlements (App Group shared with the widget)
TonicKit/            Swift package: scoring engine, models, presets (no UI)
  Sources/TonicKit/
    Model/           Day, Behavior, LogEntry
    Engine/          Tuning, Weighting, Quality, SleepScoring, LevelSystem, RankTheme, ProgressionEngine
    Presets/         Built-in behavior library
  Tests/             Unit tests + a 1-year pacing simulation
scripts/             Helper scripts
```

## Running the app

Open `Tonic.xcodeproj` in Xcode 27 or later, pick an iPhone simulator, and press Run.
iOS 18 or later is required.

## Running the tests

```bash
./scripts/test-engine.sh
```

## License

MIT. See [LICENSE](LICENSE).
