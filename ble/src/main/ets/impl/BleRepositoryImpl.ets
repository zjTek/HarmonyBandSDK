import { BleGattClient, GattConnectState } from '../gatt/BleGattClient';
import { JLWatchManager } from '../jl/JLWatchManager';
import { BleCommands, BleRequestId, toUnsignedByte } from '../util/BleConstants';
import {
  BandConfig,
  BleConnectionPhase,
  BleConnectStateListener,
  BleDailyPayload,
  BleDataResult,
  BleExaminePayload,
  BleLogListener,
  BleResult,
  BleResultCallback,
  BlueEventState,
  BoundDevice,
  CallControlListener,
  CameraOpenListener,
  CameraShakeListener,
  DailyDataListener,
  DeviceItem,
  DeviceSearchListener,
  DeviceSearchPhase,
  ExamineDataCallback,
  FindPhoneListener,
  HealthDataListener,
  WeatherRequestListener
} from '../model/BleTypes';

type PendingCallback = BleResultCallback;

/**
 * Business logic and protocol dispatch layer.
 * Mirrors Android BleRepositoryImpl.
 */
export class BleRepositoryImpl {
  private gattClient: BleGattClient = new BleGattClient();
  private connectState: BlueEventState = new BlueEventState(BleConnectionPhase.INITIAL);
  private connectListeners: BleConnectStateListener[] = [];
  private searchListeners: DeviceSearchListener[] = [];
  private searchPhase: DeviceSearchPhase = DeviceSearchPhase.IDLE;
  private searchDevices: DeviceItem[] = [];
  private boundDevice: BoundDevice = new BoundDevice();
  private bondName: string = '';
  private bondMac: string = '';
  private callbackStack: Map<number, PendingCallback> = new Map();
  private dailyDataListener: DailyDataListener | null = null;
  private healthDataListener: HealthDataListener | null = null;
  private examineDataCallback: ExamineDataCallback | null = null;
  private findPhoneListener: FindPhoneListener | null = null;
  private cameraShakeListener: CameraShakeListener | null = null;
  private cameraOpenListener: CameraOpenListener | null = null;
  private callControlListener: CallControlListener | null = null;
  private weatherRequestListener: WeatherRequestListener | null = null;
  private bleLogListener: BleLogListener | null = null;
  private isJlWatch: boolean = false;
  private notificationFlag: number = 0xFF;
  private initialized: boolean = false;
  private reconnectTimer: number = -1;

  constructor() {
    this.gattClient.setDataListener((data: Uint8Array, isJl: boolean): void => {
      if (isJl) {
        this.onReceiveJlResponse(data);
      } else {
        this.onReceiveResponse(data);
      }
    });
    this.gattClient.setStateListener((state: GattConnectState, _mtu: number): void => {
      if (state === GattConnectState.DISCONNECTED) {
        JLWatchManager.shared.reset();
        this.emitConnectState(new BlueEventState(BleConnectionPhase.DISCONNECTED));
        this.scheduleAutoReconnect();
      }
    });
    this.gattClient.setScanListener((devices: DeviceItem[]): void => {
      this.searchDevices = devices;
      this.emitSearchState();
    });
    this.gattClient.setLogListener((msg: string): void => {
      this.bleLogListener?.(msg);
    });
  }

  get bandConfig(): BandConfig {
    return this.boundDevice.config;
  }

  get isRoundWatch(): boolean {
    const watchType = this.boundDevice.config.watchType;
    return watchType === 4 || watchType === 5 || watchType === 0x0a;
  }

  get isJLieWatch(): boolean {
    return this.isJlWatch;
  }

  get notificationFlagValue(): number {
    return this.notificationFlag;
  }

  set notificationFlagValue(value: number) {
    this.notificationFlag = value;
    this.changeNotifySetting(value);
  }

  async initializeSdk(): Promise<void> {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    await this.gattClient.ensureBluetoothEnabled();
    if (this.bondMac.length > 0) {
      this.scheduleAutoReconnect();
    }
  }

  getConnectState(): BlueEventState {
    return this.connectState;
  }

  subscribeConnectState(listener: BleConnectStateListener): () => void {
    this.connectListeners.push(listener);
    listener(this.connectState);
    return (): void => {
      this.connectListeners = this.connectListeners.filter((item: BleConnectStateListener): boolean => item !== listener);
    };
  }

  subscribeDeviceSearch(listener: DeviceSearchListener): () => void {
    this.searchListeners.push(listener);
    listener(this.searchPhase, this.searchDevices);
    return (): void => {
      this.searchListeners = this.searchListeners.filter((item: DeviceSearchListener): boolean => item !== listener);
    };
  }

  updateBondDevice(name: string, mac: string): void {
    this.bondName = name;
    this.bondMac = mac;
    this.boundDevice.name = name;
    this.boundDevice.mac = mac;
  }

  getBondDevice(): BoundDevice {
    return this.boundDevice;
  }

  startScan(): void {
    this.searchPhase = DeviceSearchPhase.SCANNING;
    this.searchDevices = [];
    this.emitSearchState();
    this.gattClient.startScan(10000);
  }

  stopScan(): void {
    this.gattClient.stopScan();
    this.searchPhase = DeviceSearchPhase.FINISH;
    this.emitSearchState();
  }

  connectBleDevice(device: DeviceItem, timeoutMs: number = 35000, callback?: BleResultCallback): void {
    if (callback) {
      this.callbackStack.set(BleRequestId.CONNECT, callback);
    }
    this.stopScan();
    this.emitConnectState(new BlueEventState(BleConnectionPhase.CONNECTING));
    this.gattClient.connect(device, timeoutMs).then((): void => {
      this.isJlWatch = this.gattClient.hasJlService();
      this.emitConnectState(new BlueEventState(BleConnectionPhase.BLUETOOTH_CONNECTED));
      this.boundDevice.name = device.name;
      this.boundDevice.mac = device.mac.length > 0 ? device.mac : device.deviceId;
      this.getBandConfig();
    }).catch((err: Error) => {
      this.emitConnectState(new BlueEventState(BleConnectionPhase.DISCONNECTED));
      this.invokeCallback(BleRequestId.CONNECT, BleResult.failure(err.message));
    });
  }

  disconnect(): void {
    this.clearReconnectTimer();
    JLWatchManager.shared.reset();
    this.gattClient.disconnect();
    this.emitConnectState(new BlueEventState(BleConnectionPhase.DISCONNECTED));
  }

  unbindDevice(): void {
    this.bondName = '';
    this.bondMac = '';
    this.boundDevice = new BoundDevice();
    this.disconnect();
  }

  writeCommandData(data: Uint8Array): void {
    this.gattClient.writeCommand(data);
  }

  getBandConfig(): void {
    this.writeCommandData(new Uint8Array([BleCommands.BAND_CONFIG]));
  }

  getSupportedFunc(): void {
    this.writeCommandData(new Uint8Array([BleCommands.SUPPORT_FUNC]));
  }

  getUserInfo(): void {
    this.writeCommandData(new Uint8Array([BleCommands.USER_INFO]));
  }

  getSoftVersion(): void {
    this.writeCommandData(new Uint8Array([BleCommands.SOFT_VER]));
  }

  getSportData(day: number): void {
    this.writeCommandData(new Uint8Array([BleCommands.SPORT_DATA, day]));
  }

  getExamineData(callback?: ExamineDataCallback): void {
    this.examineDataCallback = callback ?? null;
    this.writeCommandData(new Uint8Array([BleCommands.EXAMINE_REQ, 0x01]));
  }

  postFindBand(callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SET_LIGHT_UP, callback);
    this.writeCommandData(new Uint8Array([BleCommands.FIND_BAND]));
  }

  postAntiLost(on: boolean, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SET_ANTI_LOST, callback);
    this.writeCommandData(new Uint8Array([BleCommands.ANTI_LOST, on ? 1 : 0]));
  }

  postLightUp(on: boolean, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SET_LIGHT_UP, callback);
    this.writeCommandData(new Uint8Array([BleCommands.LIGHT_UP, on ? 1 : 0]));
  }

  postBandReset(callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SET_ALARM, callback);
    this.writeCommandData(new Uint8Array([BleCommands.FACTORY_SET]));
  }

  postScreenSaverInterval(data: Uint8Array, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SET_SCREEN_SAVER_INTERVAL, callback);
    const payload = new Uint8Array(1 + data.length);
    payload[0] = BleCommands.SCREEN_SAVER;
    payload.set(data, 1);
    this.writeCommandData(payload);
  }

  postAlarm(data: Uint8Array, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SET_ALARM, callback);
    const payload = new Uint8Array(1 + data.length);
    payload[0] = BleCommands.ALARM;
    payload.set(data, 1);
    this.writeCommandData(payload);
  }

  postHeartRate(data: Uint8Array, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SET_HEART_RATE_SETTING, callback);
    const payload = new Uint8Array(1 + data.length);
    payload[0] = BleCommands.HEART_RATE;
    payload.set(data, 1);
    this.writeCommandData(payload);
  }

  postWeather(data: Uint8Array, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SET_ALARM, callback);
    const payload = new Uint8Array(1 + data.length);
    payload[0] = BleCommands.WEATHER;
    payload.set(data, 1);
    this.writeCommandData(payload);
  }

  postUserInfo(data: Uint8Array, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SET_ALARM, callback);
    const payload = new Uint8Array(1 + data.length);
    payload[0] = BleCommands.SET_USER_INFO;
    payload.set(data, 1);
    this.writeCommandData(payload);
  }

  postCameraState(isOn: boolean, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SET_ALARM, callback);
    this.writeCommandData(new Uint8Array([BleCommands.CAMERA_TO_BAND, isOn ? 1 : 0]));
  }

  postScreenStart(data: Uint8Array, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SEND_SCREEN_DATA, callback);
    const payload = new Uint8Array(1 + data.length);
    payload[0] = BleCommands.SCREEN_START;
    payload.set(data, 1);
    this.writeCommandData(payload);
  }

  postScreenData(data: Uint8Array, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SEND_SCREEN_DATA, callback);
    const payload = new Uint8Array(1 + data.length);
    payload[0] = BleCommands.SCREEN_DATA;
    payload.set(data, 1);
    this.writeCommandData(payload);
  }

  postScreenParams(data: Uint8Array): void {
    const payload = new Uint8Array(1 + data.length);
    payload[0] = BleCommands.SCREEN_PARAM;
    payload.set(data, 1);
    this.writeCommandData(payload);
  }

  postMarketScreenStart(data: Uint8Array, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SEND_MARKET_SCREEN_DATA, callback);
    const payload = new Uint8Array(1 + data.length);
    payload[0] = BleCommands.MARKET_START;
    payload.set(data, 1);
    this.writeCommandData(payload);
  }

  postMarketScreenData(data: Uint8Array, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SEND_MARKET_SCREEN_DATA, callback);
    const payload = new Uint8Array(1 + data.length);
    payload[0] = BleCommands.MARKET_DATA;
    payload.set(data, 1);
    this.writeCommandData(payload);
  }

  postOSPlatform(data: number, callback?: BleResultCallback): void {
    this.enqueueCallback(BleRequestId.SET_ALARM, callback);
    this.writeCommandData(new Uint8Array([BleCommands.OS_PLATFORM, data]));
  }

  postLanguage(data: Uint8Array): void {
    const payload = new Uint8Array(1 + data.length);
    payload[0] = BleCommands.LANGUAGE;
    payload.set(data, 1);
    this.writeCommandData(payload);
  }

  changeNotifySetting(value: number): void {
    this.writeCommandData(new Uint8Array([BleCommands.NOTIFY_FLAG, value]));
  }

  setDailyDataListener(listener: DailyDataListener | null): void {
    this.dailyDataListener = listener;
  }

  removeDailyDataListener(): void {
    this.dailyDataListener = null;
  }

  setHealthDataListener(listener: HealthDataListener | null): void {
    this.healthDataListener = listener;
  }

  setFindPhoneListener(listener: FindPhoneListener | null): void {
    this.findPhoneListener = listener;
  }

  setCameraShakeListener(listener: CameraShakeListener | null): void {
    this.cameraShakeListener = listener;
  }

  setCameraOpenListener(listener: CameraOpenListener | null): void {
    this.cameraOpenListener = listener;
  }

  setCallControlListener(listener: CallControlListener | null): void {
    this.callControlListener = listener;
  }

  setWeatherRequestListener(listener: WeatherRequestListener | null): void {
    this.weatherRequestListener = listener;
  }

  addBleLogListener(listener: BleLogListener | null): void {
    this.bleLogListener = listener;
  }

  bleStateToConnected(): void {
    this.gattClient.markReady();
    this.emitConnectState(new BlueEventState(BleConnectionPhase.BLUETOOTH_READY, this.boundDevice));
    this.invokeCallback(BleRequestId.CONNECT, BleResult.success('Connection successful'));
  }

  private onReceiveResponse(data: Uint8Array): void {
    if (data.length === 0) {
      return;
    }
    const command = data[0];
    switch (command) {
      case BleCommands.BAND_CONFIG:
        this.processBasicConfig(data);
        break;
      case BleCommands.SUPPORT_FUNC:
        this.processSupportedFunc(data);
        break;
      case BleCommands.USER_INFO:
        this.processUserInfo(data);
        break;
      case BleCommands.SPORT_DATA:
        this.parseDailyData(data);
        break;
      case BleCommands.EXAMINE_RESP:
        this.parseExamineData(data);
        break;
      case BleCommands.ANTI_LOST:
        this.invokeCallback(BleRequestId.SET_ANTI_LOST, BleResult.success());
        break;
      case BleCommands.LIGHT_UP:
      case BleCommands.WATCH_LIGHT_UP:
        this.invokeCallback(BleRequestId.SET_LIGHT_UP, BleResult.success());
        break;
      case BleCommands.SCREEN_SAVER:
        this.invokeCallback(BleRequestId.SET_SCREEN_SAVER_INTERVAL, BleResult.success());
        break;
      case BleCommands.HEART_RATE:
        this.invokeCallback(BleRequestId.SET_HEART_RATE_SETTING, BleResult.success());
        break;
      case BleCommands.ALARM:
        this.invokeCallback(BleRequestId.SET_ALARM, BleResult.success());
        break;
      case BleCommands.SCREEN_DATA:
        this.invokeCallback(BleRequestId.SEND_SCREEN_DATA, BleResult.success());
        break;
      case BleCommands.MARKET_DATA:
        this.invokeCallback(BleRequestId.SEND_MARKET_SCREEN_DATA, BleResult.success());
        break;
      case BleCommands.SWITCH_WATCH:
        this.invokeCallback(BleRequestId.COMMAND_SWITCH_WATCH, BleResult.success());
        break;
      case BleCommands.REJECT_CALL:
        if (data.length > 1) {
          this.callControlListener?.(toUnsignedByte(data[1]) === 2);
        }
        break;
      case BleCommands.FIND_PHONE:
        this.findPhoneListener?.(true);
        break;
      case BleCommands.CAMERA_TO_BAND:
        this.cameraShakeListener?.(true);
        break;
      case BleCommands.CAMERA_OPEN:
        if (data.length > 1) {
          this.cameraOpenListener?.(toUnsignedByte(data[1]) === 0);
        }
        break;
      case BleCommands.WEATHER_REQ:
        this.weatherRequestListener?.();
        break;
      default:
        break;
    }
  }

  private onReceiveJlResponse(data: Uint8Array): void {
    JLWatchManager.shared.notifyReceivedData(data);
  }

  private processBasicConfig(data: Uint8Array): void {
    if (data.length < 12) {
      return;
    }
    const cfg = this.boundDevice.config;
    cfg.hrInterval = toUnsignedByte(data[1]);
    cfg.hrFlag = toUnsignedByte(data[2]);
    cfg.hrAlarmFlag = toUnsignedByte(data[3]);
    cfg.hrUp = toUnsignedByte(data[4]);
    cfg.hrDown = toUnsignedByte(data[5]);
    cfg.gestureUp = toUnsignedByte(data[6]) & 0x01;
    cfg.screenSaver = toUnsignedByte(data[7]);
    cfg.alarmHour = toUnsignedByte(data[8]);
    cfg.alarmMinute = toUnsignedByte(data[9]);
    cfg.alarmFlag = toUnsignedByte(data[10]);
    cfg.notifyFlag = (toUnsignedByte(data[11]) & 0xFFFF) | ((toUnsignedByte(data[12]) & 0xFFFF) << 8);
    if (data.length > 15) {
      cfg.watchType = toUnsignedByte(data[15]);
    }
    this.notificationFlag = cfg.notifyFlag;
    this.getSupportedFunc();
  }

  private processSupportedFunc(data: Uint8Array): void {
    if (data.length <= 2) {
      this.getUserInfo();
      return;
    }
    const cfg = this.boundDevice.config;
    const flag = toUnsignedByte(data[1]);
    const flag2 = toUnsignedByte(data[2]);
    cfg.hasTheme = ((flag >> 3) & 0x01) === 1;
    cfg.moreTheme = ((flag >> 5) & 0x01) === 1;
    cfg.canSetTimeFormat = ((flag >> 6) & 0x01) === 1;
    cfg.hasLongSaver = ((flag >> 7) & 0x01) === 1;
    cfg.hasHeadset = ((flag2 >> 2) & 0x01) === 1;
    if (data.length > 4) {
      if (toUnsignedByte(data[3]) !== 0) {
        cfg.jlCustomWatchSuffix = `WATCH${toUnsignedByte(data[3])}`;
      }
      if (toUnsignedByte(data[4]) !== 0) {
        cfg.jlDialMarketSuffix = `WATCH${toUnsignedByte(data[4])}`;
      }
    }
    this.getUserInfo();
  }

  private processUserInfo(data: Uint8Array): void {
    if (data.length > 8) {
      const cfg = this.boundDevice.config;
      cfg.sexType = toUnsignedByte(data[1]);
      cfg.age = toUnsignedByte(data[2]);
      cfg.height = toUnsignedByte(data[3]);
      cfg.weight = toUnsignedByte(data[4]);
      cfg.stepTarget = toUnsignedByte(data[5]) | (toUnsignedByte(data[6]) << 8) | (toUnsignedByte(data[7]) << 16);
      cfg.timeStyle = toUnsignedByte(data[8]);
    }
    if (this.isJlWatch) {
      this.startJlAuth();
    } else {
      this.bleStateToConnected();
    }
  }

  private startJlAuth(): void {
    const deviceId = this.gattClient.getConnectedDeviceId();
    if (deviceId.length === 0) {
      this.bleLogListener?.('JL auth skipped: no connected device');
      this.bleStateToConnected();
      return;
    }
    JLWatchManager.shared.setupDevice(
      deviceId,
      this.gattClient.getConnectedDeviceName() || this.boundDevice.name,
      (payload: Uint8Array): boolean => this.gattClient.writeJlCommand(payload),
      {
        onAuthSuccess: (): void => {
          this.bleLogListener?.('JL RCSP auth succeeded');
          this.bleStateToConnected();
        },
        onAuthFailed: (): void => {
          this.bleLogListener?.('JL RCSP auth failed');
          this.invokeCallback(BleRequestId.CONNECT, BleResult.failure('JL auth failed'));
          this.disconnect();
        },
        onLog: (msg: string): void => {
          this.bleLogListener?.(msg);
        }
      }
    );
  }

  private parseDailyData(data: Uint8Array): void {
    if (!this.dailyDataListener) {
      return;
    }
    if (data.length < 8) {
      this.dailyDataListener(new BleDataResult(0, null, 'Data is invalid'));
      return;
    }
    const payload = new BleDailyPayload();
    payload.step = (toUnsignedByte(data[2]) << 8) | toUnsignedByte(data[3]);
    payload.deepHour = toUnsignedByte(data[4]);
    payload.deepMin = toUnsignedByte(data[5]);
    payload.lowHour = toUnsignedByte(data[6]);
    payload.lowMin = toUnsignedByte(data[7]);
    if (data.length > 8) {
      payload.wakeTime = toUnsignedByte(data[8]);
    }
    this.dailyDataListener(new BleDataResult(200, payload, 'Success'));
  }

  private parseExamineData(data: Uint8Array): void {
    const payload = new BleExaminePayload();
    if (data.length >= 6) {
      payload.heartRate = toUnsignedByte(data[1]);
      payload.lowPressure = toUnsignedByte(data[2]);
      payload.highPressure = toUnsignedByte(data[3]);
      payload.oxygen = toUnsignedByte(data[4]);
      payload.fatigueIndex = toUnsignedByte(data[5]);
    }
    const result = new BleDataResult(
      data.length >= 6 ? 200 : 1,
      data.length >= 6 ? payload : null,
      data.length >= 6 ? 'Success' : 'Data is invalid'
    );
    this.healthDataListener?.(result);
    this.examineDataCallback?.(result);
    this.examineDataCallback = null;
  }

  private enqueueCallback(requestId: number, callback?: BleResultCallback): void {
    if (callback) {
      this.callbackStack.set(requestId, callback);
    }
  }

  private invokeCallback(requestId: number, result: BleResult): void {
    const callback = this.callbackStack.get(requestId);
    if (callback) {
      this.callbackStack.delete(requestId);
      callback(result);
    }
  }

  private emitConnectState(state: BlueEventState): void {
    this.connectState = state;
    this.connectListeners.forEach((listener: BleConnectStateListener): void => {
      listener(state);
    });
  }

  private emitSearchState(): void {
    this.searchListeners.forEach((listener: DeviceSearchListener): void => {
      listener(this.searchPhase, this.searchDevices);
    });
  }

  private scheduleAutoReconnect(): void {
    if (this.bondMac.length === 0) {
      return;
    }
    this.clearReconnectTimer();
    this.reconnectTimer = setTimeout((): void => {
      this.startScan();
    }, 3000);
  }

  private clearReconnectTimer(): void {
    if (this.reconnectTimer >= 0) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = -1;
    }
  }
}

export const bleRepository: BleRepositoryImpl = new BleRepositoryImpl();
