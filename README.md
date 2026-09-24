# break-reminder

A break reminder for macOS that you actually notice. Instead of a notification you
swipe away without reading, it blurs the whole screen behind a centered card, then
clears itself after a countdown.

- Blurs every attached display without hiding what's underneath — your work stays
  visible but unreadable, so there's nothing to skim and nothing to lose.
- Centered card with an **OK** button; Return dismisses it too.
- Closes itself after a countdown (default 30s) if you do nothing.
- An eye icon in the menu bar shows the time left until the next break, turns
  reminders on and off, and sets the interval (default 45 minutes).

No dependencies beyond the Swift toolchain that ships with the Xcode Command Line
Tools, and no screen-recording permission — the blur is done by the window server.

## Install

```bash
git clone https://github.com/svensoldin/break-reminder.git
cd break-reminder
./install.sh
```

## Configure

Pick the interval from the eye icon's **Interval** menu: a preset, or **Custom…**
for any number of minutes. The choice is saved and survives restarts.

`install.sh` reads two environment variables for the overlay itself:

| Variable            | Default                        | Meaning                          |
| ------------------- | ------------------------------ | -------------------------------- |
| `DISPLAY_SECONDS`   | `30`                           | How long it stays on screen      |
| `MESSAGE`           | `Look away, stretch, breathe.` | The line under the title         |

```bash
DISPLAY_SECONDS=20 MESSAGE="Stand up." ./install.sh
```

Re-run `./install.sh` after changing anything; it rebuilds and reloads the app.

## Menu bar app

`break-reminder-menu` is started at login by a `launchd` agent and does the
scheduling: it opens the overlay when the countdown runs out, then starts the next
countdown once you dismiss it. Waking the Mac from sleep also restarts the
countdown, since time asleep is time away from the screen. Quitting the menu bar
app stops the reminders; re-run `./install.sh` or log back in to bring it back.

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
