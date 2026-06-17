import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  BleConnectionPhase,
  BleManager,
  BlueEventState,
  DeviceItem,
  DeviceSearchPhase
} from 'ble';

@Entry
@Component
struct MainPage {
  @State connectPhase: BleConnectionPhase = BleConnectionPhase.INITIAL;
  @State connectLabel: string = 'Disconnected';
  @State searchPhase: DeviceSearchPhase = DeviceSearchPhase.IDLE;
  @State devices: DeviceItem[] = [];
  @State logLines: string[] = [];
  @State boundName: string = '';
  private unsubscribeConnect?: () => void;
  private unsubscribeSearch?: () => void;

  aboutToAppear(): void {
    this.requestBlePermissions();
    this.unsubscribeConnect = BleManager.subscribeConnectState((state: BlueEventState): void => {
      this.connectPhase = state.phase;
      this.boundName = state.device?.name ?? '';
      switch (state.phase) {
        case BleConnectionPhase.INITIAL:
          this.connectLabel = 'Initial';
          break;
        case BleConnectionPhase.CONNECTING:
          this.connectLabel = 'Connecting…';
          break;
        case BleConnectionPhase.BLUETOOTH_CONNECTED:
          this.connectLabel = 'Connected (handshake)';
          break;
        case BleConnectionPhase.BLUETOOTH_READY:
          this.connectLabel = `Ready: ${this.boundName}`;
          break;
        case BleConnectionPhase.DISCONNECTED:
          this.connectLabel = 'Disconnected';
          break;
      }
    });
    this.unsubscribeSearch = BleManager.subscribeDeviceSearch((phase: DeviceSearchPhase, list: DeviceItem[]): void => {
      this.searchPhase = phase;
      this.devices = list;
    });
    BleManager.addBleLogListener((msg: string): void => {
      this.logLines = [msg, ...this.logLines].slice(0, 20);
    });
    const bond = BleManager.getBondDevice();
    this.boundName = bond.name;
  }

  aboutToDisappear(): void {
    this.unsubscribeConnect?.();
    this.unsubscribeSearch?.();
  }

  private async requestBlePermissions(): Promise<void> {
    const permissions: Permissions[] = [
      'ohos.permission.ACCESS_BLUETOOTH',
      'ohos.permission.DISCOVER_BLUETOOTH',
      'ohos.permission.USE_BLUETOOTH',
      'ohos.permission.APPROXIMATELY_LOCATION'
    ];
    const atManager = abilityAccessCtrl.createAtManager();
    const context = getContext(this) as common.UIAbilityContext;
    try {
      await atManager.requestPermissionsFromUser(context, permissions);
    } catch (err) {
      const error = err as BusinessError;
      this.appendLog(`Permission error: ${error.message}`);
    }
  }

  private appendLog(msg: string): void {
    this.logLines = [msg, ...this.logLines].slice(0, 20);
  }

  build() {
    Column({ space: 12 }) {
      Text('HarmonyBand BLE SDK Demo')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 24, bottom: 8 });

      Text(`Status: ${this.connectLabel}`)
        .fontSize(16)
        .fontColor(this.connectPhase === BleConnectionPhase.BLUETOOTH_READY ? '#2E7D32' : '#555555');

      Row({ space: 12 }) {
        Button('Scan')
          .enabled(this.searchPhase !== DeviceSearchPhase.SCANNING)
          .onClick((): void => {
            BleManager.startScan();
            this.appendLog('Scan started');
          });
        Button('Stop Scan')
          .onClick((): void => {
            BleManager.stopScan();
            this.appendLog('Scan stopped');
          });
        Button('Disconnect')
          .onClick((): void => {
            BleManager.disconnect();
            this.appendLog('Disconnected');
          });
      }
      .width('100%')
      .justifyContent(FlexAlign.Center);

      Text(`Found devices (${this.devices.length})`)
        .fontSize(14)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 8 });

      List({ space: 8 }) {
        ForEach(this.devices, (device: DeviceItem) => {
          ListItem() {
            Row() {
              Column({ space: 4 }) {
                Text(device.name.length > 0 ? device.name : 'Unknown')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium);
                Text(`${device.deviceId}  RSSI ${device.rssi}`)
                  .fontSize(12)
                  .fontColor('#888888');
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1);

              Button('Connect')
                .height(32)
                .onClick((): void => {
                  BleManager.updateBondDevice(device.name, device.deviceId);
                  BleManager.connectBleDevice(device, 35000, (result): void => {
                    this.appendLog(`Connect result: ${result.message}`);
                  });
                });
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#F5F5F5')
            .borderRadius(8);
          }
        }, (device: DeviceItem): string => device.deviceId);
      }
      .layoutWeight(1)
      .width('100%');

      Text('BLE Log')
        .fontSize(14)
        .alignSelf(ItemAlign.Start);

      List() {
        ForEach(this.logLines, (line: string, index: number) => {
          ListItem() {
            Text(line)
              .fontSize(11)
              .fontColor('#666666');
          }
        }, (line: string, index: number): string => `${index}_${line}`);
      }
      .height(120)
      .width('100%')
      .backgroundColor('#FAFAFA')
      .borderRadius(8)
      .padding(8);
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, bottom: 16 });
  }
}
