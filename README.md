# HarmonyBandSdK

HarmonyOS BLE SDK for PowerBand smart bands. Mirrors the Android `BandSDKDemo/app/ble` module architecture and integrates the Jieli (杰理) vendor SDK from `HarmonyOS-JL_OTA`.

## Project Structure

```
HarmonyBandSdK/
├── ble/              # HAR — PowerBand BLE SDK (public API: BleManager)
├── lib_rcsp/         # HAR — Jieli RCSP/OTA/Auth vendor wrapper
├── entry/            # Demo app — scan, connect, debug log
└── AppScope/         # Application identity
```

### Architecture (mirrors Android)

```
Host App / Demo
    └── BleManager (facade)
          └── BleRepositoryImpl (protocol + state)
                └── BleGattClient (GATT scan/connect/write/notify)
                      └── BleSendDataHandler (MTU-aware write queue)
```

| Android (`BandSDKDemo/app/ble`) | HarmonyOS (`ble` module) |
|----------------------------------|--------------------------|
| `BleManager` | `BleManager.ets` |
| `BleRepositoryImpl` | `impl/BleRepositoryImpl.ets` |
| `BlePeripheral` | `gatt/BleGattClient.ets` |
| `BLEConstants` | `util/BleConstants.ets` |
| `JLWatchManager` + Jieli AAR | `lib_rcsp` HAR wrapper (Step 4) |

## Setup (Step by Step)

### Step 1 — Open in DevEco Studio

1. Open **DevEco Studio** (HarmonyOS NEXT, SDK 6.0+ recommended).
2. **File → Open** → select `/Users/fortress/powerband/HarmonyBandSdK`.
3. Let DevEco sync dependencies (`ohpm install` runs automatically).

### Step 2 — Vendor HAR files (Jieli)

Copy the three Jieli HAR files into `lib_rcsp/lib/`:

```bash
cp /Users/fortress/powerband/ghubcode/HarmonyOS-JL_OTA/libs/JL/JL_*.har \
   /Users/fortress/powerband/HarmonyBandSdK/lib_rcsp/lib/
```

Required files:
- `JL_OTA_1.0.1-release.har`
- `JL_RCSP_1.0.1-release.har`
- `JL_Auth_1.0.1-release.har`

### Step 3 — Build

In DevEco Studio: **Build → Build Hap(s)/APP(s)** for the `entry` module.

Or from terminal (after DevEco SDK is configured):

```bash
./hvigorw assembleHap -p module=entry -p product=default
```

### Step 4 — Run demo on device

1. Enable Bluetooth on the HarmonyOS device.
2. Grant BLE and location permissions when prompted.
3. Tap **Scan** → select a PowerBand device → **Connect**.
4. On success, status shows **Ready** after band config handshake (`0x22 → 0x28 → 0x35`).

## Using the SDK in your app

Add the `ble` HAR as a dependency in your entry module's `oh-package.json5`:

```json5
{
  "dependencies": {
    "ble": "file:../ble"   // or path to published HAR
  }
}
```

Import and use:

```typescript
import { BleManager, DeviceItem, BleConnectionPhase } from 'ble';

await BleManager.initializeSdk();

BleManager.subscribeConnectState((state) => {
  if (state.phase === BleConnectionPhase.BLUETOOTH_READY) {
    BleManager.getSportData(0);
  }
});

BleManager.startScan();
BleManager.connectBleDevice(new DeviceItem('My Band', deviceId, rssi, deviceId));
```

## Public API (`BleManager`)

| Category | Methods |
|----------|---------|
| Lifecycle | `initializeSdk`, `disconnect`, `unbindDevice` |
| Scan / Connect | `startScan`, `stopScan`, `connectBleDevice`, `updateBondDevice` |
| Device info | `getBandConfig`, `getSupportedFunc`, `getUserInfo`, `getSoftVersion` |
| Health / Sport | `getSportData`, `getExamineData`, `setDailyDataListener`, `setHealthDataListener` |
| Settings | `postAlarm`, `postHeartRate`, `postAntiLost`, `postLightUp`, `postWeather`, `postUserInfo` |
| Watch face | `postScreenStart`, `postScreenData`, `postScreenParams`, `postMarketScreenStart`, `postMarketScreenData` |
| Events | `setFindPhoneListener`, `setCameraShakeListener`, `setCallControlListener`, `setWeatherRequestListener` |

## GATT UUIDs

| Role | UUID |
|------|------|
| PowerBand service | `66880000-0000-1000-8000-008012563489` |
| TX (write) | `66880001-0000-1000-8000-008012563489` |
| RX (notify) | `66880002-0000-1000-8000-008012563489` |
| Jieli service | `0000AE00-0000-1000-8000-00805F9B34FB` |
| Jieli TX / RX | `0000AE01-...` / `0000AE02-...` |

## Permissions (host app)

Declare in your entry `module.json5`:

- `ohos.permission.ACCESS_BLUETOOTH`
- `ohos.permission.DISCOVER_BLUETOOTH`
- `ohos.permission.USE_BLUETOOTH`
- `ohos.permission.APPROXIMATELY_LOCATION` (required for BLE scan on some devices)

## Jieli RCSP Auth (JL watches)

For bands with a Jieli chip (AE00/AE01/AE02 GATT service), the SDK runs JL auth automatically after the PowerBand handshake:

```
connect → MTU → band config (0x22→0x28→0x35) → JLAuth.startAuth → bleStateToConnected
```

- `ble/src/main/ets/jl/JLWatchManager.ets` — auth + RCSP session (mirrors Android `JLWatchManager`)
- Uses `lib_rcsp` → `jl-auth` / `jl-rcsp` vendor HARs
- On auth failure the connection is dropped (same as Android)

## Next Steps

1. ~~**JLWatchManager integration**~~ — done (auth wired via `JLWatchManager`)
2. **OTA** — add `BluetoothOTAManager` pattern from `HarmonyOS-JL_OTA` for firmware upgrade.
3. **Notification mirroring** — port `PowerbandNotifyService` when HarmonyOS notification access API is available.
4. **Publish HAR** — build `ble` module as release HAR for distribution to app teams.

## Reference Projects

- Android BLE SDK: `/Users/fortress/powerband/BandSDKDemo/app/ble`
- Jieli HarmonyOS OTA: `/Users/fortress/powerband/ghubcode/HarmonyOS-JL_OTA`
- HarmonyPowerband app (stub API reference): `/Users/fortress/powerband/ghubcode/HarmonyPowerband`
# HarmonyBandSDK
