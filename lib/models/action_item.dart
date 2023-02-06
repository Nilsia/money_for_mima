import 'package:flutter/material.dart';

enum ActionItemEnum { add, rm, edit, duplicate, imp, replace, exp }

class ActionItem {
  final String text;
  final IconData? iconData;
  bool isHovering = false, empty = false, enable;
  ActionItemEnum actionItemEnum;

  ActionItem(this.text, this.iconData, this.enable, this.actionItemEnum);

  @override
  String toString() {
    // TODO: implement toString
    return "text: $text, icon: $iconData, ";
  }

}
