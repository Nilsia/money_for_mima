import 'package:flutter/material.dart';

enum ActionItemEnum { add, rm, edit, duplicate, imp, replace, exp, unSelectAll }

class ActionItem {
  final String text;
  final IconData? iconData;
  bool isHovering = false, empty = false, enable, hidden;
  ActionItemEnum actionItemEnum;

  ActionItem(this.text, this.iconData, this.enable, this.actionItemEnum,
      {this.hidden = false});

  @override
  String toString() {
    return "text: $text, icon: $iconData, ";
  }
}
