// src/main/ets/pages/Index.ets
import { SensorData, ZoneData } from '../viewmodel/SmartShedBean';
import { LogType, MqttReceiverClient } from '../service/MqttReceiverClient';
import { HdsNavigation, HdsTabs, ScrollEffectType } from '@hms.hds.hdsBaseComponent';
import { curves, display, LengthMetrics, promptAction } from '@kit.ArkUI';
import { BlurStrategy, hdsMaterial, HdsNavigationTitleMode, HdsTabsController } from '@kit.UIDesignKit';
import { ManualPage } from '../view/ManualPage';
import { AutoPage } from '../view/AutoPage';
import { vibration } from '../service/vibration';
import { consolePage } from './console';
import { LogMessage } from '../viewmodel/ConsoleBean';

export class GlobalLogBus {
  private static onLogEmit: ((type: LogType, content: string) => void) | null = null;

  public static register(cb: (type: LogType, content: string) => void) {
    GlobalLogBus.onLogEmit = cb;
  }
  public static unregister() {
    GlobalLogBus.onLogEmit = null;
  }

  public static emit(type: LogType, content: string) {
    if (GlobalLogBus.onLogEmit) {
      GlobalLogBus.onLogEmit(type, content);
    }
  }
}

AppStorage.setOrCreate('isBoardRgbConnected', false);
AppStorage.setOrCreate('isBoardSoiConnected', false);
AppStorage.setOrCreate('autoEnabled', false);
AppStorage.setOrCreate('autoEnabled', false);
AppStorage.setOrCreate('temp', 28);
AppStorage.setOrCreate('hum', 50);
AppStorage.setOrCreate('intensity', 134);
AppStorage.setOrCreate('moisture', 50);
AppStorage.setOrCreate('fanValue', 0);
AppStorage.setOrCreate('waterPumpValue', 0);
AppStorage.setOrCreate('ledValue', 0);
AppStorage.setOrCreate('zone1', new ZoneData());

@Entry
@Component
struct Index {
  private TabBarController: HdsTabsController = new HdsTabsController();
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();
  @StorageLink("vibrationON") vibrationON: boolean = true;
  @State navBarWidth: string | number = '100%';
  @StorageLink("isWideScreen") isWideScreen: boolean = true;

  @StorageLink('isBoardRgbConnected') isBoardRgbConnected: boolean = false;
  @StorageLink('isBoardSoiConnected') isBoardSoiConnected: boolean = false;
  @StorageLink('autoEnabled') autoEnabled: boolean = false;
  @StorageLink('temp') temp: number = 28;
  @StorageLink('hum') hum: number = 50;
  @StorageLink('intensity') intensity: number = 134;
  @StorageLink('moisture') moisture: number = 50;
  @StorageLink('fanValue') fanValue: number = 0;
  @StorageLink('waterPumpValue') waterPumpValue: number = 0;
  @StorageLink('ledValue') ledValue: number = 0;
  @StorageLink('zone1') zone1: ZoneData = new ZoneData();

  @StorageLink("lightIntensity") lightIntensity: number = 10;
  @State animStep1: boolean = false;
  @State animStep2: boolean = false;
  @State animStep3: boolean = false;
  @State logList: LogMessage[] = [];

  private mqttClient!: MqttReceiverClient;

  private toggleSplitMode(isSplit: boolean) {
    animateTo({
      curve: curves.springMotion(0.4, 0.8),
      duration: 400
    }, () => {
      this.navBarWidth = isSplit ? '40%' : '100%';
    })
  }

  aboutToAppear(): void {
    GlobalLogBus.register((type: LogType, content: string) => {
      const now = new Date();
      const timeStr = `${now.getHours()}:${now.getMinutes()}:${now.getSeconds()}`;
      this.logList.push({ id: Date.now(), time: timeStr, type, content });
      if (this.logList.length > 100) this.logList.shift();
    });

    try {
      this.mqttClient = new MqttReceiverClient((topic: string, payload: string) => {
        this.onMqttMessage(topic, payload);
      });

      this.mqttClient.setLogCallback((type: LogType, content: string) => {
        GlobalLogBus.emit(type, content);
      });

      this.mqttClient.onStart();
    } catch (error) {
      console.error(`[App] 初始化失败: ${JSON.stringify(error)}`);
      this.isBoardRgbConnected = false;
      this.isBoardSoiConnected = false;
      promptAction.showToast({ message: '板端通讯组件初始化失败', duration: 3000 });
    }
    if(this.isWideScreen) { this.toggleSplitMode(true); this.pageStack.pushPathByName("ConsolePage", null);}
    else this.toggleSplitMode(false);
  }

  aboutToDisappear(): void {
    this.zone1.isExit = true;
    GlobalLogBus.unregister();
    if (this.zone1.autoManagerThread !== null) {
      clearInterval(this.zone1.autoManagerThread);
      this.zone1.autoManagerThread = null;
    }
    if (this.mqttClient) {
      this.mqttClient.disconnect();
    }
  }

  onBackPress(): boolean | void {
    if(this.vibrationON) vibration.dotVibration()
    if (this.pageStack.size() > 0) {
      this.pageStack.pop();
      if (this.pageStack.size() === 0) {
        this.toggleSplitMode(false);
      }
      return true;
    }
  }

  private onMqttMessage(topic: string, payload: string): void {
    console.info(`[App] MQTT收到 -> Topic: ${topic}, Payload: ${payload}`);

    try {
      const data: SensorData = JSON.parse(payload);

      switch (topic) {
        case 'Rayawa/rgb/light_intensity':
          this.isBoardRgbConnected = true;
          if (data.intensity !== undefined) {
            const val = Number(data.intensity);
            this.intensity = val;
            this.zone1.bean.intensity = val;
          }
          break;

        case 'Rayawa/rgb/temp_and_hum':
          this.isBoardRgbConnected = true;
          if (data.temp !== undefined) {
            const tVal = Number(data.temp);
            this.temp = tVal;
            this.zone1.bean.temp = tVal;
          }
          if (data.hum !== undefined) {
            const hVal = Number(data.hum);
            this.hum = hVal;
            this.zone1.bean.hum = hVal;
          }
          break;

        case 'Rayawa/soi/soil_moisture':
          this.isBoardSoiConnected = true;
          if (data.moisture !== undefined) {
            const val = Number(data.moisture);
            this.moisture = val;
            this.zone1.bean.moisture = val;
          }
          break;

        default:
          console.warn(`[App] 未知或无需直接解析的 Topic: ${topic}`);
          break;
      }

    } catch (e) {
      console.error(`[App] JSON解析失败: ${JSON.stringify(e)}`);
    }
  }

  @Builder
  PageMap(name: string) {
    if (name === "ConsolePage") {
      consolePage({
        logList: this.logList,
        onCloseSplit: () => {
          this.isWideScreen = px2vp(display.getDefaultDisplaySync().width)>600? true: false;
          animateTo({
            curve: curves.springMotion(0.4, 0.8),
            duration: 350
          }, () => {
            this.navBarWidth= '100%';
          })
        }
      })
    }
  }
  @State currentTabIndex: number = 0;

  build() {
    HdsNavigation(this.pageStack) {
      HdsTabs({ controller: this.TabBarController }) {
        TabContent() {
          ManualPage({ mqttClient: this.mqttClient, isVisible: this.currentTabIndex === 0 })
        }
        .tabBar(new BottomTabBarStyle($r('sys.media.wifi_router_fill'), "自定义模式"))

        TabContent() {
          AutoPage({ mqttClient: this.mqttClient, isVisible: this.currentTabIndex === 1 })
        }
        .tabBar(new BottomTabBarStyle($r('sys.media.wifi_router_fill'), "智能模式"))
      }
      .onChange((index: number) => {
        if(this.vibrationON) vibration.dotVibration();
        this.currentTabIndex = index;
      })
      .blurStrategy(BlurStrategy.ENABLE)
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .vertical(false)
      .scrollable(false)
      .barFloatingStyle({
        barBottomMargin: 30,
        lightColor: Color.White,
        gradientMask: { maskColor: $r("app.color.backcolor"), maskHeight: 1 },
        systemMaterialEffect:{
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      })
    }
    .mode(NavigationMode.Auto)
    .navBarWidth(this.navBarWidth)
    .navDestination(this.PageMap)
    .width("100%")
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .titleMode(HdsNavigationTitleMode.FULL)
    .hideBackButton(true)
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20),
        },
        systemMaterialEffect:{
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r("sys.color.ohos_id_color_background") },
          contentStyle: {
            titleStyle: { mainTitleColor: $r("sys.color.font_primary") },
          },
        },
      },
      content: {
        title: { mainTitle: "智慧大棚控制终端" },
        menu: {
          value: [
            {
              content: {
                label: "console",
                icon: $r("sys.symbol.code_square"),
                isEnabled: true,
                action: () => {
                  if(this.vibrationON) vibration.dotVibration()
                  let index = this.pageStack.getIndexByName("ConsolePage");
                  if (index.length > 0) {
                    this.pageStack.moveToTop("ConsolePage");
                  } else {
                    this.pageStack.pushPathByName("ConsolePage", null);
                    this.toggleSplitMode(true);
                  }
                },
              },
            },
          ],
        },
      },
    });
  }
}