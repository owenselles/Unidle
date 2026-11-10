# Unidle

A macOS menu bar app that moves the pointer for you on an interval you choose,
so the Mac doesn't decide you've left.

On each interval it traces the pointer through a small circle — twenty-four
steps over about a third of a second — and returns it to exactly the position it
started from, using `CGEventPost`. The movement size is configurable (Small,
Medium, Large), and `None` posts a single event that doesn't move the cursor at
all.

Producing an input event resets the idle clock that
`CGEventSourceSecondsSinceLastEventType` reports, which is the value
presence-aware apps read. It also resets IOKit's `HIDIdleTime`, which drives
display and system sleep — so sleep prevention comes free, with no power
assertion.

Requires macOS 14 or later.

Source-available, not open source: you may build and run it for your own
personal use, including on a work machine, and modify it to do so. You may not
redistribute or sell it. See [LICENSE](LICENSE).

## Building it yourself

You need [Xcode](https://developer.apple.com/xcode/) and
[XcodeGen](https://github.com/yonaskolb/XcodeGen). The `.xcodeproj` is generated
and deliberately not in version control.

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

### No Apple Developer account needed

Build the `UnidleDirect` target with an ad-hoc signature. This needs no Apple
account, no certificate, and no team ID:

```bash
xcodebuild -scheme UnidleDirect -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" build
```

The app lands at `build/Build/Products/Release/UnidleDirect.app`. Copy it to
`/Applications` and open it.

**Build `UnidleDirect`, not `Unidle`.** The sandboxed `Unidle` target exists for
the Mac App Store, and a sandboxed build never receives the Accessibility
permission prompt — macOS suppresses it, so you'd have to add the app to the
permission list by hand. The unsandboxed target prompts normally, which is a far
better experience when you're running your own build.

### If you do have a developer account

`project.yml` carries the original author's team and bundle identifiers, so
change these before building the signed targets, or override them on the command
line:

```bash
xcodebuild -scheme UnidleDirect DEVELOPMENT_TEAM=YOURTEAMID PRODUCT_BUNDLE_IDENTIFIER=com.yourname.unidle build
```

## First run

Unidle lives in the menu bar — there's no Dock icon and no main window.

1. Click the pointer icon in the menu bar and switch on **Keep Me Active**
2. Approve the Accessibility prompt when it appears. macOS requires this before
   any app may move the pointer on your behalf; without it Unidle can't do
   anything, and the menu will say so.
3. Leave the machine alone for a minute. The pointer traces a circle and returns
   to where it started.

If the permission doesn't take, the welcome window has buttons that open the
right settings pane and reveal the app in Finder.

Settings (⌘,) covers the movement size, how long a pause must last before Unidle
steps in, work-hours scheduling, timed sessions, launch at login, and pausing on
low battery.

## Targets

| Target | Sandbox | For |
|---|---|---|
| `UnidleDirect` | No | Building and running it yourself — **start here** |
| `Unidle` | Yes | Mac App Store builds |
| `UnidleTests` | — | Unit tests |

## Tests

```bash
xcodebuild test -scheme Unidle -destination 'platform=macOS'
```

Forty-two of them. Decision logic lives in `ActivityPolicy`, a pure value type,
so schedule precedence, timed-session expiry and the low-battery rule are all
testable without a running app. `PointerMovement` covers the path geometry —
that it starts and ends on the origin, and that the steps are small enough to
follow by eye.

`WorkSchedule` covers overnight windows and the Sunday-to-Saturday week wrap.
Note that only a Sunday morning exercises that wrap: a test written against any
other weekday passes against a broken implementation, which is a mistake this
suite made once already.

## Tools

| Script | Does |
|---|---|
| `Tools/makeicon.swift` | Renders the full app icon set from code |
| `Tools/verify-movement.swift` | Watches a running copy and reports pointer travel, drift, and whether the idle clock reset |
| `Tools/makescreenshots.swift` | Composites App Store screenshots |

```bash
swift Tools/verify-movement.swift 120
```
