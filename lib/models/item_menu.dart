import 'package:flutter/material.dart';
import 'package:money_for_mima/pages/due_page.dart';
import 'package:money_for_mima/pages/home_page.dart';
import 'package:money_for_mima/pages/settings_page.dart';
import 'package:money_for_mima/pages/transaction_page.dart';

enum PagesEnum { home, due, transaction, settings }

class ItemMenu {
  final String text;
  final Icon icon;
  PagesEnum pageTarget;
  bool isHovering = false, needAccount;

  ItemMenu(this.text, this.icon, this.pageTarget, {this.needAccount = true});

  /// return true if has navigated else false
  bool navigate(PagesEnum currentPage, BuildContext context, int accountID) {
    final Widget widget;
    print("navigating to ${pageTarget.name}");
    if (pageTarget.name == currentPage.name) {
      return false;
    }
    switch (pageTarget) {
      case PagesEnum.home:
        widget = const HomePage();
        break;
      case PagesEnum.due:
        widget = DuePage(accountID);
        break;
      case PagesEnum.transaction:
        widget = TransactionPage(accountID);
        break;
      case PagesEnum.settings:
        widget = SettingsPage(accountID);
        break;
    }

    Navigator.push(
        context, PageRouteBuilder(pageBuilder: (_, __, ___) => widget));
    return true;
  }
}
