import 'package:flutter/material.dart';

import 'chinese_calendar.dart';
import 'main.dart';

const chineseCalendarName = "農曆";
const weekDayNames = ["日", "一", "二", "三", "四", "五", "六"];

extension IntExtensions on int {
  String padZero(int width) => this.toString().padLeft(width, "0");
}

class CalendarPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return CalendarPageState();
  }
}

class CalendarPageState extends State<CalendarPage> {
  static const holidayColor = Colors.red;

  int baseYear = 2020;
  int currentPage;
  DateTime selectedDate;
  PageController _controller;
  double monthTableHeight;

  @override
  void initState() {
    super.initState();
    var today = todayDate();
    selectedDate = today;
    currentPage = monthToPage(today.year, today.month);
    _controller = PageController(initialPage: currentPage);
    initAsync();
  }

  Future<void> initAsync() async {
    await chineseCalendar.loadFile();
    int year = pageToYear(currentPage);
    int month = pageToMonth(currentPage);
    baseYear = 2019;
    int newPage = monthToPage(year, month);
    print("init.newPage=$newPage,$currentPage");
    if (newPage == currentPage)
      onPageChanged(currentPage);
    else
      _controller.jumpToPage(newPage);
  }

  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var text = pageToMonth(currentPage).padZero(2);
    var today = todayDate();
    print("build.page=$currentPage");
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
                icon: Icon(Icons.fast_rewind),
                onPressed: () => onMonthChanged(-DateTime.monthsPerYear)),
            IconButton(
                icon: Icon(Icons.keyboard_arrow_left),
                onPressed: () => onMonthChanged(-1)),
            Text("${pageToYear(currentPage)}-$text"),
            IconButton(
                icon: Icon(Icons.keyboard_arrow_right),
                onPressed: () => onMonthChanged(1)),
            IconButton(
                icon: Icon(Icons.fast_forward),
                onPressed: () => onMonthChanged(DateTime.monthsPerYear)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: onEditorPressed,
          )
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        print(
            "body.page=$currentPage,${_controller.hasClients ? _controller.page : null}");
        var orientation = MediaQuery.of(context).orientation;
        var height = constraints.maxHeight;
        if (orientation == Orientation.portrait) {
          height *= 0.5;
          return Column(children: [
            Expanded(child: buildCalendar(height)),
            Expanded(child: buildDateInfo(height)),
          ]);
        } else {
          return Row(children: [
            Expanded(child: buildCalendar(height)),
            Expanded(child: buildDateInfo(height)),
          ]);
        }
      }),
      floatingActionButton: selectedDate == today
          ? null
          : FloatingActionButton(
              child: Text("今", style: TextStyle(fontSize: 30)),
              onPressed: () => onDateChanged(DateTime.now()),
            ),
    );
  }

  Widget buildCalendar(double layoutHeight) {
    var height = layoutHeight * 0.08;
    monthTableHeight = layoutHeight - height;
    var weekRow = List<Widget>(weekDayNames.length);
    for (int i = 0; i < weekRow.length; i++) {
      weekRow[i] = SizedBox(
        height: height,
        child: FittedBox(
          child: Text(
            weekDayNames[i],
            style: TextStyle(color: isWeekend(i) ? holidayColor : null),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekRow,
        ),
        Expanded(
          child: PageView.builder(
            key: PageStorageKey(1),
            controller: _controller,
            onPageChanged: onPageChanged,
            itemBuilder: buildMonthTable,
          ),
        ),
      ],
    );
  }

  Widget buildMonthTable(BuildContext context, int index) {
    int year = pageToYear(index);
    int month = pageToMonth(index);
    var date = DateTime(year, month);
    var nextMonth = DateTime(date.year, date.month + 1);
    if (date.weekday != DateTime.sunday)
      date = date.subtract(Duration(days: date.weekday));
    var days = nextMonth.difference(date).inDays;
    var is5rows = days <= 35;
    var rows = List<TableRow>(is5rows ? 5 : 6);
    var boxHeight = monthTableHeight / 6;
    var height1 = boxHeight * 8 / 15;
    var height2 = boxHeight - height1;
    var boxPadding =
        is5rows ? EdgeInsets.symmetric(vertical: boxHeight / 10) : null;
    var selectedDeco = BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      color: Colors.lightBlue,
    );
    var todayDeco = BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      color: Colors.lightBlue.withAlpha(64),
    );
    var today = todayDate();
    var cdate = ChineseDate(date);
    for (int j = 0; j < rows.length; j++) {
      var row = List<Widget>(weekDayNames.length);
      for (int i = 0; i < row.length; i++) {
        var date1 = date;
        var color = date.month == month ? getDateColor(date) : Colors.grey;
        var text = Column(children: [
          SizedBox(
            height: height1,
            child: FittedBox(
              child: Text(
                "${date.day}",
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(
            height: height2,
            child: cdate.hasData
                ? FittedBox(
                    child: Text(
                      cdate.displayName,
                      style: TextStyle(color: color),
                    ),
                  )
                : null,
          ),
        ]);
        row[i] = GestureDetector(
          child: Container(
            padding: boxPadding,
            decoration: date1 == selectedDate
                ? selectedDeco
                : date1 == today
                    ? todayDeco
                    : null,
            child: text,
          ),
          onTap: () => onDateChanged(date1),
          behavior: HitTestBehavior.translucent,
        );
        date = date.add(Duration(days: 1));
        cdate.add(1);
      }
      rows[j] = TableRow(children: row);
    }
    return Table(children: rows);
  }

  Widget buildDateInfo(double layoutHeight) {
    var cdate = ChineseDate(selectedDate);
    var ctext = "$chineseCalendarName${cdate.dateName}";
    return Column(
      children: [
        Divider(height: 8, thickness: 8),
        Text.rich(TextSpan(children: [
          TextSpan(text: "$ctext\n"),
          TextSpan(text: cdate.yearName),
        ])),
        Expanded(child: Container(color: Colors.black12)),
      ],
    );
  }

  void onPageChanged(int page) {
    setState(() {
      currentPage = page;
    });
  }

  void onMonthChanged(int month) {
    _controller.animateToPage(currentPage + month,
        duration: Duration(milliseconds: 500), curve: Curves.ease);
  }

  void onDateChanged(DateTime date) {
    selectedDate = DateTime(date.year, date.month, date.day);
    int newPage = monthToPage(date.year, date.month);
    if (newPage == currentPage)
      onPageChanged(currentPage);
    else
      onMonthChanged(newPage - currentPage);
  }

  Future<void> onEditorPressed() async {
    await MyApp.openCalendarEditor(context);
    onPageChanged(currentPage);
  }

  DateTime todayDate() {
    var date = DateTime.now();
    return DateTime(date.year, date.month, date.day);
  }

  int pageToYear(int page) => baseYear + page ~/ DateTime.monthsPerYear;
  int pageToMonth(int page) => page % DateTime.monthsPerYear + 1;
  int monthToPage(int year, int month) =>
      (year - baseYear) * DateTime.monthsPerYear + month - 1;

  bool isWeekend(int wday) => wday < DateTime.monday || wday > DateTime.friday;
  Color getDateColor(DateTime date) {
    return isWeekend(date.weekday) ? holidayColor : null;
  }
}
