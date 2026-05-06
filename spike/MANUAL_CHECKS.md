# Spike — Manual Verification

Automated tests covered the easy stuff. These need real hardware events and a human watching the log. ~10 min total.

## Setup

Open Terminal in `spike/` dir.

```bash
swift build
./.build/debug/spike
```

You'll see device list + listener registration + a `Commands:` line. Leave it running. Watch the output as you do each check.

Note your starting state from the printout:
- Default input + output device
- Default input gain (write it down — you'll restore it)

When done, quit with `q` + Enter (or Ctrl-C).

---

## Check 1 — Device list listener fires on plug/unplug

**What we're proving:** `kAudioHardwarePropertyDevices` listener actually wakes up when hardware comes/goes. Whole app depends on this.

**Steps:**
1. Spike running.
2. Unplug your USB mic (fifine).
3. **Expect:** within ~1 s, log line:
   ```
   [HH:MM:SS.mmm] device list changed
       [I-] MacBook Pro Microphone (...)
       [-O] MacBook Pro Speakers (...)
       [-O] GF270L (...)
   ```
   (fifine gone from list)
4. Plug fifine back in.
5. **Expect:** another `device list changed` line, fifine reappears.

**Pass criteria:** both events logged within 2 s of action. Device list reflects reality.

**If fails:** listener selector wrong, or scope wrong, or `AudioObjectAddPropertyListenerBlock` got blocked by sandbox/TCC. Investigate before Phase 1.

---

## Check 2 — Default input device listener fires on external change

**What we're proving:** when *macOS* (not us) changes the default input — e.g., on USB device connect — listener fires. This is the trigger for auto-restore.

**Steps:**
1. Spike running. Note current default input.
2. Open **System Settings → Sound → Input**.
3. Click a different input device.
4. **Expect:** log line:
   ```
   [HH:MM:SS.mmm] default INPUT changed -> <id> <name>
   ```
5. Click back to original. **Expect:** another log line.

**Pass criteria:** listener fires within 1 s of each click.

**Bonus — auto-switch on connect:**
1. With spike running, set default input to built-in mic (in Settings).
2. Unplug fifine, plug it back.
3. **Expect:** macOS auto-switches default to fifine → log fires `default INPUT changed -> 102 fifine Microphone`.
4. **Confirms:** macOS does the auto-switch we want to override. We see the event. Good.

---

## Check 3 — Default output device + system output listeners

Same as Check 2 but for output. Open System Settings → Sound → Output, switch device, watch log.

**Expect:** `default OUTPUT changed -> ...` and possibly `default SYSTEM OUTPUT changed -> ...` (system output = alerts/UI sounds; sometimes same device, sometimes separate).

**Pass criteria:** at least `default OUTPUT changed` fires. System output line is informational — confirms whether we need to pin both or just main output.

---

## Check 4 — Volume listener fires on external gain change

**What we're proving:** another app or System Settings changing input gain triggers our listener → we can fight back. Critical for gain-lock feature.

**Steps:**
1. Spike running. Note current input gain (e.g. 0.6875).
2. Open **System Settings → Sound → Input**, drag the **Input volume** slider.
3. **Expect:** log line(s):
   ```
   [HH:MM:SS.mmm] gain listener fired (element 1)
   [HH:MM:SS.mmm] gain listener fired (element 2)
   ```
   (likely both channels, slightly staggered)

**Pass criteria:** listener fires within 1 s of slider drag.

**Bonus — app-driven AGC:**
1. Spike running. Open Zoom (or Google Meet in Chrome).
2. Start a test call. Make sure "Automatically adjust microphone volume" is enabled in app settings.
3. Talk loud / soft for ~10 s.
4. **Expect:** log lines firing as the app adjusts gain. Possibly many per second.

**Reveals:** how aggressive AGC is in real apps. Informs the runaway guard threshold (currently > 10/sec for > 1 s in PRD §4a).

---

## Check 5 — Pin override race

**What we're proving:** when macOS auto-switches default device on Bluetooth connect, can our app override it back fast enough?

Manual rough version (real implementation will do this automatically):

1. Spike running. Two devices available — say speakers (90) and a Bluetooth headset.
2. Note default output ID.
3. Pair / connect the Bluetooth headset.
4. **Expect:** log shows `default OUTPUT changed -> <bluetooth>`.
5. Immediately type `o 90` + Enter to force back to speakers.
6. **Expect:** `setDefaultOutput -> 0` then `default OUTPUT changed -> 90`.
7. Disconnect Bluetooth → reconnect → repeat.

**Pass criteria:** override always succeeds (`setDefaultOutput -> 0`). No errors. macOS doesn't fight us back after our write.

**If macOS re-overrides:** our write loses. Means we need a retry loop or a different override technique (e.g., set the device priority list at the HAL level). Revisit before Phase 1.

---

## Check 6 — Self-write echo (re-confirm spike finding)

Already verified non-interactively, but worth eyeballing:

1. Spike running.
2. Type `g 0.4` + Enter.
3. **Expect:** `setInputVolume -> 0`. Should NOT see `gain listener fired` line (volume listener does not echo own writes).
4. Type `i 97` + Enter (switch default input to built-in mic).
5. **Expect:** `setDefaultInput -> 0` AND a `default INPUT changed` line right after — listener DOES echo own writes for default-device.
6. Restore: `i 102` and `g 0.6875` (or your noted starting gain).

**Confirms architecture decision:** self-write filter on device-pin path, not on gain path.

---

## Reporting

For each check, note:
- Pass / fail
- Latency observed (rough — "<1 s" / "1–2 s" / "slow")
- Any unexpected log lines

Anything red → stop, debug before Phase 1. Anything yellow → file as known quirk, decide if it's a v1 blocker.

Spike is throwaway — won't be in shipping app. But these findings drive the real engine design.
