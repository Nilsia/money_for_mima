import 'package:flutter/material.dart';
import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/action_item.dart';
import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/item_menu.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/models/transactions.dart';
import 'package:money_for_mima/pages/home_page.dart';
import 'package:money_for_mima/utils/tools.dart';

import 'package:intl/intl.dart';

// day of month not updater (supposed also to year, and day)
// outsiderID duplicated with same name

class TransactionPage extends StatefulWidget {
  final int accountID;

  const TransactionPage(this.accountID, {Key? key}) : super(key: key);

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  List<ActionItem?> actionItemList = [
    ActionItem("Ajouter", Icons.add_box_outlined, true, ActionItemEnum.add),
    ActionItem("Modifier", Icons.edit, false, ActionItemEnum.edit),
    ActionItem("Supprimer", Icons.delete, false, ActionItemEnum.rm),
    ActionItem("Dupliquer", Icons.control_point_duplicate, false,
        ActionItemEnum.duplicate),
    ActionItem(
        "Remplacer", Icons.bookmark_outline, false, ActionItemEnum.replace),
    null,
    ActionItem("Importer", Icons.import_contacts, true, ActionItemEnum.imp)
  ];
  final double rowHeaderHeight = 32.0;
  DatabaseManager db = DatabaseManager();

  DateTime selectedDate = DateTime.now();
  List<int> clickedRowIndex = <int>[];

  TextEditingController dateController = TextEditingController(),
      amountController = TextEditingController(),
      outsiderController = TextEditingController();

  Account account = Account.none([], []);
  String accountSelectedName = "";
  List<Account> accountList = [];

  /*Account(
      1,
      "test",
      1200.0,
      1200.0,
      true,
      [
        Transactions(20.0, DateTime.now(), Outsider(0, "Carrefour"), false),
        Transactions(-220.0, DateTime.now(), Outsider(1, "Carrefour"), true)
      ],
      [],
      true);*/

  @override
  void initState() {
    initAll();

    initControllers();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //DateTime d = DateTime.parse(selectedDate.toString());
    return Scaffold(
      appBar: Tools.generateNavBar(PagesEnum.transaction, [account]),
      body: Row(
        children: [
          Tools.generateMenu(actionItemList,
              update: () => setState(() {}),
              actionItemTapped: (ActionItem item) => actionItemTapped(item)),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                generateAccountDropDown(),
                Container(
                  alignment: Alignment.topCenter,
                  child: Table(
                    border: TableBorder.all(),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const <int, TableColumnWidth>{
                      0: FixedColumnWidth(100), // Date
                      1: FixedColumnWidth(70), // Pointé
                      2: FixedColumnWidth(120), // Montant
                      3: FixedColumnWidth(200), // Solde
                      4: FlexColumnWidth(), // Tiers
                    },
                    children:
                        generateTableRows() /*.addAll(generateOperationsRows())*/,
                  ),
                ),
              ],
            ),
          ))
        ],
      ),
    );
  }

  void initControllers() {
    dateController.text = DateFormat("dd/MM/yyyy").format(selectedDate);
    amountController.text = "";
    outsiderController.text = "";
  }

  Widget generateAccountDropDown() {
    if (accountList.isEmpty) {
      return const SizedBox(width: 0, height: 0);
    }
    accountSelectedName = accountList.first.designation;
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 20, top: 10),
      child: Container(
        alignment: Alignment.topLeft,
        child: DropdownButton<String>(
          value: accountSelectedName,
          onChanged: accountList.length == 1
              ? null
              : (String? value) {
                  setState(() {
                    accountSelectedName = value!;
                  });
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

  TableRow generateRowAdder() {
    return TableRow(children: <Widget>[
      // date
      TableCell(
          child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () {
            Tools.selectDate(context, selectedDate, dateController,
                setState: () => setState(() {}));
          },
          child: TextFormField(
            controller: dateController,
            enabled: false,
            keyboardType: TextInputType.text,
          ),
        ),
      )),
      // state
      TableCell(
          child: SizedBox(
        child: Align(
          alignment: Alignment.center,
          child: Checkbox(
            value: false,
            onChanged: (bool? value) {},
          ),
        ),
      )), //
      // amount
      TableCell(
          child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: TextField(
          controller: amountController,
        ),
      )),
      // balance
      TableCell(child: Container()),
      // outsider
      TableCell(
          child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: outsiderController,
        ),
      ))
    ]);
  }

  TableRow generateHeader() {
    return TableRow(
      children: <Widget>[
        Tools.generateTableCell("DATE", rowHeaderHeight,
            alignment: Alignment.center),
        Tools.generateTableCell("POINTÉ", rowHeaderHeight,
            alignment: Alignment.center),
        Tools.generateTableCell("MONTANT", rowHeaderHeight,
            alignment: Alignment.center),
        Tools.generateTableCell("SOLDE", rowHeaderHeight,
            alignment: Alignment.center),
        Tools.generateTableCell("TIERS", rowHeaderHeight,
            alignment: Alignment.center),
      ],
    );
  }

  List<TableRow> generateTableRows() {
    List<TableRow> list = [];
    list.add(generateHeader());
    list.add(generateRowAdder());
    list.addAll(generateTransactionsRows());
    return list;
  }

  void unHoverAll() {
    for (var element in actionItemList) {
      if (element == null) {
        continue;
      }
      element.isHovering = false;
    }
  }

  List<TableRow> generateTransactionsRows() {
    return List<TableRow>.generate(account.transactionsList.length, (int i) {
      Transactions tr = account.transactionsList[i];
      double height = 50;
      Alignment a = Alignment.centerLeft;
      EdgeInsetsGeometry e = const EdgeInsets.only(left: 10.0);
      Color amountColor = tr.amount >= 0 ? Colors.green : Colors.red;
      BoxDecoration? decoration = clickedRowIndex.contains(i)
          ? const BoxDecoration(color: Colors.indigoAccent)
          : null;
      return TableRow(decoration: decoration, children: <Widget>[
        // date
        TableRowInkWell(
            onTap: () {
              manageTableRowClick(i);
            },
            child: Tools.generateTableCell(tr.formatDate(), height,
                alignment: a, pad: e)),
        // flagged
        Center(
          child: Checkbox(
            value: tr.flagged,
            onChanged: (bool? value) async {
              if (await tr.setFlaggedDB(db) == -1) {
                Tools.showNormalSnackBar(context, "Une erreur est survenue");
                return;
              }
              setState(() {});
            },
          ),
        ),
        // amount
        TableRowInkWell(
          onTap: () => {manageTableRowClick(i)},
          child: Tools.generateTableCell(tr.amount.toString(), height,
              alignment: a,
              pad: e,
              color: amountColor,
              fontWeight: FontWeight.bold),
        ),
        // balance
        TableRowInkWell(
          onTap: () {
            manageTableRowClick(i);
          },
          child: Tools.generateTableCell(account.balance.toString(), height,
              alignment: a, pad: e),
        ),
        // outsider
        TableRowInkWell(
            onTap: () {
              manageTableRowClick(i);
            },
            child: Tools.generateTableCell(tr.outsider!.name, height,
                alignment: a, pad: e)),
      ]);
    });
  }

  void manageTableRowClick(int i) {
    if (clickedRowIndex.contains(i)) {
      clickedRowIndex.remove(i);
      verifyActionItemList();
    } else {
      clickedRowIndex.add(i);
      verifyActionItemList();
    }

    setState(() {});
  }

  void verifyActionItemList() {
    switch (clickedRowIndex.length) {
      case 0:
        initActionItems();
        break;
      case 1:
        setAllActionItemToEnable();
        break;
      default:
        setActionItemSeveralSelected();
        break;
    }
  }

  void setActionItemSeveralSelected() {
    for (ActionItem? value in actionItemList) {
      if (value == null) {
        continue;
      }
      switch (value.actionItemEnum) {
        case ActionItemEnum.imp:
        case ActionItemEnum.rm:
        case ActionItemEnum.add:
          value.enable = true;
          break;
        case ActionItemEnum.edit:
        case ActionItemEnum.duplicate:
        case ActionItemEnum.replace:
        case ActionItemEnum.exp:
          value.enable = false;
          break;
      }
    }
  }

  void setAllActionItemToEnable() {
    for (ActionItem? value in actionItemList) {
      if (value == null) {
        continue;
      }
      value.enable = true;
    }
  }

  void initActionItems() {
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
          value.enable = false;
          break;
      }
    }
  }

  Future<void> actionItemTapped(ActionItem item) async {
    if (item.text.isEmpty || !item.enable) {
      return;
    }

    switch (item.actionItemEnum) {
      case ActionItemEnum.add:
        if (dateController.text.isNotEmpty &&
            outsiderController.text.isNotEmpty &&
            amountController.text.isNotEmpty) {
          await db.addTransactionsToAccount(
              account.id,
              Transactions(0, double.parse(amountController.text), selectedDate,
                  Outsider(0, outsiderController.text), false));
          initControllers();
          reloadAccountWithCheck();
        }
        break;
      case ActionItemEnum.rm:
        // TODO: Handle this case.
        break;
      case ActionItemEnum.edit:
        // TODO: Handle this case.
        break;
      case ActionItemEnum.duplicate:
        // TODO: Handle this case.
        break;
      case ActionItemEnum.imp:
        // TODO: Handle this case.
        break;
      case ActionItemEnum.replace:
        // TODO: Handle this case.
        break;
      case ActionItemEnum.exp:
        // TODO: Handle this case.
        break;
    }
  }

  Future<void> reloadAccountList({bool init = false}) async {
    accountList = await db.getAllAccounts();
  }

  Future<void> reloadAccountWithCheck() async {
    if (!await db.initDone()) {
      db.init().then((value) => {
            reloadAccount(),
          });
    } else {
      reloadAccount();
    }
    accountSelectedName = account.designation;
  }

  void initAll() async {
    db.init().then((value) async =>
        {reloadAccountWithCheck(), await reloadAccountList(), setState(() {})});
  }

  void reloadAccount() {
    db.getAccount(super.widget.accountID).then((value) => {
          if (value == null)
            {
              Navigator.push(
                  context,
                  PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const HomePage()))
            },
          account = value!,
          setState(() {})
        });
  }
}
