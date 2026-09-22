# break-reminder

A break reminder for macOS that you actually notice. Instead of a notification you
swipe away without reading, it blurs the whole screen behind a centered card, then
clears itself after a countdown.

- Blurs every attached display without hiding what's underneath — your work stays
  visible but unreadable, so there's nothing to skim and nothing to lose.
- Centered card with an **OK** button; Return dismisses it too.
- Closes itself after a countdown (default 30s) if you do nothing.
- Runs on a fixed interval via `launchd` (default 45 minutes).

No dependencies beyond the Swift toolchain that ships with the Xcode Command Line
Tools, and no screen-recording permission — the blur is done by the window server.

## Install

```bash
git clone https://github.com/svensoldin/break-reminder.git
cd break-reminder
./install.sh
```

## Configure

`install.sh` reads three environment variables:

| Variable            | Default                        | Meaning                          |
| ------------------- | ------------------------------ | -------------------------------- |
| `INTERVAL_SECONDS`  | `2700` (45 min)                | How often the reminder fires     |
| `DISPLAY_SECONDS`   | `30`                           | How long it stays on screen      |
| `MESSAGE`           | `Look away, stretch, breathe.` | The line under the title         |

```bash
INTERVAL_SECONDS=1200 DISPLAY_SECONDS=20 MESSAGE="Stand up." ./install.sh
```

Re-run `./install.sh` after changing anything; it rebuilds and reloads the agent.

## Try it without waiting

```bash
./break-reminder 5 "Testing."
```

## Uninstall

```bash
./uninstall.sh
```

## How the blur works

Each screen gets a borderless `NSWindow` at `.screenSaver` level whose content view
is an `NSVisualEffectView` in `.behindWindow` blending mode. That mode asks the
window server to blur whatever is composited behind the window, which is why the
effect covers other applications and costs no permissions.

The window level is the one knob worth knowing about: `.screenSaver` puts the
overlay above everything, including full-screen apps. Drop it to `.floating` in
`BreakReminder.swift` if you'd rather it not interrupt presentations.

## Caveat

The overlay takes keyboard focus for the duration so Return can dismiss it. If that
interrupts your typing, lower `DISPLAY_SECONDS` or change the window level.
