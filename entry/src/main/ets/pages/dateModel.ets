import { Lunar } from './Lunar'
import http from '@ohos.net.http'

// 日期类
export class date {
  isSelected: boolean = false;  // 是否被选中
  isToday: boolean = false;   // 是否是今天
  solarDate: Date | null ;   // 公历日期
  weekDay: number = 0; // 一周的第几天 (从星期日开始)
  lunarMonth: string = ""; // 农历月
  lunarDay: string = "";   // 农历日
  lunarResult: any ;  // 农历转换结果
  lunar = new Lunar();  // 农历计算工具

  constructor(isToday: boolean, date: Date | null) {
    this.isToday = isToday;
    this.solarDate = date;
    if(this.solarDate !== null){
      this.weekDay = this.solarDate.getDay();  // 一周的第几天 (从星期日开始)
      this.lunarResult = this.lunar.solarToLunar(date); // 将公历日期转换成农历日期
      this.lunarMonth = this.lunar.lunarFormat(this.lunarResult, "M");  // 从转换结果中获取农历月字符串
      this.lunarDay = this.lunar.lunarFormat(this.lunarResult, "D");  // 从转换结果中获取农历日字符串
    }
  }
}
