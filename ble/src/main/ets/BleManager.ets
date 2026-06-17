import { bleRepository } from './impl/BleRepositoryImpl';
import {
  BandConfig,
  BleConnectStateListener,
  BleLogListener,
  BleResultCallback,
  BlueEventState,
  BoundDevice,
  CallControlListener,
  CameraOpenListener,
  CameraShakeListener,
  DailyDataListener,
  DeviceItem,
  DeviceSearchPhase,
  ExamineDataCallback,
  FindPhoneListener,
  HealthDataListener,
  WeatherRequestListener
} from './model/BleTypes';

/**
 * Public SDK facade — mirrors Android com.longtxt.core.ble.BleManager.
 */
export class BleManager {
  static readonly isStubSdk: boolean = false;

  static get bandConfig(): BandConfig {
    return bleRepository.bandConfig;
  }

  static get isRoundWatch(): boolean {
    return bleRepository.isRoundWatch;
  }

  static get isJLieWatch(): boolean {
    return bleRepository.isJLieWatch;
  }

  static get notificationFlag(): number {
    return bleRepository.notificationFlagValue;
  }

  static set notificationFlag(value: number) {
    bleRepository.notificationFlagValue = value;
  }

  static initializeSdk(): Promise<void> {
    return bleRepository.initializeSdk();
  }

  static getConnectState(): BlueEventState {
    return bleRepository.getConnectState();
  }

  static subscribeConnectState(listener: BleConnectStateListener): () => void {
    return bleRepository.subscribeConnectState(listener);
  }

  static subscribeDeviceSearch(listener: (phase: DeviceSearchPhase, devices: DeviceItem[]) => void): () => void {
    return bleRepository.subscribeDeviceSearch(listener);
  }

  static updateBondDevice(name: string, mac: string): void {
    bleRepository.updateBondDevice(name, mac);
  }

  static getBondDevice(): BoundDevice {
    return bleRepository.getBondDevice();
  }

  static startScan(): void {
    bleRepository.startScan();
  }

  static stopScan(): void {
    bleRepository.stopScan();
  }

  static connectBleDevice(device: DeviceItem, timeoutMs: number = 35000, callback?: BleResultCallback): void {
    bleRepository.connectBleDevice(device, timeoutMs, callback);
  }

  static disconnect(): void {
    bleRepository.disconnect();
  }

  static unbindDevice(): void {
    bleRepository.unbindDevice();
  }

  static getBandConfig(): void {
    bleRepository.getBandConfig();
  }

  static getSupportedFunc(): void {
    bleRepository.getSupportedFunc();
  }

  static getUserInfo(): void {
    bleRepository.getUserInfo();
  }

  static getSoftVersion(): void {
    bleRepository.getSoftVersion();
  }

  static getSportData(day: number): void {
    bleRepository.getSportData(day);
  }

  static getExamineData(callback?: ExamineDataCallback): void {
    bleRepository.getExamineData(callback);
  }

  static postFindBand(callback?: BleResultCallback): void {
    bleRepository.postFindBand(callback);
  }

  static postAntiLost(enabled: boolean, callback?: BleResultCallback): void {
    bleRepository.postAntiLost(enabled, callback);
  }

  static postLightUp(enabled: boolean, callback?: BleResultCallback): void {
    bleRepository.postLightUp(enabled, callback);
  }

  static postBandReset(callback?: BleResultCallback): void {
    bleRepository.postBandReset(callback);
  }

  static postScreenSaverInterval(data: Uint8Array, callback?: BleResultCallback): void {
    bleRepository.postScreenSaverInterval(data, callback);
  }

  static postAlarm(data: Uint8Array, callback?: BleResultCallback): void {
    bleRepository.postAlarm(data, callback);
  }

  static postHeartRate(data: Uint8Array, callback?: BleResultCallback): void {
    bleRepository.postHeartRate(data, callback);
  }

  static postWeather(data: Uint8Array, callback?: BleResultCallback): void {
    bleRepository.postWeather(data, callback);
  }

  static postUserInfo(data: Uint8Array, callback?: BleResultCallback): void {
    bleRepository.postUserInfo(data, callback);
  }

  static postCameraState(isOn: boolean, callback?: BleResultCallback): void {
    bleRepository.postCameraState(isOn, callback);
  }

  static postScreenStart(data: Uint8Array, callback?: BleResultCallback): void {
    bleRepository.postScreenStart(data, callback);
  }

  static postScreenData(data: Uint8Array, callback?: BleResultCallback): void {
    bleRepository.postScreenData(data, callback);
  }

  static postScreenParams(data: Uint8Array): void {
    bleRepository.postScreenParams(data);
  }

  static postMarketScreenStart(data: Uint8Array, callback?: BleResultCallback): void {
    bleRepository.postMarketScreenStart(data, callback);
  }

  static postMarketScreenData(data: Uint8Array, callback?: BleResultCallback): void {
    bleRepository.postMarketScreenData(data, callback);
  }

  static postOSPlatform(data: number, callback?: BleResultCallback): void {
    bleRepository.postOSPlatform(data, callback);
  }

  static postLanguage(data: Uint8Array): void {
    bleRepository.postLanguage(data);
  }

  static writeCommandData(data: Uint8Array): void {
    bleRepository.writeCommandData(data);
  }

  static setDailyDataListener(listener: DailyDataListener | null): void {
    bleRepository.setDailyDataListener(listener);
  }

  static removeDailyDataListener(): void {
    bleRepository.removeDailyDataListener();
  }

  static setHealthDataListener(listener: HealthDataListener | null): void {
    bleRepository.setHealthDataListener(listener);
  }

  static setFindPhoneListener(listener: FindPhoneListener | null): void {
    bleRepository.setFindPhoneListener(listener);
  }

  static setCameraShakeListener(listener: CameraShakeListener | null): void {
    bleRepository.setCameraShakeListener(listener);
  }

  static setCameraOpenListener(listener: CameraOpenListener | null): void {
    bleRepository.setCameraOpenListener(listener);
  }

  static setCallControlListener(listener: CallControlListener | null): void {
    bleRepository.setCallControlListener(listener);
  }

  static setWeatherRequestListener(listener: WeatherRequestListener | null): void {
    bleRepository.setWeatherRequestListener(listener);
  }

  static addBleLogListener(listener: BleLogListener | null): void {
    bleRepository.addBleLogListener(listener);
  }
}
