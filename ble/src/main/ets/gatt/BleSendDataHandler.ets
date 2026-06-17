import { ble } from '@kit.ConnectivityKit';
import { BufferQueue } from '../util/BufferQueue';

const TAG: string = 'BleSendDataHandler';

class SendDataInfo {
  gattClient: ble.GattClientDevice;
  characteristic: ble.BLECharacteristic;
  data: Uint8Array;

  constructor(gattClient: ble.GattClientDevice, characteristic: ble.BLECharacteristic, data: Uint8Array) {
    this.gattClient = gattClient;
    this.characteristic = characteristic;
    this.data = data;
  }
}

/** MTU-aware serialized GATT write queue (adapted from Jieli HarmonyOS SDK). */
export class BleSendDataHandler {
  private sendDataInfoQueue: BufferQueue<SendDataInfo> = new BufferQueue<SendDataInfo>();
  private running: boolean = false;

  constructor() {
    this.run();
  }

  removeDevice(gattClient: ble.GattClientDevice): void {
    const deviceId = gattClient.getDeviceId();
    let sendDataInfoArray = this.sendDataInfoQueue.getItemList();
    sendDataInfoArray = sendDataInfoArray.filter((item: SendDataInfo): boolean => {
      return item.gattClient.getDeviceId() !== deviceId;
    });
    this.sendDataInfoQueue.setItemList(sendDataInfoArray);
  }

  sendData(gattClient: ble.GattClientDevice, characteristic: ble.BLECharacteristic, data: Uint8Array,
    mtu: number): void {
    let realMtu = 20;
    if (mtu > 512) {
      realMtu = 509;
    } else {
      realMtu = mtu - 3;
    }
    const dataLen = data.byteLength;
    const blockCount = Math.floor(dataLen / realMtu);
    for (let i = 0; i < blockCount; i++) {
      const blockData = new Uint8Array(realMtu);
      blockData.set(data.slice(i * realMtu, i * realMtu + blockData.length));
      this.sendDataInfoQueue.enqueue(new SendDataInfo(gattClient, characteristic, blockData));
    }
    if (dataLen % realMtu !== 0) {
      const remainder = new Uint8Array(dataLen % realMtu);
      remainder.set(data.slice(dataLen - dataLen % realMtu, dataLen));
      this.sendDataInfoQueue.enqueue(new SendDataInfo(gattClient, characteristic, remainder));
    }
  }

  private async run(): Promise<void> {
    if (this.running) {
      return;
    }
    this.running = true;
    while (true) {
      try {
        const sendDataInfo = await this.sendDataInfoQueue.dequeueAsync();
        if (sendDataInfo) {
          await this.writeCharacteristic(sendDataInfo.gattClient, sendDataInfo.characteristic, sendDataInfo.data);
        }
      } catch (error) {
        console.error(TAG, `Write exception: ${JSON.stringify(error)}`);
        break;
      }
    }
  }

  private writeCharacteristic(gattClient: ble.GattClientDevice, characteristic: ble.BLECharacteristic,
    data: Uint8Array): Promise<void> {
    const writeCharacteristic: ble.BLECharacteristic = {
      serviceUuid: characteristic.serviceUuid,
      characteristicUuid: characteristic.characteristicUuid,
      characteristicValue: data.buffer,
      descriptors: characteristic.descriptors
    };
    return gattClient.writeCharacteristicValue(writeCharacteristic, ble.GattWriteType.WRITE_NO_RESPONSE);
  }
}
