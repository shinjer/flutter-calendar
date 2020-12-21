import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// 中央研究院 兩千年中西曆轉換
// https://sinocal.sinica.edu.tw/
// 臺北市立天文科學教育館-陰陽曆對照表+曆象表(出版品)-陰陽曆對照表+曆象表
// https://www.tam.gov.taipei/News_Content.aspx?n=2D5F18609004C0CE&sms=3AABB000A3E78431&s=AC19298B0509F078

final chineseCalendar = ChineseCalendar();

class ChineseCalendar {
  static const zodiacNames = [
    "鼠",
    "牛",
    "虎",
    "兔",
    "龍",
    "蛇",
    "馬",
    "羊",
    "猴",
    "雞",
    "狗",
    "豬"
  ];
  static const monthNames = [
    "正月",
    "二月",
    "三月",
    "四月",
    "五月",
    "六月",
    "七月",
    "八月",
    "九月",
    "十月",
    "十一月",
    "十二月"
  ];
  static const numeralNames = [
    "零",
    "一",
    "二",
    "三",
    "四",
    "五",
    "六",
    "七",
    "八",
    "九",
    "十"
  ];
  static const solarTermNames = [
    "立春",
    "雨水",
    "驚蟄",
    "春分",
    "清明",
    "穀雨",
    "立夏",
    "小滿",
    "芒種",
    "夏至",
    "小暑",
    "大暑",
    "立秋",
    "處暑",
    "白露",
    "秋分",
    "寒露",
    "霜降",
    "立冬",
    "小雪",
    "大雪",
    "冬至",
    "小寒",
    "大寒"
  ];
  static const stemNames = "甲乙丙丁戊己庚辛壬癸";
  static const branchNames = "子丑寅卯辰巳午未申酉戌亥";
  static const yearString = "年";
  static const leapName = "閏";
  static const initialName = "初";
  static const numeralName20 = "廿";

  static const assetsPath = "assets";
  static const solarTermMonth = 2;

  static String toYearName(int year) {
    int idx = year - 4;
    return stemNames[idx % stemNames.length] +
        branchNames[idx % branchNames.length];
  }

  static String toZodiacName(int year) =>
      zodiacNames[(year - 4) % zodiacNames.length];
  static String toMonthName(int month) => monthNames[month - 1];
  static String toLeapMonthName(int month) => leapName + monthNames[month - 1];
  static String toDayName(int day) {
    if (day < 1) return day.toString();
    if (day <= 10) return initialName + numeralNames[day];
    if (day < 20) return numeralNames[10] + numeralNames[day - 10];
    if (day == 20 || day == 30)
      return numeralNames[day ~/ 10] + numeralNames[10];
    if (day < 30) return numeralName20 + numeralNames[day - 20];
    return day.toString();
  }

  Map<int, ChineseYearData> _yearMap = {};
  var fileName = "chinese_calendar.json";

  Future<String> getFilePath() async {
    var dir = await getExternalStorageDirectory();
    return dir != null ? "${dir.path}/$fileName" : null;
  }

  Future<void> loadFile() async {
    for (int kind = 0; kind < 2; kind++) {
      String source;
      if (kind == 0) {
        try {
          source = await rootBundle.loadString("$assetsPath/$fileName");
        } catch (err) {
          print("rootBundle=$err");
          continue;
        }
      } else {
        if (kIsWeb) continue;
        var path = await getFilePath();
        if (path == null) continue;
        var file = File(path);
        if (!await file.exists()) {
          print("No such file \"$path\"");
          continue;
        }
        source = await file.readAsString();
      }
      var json = jsonDecode(source);
      if (json is List) {
        for (int i = 0; i < json.length; i++) {
          var data = ChineseYearData.fromJson(json[i]);
          _yearMap[data.year] = data;
//          print("$i.${jsonEncode(data)}");
        }
      }
    }
  }

  Future<void> saveFile() async {
    var list = getYearList();
    var sb = StringBuffer();
    for (int i = 0; i < list.length; i++) {
      var data = _yearMap[list[i]];
      var json = jsonEncode(data);
      sb.write(i > 0 ? ",\n$json" : json);
    }
    var text = "[\n$sb\n]";
    if (!kIsWeb) {
      var path = await getFilePath();
      var file = File(path);
      await file.writeAsString(text);
      print("save path=${file.path}");
    }
    print("chinese_calendar=$text");
  }

  Future<void> loadMonthsTxt() async {
    var logTag = "--months";
    var source = await rootBundle.loadString("$assetsPath/months.txt");
    int start = 0;
    ChineseYearData data;
    while (start < source.length) {
      int end = source.indexOf("\n", start);
      end = end < 0 ? source.length : end;
      var line = source.substring(start, end);
      int idx = line.indexOf("西元");
      if (idx >= 0) {
        idx += 2;
        int idx1 = line.indexOf("年", idx);
        int idx2 = line.indexOf("月", idx1 + 1);
        int idx3 = line.indexOf("日", idx2 + 1);
        int year = int.parse(line.substring(idx, idx1));
        int month = int.parse(line.substring(idx1 + 1, idx2));
        int day = int.parse(line.substring(idx2 + 1, idx3));
        print("$logTag.year=$year,,$month,,$day");
        if (data != null) _yearMap[data.year] = data;
        data = ChineseYearData(year);
        data.setBeginDate(DateTime(year, month, day));
      } else if (data != null && line.isNotEmpty) {
        bool isLeap = line[0] == leapName;
        int idx1 = isLeap ? 1 : 0;
        int idx2 = line.indexOf("\t", idx1);
        int month = int.tryParse(line.substring(idx1, idx2));
        if (month != null) {
          if (isLeap) {
            data.leapMonth = month;
            month = ChineseYearData.leapMonthIndex;
          }
          data.setLongMonth(month, line[line.length - 1] != "-");
          print("$logTag.month=$month,${line[line.length - 1]}");
        }
      }
      start = end + 1;
    }
    if (data != null) _yearMap[data.year] = data;
  }

  Future<void> loadSolarTermsTxt() async {
    var logTag = "--solarTerms";
    var source = await rootBundle.loadString("$assetsPath/solar_terms.txt");
    int start = 0;
    while (start < source.length) {
      int end = source.indexOf("\n", start);
      end = end < 0 ? source.length : end;
      var line = source.substring(start, end);
      int idx1 = line.indexOf(" ");
      int year = int.tryParse(line.substring(0, idx1));
      if (year != null) {
        while (idx1 < line.length && line[idx1] == " ") idx1++;
        while (idx1 < line.length) {
          int idx2 = line.indexOf(".", idx1);
          int idx3 = line.indexOf(" ", idx2 + 1);
          idx3 = idx3 < 0 ? line.length : idx3;
          int month = int.parse(line.substring(idx1, idx2));
          int day = int.parse(line.substring(idx2 + 1, idx3));
          var yid = toSolarTermID(year, month, day);
          var data = _yearMap[yid[0]];
          if (data != null) data.setSolarTermDay(yid[1], day);
          print(
              "$logTag.$year.$month.$day=$yid,${data?.getSolarTermDate(yid[1])}");
          idx1 = idx3 + 1;
        }
      }
      start = end + 1;
    }
  }

  List<int> getYearList() {
    return _yearMap.keys.toList()..sort();
  }

  bool hasYearData(int year) {
    return _yearMap.containsKey(year);
  }

  ChineseYearData getYearData(int year) {
    var data = _yearMap[year];
    return data?.copy();
  }

  void setYearData(ChineseYearData data) {
    _yearMap[data.year] = data.copy();
  }

  List<int> toSolarTermID(int year, int month, int day) {
    int year2 = year;
    int id = month - solarTermMonth;
    if (id < 0) {
      year2--;
      id += DateTime.monthsPerYear;
    }
    id = (id << 1) + (day >= 16 ? 2 : 1);
    return [year2, id];
  }

  int getSolarTermID(DateTime date) {
    var yid = toSolarTermID(date.year, date.month, date.day);
    int year = yid[0];
    int id = yid[1];
    var date1 = getSolarTermDate(year, id);
    var date2 = DateTime(date.year, date.month, date.day);
    return date1 == date2 ? id : 0;
  }

  DateTime getSolarTermDate(int year, int id) {
    var data = _yearMap[year];
    return data?.getSolarTermDate(id);
  }
}

class ChineseYearData {
  static const shortMonthDays = 29;
  static const leapMonthIndex = 13;

  int year = 0;
  int beginDays = 0;
  int monthData = 0;
  int leapMonth = 0;
  List<int> solarTerms;

  bool get hasLeapMonth => leapMonth > 0;
  int get length => DateTime.monthsPerYear + (hasLeapMonth ? 1 : 0);

  ChineseYearData(this.year,
      [this.beginDays = 0,
      this.monthData = 0,
      this.leapMonth = 0,
      dynamic terms]) {
    solarTerms = terms is List ? List.from(terms) : null;
  }

  ChineseYearData.fromJson(Map<String, dynamic> json)
      : this(json["year"], json["beginDays"], json["monthData"],
            json["leapMonth"], json["solarTerms"]);

  Map<String, dynamic> toJson() {
    return {
      "year": year,
      "beginDays": beginDays,
      "monthData": monthData,
      "leapMonth": leapMonth,
      "solarTerms": solarTerms,
    };
  }

  ChineseYearData copy() {
    return ChineseYearData(year, beginDays, monthData, leapMonth, solarTerms);
  }

  DateTime getBeginDate() {
    var date = DateTime(year).add(Duration(days: beginDays));
    return date;
  }

  void setBeginDate(DateTime date) {
    var diff = DateTime(date.year, date.month, date.day)
        .difference(DateTime(date.year));
    year = date.year;
    beginDays = diff.inDays;
  }

  bool isLongMonth(int month) {
    int idx = month - 1;
    return ((monthData >> idx) & 1) > 0;
  }

  int getMonthDays(int month) {
    return shortMonthDays + (isLongMonth(month) ? 1 : 0);
  }

  void setLongMonth(int month, bool islong) {
    int idx = month - 1;
    if (islong)
      monthData |= 1 << idx;
    else
      monthData &= ~(1 << idx);
  }

  bool isLongLeapMonth() {
    return isLongMonth(leapMonthIndex);
  }

  int getLeapMonthDays() {
    return getMonthDays(leapMonthIndex);
  }

  void setLongLeapMonth(bool islong) {
    setLongMonth(leapMonthIndex, islong);
  }

  int monthToIndex(int month) {
    if (!hasLeapMonth || month <= leapMonth) {
      return month - 1;
    }
    return month < leapMonthIndex ? month : leapMonth;
  }

  int indexToMonth(int i) {
    if (!hasLeapMonth || i < leapMonth) {
      return i + 1;
    }
    return i == leapMonth ? leapMonthIndex : i;
  }

  List<int> find(int days, [int month = 1]) {
    int length = this.length;
    for (int i = monthToIndex(month); i < length; i++) {
      int month2 = indexToMonth(i);
      int mdays = getMonthDays(month2);
      if (days <= mdays) {
        return [year, month2, days];
      }
      days -= mdays;
    }
    return [days];
  }

  List<int> findLast(int days, [int month = 0]) {
    for (int i = (month < 1 ? length : monthToIndex(month)) - 1; i >= 0; i--) {
      int month2 = indexToMonth(i);
      int mdays = getMonthDays(month2);
      days += mdays;
      if (days >= 1) {
        return [year, month2, days];
      }
    }
    return [days];
  }

  int getSolarTermDay(int id) {
    if (solarTerms == null) return 0;
    int idx = id - 1;
    int value = solarTerms[idx >> 3];
    value = (value >> ((idx & 7) << 2)) & 15;
    return value;
  }

  DateTime getSolarTermDate(int id) {
    int idx = id - 1;
    int month = ChineseCalendar.solarTermMonth + (idx >> 1);
    var date = DateTime(year, month, ((idx & 1) << 4) + getSolarTermDay(id));
    return date;
  }

  void setSolarTermDay(int id, int day) {
    if (solarTerms == null) solarTerms = [0, 0, 0];
    int idx = id - 1;
    int shift = (idx & 7) << 2;
    int i = idx >> 3;
    solarTerms[i] &= ~(15 << shift);
    solarTerms[i] |= (day & 15) << shift;
  }
}

class ChineseDate {
  DateTime _dateTime;
  int _year;
  int _month;
  int _day;

  ChineseDate(DateTime date) {
    setDate(date);
  }

  bool get hasData => _year != null;
  ChineseYearData get yearData => chineseCalendar.getYearData(_year);
  String get displayName {
    if (!hasData) return "";
    return _day == 1 ? _getMonthName(yearData) : _getDayName();
  }

  String get yearName {
    if (!hasData) return "";
    return "${ChineseCalendar.toYearName(_year)}${_getZodiacName()}${ChineseCalendar.yearString}";
  }

  String get dateName {
    if (!hasData) return "";
    return "${_getMonthName(yearData)}${_getDayName()}";
  }

  String _getZodiacName() => ChineseCalendar.toZodiacName(_year);
  String _getMonthName(ChineseYearData data, [bool hasLong = false]) {
    var name = _month == ChineseYearData.leapMonthIndex
        ? ChineseCalendar.toLeapMonthName(data.leapMonth)
        : ChineseCalendar.toMonthName(_month);
    if (hasLong) name += data.isLongMonth(_month) ? "大" : "小";
    return name;
  }

  String _getDayName() => ChineseCalendar.toDayName(_day);

  void _setDate([int year, int month = 0, int day = 0]) {
    _year = year;
    _month = month;
    _day = day;
  }

  void _findInData(ChineseYearData data, int month, int days) {
    var result;
    if (days < 1) {
      result = data.findLast(days, month);
      if (result.length < 3) {
        data = chineseCalendar.getYearData(data.year - 1);
        if (data != null) result = data.findLast(result[0]);
      }
    } else {
      result = data.find(days, month);
      if (result.length < 3) {
        data = chineseCalendar.getYearData(data.year + 1);
        if (data != null) result = data.find(result[0]);
      }
    }
    result.length >= 3 ? _setDate(result[0], result[1], result[2]) : _setDate();
  }

  void setDate(DateTime date) {
    _dateTime = DateTime(date.year, date.month, date.day);
    _setDate();
    for (int i = 0; i < 2; i++) {
      var data = chineseCalendar.getYearData(_dateTime.year - i);
      if (data != null) {
        int days = _dateTime.difference(data.getBeginDate()).inDays;
        _findInData(data, 1, 1 + days);
        break;
      }
    }
  }

  void add(int days) {
    var date = _dateTime.add(Duration(days: days));
    if (hasData && (date.year == _year || date.year == _year + 1)) {
      _findInData(yearData, _month, _day + days);
      _dateTime = date;
    } else
      setDate(date);
  }
}
