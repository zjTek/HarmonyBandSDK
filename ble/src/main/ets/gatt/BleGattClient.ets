import { access, ble, constant } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BleSendDataHandler } from './BleSendDataHandler';
import { BleUuids, bytesToHex } from '../util/BleConstants';
import { DeviceItem } from '../model/BleTypes';

const TAG: string = 'BleGattClient';

export enum GattConnectState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2,
  READY = 3
}

export type GattDataListener = (data: Uint8Array, isJlChannel: boolean) => void;
export type GattStateListener = (state: GattConnectState, mtu: number) => void;
export type GattScanListener = (devices: DeviceItem[]) => void;

interface ConnectedDeviceInfo {
  deviceId: string;
  deviceName: string;
  gattClient: ble.GattClientDevice;
  mtu: number;
  txCharacteristic?: ble.BLECharacteristic;
  rxCharacteristic?: ble.BLECharacteristic;
  jlTxCharacteristic?: ble.BLECharacteristic;
  jlRxCharacteristic?: ble.BLECharacteristic;
}

/**
 * Low-level GATT client for PowerBand bands.
 * Handles scan, connect, MTU negotiation, notify enable, and serialized writes.
 */
export class BleGattClient {
  private isScanning: boolean = false;
  private scanTimeoutId: number = -1;
  private scanDevices: Map<string, DeviceItem> = new Map();
  private sendDataHandler: BleSendDataHandler = new BleSendDataHandler();
  private connectedDevice: ConnectedDeviceInfo | null = null;
  private connectState: GattConnectState = GattConnectState.DISCONNECTED;
  private dataListener: GattDataListener | null = null;
  private stateListener: GattStateListener | null = null;
  private scanListener: GattScanListener | null = null;
  private logListener: ((msg: string) => void) | null = null;
  private deviceFindCallback = (results: Array<ble.ScanResult>): void => {
    this.onDeviceFound(results);
  };

  setDataListener(listener: GattDataListener | null): void {
    this.dataListener = listener;
  }

  setStateListener(listener: GattStateListener | null): void {
    this.stateListener = listener;
  }

  setScanListener(listener: GattScanListener | null): void {
    this.scanListener = listener;
  }

  setLogListener(listener: ((msg: string) => void) | null): void {
    this.logListener = listener;
  }

  getConnectState(): GattConnectState {
    return this.connectState;
  }

  isConnected(): boolean {
    return this.connectState === GattConnectState.CONNECTED || this.connectState === GattConnectState.READY;
  }

  getMtu(): number {
    return this.connectedDevice?.mtu ?? BleUuids.DEFAULT_MTU;
  }

  private log(message: string): void {
    console.info(TAG, message);
    this.logListener?.(message);
  }

  async ensureBluetoothEnabled(): Promise<boolean> {
    try {
      const state = access.getState();
      if (state === access.BluetoothState.STATE_ON) {
        return true;
      }
      return false;
    } catch (err) {
      this.log(`Bluetooth state check failed: ${JSON.stringify(err)}`);
      return false;
    }
  }

  startScan(timeoutMs: number = 10000): void {
    if (this.isScanning) {
      this.stopScan();
    }
    this.scanDevices.clear();
    try {
      ble.on('BLEDeviceFind', this.deviceFindCallback);
      const scanOptions: ble.ScanOptions = {
        interval: 500,
        dutyMode: ble.ScanDuty.SCAN_MODE_LOW_LATENCY,
        matchMode: ble.MatchMode.MATCH_MODE_AGGRESSIVE
      };
      ble.startBLEScan(null, scanOptions);
      this.isScanning = true;
      this.log('BLE scan started');
      this.scanTimeoutId = setTimeout((): void => {
        this.stopScan();
      }, timeoutMs);
    } catch (err) {
      this.log(`Scan start failed: ${JSON.stringify(err)}`);
      this.isScanning = false;
    }
  }

  stopScan(): void {
    if (this.scanTimeoutId >= 0) {
      clearTimeout(this.scanTimeoutId);
      this.scanTimeoutId = -1;
    }
    if (!this.isScanning) {
      return;
    }
    try {
      ble.stopBLEScan();
      ble.off('BLEDeviceFind', this.deviceFindCallback);
    } catch (err) {
      this.log(`Scan stop failed: ${JSON.stringify(err)}`);
    }
    this.isScanning = false;
    this.log('BLE scan stopped');
  }

  private onDeviceFound(results: Array<ble.ScanResult>): void {
    let changed = false;
    for (const result of results) {
      const deviceId = result.deviceId;
      const name = result.deviceName ?? '';
      const rssi = result.rssi ?? 0;
      const existing = this.scanDevices.get(deviceId);
      if (!existing || existing.rssi !== rssi) {
        this.scanDevices.set(deviceId, new DeviceItem(name, deviceId, rssi, deviceId));
        changed = true;
      }
    }
    if (changed) {
      this.scanListener?.(Array.from(this.scanDevices.values()));
    }
  }

  connect(device: DeviceItem, timeoutMs: number = 35000): Promise<void> {
    return new Promise((resolve, reject) => {
      if (this.connectedDevice) {
        this.disconnect();
      }
      this.updateConnectState(GattConnectState.CONNECTING, BleUuids.DEFAULT_MTU);
      const deviceId = device.deviceId.length > 0 ? device.deviceId : device.mac;
      let connectTimeoutId = setTimeout((): void => {
        this.log('Connection timeout');
        this.disconnect();
        reject(new Error('Connection timeout'));
      }, timeoutMs);
      try {
        const gattClient = ble.createGattClientDevice(deviceId);
        const onCharacteristicChange = (characteristic: ble.BLECharacteristic): void => {
          const data = new Uint8Array(characteristic.characteristicValue);
          const isJl = characteristic.serviceUuid.toUpperCase().includes('AE00') ||
            characteristic.characteristicUuid.toUpperCase().includes('AE02');
          this.log(`RX [${isJl ? 'JL' : 'PB'}]: ${bytesToHex(data)}`);
          this.dataListener?.(data, isJl);
        };
        const initServices = (): void => {
          this.discoverServices(gattClient).then((): void => {
            gattClient.on('BLECharacteristicChange', onCharacteristicChange);
            clearTimeout(connectTimeoutId);
            this.updateConnectState(GattConnectState.CONNECTED, this.connectedDevice?.mtu ?? BleUuids.DEFAULT_MTU);
            resolve();
          }).catch((err: BusinessError) => {
            clearTimeout(connectTimeoutId);
            this.disconnect();
            reject(err);
          });
        };
        const onMtuChange = (mtu: number): void => {
          if (this.connectedDevice) {
            this.connectedDevice.mtu = mtu;
          }
          this.log(`MTU changed: ${mtu}`);
          initServices();
        };
        const onConnectionStateChange = (state: ble.BLEConnectionChangeState): void => {
          if (state.state === constant.ProfileConnectionState.STATE_CONNECTED) {
            this.connectedDevice = {
              deviceId,
              deviceName: device.name,
              gattClient,
              mtu: BleUuids.DEFAULT_MTU
            };
            try {
              gattClient.setBLEMtuSize(BleUuids.REQUEST_MTU);
              gattClient.on('BLEMtuChange', onMtuChange);
              setTimeout((): void => {
                if (this.connectState === GattConnectState.CONNECTING) {
                  initServices();
                }
              }, 5000);
            } catch (err) {
              this.log(`MTU request failed: ${JSON.stringify(err)}`);
              initServices();
            }
          } else if (state.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
            gattClient.off('BLECharacteristicChange');
            gattClient.off('BLEConnectionStateChange');
            gattClient.off('BLEMtuChange');
            this.sendDataHandler.removeDevice(gattClient);
            this.connectedDevice = null;
            this.updateConnectState(GattConnectState.DISCONNECTED, BleUuids.DEFAULT_MTU);
          }
        };
        gattClient.on('BLEConnectionStateChange', onConnectionStateChange);
        gattClient.connect();
      } catch (err) {
        clearTimeout(connectTimeoutId);
        this.updateConnectState(GattConnectState.DISCONNECTED, BleUuids.DEFAULT_MTU);
        reject(err);
      }
    });
  }

  private async discoverServices(gattClient: ble.GattClientDevice): Promise<void> {
    const services = await gattClient.getServices();
    if (services.length === 0) {
      throw new Error('No GATT services found');
    }
    let txChar: ble.BLECharacteristic | undefined;
    let rxChar: ble.BLECharacteristic | undefined;
    let jlTxChar: ble.BLECharacteristic | undefined;
    let jlRxChar: ble.BLECharacteristic | undefined;
    for (const service of services) {
      const serviceUuid = service.serviceUuid.toUpperCase();
      for (const characteristic of service.characteristics) {
        const charUuid = characteristic.characteristicUuid.toUpperCase();
        if (serviceUuid.includes('66880000') && charUuid.includes('66880001')) {
          txChar = characteristic;
        } else if (serviceUuid.includes('66880000') && charUuid.includes('66880002')) {
          rxChar = characteristic;
          await this.enableNotify(gattClient, characteristic);
        } else if (serviceUuid.includes('AE00') && charUuid.includes('AE01')) {
          jlTxChar = characteristic;
        } else if (serviceUuid.includes('AE00') && charUuid.includes('AE02')) {
          jlRxChar = characteristic;
          await this.enableNotify(gattClient, characteristic);
        }
      }
    }
    if (!txChar || !rxChar) {
      throw new Error('PowerBand GATT characteristics not found');
    }
    if (this.connectedDevice) {
      this.connectedDevice.txCharacteristic = txChar;
      this.connectedDevice.rxCharacteristic = rxChar;
      this.connectedDevice.jlTxCharacteristic = jlTxChar;
      this.connectedDevice.jlRxCharacteristic = jlRxChar;
    }
    this.log(`Services discovered. JL watch: ${jlTxChar !== undefined}`);
  }

  private enableNotify(gattClient: ble.GattClientDevice, characteristic: ble.BLECharacteristic): Promise<boolean> {
    return new Promise((resolve) => {
      gattClient.setCharacteristicChangeNotification(characteristic, true, (err: BusinessError) => {
        if (err) {
          this.log(`Notify enable failed: ${JSON.stringify(err)}`);
          resolve(false);
        } else {
          resolve(true);
        }
      });
    });
  }

  writeCommand(data: Uint8Array): boolean {
    if (!this.connectedDevice?.txCharacteristic) {
      this.log('Cannot write: not connected or TX char missing');
      return false;
    }
    this.log(`TX: ${bytesToHex(data)}`);
    this.sendDataHandler.sendData(
      this.connectedDevice.gattClient,
      this.connectedDevice.txCharacteristic,
      data,
      this.connectedDevice.mtu
    );
    return true;
  }

  writeJlCommand(data: Uint8Array): boolean {
    if (!this.connectedDevice?.jlTxCharacteristic) {
      return false;
    }
    this.log(`TX [JL]: ${bytesToHex(data)}`);
    this.sendDataHandler.sendData(
      this.connectedDevice.gattClient,
      this.connectedDevice.jlTxCharacteristic,
      data,
      this.connectedDevice.mtu
    );
    return true;
  }

  hasJlService(): boolean {
    return this.connectedDevice?.jlTxCharacteristic !== undefined;
  }

  getConnectedDeviceId(): string {
    return this.connectedDevice?.deviceId ?? '';
  }

  getConnectedDeviceName(): string {
    return this.connectedDevice?.deviceName ?? '';
  }

  markReady(): void {
    if (this.connectedDevice) {
      this.updateConnectState(GattConnectState.READY, this.connectedDevice.mtu);
    }
  }

  disconnect(): void {
    if (this.connectedDevice?.gattClient) {
      try {
        this.connectedDevice.gattClient.disconnect();
        this.connectedDevice.gattClient.close();
      } catch (err) {
        this.log(`Disconnect error: ${JSON.stringify(err)}`);
      }
      this.sendDataHandler.removeDevice(this.connectedDevice.gattClient);
    }
    this.connectedDevice = null;
    this.updateConnectState(GattConnectState.DISCONNECTED, BleUuids.DEFAULT_MTU);
  }

  private updateConnectState(state: GattConnectState, mtu: number): void {
    this.connectState = state;
    this.stateListener?.(state, mtu);
  }
}
