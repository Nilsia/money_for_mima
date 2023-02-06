import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/action_item.dart';
import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/item_menu.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/models/transactions.dart';
import 'package:money_for_mima/pages/transaction_page.dart';
import 'package:money_for_mima/utils/tools.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DatabaseManager db = DatabaseManager();
  PagesEnum currentPage = PagesEnum.home;
  List<Account> accountList = [];

  /*[
    Account(
        1,
        "test",
        1200,
        1000,
        true,
        [
          Transactions(20.0, DateTime.now(), Outsider(1, "Carrefour"), false),
          Transactions(-220.0, DateTime.now(), Outsider(1, "Carrefour"), true)
        ],
        [],
        true),
    Account(1, "compte bancaire principal", -4025155518661, -715, false, [], [],
        false),
  ];*/

  DateTime accountDate = DateTime.now();
  TextEditingController acNameCont = TextEditingController(),
      acBalanceCont = TextEditingController(),
      acDateCont = TextEditingController();

  final Color accountsBorderColor = Colors.black;
  final double accountsListWidth = 300;
  bool hasInit = false;

  List<ActionItem> actionItemList = [
    ActionItem("Ajouter", Icons.add, true, ActionItemEnum.add)
  ];

  @override
  void initState() {
    db.init().then((value) async {
      db.getAllAccounts().then((value) {
        accountList = value;
        setState(() {});
      });
    });
    initTextFieldsDialog();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Tools.generateNavBar(currentPage, accountList),
      body: Row(
        children: [
          Tools.generateMenu(actionItemList,
              update: () => setState(() {}),
              actionItemTapped: (ActionItem item) => manageOnTapItemMenu(item)),
          generateElements()
        ],
      ),
    );
  }

  Widget generateElements() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          height: double.infinity,
          width: double.infinity,
          child: Row(
            children: [
              generateListOfAccounts(),
            ],
          ),
        ),
      ),
    );
  }

  Widget generateListOfAccounts() {
    return Expanded(
        flex: 1,
        child: Column(
          //crossAxisAlignment: CrossAxisAlignment.start, stick col to the start
          children: [
            // title
            Container(
              width: accountsListWidth,
              decoration: BoxDecoration(
                  border: Border(
                      left: BorderSide(color: accountsBorderColor),
                      right: BorderSide(color: accountsBorderColor),
                      top: BorderSide(color: accountsBorderColor))),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Align(
                    alignment: Alignment.center,
                    child: Text("Tous vos comptes")),
              ),
            ),
            // all lists
            Container(
              width: accountsListWidth,
              height: 500,
              decoration:
                  BoxDecoration(border: Border.all(color: Colors.black)),
              // display all lists
              child: ListView.builder(
                  itemCount: accountList.length,
                  itemBuilder: (BuildContext context, int i) {
                    BorderSide borderBetween = i != accountList.length - 1
                        ? const BorderSide(color: Colors.grey)
                        : BorderSide.none;
                    Account ac = accountList[i];

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                            context,
                            PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    TransactionPage(ac.id)));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                            border: Border(bottom: borderBetween)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4.0, horizontal: 8),
                          child: Row(
                            children: generateAccountItem(ac),
                          ),
                        ),
                      ),
                    );
                  }),
            )
          ],
        ));
  }

  List<Widget> generateAccountItem(Account ac) {
    List<Widget> accountItem = [
      Expanded(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                ac.designation,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              ac.balance.toString(),
              style: TextStyle(
                  color: ac.balance >= 0 ? Colors.green : Colors.red,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            )
          ],
        ),
      )
    ];
    if (ac.selected) {
      accountItem.add(const Expanded(
        child: SizedBox(
          height: 45,
          child: Align(
              alignment: Alignment.bottomRight,
              child: Text(
                "sélectionné",
                style: TextStyle(fontSize: 10),
                overflow: TextOverflow.fade,
              )),
        ),
      ));
    }
    return accountItem;
  }

  void addListDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Ajout d'un compte"),
              content: SizedBox(
                width: 500,
                height: 230,
                child: Column(
                  children: [
                    const Text("Désignation du compte"),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 30.0, top: 8),
                      child: SizedBox(
                        width: 300,
                        child: TextField(
                          autofocus: true,
                          controller: acNameCont,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder()),
                        ),
                      ),
                    ),
                    // balance and date
                    const Text("Solde initial et la date de ce solde"),
                    Row(
                      children: [
                        // balance
                        Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                controller: acBalanceCont,
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder()),
                              ),
                            )),
                        // date
                        Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                controller: acDateCont,
                                decoration: const InputDecoration(
                                    labelText: "Date",
                                    border: OutlineInputBorder()),
                              ),
                            )),
                      ],
                    ),
                    // buttons
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ElevatedButton(
                                  style: ButtonStyle(
                                      backgroundColor:
                                          MaterialStateProperty.all(
                                              Colors.red)),
                                  onPressed: () => closeNewAccountDialog(),
                                  child: const Text("ANNULER")),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ElevatedButton(
                                  style: ButtonStyle(
                                      backgroundColor:
                                          MaterialStateProperty.all(
                                              Colors.green)),
                                  onPressed: () => submitNewAccountDialog(),
                                  child: const Text("AJOUTER")),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ));
  }

  void closeNewAccountDialog() {
    Navigator.of(context).pop();
  }

  Future<void> submitNewAccountDialog() async {
    if (acDateCont.text.isEmpty ||
        acBalanceCont.text.isEmpty ||
        acNameCont.text.isEmpty) {
      SnackBar snackBar = const SnackBar(
          content: Text("Les données fournies ne sont pas valides"));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }

    final double balance;
    try {
      balance = double.parse(acBalanceCont.text);
    } catch (e) {
      SnackBar snackBar = const SnackBar(content: Text("Solde founi invalide"));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }

    // check if name of account is already used
    for (var ac in accountList) {
      if (ac.designation == acNameCont.text) {
        SnackBar snackBar = const SnackBar(
            content: Text("Ce nom de compte est déjà utilisé !"));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        return;
      }
    }
    Account? selectedAC = getSelectedAccount();
    if (selectedAC != null) {
      selectedAC.setSelectionDB(db, false);
    }
    Account ac = await db.addAccount(acNameCont.text, balance, "", accountDate);
    accountList.add(ac);
    setState(() {});

    closeNewAccountDialog();
    initTextFieldsDialog();
  }

  void manageOnTapItemMenu(ActionItem item) {
    switch (item.actionItemEnum) {
      case ActionItemEnum.add:
        addListDialog();
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

  Account? getSelectedAccount() {
    for (Account ac in accountList) {
      if (ac.selected) {
        return ac;
      }
    }
    return null;
  }

  void initTextFieldsDialog() {
    acDateCont.text = DateFormat("dd/MM/yyyy").format(accountDate);
    acBalanceCont.text = "";
    acNameCont.text = "";
  }
}
