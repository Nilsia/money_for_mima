import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:money_for_mima/includes/app_bar_content.dart';
import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/action_item.dart';
import 'package:money_for_mima/models/due.dart';
import 'package:money_for_mima/models/item_menu.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/utils/custom_color_schema.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BoolPointer {
  bool i = false;
}

enum PopupAction { edit, delete, add }

extension NumberExtension on num {
  bool get isInteger => this is int;
}

class SDenum {
  int? defaultt;
  String label;
  Map<String?, Object?>? map;

  SDenum(this.label, {this.defaultt, this.map}) {
    map ??= {};
  }

  SDenum.none({this.label = "", this.defaultt, this.map});
}

enum DialogError {
  dateBefore,
  dateAfter,
  invalidAmount,
  invalidOutsider,
  unknown,
  noError,
  tooMuchPrecision,
}

class Tools {
  static const menuBackgroundColor = Colors.blueAccent;

  static const double menuWidth = 200;
  static const double appBarHeight = 60.0;

  static List<T> nullFilter<T>(List<T?> list) => [...list.whereType<T>()];

  static PreferredSize generateNavBar(
      PagesEnum currentPage, List<Account> accountList) {
    final List<ItemMenu> itemMenuList = [
      ItemMenu("Accueil", const Icon(Icons.home), PagesEnum.home),
      ItemMenu("Opérations", const Icon(Icons.book), PagesEnum.transaction),
      ItemMenu(
          "Échéances", const Icon(Icons.calendar_today_rounded), PagesEnum.due),
      ItemMenu("Paramètres", const Icon(Icons.settings), PagesEnum.settings),
    ];

    return PreferredSize(
      preferredSize: const Size.fromHeight(appBarHeight),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Colors.blue, Colors.pink],
          ),
        ),
        child:
            AppBarContent(itemMenuList, currentPage, appBarHeight, accountList),
      ),
    );
  }

  static getBackgroundList(BuildContext context) => [
        Theme.of(context).colorScheme.backgroundListDistinct1,
        Theme.of(context).colorScheme.backgroundListDistinct2
      ];

  static Widget generateTableCell(String text, double? height,
      {Alignment alignment = Alignment.centerLeft,
      EdgeInsetsGeometry pad = EdgeInsets.zero,
      Color? color,
      FontWeight? fontWeight}) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: pad,
        child: Align(
          alignment: alignment,
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: fontWeight),
          ),
        ),
      ),
    );
  }

  static Widget _buildTableCellContainer(
      {required Widget child, required double width, required double height}) {
    return SizedBox(width: width, height: height, child: child);
  }

  static Widget buildTableCell(String text, double height, double width,
      {Alignment alignment = Alignment.centerLeft,
      EdgeInsetsGeometry pad = EdgeInsets.zero,
      Color? color,
      FontWeight? fontWeight,
      BoxDecoration? decoration,
      Widget? child}) {
    return _buildTableCellContainer(
        child: Container(
          decoration: decoration,
          child: Padding(
            padding: pad,
            child: Align(
                alignment: alignment,
                child: child ??
                    Text(text,
                        style:
                            TextStyle(color: color, fontWeight: fontWeight))),
          ),
        ),
        width: width,
        height: height);
  }

  static Widget generateMenu(List<ActionItem?> actionItemList,
      {void Function(ActionItem item)? actionItemTapped,
      void Function()? update}) {
    List<int> aiToRemove = <int>[];
    for (int i = 0; i < actionItemList.length; i++) {
      if (actionItemList[i] != null && actionItemList[i]!.hidden) {
        aiToRemove.add(i);
      }
    }

    int nbRemoved = 0;
    for (int i in aiToRemove) {
      actionItemList.removeAt(i - nbRemoved);
      nbRemoved++;
    }

    return SizedBox(
        width: menuWidth,
        height: double.infinity,
        child: Container(
          width: menuWidth,
          decoration: const BoxDecoration(color: menuBackgroundColor),
          height: double.infinity,
          child: ListView.builder(
              itemCount: actionItemList.length,
              itemBuilder: (BuildContext context, int i) {
                ActionItem item = actionItemList[i] == null
                    ? ActionItem("", null, false, ActionItemEnum.add)
                    : actionItemList[i]!;

                Color? itemColor = item.enable ? null : Colors.grey;
                SystemMouseCursor? smc =
                    item.enable ? SystemMouseCursors.click : null;

                return AnimatedContainer(
                  duration: const Duration(microseconds: 200),
                  decoration: BoxDecoration(
                      color: item.isHovering && item.enable
                          ? Colors.red
                          : menuBackgroundColor),
                  child: InkWell(
                    onTap: () {
                      if (actionItemTapped != null) {
                        actionItemTapped(item);
                      }
                    },
                    onHover: (bool hovering) {
                      if (item.text.isEmpty) {
                        return;
                      }
                      item.isHovering = hovering;
                      if (update != null) {
                        update();
                      }
                    },
                    child: ListTile(
                      mouseCursor: smc,
                      title: Text(
                        item.text,
                        style: TextStyle(color: itemColor),
                      ),
                      leading: Icon(
                        item.iconData,
                        color: itemColor,
                      ),
                    ),
                  ),
                );
              }),
        ));
  }

  static Future<DateTime?> selectDate(BuildContext context,
      DateTime selectedDate, TextEditingController dateController,
      {void Function()? setState}) async {
    final DateTime? dateTime = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2050),
        initialDatePickerMode: DatePickerMode.day);
    if (dateTime != null) {
      selectedDate = dateTime;
      dateController.text = DateFormat("dd/MM/yyyy").format(selectedDate);
      if (setState == null) {
        return selectedDate;
      }
      setState();
      return selectedDate;
    }
    return null;
  }

  static bool stringToBool(String v) {
    return v == "true";
  }

  static SnackBar showNormalSnackBar(BuildContext context, String text) {
    SnackBar snackBar = SnackBar(content: Text(text));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    return snackBar;
  }

  static bool areSameDay(DateTime d1, DateTime d2) {
    return d1.day == d2.day && d1.month == d2.month && d1.year == d2.year;
  }

  static Widget buildAccountDropDown(
      {required List<Account> accountList,
      required Account account,
      required String accountSelectedName,
      required void Function() update,
      required void Function(int) onSelection,
      bool isExpanded = true}) {
    if (accountList.isEmpty) {
      return const SizedBox(width: 0, height: 0);
    }
    if (accountSelectedName.isEmpty) {
      accountSelectedName = account.isNone()
          ? accountList.first.designation
          : account.designation;
    }
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 20, top: 10),
      child: Container(
        alignment: Alignment.topLeft,
        child: DropdownButton<String>(
          value: accountSelectedName,
          elevation: 16,
          isExpanded: isExpanded,
          onChanged: accountList.length == 1
              ? null
              : (String? value) {
                  accountSelectedName = value!;
                  for (Account ac in accountList) {
                    if (ac.designation == value) {
                      onSelection(ac.id);
                      break;
                    }
                  }
                  update();
                },
          items: accountList.map<DropdownMenuItem<String>>((Account ac) {
            return DropdownMenuItem<String>(
              value: ac.designation,
              child: Text(ac.designation),
            );
          }).toList(),
        ),
      ),
    );
  }

  static String formatDate(DateTime date) {
    return DateFormat("dd/MM/yyyy").format(date);
  }

  static String periodToString(Period? period) {
    switch (period) {
      case null:
        return "Une seule fois";
      case Period.daily:
        return "Chaque jour";
      case Period.weekly:
        return "Chaque semaine";
      case Period.monthly:
        return "Chaque mois";
      case Period.quarterly:
        return "Tous les 3 mois";
      case Period.biAnnual:
        return "Chaque semestre";
      case Period.yearly:
        return "Tous les ans";
    }
  }

  static void verifyActionItemList(
      List<int> clickedRowsList, List<ActionItem?> actionItemList) {
    switch (clickedRowsList.length) {
      case 0:
        initActionItems(actionItemList);
        break;
      case 1:
        setAllActionItemToEnable(actionItemList);
        break;
      default:
        setActionItemSeveralSelected(actionItemList);
        break;
    }
  }

  static void setAllActionItemToEnable(List<ActionItem?> actionItemList) {
    for (ActionItem? value in actionItemList) {
      if (value == null) {
        continue;
      }
      value.enable = true;
    }
  }

  static void setActionItemSeveralSelected(List<ActionItem?> actionItemList) {
    for (ActionItem? value in actionItemList) {
      if (value == null) {
        continue;
      }
      switch (value.actionItemEnum) {
        case ActionItemEnum.imp:
        case ActionItemEnum.rm:
        case ActionItemEnum.duplicate:
        case ActionItemEnum.add:
        case ActionItemEnum.unSelectAll:
          value.enable = true;
          break;
        case ActionItemEnum.edit:
        case ActionItemEnum.replace:
        case ActionItemEnum.exp:
          value.enable = false;
          break;
      }
    }
  }

  static void initActionItems(List<ActionItem?> actionItemList) {
    for (ActionItem? value in actionItemList) {
      if (value == null) {
        continue;
      }
      switch (value.actionItemEnum) {
        case ActionItemEnum.imp:
        case ActionItemEnum.add:
          value.enable = true;
          break;
        case ActionItemEnum.rm:
        case ActionItemEnum.edit:
        case ActionItemEnum.duplicate:
        case ActionItemEnum.replace:
        case ActionItemEnum.exp:
        case ActionItemEnum.unSelectAll:
          value.enable = false;
          break;
      }
    }
  }

  static void manageTableRowClick(
      int i, List<int> clickedRowsList, List<ActionItem?> actionItemList,
      {required void Function() setState}) {
    if (clickedRowsList.contains(i)) {
      clickedRowsList.remove(i);
    } else {
      clickedRowsList.add(i);
    }
    Tools.verifyActionItemList(clickedRowsList, actionItemList);

    setState();
  }

  static DateTime? generateNextDateTime(Period period, DateTime date,
      {int last = 1, DateTime? referenceDate}) {
    referenceDate ??= date;
    DateTime newDate = date;
    if (last == 0) {
      return null;
    }

    switch (period) {
      case Period.daily:
        return date.add(Duration(days: last));
      case Period.weekly:
        return date.add(Duration(days: 7 * last));
      case Period.monthly:
        if (last > 0) {
          for (int i = 0; i < last; i++) {
            if (newDate.month == 12) {
              newDate = DateTime(newDate.year + 1, 1, referenceDate.day);
            } else {
              newDate = DateTime(
                  newDate.year,
                  newDate.month + 1,
                  min(referenceDate.day,
                      getDaysInMonth(newDate.year, newDate.month + 1)));
            }
          }
        } else {
          for (int i = 0; i < last.abs(); i++) {
            if (newDate.month == 1) {
              newDate = DateTime(newDate.year - 1, 12, referenceDate.day);
            } else {
              newDate = DateTime(
                  newDate.year,
                  newDate.month - 1,
                  min(referenceDate.day,
                      getDaysInMonth(newDate.year, newDate.month - 1)));
            }
          }
        }
        return newDate;
      case Period.quarterly:
        return generateNextDateTime(Period.monthly, date,
            referenceDate: referenceDate, last: 3 * last);
      case Period.biAnnual:
        return generateNextDateTime(Period.monthly, date,
            referenceDate: referenceDate, last: 6 * last);
      case Period.yearly:
        return generateNextDateTime(Period.monthly, date,
            referenceDate: referenceDate, last: 12 * last);
    }
  }

  static int getDaysInMonth(int year, int month) {
    if (month == DateTime.february) {
      final bool isLeapYear =
          (year % 4 == 0) && (year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const List<int> daysInMonth = <int>[
      31,
      -1,
      31,
      30,
      31,
      30,
      31,
      31,
      30,
      31,
      30,
      31
    ];
    return daysInMonth[month - 1];
  }

  static Widget buildSearchBar(
      {required TextEditingController controller,
      required SDenum sd,
      required double width,
      required void Function(Object? s) onSelected,
      required void Function() setState,
      bool enableFilter = true,
      FocusNode? focusNode}) {
    width = max(width, 170);
    final List<DropdownMenuEntry<String>> dropdownItems = [];

    sd.map!.forEach((String? key, Object? value) {
      if (key == null || value == null) {
        dropdownItems.add(
            const DropdownMenuEntry(value: "", label: "---", enabled: false));
      } else {
        dropdownItems
            .add(DropdownMenuEntry(value: value.toString(), label: key));
      }
    });
    return Row(
      children: [
        Focus(
          focusNode: focusNode,
          child: DropdownMenu<String>(
            menuHeight: 300,
            width: width,
            controller: controller,
            dropdownMenuEntries: dropdownItems,
            enableFilter: enableFilter,
            leadingIcon: const Icon(Icons.search),
            label: Text(sd.label),
            onSelected: onSelected,
            trailingIcon: const Icon(Icons.arrow_drop_down),
          ),
        ),
        SizedBox(
          width: 23,
          child: InkWell(
            child: const Icon(Icons.close),
            onTap: () {
              controller.clear();
              enableFilter = false;
              setState();
            },
          ),
        )
      ],
    );
  }

  static Map<String, Outsider> getOutsiderListName(List<Outsider> oList) {
    Map<String, Outsider> nl = {};
    for (Outsider o in oList) {
      nl[o.name] = o;
    }
    return nl;
  }

  static Future<bool?> confirmRemoveItem(
      BuildContext context, String title, String s,
      {bool overwrite = false}) async {
    return buildSimpleAlertDialog(context, title,
        "${!overwrite ? "Êtes-vous sûr(e) de vouloir supprimer $s" : s} Cette action est irréversible",
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.grey)),
              child: const Text("ANNULER")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Colors.red)),
            child: const Text("VALIDER"),
          )
        ]);
  }

  static Future<bool?> buildSimpleAlertDialog(
      BuildContext context, String title, String content,
      {List<Widget>? actions}) {
    actions ??= [
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(true),
        style:
            ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.red)),
        child: const Text("OK"),
      )
    ];

    return showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: SizedBox(child: Text(content)),
              actions: actions,
            ));
  }

  static Widget buildIntChoice(List<int> intList, int? defaultIndex,
      {required double width,
      required TextEditingController controller,
      required String label,
      required void Function(int? value) onSelected,
      bool enableFilter = false}) {
    if (defaultIndex == null || intList.isEmpty) {
      intList.add(10);
      defaultIndex = 0;
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        alignment: Alignment.centerLeft,
        child: DropdownMenu<int>(
          initialSelection: intList[defaultIndex],
          menuHeight: 300,
          width: width,
          controller: controller,
          enableFilter: enableFilter,
          label: Text(label),
          dropdownMenuEntries: intList
              .map((e) => DropdownMenuEntry(value: e, label: e.toString()))
              .toList(),
          onSelected: onSelected,
        ),
      ),
    );
  }

  static Future<SharedPreferences> getSP() async {
    return await SharedPreferences.getInstance();
  }

  static Future<PackageInfo> getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  static Future<String> getPrefsVersion(
      {SharedPreferences? sharedPreferences}) async {
    SharedPreferences sp = sharedPreferences ?? await getSP();

    return sp.getString("appVersion") ?? "";
  }

  static Future<bool> getShowNewVersion(
      {SharedPreferences? sharedPreferences}) async {
    SharedPreferences sp = sharedPreferences ?? await getSP();
    return sp.getBool("showNewVersion") ?? true;
  }

  /// takes the value [state] and put it into shared preferences, the function
  ///  return [state], if [sharedPreferences] is not given it get from Tools
  static Future<bool> setShowNewVersion(bool state,
      {required SharedPreferences? sharedPreferences}) async {
    SharedPreferences sp = sharedPreferences ?? await getSP();
    await sp.setBool("showNewVersion", state);
    return state;
  }

  static Future<String> getPackageVersion({PackageInfo? packageInfo}) async {
    PackageInfo pi = packageInfo ?? await getPackageInfo();
    return pi.version;
  }

  static Future<bool> getShowDialogOnError(
      {SharedPreferences? sharedPreferences}) async {
    SharedPreferences sp = sharedPreferences ?? await getSP();
    return sp.getBool("showDialogOnError") ?? true;
  }

  /// takes the value [state] and put it into shared preferences, the function
  ///  return [state], if [sharedPreferences] is not given it get from Tools
  static Future setShowDialogOnError(bool state,
      {required SharedPreferences? sharedPreferences}) async {
    SharedPreferences sp = sharedPreferences ?? await getSP();
    await sp.setBool("showDialogOnError", state);
    return state;
  }
}
