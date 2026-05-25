import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { curves, LengthMetrics } from '@kit.ArkUI';
import { vibration } from '../service/vibration';
import { LogMessage, LogType } from '../viewmodel/ConsoleBean';
import { hdsEffect } from '@kit.UIDesignKit';

@Component
export struct consolePage {
  onCloseSplit?: () => void;
  private scroller: Scroller = new Scroller();
  @StorageLink("isWideScreen") isWideScreen: boolean = true;
  @StorageLink("vibrationON") vibrationON: boolean = true;
  @Consume('pageStack') pageStack: NavPathStack;
  @State controller: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController();
  @State animStep1: number = 0;
  private timer1: number = -1;
  @State @Watch('onLogListChange') logList: LogMessage[] = [];
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
    if (this.isAtBottom) {
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 50);
    }
  }
  private getTypeColor(type: LogType): Color | string {
    switch (type) {
      case LogType.SEND:
        return '#007DFF';
      case LogType.RECEIVE:
        return '#30BF17';
      case LogType.INFO:
        return '#999999';
      case LogType.ERROR:
        return '#F5222D';
      default:
        return '#333333';
    }
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
            ForEach(this.logList, (item: LogMessage) => {
              ListItem() {
                Row({ space: 5 }) {
                  Text(`[${this.getTime(item.time)}]`)
                    .fontSize(10)
                    .fontColor(Color.Gray)
                    .flexShrink(0)

                  Text(`[${this.getTypeLabel(item.type)}]`)
                    .fontColor(this.getTypeColor(item.type))
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .flexShrink(0)

                  Text(item.content)
                    .fontColor(this.getTypeColor(item.type))
                    .fontSize(12)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                } .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({
                  illuminatedType: hdsEffect.PointLightIlluminatedType.CONTENT,
                }).buildEffect())
                .width("99%")
                .align(Alignment.Start)
              }
              .borderRadius(16)
            })
          }
          .onScrollIndex((end: number) => {
            if (end >= this.logList.length - 4) {
              this.isAtBottom = true;
            } else {
              this.isAtBottom = false;
            }
          })

          .width('96%')
          .padding({ left: 10, right: 10, bottom: 10 })
          .margin({ bottom: 20 })
          .layoutWeight(1)
          .borderWidth(0.5)
          .borderColor($r("app.color.border"))
          .backgroundColor($r("app.color.background"))
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