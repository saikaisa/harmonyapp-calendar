import {  date } from './dateModel'
import { Lunar } from './Lunar'
import router from '@ohos.router'
import prompt from '@ohos.promptAction';
import ScheduleData from './ScheduleData'
import { dialog } from './dialog'
import Logger from '../common/utils/Logger'
import scheduleTable from '../common/database/tables/ScheduleTable'
import Prompt from '@system.prompt'
import reminderAgentManager from'@ohos.reminderAgentManager';
import wantAgent from '@ohos.wantAgent';


@Entry
@Component
struct Index {
  // @State 用于声明该变量为状态变量，只需修改状态变量的值，界面就会自动更新
  @State year: number = (new Date()).getFullYear();   // 当前显示的年份
  @State month: number = (new Date()).getMonth() + 1; // 当前显示的月份
  @State day: number = (new Date()).getDate(); // 当前显示的日期
  // 当前月份第一天是星期几（0表示星期日，1表示星期一，以此类推）
  @State firstWeekDay: number = new Date(new Date().getFullYear(), new Date().getMonth(), 1).getDay();
  @State selectYYMM: boolean = false;  // 导航栏中，当前年月右边的箭头，点击选择年月

  @State days: date[] = [];   // 当前月份的所有日期对象（包括显示在日历中的1号前的空白日期）
  @State selectedIndex: number = Math.min(30, Math.floor(Math.random()*5+7)); // 当前选中的日期在日历中的编号（注意：日历中1号前的空白日期也占编号）
  @State selectedDate: Date = new Date(); // 当前选中的日期
  @State isInsert: boolean = false; // false：插入新日程；true：修改日程
  @State deleteList: ScheduleData[] = [];
  @State schedules: ScheduleData[] = [];
  @State schedulesOfday: ScheduleData[] = [];
  @State scheduleIndex: number = 0;   // 日程在schedules数组中的下标

  private tabController: TabsController = new TabsController(); // 滑动切换月份的Tab控制器
  @State offsetx: number = 0; // 记录滑动切换月份时滑动的最大像素长度，以判定滑动到什么程度的时候切换

  private months: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  private weeks: string[] = ["日", "一", "二", "三", "四", "五", "六"];
  public colorArray: string = '#009EFE';  // 日程的背景色
  public scheduletable = new scheduleTable(()=>{});

  @State newSchedule: ScheduleData = {
    id:0,
    title: "",
    date: "",
    year: 0,
    month: 0,
    note:"",
  }

  searchController: SearchController = new SearchController();
  dialogController: CustomDialogController = new CustomDialogController({
    builder: dialog({
      isInsert: $isInsert,  // 是否为插入新数据
      newSchedule: $newSchedule,  // 新的日程对象
      selectedDate: $selectedDate,  // 要创建日程的日期
      // dialog返回的isInsert标记和新日程传递到accept函数
      confirm: (isInsert: boolean, newSchedule: ScheduleData) => this.accept(isInsert, newSchedule)
    }),
    customStyle: true,
    alignment: DialogAlignment.Bottom
  });

  // 切换到搜索结果页面
  async routePage(searchValue: string, schedules: ScheduleData[]) {
    let options = {
      url: 'pages/SearchPage',
      params: {
        searchValue: searchValue, // 搜索关键字
        colorArray : this.colorArray, // 给搜索结果日程加上彩色背景
        schedules: schedules, // 搜索结果
      }
    }
    try {
      await router.pushUrl(options)
    } catch (err) {
      console.info(` fail callback, code: ${err.code}, msg: ${err.msg}`)
    }
  }

  // 创建新日程
  accept(isInsert: boolean, newSchedule: ScheduleData): void {
    if (isInsert) {
      // Logger.info('[Debug.Index]', `The account inserted is:  ${JSON.stringify(newSchedule)}`);
      // 通过insertData将新日程插入数据库，返回插入后的新日程id
      this.scheduletable.insertData(newSchedule, (id:number) => {
        newSchedule.id = id;
        this.schedules.push(newSchedule); // 更新schedules数组
        // 设置日程提醒，提醒时间为日程当天上午9点
        let datetime: reminderAgentManager.LocalDateTime = {
          year: newSchedule.year,
          month: newSchedule.month,
          day: (new Date(newSchedule.date)).getDate(),
          hour: 9,
          minute: 0,
        }
        // 通过reminderAgentManager创建一个提醒事项
        let remindercalendar: reminderAgentManager.ReminderRequestCalendar = {
          dateTime: datetime,
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
          actionButton: [
            {
              title: '延迟通知',
              type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_SNOOZE
            }],
          wantAgent: {
            pkgName: "com.example.calendar",
            abilityName: "EntryAbility"
          },
          timeInterval: 3600,
          title: '日程提醒',  // 通知标题
          content: newSchedule.title + '(点击查看详情)',  // 通知详情
        }
        try {
          // 发布提醒
          reminderAgentManager.publishReminder(remindercalendar, (err, reminderId) => {})
          console.log("日程提醒添加成功，日程：", newSchedule.title  + (newSchedule.note === ''? '' :(',详情：' + newSchedule.note)))
        } catch (error) {
          console.log("日程提醒添加失败, 错误信息为：", error.code + error.message)
        }
        this.isInsert = false;
      })
    } else {
      this.scheduletable.updateData(newSchedule, () => {
        let list = this.schedules;
        this.schedules = [];
        list[this.scheduleIndex] = newSchedule;
        this.schedules = list;
        this.scheduleIndex = -1;
      })
    }
  }

  // 计算日期天数差
  ComputeDays(date1:Date, date2:Date): number {
    let diff = date1.getTime() - date2.getTime();
    return Math.floor(diff / (1000 * 60 * 60 * 24)) +1;
  }

  selectListItem(item: ScheduleData) {
    this.isInsert = false; // 编辑模式
    this.scheduleIndex = this.schedules.indexOf(item);
    this.newSchedule = {
      id: item.id,
      title: item.title,
      date: item.date,
      year: item.year,
      month: item.month,
      note: item.note
    };
  }

  // 删除功能
  deleteListItem() {
    for (let i = 0; i < this.deleteList.length; i++) { // 删除每一项选中的账目并更新页面上的账目清单
      let tmp = this.deleteList[i];
      let index = this.schedules.indexOf(this.deleteList[i]);
      this.schedules.splice(index, 1);
      this.scheduletable.deleteData(this.deleteList[i], () => {
      });
    }
    this.deleteList = [];
  }

  // 将日期转化为字符串
  DateToStr(currentDate: Date) {
    let tmp = currentDate
    console.log("转换的日期为：", currentDate.toDateString())
    const dateString: string = `${currentDate.getFullYear()}-${(currentDate.getMonth() + 1).toString().padStart(2, '0')}-${currentDate.getDate().toString().padStart(2, '0')}`;
    return dateString;
  }

  // 获取当前选中日期的所有日程
  getSchedules() {
    let schedulesOfday = [];  // 当前日期的所有日程
    let dateString = this.DateToStr(this.days[this.selectedIndex].solarDate);  // 当前选中日期的字符串
    // 在所有日程数组中匹配日期为当前选中日期的日程
    for (let i = 0; i < this.schedules.length; i++) {
      if (this.schedules[i].date === dateString) {
        schedulesOfday.push(this.schedules[i])
      }
    }
    return schedulesOfday;
  }

  // 切换月份时调用，初始化当前月份的天数和日程
  aboutToAppear(specified: boolean = false) {
    // 更新当前月份第一天是星期几
    this.firstWeekDay = new Date(this.year, this.month-1, 1).getDay();

    // 当前显示的日期下标
    this.selectedIndex = this.day + this.firstWeekDay - 1;

    // 重新计算days数组（显示新的月份），有 3 种情况
    // 1. 滑动切换到当前月时，默认选中今天（此时未指定特定日期）
    if (!specified && this.year === new Date().getFullYear() && this.month - 1 === new Date().getMonth()) {
      this.day = (new Date()).getDate();
    } else if (!specified) {
      // 2. 滑动切换到其他月时，默认选中1号（未指定特定日期，且未选中当前月）
      this.day = 1;
    } // 3. 指定了特定日期跳转，则 this.day 即为事先指定修改好的日期，这里不再做修改
    this.jumpToDate(this.year, this.month, this.day);

    // 获取当前年份的日程
    this.scheduletable.getRdbStore(() => {
      this.scheduletable.query('year', this.year, (result) => {
        this.schedules = result;
      })
    })
  }

  // 获取当前月份的所有天数并更新 days 数组
  jumpToDate(year: number, month: number, day: number) {
    this.days = [];
    let daysOfMonth = new Date(year, month, 0).getDate();  // 当前月份的总天数

    let today = new Date(); // 今天的日期

    // 添加当前月份第一天之前的占位日期对象（空白日期），确保星期日是在第一列的
    for(let i = 0; i < this.firstWeekDay; i++) {
      this.days.push(new date(false, null)); // 插入一个无效日期对象，表示空白处
    }

    // 添加当前月份的实际日期对象
    for (let i = 1; i <= daysOfMonth; i++) {
      let currentDay = new Date(year, month - 1, i);
      let isToday = false;

      // 判断当前日期是否为今天
      if(currentDay.toDateString() === today.toDateString()) {
        isToday = true;
      }

      // 创建一个新的日期对象，记录当前日期的各种状态
      let tmp = new date(isToday, currentDay);

      if (i === day) {
        this.selectedDate = currentDay;
        tmp.isSelected = true;
      }

      // 将当前日期对象添加到日期数组中
      this.days.push(tmp);
    }
  }

  // 构建页面
  build() {
    Row() {
      Column() {
        // ================================= 导航栏开始 =================================
        Row() {
          // 显示当前年月
          Text(`${this.year}年${this.month}月`)
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
            .margin({ left: '1%' })
            .height('100%')

          // 显示当前年月右边的箭头（向上或向下箭头）并绑定点击事件
          // selectYYMM：false(默认)：向下, true：向上
          Image(this.selectYYMM ? $rawfile('up_arrow.png') : $rawfile('down_arrow.png'))
            .width('4%')
            .height('26%')
            .onClick(() => {
              this.selectYYMM = true;
              // 显示日期选择对话框
              DatePickerDialog.show({
                // 设置可供选择的日期范围
                start: new Date('1901-1-1'),
                end: new Date('2099-12-31'),
                selected: new Date(),
                // 按下确定按钮后接收当前选中的日期参数
                onAccept:(value: DatePickerResult) =>{
                  this.year = value.year;
                  this.month = value.month+1; // 月份从0开始，需要加1
                  this.day = value.day;
                  this.aboutToAppear(true);
                  this.selectYYMM = false;
                },
                // 取消选择
                onCancel:() =>{
                  console.info("用户取消")
                  this.selectYYMM = false;
                },
                // 日期选择器值改变时，输出当前选中日期
                // onChange:(value: DatePickerResult) =>{
                //   console.info("日期变更为:" + JSON.stringify(value))
                // }
              })
            })
          Blank()
          // 搜索图标，绑定搜索菜单，searchMenu方法
          Image($r('app.media.search')).width('8%').height('46%').margin({right:10})
            .bindMenu(this.searchMenu())
          // 新建日程图标，绑定下面的内联新建日程方法
          Image($rawfile('add.png')).width('6%').height('45%').margin({right:10})
            .bindMenu([
              {
                value:'新建日程',
                action:() => {
                  this.newSchedule = {
                    id:0,
                    title: "",
                    date: "",
                    year: this.year,
                    month: this.month,
                    note:"",
                  }
                  this.isInsert = true
                  this.dialogController.open()
                }
              }
            ])
        }
        .width('100%')
        .height('7%')
        .alignSelf(ItemAlign.Start)
        .padding({ left: '2%', right: '2%' })
        .alignItems(VerticalAlign.Center)
        // ================================= 导航栏结束 =================================
        // =============================== 显示星期的行开始 ===============================
        Row() {
          ForEach(this.weeks, (item: string) => {
            Column() {
              Text(item).fontWeight((item === "日" || item === "六")?
              FontWeight.Normal:FontWeight.Bold).fontColor((item === "日" || item === "六")?
              Color.Gray: Color.Black)
            }.layoutWeight(1)
          })
        }.width('100%').height('4%').justifyContent(FlexAlign.Center).margin({ top: 5 })
        .padding({top:5,left:5,right:5})
        .backgroundColor('#ffeceff1').borderRadius({topLeft:5, topRight:5})
        // =============================== 显示星期的行结束 ===============================
        // ============================= 显示当前月的所有日期开始 =============================
        Row() {
          Tabs({ barPosition: BarPosition.Start, index: this.month - 1, controller: this.tabController }) {
            ForEach(this.months, (item: number) => {
              TabContent() {
                Row() {
                  // ========================= 创建网格布局显示日期 (每行) 开始 =========================
                  GridRow({ columns: 7, gutter: { y: 20 } }) {
                    // 遍历days数组，每次遍历是一个数组元素item
                    ForEach(this.days, (item: date) => {
                      GridCol() {
                        Column() {
                          // 设置空占位符或者日期
                          // 显示公历
                          Text(item.solarDate === null ? "" : item.solarDate.getDate().toString())
                            // 设置周六和周日的日期字体不加粗，周一至周五加粗
                            .fontWeight(FontWeight.Bolder)
                            .fontSize(20)
                            .fontColor(item.isToday ?
                                                    // 如果当前渲染的日期是今天，如果选中了则字体为白色，未选中字体为粉色
                                        (item.isSelected ? Color.White : '#ffff419b') ://今天日期
                                                    // 如果当前渲染的日期不是今天
                                        (item.isSelected ?
                                          // 若选中了，则字体为白色
                                          Color.White :
                                          // 若未选中，则字体为紫色(周六和周日)和黑色(周一至周五)
                                          ((item.weekDay===0 || item.weekDay===6) ?
                                            '#ff8900db' :
                                            Color.Black)))
                          // 显示农历，如果是初一则显示当前农历月份
                          Text(item.lunarDay === "初一" ? item.lunarMonth : item.lunarDay)
                            .fontSize(12)
                            .fontColor(item.isToday ? // 逻辑与公历相同
                                        (item.isSelected ? Color.White : '#ffff419b') ://今天日期的农历
                                        (item.isSelected ?
                                          Color.White :
                                          ((item.weekDay===0 || item.weekDay===6) ?
                                            '#ff8900db' :
                                            Color.Black)))
                          if (item.isToday) {
                            Row().width("35%").height(2)
                              // 如果未选中今天的日期，则设置一个粉色下划线，选中就是白色下划线
                              .backgroundColor(item.isSelected ? Color.White : '#ffff419b')//今天日期的下划线
                              .margin({ top: 1 })
                          }
                        }
                        .justifyContent(FlexAlign.Start)
                        // 如果是今天被选中，背景色设为粉色；如果是其他日期被选中，背景色设为绿色
                        .backgroundColor(item.isToday ? (item.isSelected ? '#ffff419b' : "") : (item.isSelected ? '#ff1486ea' : ''))
                        .borderRadius(50).width(45).height(44)
                        // 点击切换选中日期
                        .onClick(() => {
                          for (let i = 0; i < this.days.length; i++) {
                            if (this.days[i].solarDate !== null && this.days[i].solarDate.getTime() === item.solarDate.getTime()) {
                              this.selectedIndex = i;
                              this.selectedDate = item.solarDate;
                              this.day = i - this.firstWeekDay + 1;
                              break;
                            }
                          }
                          // console.log("选中日期的days下标index：", this.selectedIndex)
                          this.jumpToDate(this.year, this.month, this.day);
                        })
                      }
                    })
                  }.width('100%').height('100%')
                  // ========================= 创建网格布局显示日期 (每行) 结束 =========================
                }.width('100%').height('100%')
              }.width('100%').height('100%')
              // 手势拖动切换月份
              .gesture(
                PanGesture()
                  .onActionUpdate((event: GestureEvent) => {
                    this.offsetx = event.offsetX;
                    // console.log("offset: " + event.offsetX)
                  })
                  .onActionEnd(() => {
                    if (this.offsetx > 150) {
                      //月份减小
                      if (this.month === 1) {
                        this.year = this.year - 1;
                      }
                      this.month = this.months[(this.month + 10)%12];
                      this.tabController.changeIndex(this.month - 1);
                      this.aboutToAppear();
                      this.offsetx = 0;
                    } else if (this.offsetx < -150) {
                      //月份增大
                      if (this.month === 12) {
                        this.year = this.year + 1;
                      }
                      this.month = this.months[(this.month)%12];
                      this.tabController.changeIndex(this.month - 1);
                      this.aboutToAppear();
                      this.offsetx = 0;
                    }
                  })
              )
            })
          }
          .barMode(BarMode.Fixed)
          .animationDuration(200)
          .height('100%')
          .barHeight(1)
          .width('100%')
          .onChange((index: number) => {
            this.month = index + 1;
          })
        }.width('100%').height('48%').padding({ left: '2%', right: '2%', top: '1%' }).backgroundColor('#ffeceff1').borderRadius({bottomLeft:5, bottomRight:5})
        // ============================= 显示当前月的所有日期结束 =============================
        // ================= 显示选定日期的详细信息 (与现在相差xx天，农历日期) 开始 =================
        Column(){
          Row().width('50%').height(3).backgroundColor('#ffeceff1').margin({left:'0%'})
          Row(){
            // 显示与当天的日期差
            Text(this.ComputeDays(this.selectedDate, new Date()) === 0? "今天" :
              (this.ComputeDays(this.selectedDate, new Date()) < 0?
                (this.ComputeDays(this.selectedDate, new Date()) === -1? "昨天":
                (-1*this.ComputeDays(this.selectedDate, new Date())).toString() + "天前") :
                (this.ComputeDays(this.selectedDate, new Date()) === 1? "明天":
                (this.ComputeDays(this.selectedDate, new Date())).toString() + "天后")) )
              .fontWeight(FontWeight.Bold)
            // 显示农历
            Text("    农历" +
                  this.days[this.selectedIndex].lunarMonth +
                  this.days[this.selectedIndex].lunarDay
            ).fontColor(Color.Gray)
            Blank()
            // 进入日期详情
            Image($rawfile('more.png')).width(25).height(25).margin({right:15})
              .onClick(()=>{
                router.pushUrl({
                  url: 'pages/morePage',
                  params:{
                    date: this.DateToStr(this.days[this.selectedIndex].solarDate),  // 公历日期
                  }
                })
              })
          }.width('100%').height(40).margin({top:8})
          // =================== 显示选定日期的详细信息 (与现在相差xx天，农历日期) 结束 ===================
          // ================================= 显示日程开始 =================================
          Row(){
              if(this.getSchedules().length === 0){
                Column(){
                  Image($rawfile('calendar.png')).width(90).height(90).interpolation(ImageInterpolation.High).margin({top:40})
                  Text("暂 无 日 程").fontColor(Color.Gray).margin({top:15})
                }.width('100%').height('100%')
              }else{
                Column(){
                    List({space:5}){
                      ForEach(this.getSchedules(), (item: ScheduleData)=>{
                        ListItem(){
                          Row(){
                              Column().width(10).height(30).backgroundColor(this.colorArray).borderRadius(20)
                              Text("      " + item.title).fontWeight(FontWeight.Bold).fontSize(20).
                              textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
                            if(item.note !== ''){
                              Divider().vertical(true).height("80%").margin({left: 10})
                              Column(){
                                Text(){
                                  Span('备注： ')
                                  Span(item.note).fontWeight(FontWeight.Bold)
                                }.margin({left:10})
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                                .maxLines(3)
                              }.width('35%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Start)
                            }
                          }.width('100%').height('100%').padding({left:10}).borderRadius(10)
                        }.width('100%').height(40)
                        .swipeAction({end:this.deleteItem(item)})
                        .gesture(
                          LongPressGesture({duration:500})
                            .onAction(()=>{})
                            .onActionEnd(()=>{
                              this.selectListItem(item);
                              this.dialogController.open();
                            })
                        )
                      })
                    }.backgroundColor(Color.White).borderRadius({ topLeft: 16, topRight: 16, bottomLeft: 16, bottomRight: 16 })
                }.width('100%').height('100%').padding({left:5, right:5, top:10}).borderRadius(20)
              }
          }.width('100%').height('60%')
          // ================================= 显示日程结束 =================================
      }.width('100%').height('50%').padding({ left: '2%', right: '2%', top: '1%' }).backgroundColor('#ffeceff1').justifyContent(FlexAlign.Start)
      }.width('100%').height('100%')
    }.height('100%').width('100%').backgroundColor('#ffeceff1')
  }

  // 定义删除日程的布局
  @Builder deleteItem(item: ScheduleData){
    Row(){
      Button("编辑").size({width:'15%', height:'100%'}).backgroundColor('#ff9300').type(ButtonType.Normal)
        .onClick(()=>{
          this.isInsert = false;
          this.selectListItem(item);
          this.dialogController.open();
        })
      Button("删除").size({width:'15%', height:'100%'}).backgroundColor('#ff2700').type(ButtonType.Normal)
        .onClick(()=>{
          this.deleteList.push(item);
          this.deleteListItem();
        })
    }
  }

  // 定义跳转项的布局
  @Builder GotoItem() {
    Menu() {
      MenuItem() {
        Column() {}
      }
    }
  }

  // 定义搜索菜单的布局
  @Builder searchMenu() {
    Menu(){
      MenuItem(){
        Search({
          value: '',
          placeholder: '请输入关键字搜索',
          controller: this.searchController
        })
          .width('100%')
          .searchButton('搜索')
          .borderRadius(20).borderWidth(1.5)
          .borderColor("#33182431")
          .placeholderFont({ size: 16 })
          .textFont({ size: 16 })
          .backgroundColor('#ffeceff1')
          .onChange((searchValue: string) => {})
          .onSubmit((searchValue: string) => {
            if (searchValue === '' ) {
              prompt.showToast({ message: '输入不能为空', bottom: 70 });
            } else {
                let tmp = []
                this.scheduletable.queryForsearch(searchValue, (result) => {
                  tmp = result; // tmp保存了查询到的结果（ScheduleData对象数组）
                  this.routePage(searchValue, tmp);
                })
            }
          })
      }
    }
  }
}