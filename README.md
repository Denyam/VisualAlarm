/**
 * File: README.md
 * Created: 2026-08-25
 */

# VisualAlarm

A cross-platform SwiftUI alarm app. Scheduled alarms play a sound and flicker screen brightness; iPhone additionally blinks the torch.

## Requirements

- iOS 15.5+ / macOS 10.15+
- Xcode 26+

Deployment floors are compile-verified against the current SDK; runtime testing
covers iOS 15.5 through iOS 26.3 and the host macOS. macOS 10.15 itself is not
obtainable for runtime testing — see AGENTS.md.

## Features

- **Per-weekday scheduling** — set alarms for specific days of the week or daily.
- **Brightness flicker** — screen alternates between full and minimum brightness.
- **Torch blink** (iPhone) — rear LED flashes in sync with the flicker.
- **Haptic feedback** (iPhone) — periodic haptic pulses during the effect.
- **System sound loop** — the default alarm sound plays until dismissed.
- **Stop button** — full-screen overlay on iPhone; window on Mac.
- **Resident scheduler** (macOS) — LaunchAgent fires alarms even when the app is closed. Registered automatically via SMAppService.

## Usage

1. Launch the app and tap **+** to add an alarm.
2. Set the time and choose repeating days (or leave empty for daily).
3. Toggle the alarm on/off from the list.
4. On macOS, register the background agent from the app (agent status banner) so alarms fire while the app is closed.
5. When an alarm fires, the visual effect starts immediately; tap **Stop** to dismiss.

## Architecture

| Component | Role |
|-----------|------|
| `VisualAlarm.app` | SwiftUI UI, alarm store mirror, agent registration |
| `VisualAlarmAgentXPC.xpc` | XPC service: owns `alarms.json` storage (own container); resident scheduler under launchd, on-demand RPC otherwise |
| `VisualAlarmRunnerXPC.xpc` | XPC service: macOS alarm window (sound, flicker, Stop) |

The app pushes its full alarm list to the agent via the `syncAlarms` XPC call; the agent persists it in its own container. Resident and on-demand agent instances coordinate through the shared file plus Darwin notifications.

## iOS Background Limitations

iOS does not allow background code execution for local notifications. The system delivers the notification sound and banner while the app is closed, but the visual effects (brightness flicker, torch blink, haptics) only run when:

- The app is in the **foreground**, or
- The user **taps the notification** to open the app.

This is an iOS platform restriction — there is no workaround without private APIs.

## Building

```bash
# macOS
xcodebuild -project VisualAlarm.xcodeproj -scheme VisualAlarm \
  -destination 'platform=macOS' build

# iOS Simulator
xcodebuild -project VisualAlarm.xcodeproj -scheme VisualAlarm \
  -destination 'generic/platform=iOS Simulator' build
```

## Testing

```bash
# macOS
xcodebuild -project VisualAlarm.xcodeproj -scheme VisualAlarmTests \
  -destination 'platform=macOS' test

# iOS Simulator (pick a concrete device id, not a generic destination)
xcodebuild -project VisualAlarm.xcodeproj -scheme VisualAlarmTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## License

GPLv3
