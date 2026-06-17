/** PowerBand GATT service and characteristic UUIDs (mirrors Android BlePeripheral). */
export class BleUuids {
  static readonly MAIN_SERVICE: string = '66880000-0000-1000-8000-008012563489';
  static readonly TX_CHAR: string = '66880001-0000-1000-8000-008012563489';
  static readonly RX_CHAR: string = '66880002-0000-1000-8000-008012563489';
  static readonly JL_SERVICE: string = '0000AE00-0000-1000-8000-00805F9B34FB';
  static readonly JL_TX: string = '0000AE01-0000-1000-8000-00805F9B34FB';
  static readonly JL_RX: string = '0000AE02-0000-1000-8000-00805F9B34FB';
  static readonly CCC_DESCRIPTOR: string = '00002902-0000-1000-8000-00805F9B34FB';
  static readonly MAX_MTU: number = 517;
  static readonly DEFAULT_MTU: number = 23;
  static readonly REQUEST_MTU: number = 517;
}

/** Band command byte protocol (mirrors Android BLEConstants). */
export class BleCommands {
  static readonly SPORT_DATA: number = 0x01;
  static readonly LANGUAGE: number = 0x02;
  static readonly ALARM: number = 0x03;
  static readonly CAMERA_TO_BAND: number = 0x06;
  static readonly ANTI_LOST: number = 0x07;
  static readonly FIND_BAND: number = 0x08;
  static readonly NOTIFY_FLAG: number = 0x09;
  static readonly OS_PLATFORM: number = 0x0a;
  static readonly FACTORY_SET: number = 0x0b;
  static readonly OFF_CALL: number = 0x12;
  static readonly HEART_RATE: number = 0x0f;
  static readonly WEATHER: number = 0x1a;
  static readonly EXAMINE_REQ: number = 0x1d;
  static readonly LIGHT_UP: number = 0x1e;
  static readonly SCREEN_SAVER: number = 0x1f;
  static readonly SCREEN_DATA: number = 0x2d;
  static readonly SCREEN_START: number = 0x2e;
  static readonly MARKET_DATA: number = 0x2f;
  static readonly MARKET_START: number = 0x30;
  static readonly SCREEN_PARAM: number = 0x31;
  static readonly FIND_PHONE: number = 0x32;
  static readonly CAMERA_OPEN: number = 0x33;
  static readonly TIME_FORMAT: number = 0x34;
  static readonly USER_INFO: number = 0x35;
  static readonly BAND_CONFIG: number = 0x22;
  static readonly SUPPORT_FUNC: number = 0x28;
  static readonly REJECT_CALL: number = 0x23;
  static readonly SET_USER_INFO: number = 0x25;
  static readonly EXAMINE_RESP: number = 0x10;
  static readonly IM: number = 0x21;
  static readonly IS_INITIAL_CON: number = 0x3a;
  static readonly SOFT_VER: number = 0x39;
  static readonly HEADSET_MAC: number = 0x3c;
  static readonly WATCH_LIGHT_UP: number = 0x37;
  static readonly SWITCH_WATCH: number = 0x3E;
  static readonly WEATHER_REQ: number = 0x3F;
}

export enum BleRequestId {
  CONNECT = 1000,
  SET_ALARM = 1001,
  SET_ANTI_LOST = 1002,
  SET_LIGHT_UP = 1003,
  SET_SCREEN_SAVER_INTERVAL = 1004,
  SET_HEART_RATE_SETTING = 1005,
  SEND_SCREEN_DATA = 1006,
  SEND_MARKET_SCREEN_DATA = 1007,
  GET_HEADSET_MAC_ADDRESS = 1008,
  COMMAND_SWITCH_WATCH = 1009
}

export function toUnsignedByte(value: number): number {
  return value & 0xFF;
}

export function bytesToHex(data: Uint8Array): string {
  return Array.from(data).map((b: number): string => b.toString(16).padStart(2, '0')).join(' ');
}
