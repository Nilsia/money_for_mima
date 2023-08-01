import 'package:flutter/material.dart';
import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/item_menu.dart';

class AppBarContent extends StatefulWidget {
  final List<ItemMenu> itemMenuList;
  final PagesEnum currentPage;
  final double appBarHeight;
  final List<Account> accountList;

  const AppBarContent(
      this.itemMenuList, this.currentPage, this.appBarHeight, this.accountList,
      {super.key});

  @override
  State<AppBarContent> createState() => _AppBarContent();
}

class _AppBarContent extends State<AppBarContent> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0.0),
          child: Row(
            children: List.generate(super.widget.itemMenuList.length,
                (index) => generateItemMenu(index, context)),
          ),
        ),
      ],
    );
  }

  Widget generateItemMenu(int index, BuildContext context) {
    ItemMenu itemMenu = super.widget.itemMenuList[index];
    Border? bd = itemMenu.pageTarget == super.widget.currentPage
        ? const Border(bottom: BorderSide(color: Colors.white, width: 4))
        : null;
    return InkWell(
      onTap: () {
        if (super.widget.accountList.isEmpty) {
          final db = DatabaseManager();
          // get selected account and go to its requested page
          db.init().then((value) {
            db.getIdOfSelectedAccount().then((id) {
              if (id == null) {
                itemMenu.pageTarget = PagesEnum.home;
                itemMenu.navigate(super.widget.currentPage, context, -1);
                return;
              }
              itemMenu.navigate(super.widget.currentPage, context, id);
            });
          });
          return;
        }
        if (super.widget.accountList.length == 1) {
          itemMenu.navigate(super.widget.currentPage, context,
              super.widget.accountList[0].id);
        } else {
          for (Account ac in super.widget.accountList) {
            if (ac.selected) {
              itemMenu.navigate(super.widget.currentPage, context, ac.id);
              break;
            }
          }
        }
      },
      onHover: (bool isHovering) {
        itemMenu.isHovering = isHovering;
        setState(() {});
      },
      child: Container(
        height: super.widget.appBarHeight,
        decoration: BoxDecoration(
            color: itemMenu.isHovering ? Colors.amberAccent : null, border: bd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [itemMenu.icon, Text(itemMenu.text)]),
        ),
      ),
    );
  }
}
