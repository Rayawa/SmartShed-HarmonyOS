import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { vibration } from '../service/vibration';
import { LogMessage, LogType } from '../viewmodel/ConsoleBean.ts';

@Component
export struct consolePage {
  onCloseSplit?: () => void;
  @StorageLink("vibrationON") vibrationON: boolean = true;
  @Consume('pageStack') pageStack: NavPathStack;
  @Link logList: LogMessage[]; // 使用 @Link 实时同步 Index 的数据
  private scroller: Scroller = new Scroller();

  // 添加日志的方法
  public addLog(type: LogType, content: string) {
    const now = new Date();
    const timeStr = `${now.getHours()}:${now.getMinutes()}:${now.getSeconds()}`;
    this.logList.push({
      id: Date.now(),
      time: timeStr,
      type,
      content
    });

    // 自动滚到底部
    this.scroller.scrollEdge(Edge.Bottom);
  }
  private getTypeColor(type: LogType): Color | string {
    switch (type) {
      case LogType.SEND: return '#F39C12';    // 橙色
      case LogType.RECEIVE: return '#27AE60'; // 绿色
      case LogType.ERROR: return '#E74C3C';   // 红色
      default: return Color.Black;
    }
  }

  onPageShow() {
    this.scroller.scrollEdge(Edge.Bottom);
  }

  build() {
    HdsNavDestination() {
      Column() {
        // 顶部操作栏
        Row() {
          Text("通信控制台").fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
          Button("清空").onClick(() => this.logList = []).backgroundColor(Color.Transparent).fontColor(Color.Gray)
        }.padding(10).width('100%')

        List({ scroller: this.scroller }) {
          ForEach(this.logList, (item: LogMessage) => {
            ListItem() {
              Row() {
                Text(`${item.time} `).fontColor(Color.Gray).fontSize(10)
                Text(item.type === LogType.SEND ? "[OUT] " : "[IN] ")
                  .fontColor(item.type === LogType.SEND ? '#F39C12' : '#27AE60')
                Text(item.content).fontColor(Color.White).fontSize(12)
              }
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding(10)
        .backgroundColor('#1A000000') // 微弱的背景色
        .borderRadius(8)
      }
      .padding(10)
    }
    .onBackPressed(() => {
      if(this.vibrationON) vibration.dotVibration()
      if (this.onCloseSplit) {
        this.onCloseSplit();
        return true;
      }
      this.pageStack.pop();
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
          backgroundStyle: {
            backgroundColor: $r("sys.color.ohos_id_color_background"),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r("sys.color.font_primary"),
              subTitleColor: $r("sys.color.font_secondary"),
            },
            menuStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
            backIconStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
          },
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r("sys.color.ohos_id_color_background_transparent"),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r("sys.color.font_primary"),
              subTitleColor: $r("sys.color.font_secondary"),
            },
            menuStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
            backIconStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
          },
        },
        systemMaterialEffect:{
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      },
      content: {
        title: {
          mainTitle: "终端",
        },
        backIcon: {
          action: () => {
            if(this.vibrationON) vibration.dotVibration()
            if (this.onCloseSplit) {
              this.onCloseSplit();
            }
            this.pageStack.pop();
          },
        },
      },
    });
  }
}

@Builder
export function ConsolePageBuilder(){
  consolePage()
}