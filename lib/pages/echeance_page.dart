import 'package:flutter/material.dart';
import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/item_menu.dart';
import 'package:money_for_mima/utils/tools.dart';

class EcheancePage extends StatefulWidget {
  const EcheancePage({Key? key}) : super(key: key);

  @override
  State<EcheancePage> createState() => _EcheancePageState();
}

class _EcheancePageState extends State<EcheancePage> {
  List<Account> accountList = [];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Tools.generateNavBar(PagesEnum.echeance, accountList),
    );
  }
}
