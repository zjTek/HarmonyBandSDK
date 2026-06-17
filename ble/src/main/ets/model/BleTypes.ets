export class BandConfig {
  screenSaver: number = 5;
  watchType: number = 1;
  alarmFlag: number = 0;
  alarmHour: number = 7;
  alarmMinute: number = 30;
  hrAlarmFlag: number = 0;
  hrFlag: number = 0;
  hrUp: number = 120;
  hrDown: number = 50;
  hrInterval: number = 60;
  sexType: number = 0;
  age: number = 28;
  height: number = 170;
  weight: number = 65;
  stepTarget: number = 7000;
  gestureUp: number = 0;
  notifyFlag: number = 0xFF;
  hasTheme: boolean = false;
  moreTheme: boolean = false;
  canSetTimeFormat: boolean = false;
  hasLongSaver: boolean = false;
  hasHeadset: boolean = false;
  timeStyle: number = 0;
  softVer: string = '';
  jlCustomWatchSuffix: string = 'WATCH5';
  jlDialMarketSuffix: string = 'WATCH6';
}

export enum BleConnectionPhase {
  INITIAL = 0,
  CONNECTING = 1,
  BLUETOOTH_CONNECTED = 2,
  BLUETOOTH_READY = 3,
  DISCONNECTED = 4
}

export enum DeviceSearchPhase {
  IDLE = 0,
  SCANNING = 1,
  FINISH = 2
}

export class BoundDevice {
  name: string = '';
  mac: string = '';
  config: BandConfig = new BandConfig();

  constructor(name: string = '', mac: string = '') {
    this.name = name;
    this.mac = mac;
  }
}

export class DeviceItem {
  name: string = '';
  mac: string = '';
  deviceId: string = '';
  rssi: number = 0;

  constructor(name: string = '', mac: string = '', rssi: number = 0, deviceId: string = '') {
    this.name = name;
    this.mac = mac;
    this.rssi = rssi;
    this.deviceId = deviceId.length > 0 ? deviceId : mac;
  }
}

export class BlueEventState {
  phase: BleConnectionPhase = BleConnectionPhase.INITIAL;
  device: BoundDevice | null = null;

  constructor(phase: BleConnectionPhase = BleConnectionPhase.INITIAL, device: BoundDevice | null = null) {
    this.phase = phase;
    this.device = device;
  }

  isReady(): boolean {
    return this.phase === BleConnectionPhase.BLUETOOTH_READY;
  }

  isConnecting(): boolean {
    return this.phase === BleConnectionPhase.CONNECTING ||
      this.phase === BleConnectionPhase.BLUETOOTH_CONNECTED;
  }
}

export class BleResult {
  code: number = 0;
  message: string = '';

  constructor(code: number = 0, message: string = '') {
    this.code = code;
    this.message = message;
  }

  static success(message: string = 'Success'): BleResult {
    return new BleResult(0, message);
  }

  static failure(message: string): BleResult {
    return new BleResult(-1, message);
  }
}

export class BleDailyPayload {
  date: number = 0;
  step: number = 0;
  deepHour: number = 0;
  deepMin: number = 0;
  lowHour: number = 0;
  lowMin: number = 0;
  wakeTime: number = 0;
}

export class BleExaminePayload {
  heartRate: number = 0;
  oxygen: number = 0;
  highPressure: number = 0;
  lowPressure: number = 0;
  fatigueIndex: number = 0;
}

export class BleDataResult<T> {
  code: number = 0;
  data: T | null = null;
  message: string = '';

  constructor(code: number = 0, data: T | null = null, message: string = '') {
    this.code = code;
    this.data = data;
    this.message = message;
  }
}

export type BleConnectStateListener = (state: BlueEventState) => void;
export type BleResultCallback = (result: BleResult) => void;
export type DailyDataListener = (result: BleDataResult<BleDailyPayload>) => void;
export type ExamineDataCallback = (result: BleDataResult<BleExaminePayload>) => void;
export type HealthDataListener = (result: BleDataResult<BleExaminePayload>) => void;
export type DeviceSearchListener = (phase: DeviceSearchPhase, devices: DeviceItem[]) => void;
export type BleLogListener = (message: string) => void;
export type FindPhoneListener = (active: boolean) => void;
export type CameraShakeListener = (active: boolean) => void;
export type CameraOpenListener = (open: boolean) => void;
export type CallControlListener = (accept: boolean) => void;
export type WeatherRequestListener = () => void;

export class BaseBleResponse<T> {
  code: number = 0;
  message: string = '';
  data: T | null = null;

  constructor(code: number = 0, message: string = '', data: T | null = null) {
    this.code = code;
    this.message = message;
    this.data = data;
  }
}
