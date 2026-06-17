import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BleManager } from 'ble';

const DOMAIN = 0x5100;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    BleManager.initializeSdk().then((): void => {
      hilog.info(DOMAIN, 'BandSDK', 'BLE SDK initialized');
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'BandSDK', 'Failed to load MainPage: %{public}s', JSON.stringify(err));
      }
    });
  }
}
