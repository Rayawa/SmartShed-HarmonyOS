// src/main/ets/view/consolePage.ets
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { curves, LengthMetrics } from '@kit.ArkUI';
import { vibration } from '../service/vibration';
import { LogMessage, LogType } from '../viewmodel/ConsoleBean';
import { hdsEffect } from '@kit.UIDesignKit';

class LogDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private logList: LogMessage[] = [];

  totalCount(): number {
    return this.logList.length;
  }

  getData(index: number): LogMessage {
    return this.logList[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  public reloadData(newList: LogMessage[]): void {
    this.logList = newList;
    this.notifyDataReload();
  }

  private notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }
}

@Component
export struct consolePage {
  onCloseSplit?: () => void;
  private scroller: Scroller = new Scroller();
  @StorageLink("transparentColor") transparentColor: ResourceColor = $r("sys.color.ohos_toggle_bg_transparent")
  @StorageLink("transparentBorderColor") transparentBorderColor: ResourceColor = $r("sys.color.toast_border_color")
  @StorageLink("isWideScreen") isWideScreen: boolean = true;
  @StorageLink("vibrationON") vibrationON: boolean = true;
  @Consume('pageStack') pageStack: NavPathStack;
  @State controller: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController();
  @State animStep1: number = 0;
  private timer1: number = -1;

  @State @Watch('onLogListChange') logList: LogMessage[] = [];
  private dataSource: LogDataSource = new LogDataSource();

  @StorageLink('autoEnabled') autoEnabled: boolean = false;
  private isAtBottom: boolean = true;

  private startEnterAnimation(): void {
    this.stopEnterAnimation();
    const duration = 500;
    const curve = curves.springMotion(0.35, 0.75);
    if(this.isWideScreen) this.timer1 = setTimeout(() => { animateTo({ duration: duration, curve: curve }, () => { this.animStep1 = 1 }) }, 100);
    else this.timer1 = setTimeout(() => { animateTo({ duration: duration, curve: curve }, () => { this.animStep1 = 1 }) }, 0);
  }
  private stopEnterAnimation(): void {
    if (this.timer1 !== -1) { clearTimeout(this.timer1); this.timer1 = -1; }
    this.animStep1 = 0;
  }

  onLogListChange() {
    this.dataSource.reloadData(this.logList);

    if (this.isAtBottom) {
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 50);
    }
  }

  private getTypeColor(type: LogType): Color | string {
    switch (type) {
      case LogType.SEND:
        return this.autoEnabled? "#ff0055ff" : '#007DFF';
      case LogType.RECEIVE:
        return this.autoEnabled? "#ff12660c" : '#ff22bf17';
      case LogType.INFO:
        return this.autoEnabled? "#444444" : '#666666';
      case LogType.ERROR:
        return '#F5222D';
      default:
        return this.autoEnabled? "#111111" : '#333333';
    }
  }

  private getLogContent(content: string): string {
    if (content.includes('Rayawa/rgb/') || content.includes('RGB开发板')) {
      return '[RGB]' + content;
    } else if (content.includes('Rayawa/soi/') || content.includes('SOI开发板')) {
      return '[SOI]' + content;
    }
    return content;
  }

  private getTypeLabel(type: LogType): string {
    switch (type) {
      case LogType.SEND:
        return "SENT";
      case LogType.RECEIVE:
        return "RECV";
      case LogType.INFO:
        return "INFO";
      case LogType.ERROR:
        return "ERR";
      default:
        return "LOG";
    }
  }

  private getTime(timeStr: string): string {
    return timeStr.split(':').map(num => num.padStart(2, '0')).join(':');
  }

  aboutToAppear(): void {
    this.startEnterAnimation();
    this.dataSource.reloadData(this.logList);
  }
  aboutToDisappear(): void {
    this.stopEnterAnimation();
  }

  onPageShow() {
    this.scroller.scrollEdge(Edge.Bottom);
  }

  build() {
    HdsNavDestination() {
      Stack(){
        Column()
          .opacity(this.animStep1 ? 1 : 0)
          .visibility(this.autoEnabled ? Visibility.Visible : Visibility.None)
          .width("100%").height("100%")
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .shaderEffect({
              effectType: hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT,
              animation: {
                duration: 10000,
                iterations: -1,
                autoPlay: true,
                onFinish: ()=> {
                  console.info('Succeeded in finishing');
                }
              },
              controller: this.controller
            })
            .buildEffect())

        Column() {
          Blank().height(100)
          List({ scroller: this.scroller }) {
            LazyForEach(this.dataSource, (item: LogMessage) => {
              ListItem() {
                Row({ space: 5 }) {
                  Text(`[${this.getTime(item.time)}]`)
                    .fontSize(10)
                    .fontColor(this.autoEnabled? "#444444" : "#666666")
                    .flexShrink(0)

                  // 逻辑修正：只保留单次标签渲染，删除了下面多余的重复 Text
                  Text(`[${this.getTypeLabel(item.type)}]`)
                    .fontColor(this.getTypeColor(item.type))
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .flexShrink(0)

                  Text(this.getLogContent(item.content))
                    .fontColor(this.getTypeColor(item.type))
                    .fontSize(12)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                }
                .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({
                  illuminatedType: hdsEffect.PointLightIlluminatedType.CONTENT,
                }).buildEffect())
                .width("100%")
                .align(Alignment.Start)
              }
              .borderRadius(16)
            }, (item: LogMessage, index: number) => {
              return `${item.time}_${index}_${item.content.length}`;
            })
          }
          .cachedCount(5)
          .onReachEnd(() => {
            this.isAtBottom = true;
          })
          .onScrollFrameBegin((offset: number, state: ScrollState) => {
            if (offset < 0) {
              this.isAtBottom = false;
            }
            return { offsetRemain: offset };
          })
          .onScrollIndex((end: number) => {
            if (end >= this.dataSource.totalCount() - 4) {
              this.isAtBottom = true;
            } else {
              this.isAtBottom = false;
            }
          })
          .clip(true)
          .width('96%')
          .padding({ left: 10, right: 10, bottom: 10 })
          .margin({ bottom: 20 })
          .layoutWeight(1)
          .borderWidth(0.5)
          .borderColor(this.autoEnabled ? this.transparentBorderColor :$r("app.color.border"))
          .backgroundColor(this.autoEnabled ? this.transparentColor :$r("app.color.background"))
          .borderRadius(16)
          .shadow({
            radius: 8,
            color: "#1a000000",
            offsetX: 0,
            offsetY: 2,
          })
        }
        .width("100%").height("100%")
      }
    }
    .height("100%").width("100%")
    .backgroundColor($r("app.color.backcolor"))
    .onBackPressed(() => {
      if (this.vibrationON) vibration.dotVibration();
      if (this.onCloseSplit) {
        this.onCloseSplit();
      }
      return false;
    })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20),
        },
        originalStyle: {
          backgroundStyle: { backgroundColor: $r("sys.color.ohos_id_color_background") },
          contentStyle: {
            titleStyle: { mainTitleColor: $r("sys.color.font_primary"), subTitleColor: $r("sys.color.font_secondary") },
            menuStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary")
            },
            backIconStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary")
            },
          },
        },
        scrollEffectStyle: {
          backgroundStyle: { backgroundColor: $r("sys.color.ohos_id_color_background_transparent") },
          contentStyle: {
            titleStyle: { mainTitleColor: $r("sys.color.font_primary"), subTitleColor: $r("sys.color.font_secondary") },
            menuStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary")
            },
            backIconStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary")
            },
          },
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      },
      content: {
        title: { mainTitle: "日志" },
        backIcon: {
          action: () => {
            if (this.vibrationON) vibration.dotVibration()
            if (this.onCloseSplit) {
              this.onCloseSplit();
              console.info("堆叠关闭")
            }
            this.pageStack.pop();
          },
        },
      },
    });
  }
}

@Builder
export function ConsolePageBuilder() {
  consolePage()
}