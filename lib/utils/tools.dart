import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:money_for_mima/includes/app_bar_content.dart';
import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/action_item.dart';
import 'package:money_for_mima/models/item_menu.dart';

class Tools {
  static const menuBackgroundColor = Colors.blueAccent;

  static PreferredSize generateNavBar(
      PagesEnum currentPage, List<Account> accountList) {
    final List<ItemMenu> itemMenuList = [
      ItemMenu("Accueil", const Icon(Icons.home), PagesEnum.home),
      ItemMenu("Opérations", const Icon(Icons.book), PagesEnum.transaction),
      ItemMenu("Échéances", const Icon(Icons.calendar_today_rounded),
          PagesEnum.echeance),
    ];

    const double appBarHeight = 60.0;

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

  static Widget generateMenu(List<ActionItem?> actionItemList,
      {void Function(ActionItem item)? actionItemTapped,
      void Function()? update}) {
    return SizedBox(
        width: 200,
        height: double.infinity,
        child: Container(
          width: 100,
          decoration: const BoxDecoration(color: menuBackgroundColor),
          height: double.infinity,
          //decoration: const BoxDecoration(color: Colors.red),
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

  static void selectDate(BuildContext context, DateTime selectedDate,
      TextEditingController dateController,
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
        return;
      }
      setState();
    }
  }

  static bool stringToBool(String v) {
    return v == "true";
  }

  static SnackBar showNormalSnackBar(BuildContext context, String text) {
    SnackBar snackBar = SnackBar(content: Text(text));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    return snackBar;
  }
}
