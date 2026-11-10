# Lifting Tracker

An iPhone app for logging gym sessions with a few taps per set: every set is
pre-filled with what you did last time. Native SwiftUI, data stored on the
phone with SwiftData, iOS 17 or later. No account and no server.

## Run it

You need a Mac with Xcode 16 or later.

1. Open `LiftingTracker.xcodeproj`.
2. Pick an iPhone simulator and press Run.
3. To run on your own phone, select the LiftingTracker target, open
   Signing & Capabilities, choose your team, and change the bundle identifier
   from `com.example.LiftingTracker` to one of your own.

If Xcode will not open the project file, regenerate it: `brew install xcodegen`,
then run `xcodegen` in this folder (it reads `project.yml`).

## Fonts

The designs use Barlow Condensed for headings and numbers. The font files are
not in the repo. Download Barlow Condensed from Google Fonts and drop
`BarlowCondensed-SemiBold.ttf` and `BarlowCondensed-Bold.ttf` anywhere inside
the `LiftingTracker/` folder; the app picks them up on the next build. Without
them it uses the system condensed font, which is close.

## Tests

Product > Test in Xcode runs both:

- `LiftingTrackerTests`: unit tests for the defaulting rule and weight parsing.
- `LiftingTrackerUITests`: one flow that starts a workout, checks a set and finishes.

### Without a Mac

`.github/workflows/ios.yml` builds the app and runs both test targets on a
GitHub-hosted macOS runner. Push this folder to a GitHub repository and the
workflow runs on every push; it can also be started by hand from the Actions
tab. The full compiler output is attached to each run as the `xcode-logs`
artifact. This checks that the app compiles and the tests pass; it does not
put the app on a phone.

## Layout

```
LiftingTracker/
  LiftingTrackerApp.swift   app entry, data store
  RootView.swift            top navigation bar and the three pages
  Models/                   the five entities, the defaulting rule, session logic
  Shared/                   colours, fonts, buttons and number fields
  Workouts/                 workouts list, editor, exercise picker
  Exercises/                exercise library, detail and history chart
  LiveWorkout/              start a session, log sets, finish
LiftingTrackerTests/
LiftingTrackerUITests/
```

The defaulting rule lives in `LiftingTracker/Models/DefaultSets.swift`.
