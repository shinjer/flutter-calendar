import 'package:flutter/material.dart';

import 'chinese_calendar.dart';

class CalendarEditor extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return CalendarEditorState();
  }
}

class CalendarEditorState extends State<CalendarEditor> {
  ChineseYearData yearData;

  @override
  void initState() {
    super.initState();
    updateYear(DateTime.now().year);
    initAsync();
  }

  Future<void> initAsync() async {
    await chineseCalendar.loadFile();
    onYearPressed(0);
  }

  @override
  Widget build(BuildContext context) {
    var dateText = yearData.getBeginDate().toString();
    dateText = dateText.substring(0, dateText.indexOf(" "));
    return Scaffold(
      appBar: AppBar(
        title: Text('農曆編輯器'),
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_2),
            onPressed: () => onLoadPressed(0),
          ),
          IconButton(
            icon: Icon(Icons.wb_sunny),
            onPressed: () => onLoadPressed(1),
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: onSavePressed,
          )
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.exposure_neg_1),
                  onPressed: () => onYearPressed(-1),
                ),
                IconButton(
                  icon: Icon(Icons.exposure_plus_1),
                  onPressed: () => onYearPressed(1),
                ),
                RaisedButton(
                  onPressed: onSelectDate,
                  child: Text("$dateText"),
                ),
                Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => onEditPressed(context),
                  ),
                ),
              ],
            ),
            Material(
              color: Colors.indigo,
              child: TabBar(
                tabs: [
                  Tab(text: "月份"),
                  Tab(text: "節氣"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  buildMonthList(),
                  buildSolarTermList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ListView buildMonthList() {
    var children = <Widget>[];
    children.length = yearData.length;
    for (int i = 0; i < children.length; i++) {
      int month = i + 1;
      if (yearData.hasLeapMonth) {
        if (i == yearData.leapMonth) {
          children[i] = ListTile(
            leading: Icon(Icons.subdirectory_arrow_right),
            title: Text(ChineseCalendar.toLeapMonthName(month)),
            trailing: Checkbox(
              value: yearData.isLongLeapMonth(),
              onChanged: (value) =>
                  onLongMonthChanged(ChineseYearData.leapMonthIndex, value),
            ),
          );
          continue;
        } else if (i > yearData.leapMonth) {
          month = i;
        }
      }
      children[i] = ListTile(
        leading: Icon(month == yearData.leapMonth
            ? Icons.remove_circle
            : Icons.add_circle),
        title: Text(ChineseCalendar.toMonthName(month)),
        trailing: Checkbox(
          value: yearData.isLongMonth(month),
          onChanged: (value) => onLongMonthChanged(month, value),
        ),
        onTap: () => onMonthTap(month),
      );
    }
    return ListView(children: children);
  }

  ListView buildSolarTermList() {
    var children = List<Widget>(DateTime.monthsPerYear);
    for (int i = 0; i < children.length; i++) {
      var row = List<Widget>(2);
      for (int j = 0; j < row.length; j++) {
        int id = i * 2 + j + 1;
        var date = yearData.getSolarTermDate(id);
        row[j] = Row(
          children: [
            Text("${date.month}/${date.day}"),
            IconButton(
              icon: Icon(Icons.remove_circle_outline),
              onPressed: () => onSolarTermPressed(id, -1),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline),
              onPressed: () => onSolarTermPressed(id, 1),
            ),
          ],
        );
      }
      children[i] = Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: row,
      );
    }
    return ListView(children: children);
  }

  void onLoadPressed(int kind) async {
    if (kind == 0)
      await chineseCalendar.loadMonthsTxt();
    else
      await chineseCalendar.loadSolarTermsTxt();
    onYearPressed(0);
  }

  void onSavePressed() async {
    var calendar = chineseCalendar;
    calendar.saveFile();
  }

  void updateYear(int year) {
    var data = chineseCalendar.getYearData(year);
    yearData = data ?? ChineseYearData(year);
  }

  void onYearPressed(int year) {
    setState(() => updateYear(yearData.year + year));
  }

  void onSelectDate() async {
    var date = await showDatePicker(
      context: context,
      initialDate: yearData.getBeginDate(),
      firstDate: DateTime(yearData.year),
      lastDate: DateTime(yearData.year + 1, 1, 0),
    );
    if (date != null) {
      setState(() => yearData.setBeginDate(date));
    }
  }

  void onEditPressed(BuildContext context) {
    var calendar = chineseCalendar;
    var hasYear = calendar.hasYearData(yearData.year);
    calendar.setYearData(yearData);
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text(hasYear ? "已修改" : "已新增"),
    ));
  }

  void onMonthTap(int month) {
    setState(() {
      if (month == yearData.leapMonth)
        yearData.leapMonth = 0;
      else
        yearData.leapMonth = month;
    });
  }

  void onLongMonthChanged(int month, bool value) {
    setState(() => yearData.setLongMonth(month, value));
  }

  void onSolarTermPressed(int id, int day) {
    setState(() {
      int begin = 1;
      int end = 15;
      if (id.isEven) {
        var date = DateTime(
            yearData.year, id ~/ 2 + ChineseCalendar.solarTermMonth, 0);
        begin = 0;
        end = date.day - 16;
      }
      int newDay = yearData.getSolarTermDay(id) + day;
      newDay = newDay < begin ? end : newDay <= end ? newDay : begin;
      yearData.setSolarTermDay(id, newDay);
    });
  }
}
