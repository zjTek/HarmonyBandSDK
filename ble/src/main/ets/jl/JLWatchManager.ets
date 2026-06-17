import { JLAuth, JL_RCSP } from 'lib_rcsp';

const TAG: string = 'JLWatchManager';
const SUPPORT_RESET_FLAG: boolean = true;

export interface JLWatchAuthCallbacks {
  onAuthSuccess: () => void;
  onAuthFailed: () => void;
  onLog?: (message: string) => void;
}

/**
 * Jieli RCSP auth manager for JL-chip PowerBand watches.
 * Mirrors Android JLWatchManager auth flow using HarmonyOS jl-auth HAR.
 */
export class JLWatchManager {
  private static readonly instance: JLWatchManager = new JLWatchManager();

  static get shared(): JLWatchManager {
    return JLWatchManager.instance;
  }

  private auth: JLAuth.Auth | null = null;
  private rcspImpl: JL_RCSP.RcspImpl | null = null;
  private isAuthPass: boolean = false;
  private deviceId: string = '';
  private deviceName: string = '';
  private writeJlData: ((data: Uint8Array) => boolean) | null = null;
  private callbacks: JLWatchAuthCallbacks | null = null;

  isAuthenticated(): boolean {
    return this.isAuthPass;
  }

  getDeviceId(): string {
    return this.deviceId;
  }

  /**
   * Start JL device authentication after PowerBand handshake completes.
   * Called when AE00 JL GATT service is present (Jieli watch chip).
   */
  setupDevice(deviceId: string, deviceName: string, writeJl: (data: Uint8Array) => boolean,
    callbacks: JLWatchAuthCallbacks): void {
    this.reset();
    this.deviceId = deviceId;
    this.deviceName = deviceName;
    this.writeJlData = writeJl;
    this.callbacks = callbacks;
    this.log(`Starting JL auth for ${deviceId}`);

    this.auth = new JLAuth.Auth();
    const authListener: JLAuth.AuthListener = {
      onSendData: (_devId: string, data: ArrayBuffer): void => {
        const sent = this.writeJlData?.(new Uint8Array(data)) ?? false;
        if (!sent) {
          this.log('JL auth sendData failed — JL TX characteristic unavailable');
        }
      },
      onAuthSuccess: (): void => {
        this.log('JL auth success');
        this.isAuthPass = true;
        this.auth = null;
        this.initRcsp();
        this.callbacks?.onAuthSuccess();
      },
      onAuthFailed: (): void => {
        this.log('JL auth failed');
        this.isAuthPass = false;
        this.auth?.stopAuth();
        this.auth = null;
        this.callbacks?.onAuthFailed();
      }
    };
    this.auth.startAuth(deviceId, authListener, SUPPORT_RESET_FLAG);
  }

  /** Route inbound JL GATT notify data through auth or RCSP. */
  notifyReceivedData(data: Uint8Array): void {
    if (this.deviceId.length === 0 || data.length === 0) {
      return;
    }
    if (!this.isAuthPass && this.auth) {
      this.auth.handlerAuth(this.deviceId, data.buffer);
      return;
    }
    if (this.isAuthPass && this.rcspImpl) {
      this.rcspImpl.transmitDeviceData(new JL_RCSP.BtDevice(this.deviceId, this.deviceName), data);
    }
  }

  /** Reset auth state on disconnect (mirrors Android changeAuthState). */
  changeAuthState(authed: boolean): void {
    this.isAuthPass = authed;
    if (!authed) {
      this.teardownRcsp();
    }
  }

  /** Tear down auth and RCSP session. */
  reset(): void {
    this.auth?.stopAuth();
    this.auth = null;
    this.teardownRcsp();
    this.isAuthPass = false;
    this.deviceId = '';
    this.deviceName = '';
    this.writeJlData = null;
    this.callbacks = null;
  }

  /** Send data on JL RCSP channel (post-auth). Returns false if not ready. */
  sendRcspData(data: Uint8Array): boolean {
    if (!this.isAuthPass || !this.writeJlData) {
      return false;
    }
    return this.writeJlData(data);
  }

  getRcspImpl(): JL_RCSP.RcspImpl | null {
    return this.rcspImpl;
  }

  private initRcsp(): void {
    this.teardownRcsp();
    this.rcspImpl = new JL_RCSP.RcspImpl();
    this.rcspImpl.setOnSendDataCallback({
      sendDataToDevice: (_device: JL_RCSP.BtDevice, payload: Uint8Array): boolean => {
        return this.writeJlData?.(payload) ?? false;
      }
    });
    this.rcspImpl.transmitDeviceState(
      new JL_RCSP.BtDevice(this.deviceId, this.deviceName),
      JL_RCSP.ConnectState.CONNECTED
    );
    this.log('JL RCSP initialized');
  }

  private teardownRcsp(): void {
    if (this.rcspImpl) {
      this.rcspImpl.setOnSendDataCallback(undefined);
      this.rcspImpl.transmitDeviceState(
        new JL_RCSP.BtDevice(this.deviceId, this.deviceName),
        JL_RCSP.ConnectState.DISCONNECT
      );
      this.rcspImpl.destroy();
      this.rcspImpl = null;
    }
  }

  private log(message: string): void {
    console.info(TAG, message);
    this.callbacks?.onLog?.(message);
  }
}
