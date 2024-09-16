import router from '@ohos.router'
import http from '@ohos.net.http'
import { LoadingDialog } from './LoadingDialog'
import Prompt from '@system.prompt'
import prompt from '@ohos.prompt'

@Entry
@Component
struct MorePage {
  LoadingdialogController = new CustomDialogController({
    builder: LoadingDialog({}),
  })

  @State yearTips: string = ""; // 干支年
  @State chineseZodiac: string = ""; // 生肖年
  @State lunarCalendar: string[] = [];  // 农历月日
  @State typeDes: string = "";  // 类型（节日、工作日等）
  @State constellation: string = ""; // 星座
  @State solarTerms: string = "";   // 节气描述
  @State suit: string[] = [];     // 黄历宜
  @State avoid: string[] = [];    // 黄历忌
  @State dayOfYear: number = 0;   // 一年的第几天
  @State weekOfYear: number = 0;  // 一年的第几周

  async onPageShow() {
    this.LoadingdialogController.open()
  }

  // 将公历日期转换为详细的黄历信息
  aboutToAppear() {
    let httpRequest = http.createHttp();
    let dateParam = router.getParams()['date']; // 获取主页传来的公历日期

    // 将 dateParam 格式转换为 YYYYMMDD
    let dateObj = new Date(dateParam);
    let year = dateObj.getFullYear();
    let month = ('0' + (dateObj.getMonth() + 1)).slice(-2);  // 补零操作
    let day = ('0' + dateObj.getDate()).slice(-2);           // 补零操作
    let yymmdd = year + month + day;
    let url = 'https://www.mxnzp.com/api/holiday/single/' + yymmdd +
              '?ignoreHoliday=false&app_id=xljlk9pdslpnjqi9&app_secret=JDSTVBDRBwBNO9LXa5622S3dSxL11z2Z';

    httpRequest.request(url, {
      readTimeout: 3000,
    },(err, res) => {
      if (!err) {
        /*
        dateInfo 内容示例：
          "date":"2024-02-09",
          "weekDay":5,
          "yearTips":"癸卯",
          "type":0,
          "typeDes":"工作日",
          "chineseZodiac":"兔",
          "solarTerms":"立春后",
          "avoid":"掘井.词讼",
          "lunarCalendar":"腊月卅",
          "suit":"嫁娶.安床.开光.出行.祭祀.动土.出火.解除.会亲友.开市.交易.立券.挂匾.入宅.移徙.拆卸.破土.启钻.安葬",
          "dayOfYear":40,
          "weekOfYear":6,
          "constellation":"水瓶座",
          "indexWorkDayOfMonth":8
        */
        // @ts-ignore
        let dateInfo = JSON.parse(res.result).data; // 该日期的详细数据
        // this.days = dateInfo;
        // @ts-ignore
        // console.log("请求的数据为：" + JSON.stringify(JSON.parse(res.result).data))
        let tmp_str = "农历" + dateInfo.lunarCalendar;
        this.lunarCalendar = [];
        for (let i = 0; i < tmp_str.length; i++) {
          this.lunarCalendar.push(tmp_str[i])
        }
        this.typeDes = dateInfo.typeDes;
        this.yearTips = dateInfo.yearTips;
        this.chineseZodiac = dateInfo.chineseZodiac;
        this.solarTerms = dateInfo.solarTerms;
        this.suit = dateInfo.suit.split('.');
        this.avoid = dateInfo.avoid.split('.');
        this.dayOfYear = dateInfo.dayOfYear;
        this.weekOfYear = dateInfo.weekOfYear;
        this.constellation = dateInfo.constellation;

        // 加载完成后关闭加载动画
        this.LoadingdialogController.close();
        // @ts-ignore
        console.log("请求数据成功， 详细日期：" + dateInfo.date)
      } else {
        console.log("请求数据失败！")
        this.LoadingdialogController.close()
        prompt.showToast({ message: '加载失败，请检查网络后重试！', bottom: 70 });
        setTimeout(function (){
            router.back()
        }, 500);
      }
    });
  }

  build() {
    Row() {
      Column() {
        Row() {
          Image($rawfile('back.png')).width(25).height(25)
          Text("返回").fontWeight(FontWeight.Bold)
          Text("日期详情").fontWeight(FontWeight.Bold).margin(105).width(80)
        }
        .width('100%')
        .height(50)
        .padding({ left: 5 })
        .alignSelf(ItemAlign.Start)
        .onClick(() => {
          router.back()
        })

        Column() {
          Row() {
            Column() {
              GridRow({ columns: 1 }) {
                ForEach(this.lunarCalendar, (item: string) => {
                  GridCol() {
                    Row() {
                      Text(item).fontSize(25).fontWeight(FontWeight.Bold).height(`${100 / this.lunarCalendar.length}%`)
                    }
                  }
                })
              }.width('100%').height('100%')
            }
            .width("20%")
            .height('100%')
            .borderWidth(0.1)
            .borderColor(Color.Gray)
            .alignItems(HorizontalAlign.Start)

            Column() {
              // 干支生肖年
              Row() {
                Text("干支生肖:     ").fontWeight(FontWeight.Bold)
                Text(this.yearTips + this.chineseZodiac + "年").fontColor(Color.Gray)
              }
              .layoutWeight(1)
              .borderWidth(0.1)
              .borderColor(Color.Gray)
              .justifyContent(FlexAlign.Start)
              .padding({ left: 10 })
              .width('100%')
              // 类型
              Row() {
                Text("类型:             ").fontWeight(FontWeight.Bold)
                Text(this.typeDes).fontColor(Color.Gray)
              }
              .layoutWeight(1)
              .borderWidth(0.1)
              .borderColor(Color.Gray)
              .justifyContent(FlexAlign.Start)
              .padding({ left: 10 })
              .width('100%')
              // 节气
              Row() {
                Text("节气:             ").fontWeight(FontWeight.Bold)
                Text(this.solarTerms).fontColor(Color.Gray)
              }
              .layoutWeight(1)
              .borderWidth(0.1)
              .borderColor(Color.Gray)
              .justifyContent(FlexAlign.Start)
              .padding({ left: 10 })
              .width('100%')
              // 星座
              Row() {
                Text("星座:             ").fontWeight(FontWeight.Bold)
                Text(this.constellation).fontColor(Color.Gray)
              }
              .layoutWeight(1)
              .borderWidth(0.1)
              .borderColor(Color.Gray)
              .justifyContent(FlexAlign.Start)
              .padding({ left: 10 })
              .width('100%')
              // 描述
              Row() {
                Text("描述:             ").fontWeight(FontWeight.Bold)
                Text(`今年第${this.dayOfYear}天， 第${this.weekOfYear}周`).fontColor(Color.Gray)
              }
              .layoutWeight(1)
              .borderWidth(0.1)
              .borderColor(Color.Gray)
              .justifyContent(FlexAlign.Start)
              .padding({ left: 10 })
              .width('100%')
            }.width("80%").height('100%').borderWidth(0.1).borderColor(Color.Gray)
          }.width('100%').height("60%").borderWidth(0.1).borderColor(Color.Gray)

          Column() {
            // 黄历宜
            Row() {
              Row() {
                Row() {
                  Text(" 宜").fontSize(16).fontColor(Color.White).fontWeight(FontWeight.Bold)
                }.borderRadius(100).backgroundColor('#ff00cd00').width('50%').height('40%')
              }.width("20%").height('100%').justifyContent(FlexAlign.Center).padding(15)
              Row() {
                GridRow({ columns: 5 }) {
                  ForEach(this.suit, (item: string) => {
                    GridCol() {
                      Row() {
                        Text(item).fontSize(15).fontColor(Color.Gray)
                      }
                    }
                  })
                }.width('100%').height('100%')
              }.width("80%").height('100%')
            }.width('100%').height("50%")

            // 黄历忌
            Row() {
              Row() {
                Row() {
                  Text(" 忌").fontSize(16).fontColor(Color.White).fontWeight(FontWeight.Bold)
                }.borderRadius(100).backgroundColor('#ffd70000').width('50%').height('40%')
              }.width("20%").height('100%').justifyContent(FlexAlign.Center).padding(15)
              Row() {
                GridRow({ columns: 5 }) {
                  ForEach(this.avoid, (item: string) => {
                    GridCol() {
                      Row() {
                        Text(item).fontSize(15).fontColor(Color.Gray)
                      }
                    }
                  })
                }.width('100%').height('100%')
              }.width("80%").height('100%')
            }.width('100%').height("50%")
          }.width('100%').height("40%")
        }.width('100%').height('60%').borderWidth(0.5).margin({ top: 10 })
      }.width('100%').justifyContent(FlexAlign.Start).height('100%').padding({ left: 5, right: 5 })
    }.height('100%')
  }
}