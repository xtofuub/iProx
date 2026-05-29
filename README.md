# iProx

Passive OSINT scanner for Apple Continuity BLE advertisements. Runs as a sideloaded TrollStore app on jailbroken iOS, decodes the 0x4C00 Apple manufacturer-data stream from nearby iPhones, AirPods, Apple Watches, Macs, FindMy beacons and AirPlay targets, and surfaces what each device is actively leaking.

Built because every reference implementation of Continuity decoding (hexway, ECTO-1A, furiousMAC) is a Python script for a laptop or an ESP32 firmware. There was no on-device, productized version. iProx is that version.

## What it sees

| TLV   | Type              | Decoded fields                                              |
|-------|-------------------|-------------------------------------------------------------|
| 0x05  | AirDrop           | sender phone / email / Apple ID hash prefixes               |
| 0x07  | Proximity Pairing | AirPods / Beats model, left/right/case battery, lid state   |
| 0x09  | AirPlay Target    | flags, seed, IPv4                                           |
| 0x0C  | Handoff           | sequence, IV, auth tag, encrypted payload (not decrypted)   |
| 0x0D  | Tethering Target  | battery percent, cell service type, signal bars             |
| 0x0F  | Nearby Action     | action type + human name (AppleTV Pair, WiFi Password, etc) |
| 0x10  | Nearby Info       | lock state, AirDrop receiver, primary iCloud, iOS activity  |
| 0x12  | FindMy            | battery state, lost-mode flag, public key prefix            |

Output goes to a live list with model inference, RSSI bar, activity badges, and a detail screen with per-type cards plus the raw recent TLVs in hex.

## Why it works on a sandbox app

iOS strips Apple manufacturer data (company ID 0x004C) from third-party `CoreBluetooth` callbacks by default — that's why every other "Apple device scanner" you've tried returns empty. iProx is built for TrollStore so the IPA can be fake-signed with the private entitlements that `sharingd` and the system Bluetooth daemon use to see those adverts:

- `com.apple.bluetooth.allow`
- `com.apple.BTServer.appleMfgDataScanner`
- `com.apple.private.bluetooth-le.allow`

These pass AMFI under TrollStore's CoreTrust bypass on iOS ≤ 16.6.x. No background mode is claimed and no peripheral advertising is performed — radios stay co-existent with WiFi/cellular.

## Requirements

- iOS 15.0 – 16.6.x, arm64 or arm64e
- TrollStore installed
- Theos in WSL or macOS for building from source

## Build

```bash
git clone https://github.com/xtofuub/iProx.git
cd iProx
bash scripts/build_ipa.sh
```

The IPA lands at `packages/iProx_0.2.0.ipa`. Open it in TrollStore (`trollstorehelper install packages/iProx_0.2.0.ipa` over SSH also works).

## Layout

```
App/
  IPAppDelegate.m         window + tab bar + lifecycle
  IPScannerService.m      CBCentralManager duty-cycle scan
  IPDeviceStore.m         thread-safe device aggregation
  IPDeviceListViewController.m
  IPDeviceDetailViewController.m
  IPDeviceCell.m
  IPSettingsViewController.m
  Info.plist
  entitlements.plist
  Makefile
Daemon/
  ContinuityDecoder.m     TLV parser, no UIKit deps
  ContinuityRecord.m
  Logger.m
scripts/
  build_ipa.sh            compile + ldid sign + zip → .ipa
Makefile                  Theos aggregate (subproject: App)
```

The `Daemon/` directory is a holdover name from when this was a LaunchDaemon — those files are now just the protocol-decoder library, shared with the app via `iprox_FILES = ../Daemon/...` in `App/Makefile`. Pure C/Obj-C, no UI, easy to lift into other projects.

## Notes

- Scanning is **passive**. iProx never advertises and never probes. It only reads BLE adverts that nearby devices already broadcast in the clear.
- MAC randomization rotates Apple devices every ~15 minutes, so the same physical iPhone will show up as multiple UUIDs over time. The on-screen list keys on `CBPeripheral.identifier`.
- AirDrop type 0x05 produces 2-byte hash *prefixes*, not full hashes — useful for clustering repeat senders, not for deanonymization without a wordlist crack. A wordlist cracker tab is on the roadmap.
- Handoff type 0x0C leaks an encrypted payload that would need the paired devices' IRK to decrypt; iProx surfaces the ciphertext for completeness but does not attempt to crack it.

## Roadmap

- AirDrop hash cracker against US phone-prefix + common-email wordlists
- AirTag / FindMy beacon dashboard with cross-roll correlation
- Map view with RSSI-derived range rings
- Optional Nearby Action spam broadcaster (gated, opt-in, research-only)

## References

- hexway, [apple_bleee](https://github.com/hexway/apple_bleee) — original Python decoder
- ECTO-1A, [AppleJuice](https://github.com/ECTO-1A/AppleJuice) — Nearby Action payload table
- furiousMAC, [continuity](https://github.com/furiousMAC/continuity) — protocol notes

## Legal

Passive radio monitoring is lawful in most jurisdictions; check yours before running this in public. iProx ships with all transmit features disabled. Use only on devices and people who have consented, or for genuinely passive defensive research (e.g. AirTag scanning in your own space).

## License

MIT — see [LICENSE](LICENSE).
