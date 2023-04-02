import 'dart:math';

import 'package:flutter/material.dart';
import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/action_item.dart';
import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/item_menu.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/models/table_sort_item.dart';
import 'package:money_for_mima/models/transactions.dart';
import 'package:money_for_mima/pages/home_page.dart';
import 'package:money_for_mima/utils/tools.dart';

import 'package:intl/intl.dart';

// tr added twice

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
        "Remplacer", Icons.bookmark_outline, false, ActionItemEnum.replace,
        hidden: true),
    ActionItem(
        "Déslectionner", Icons.select_all, false, ActionItemEnum.unSelectAll),
    null,
    ActionItem("Importer", Icons.import_contacts, true, ActionItemEnum.imp)
  ];
  final double rowHeaderHeight = 38.0;
  static const double rowAdderHeight = 65;
  static const double rowHeight = 40.0;
  DatabaseManager db = DatabaseManager();

  double tableHeight = 0;
  bool amountAutofocus = false, outsiderAutofocus = false;

  List<Outsider> oList = [];

  final double dateWidth = 100,
      flaggedWidth = 70,
      amountWidth = 140,
      balanceWidth = 200,
      outsiderWidth = 500;

  bool reversed = false;
  int colNameIndex = 0;
  List<String> colNameList = ["date", "amount", "outsider"];
  int actionIndexSort = 0;
  List<TableSortItem> actionSortList = <TableSortItem>[
    TableSortItem(SortAction.allTransactions, "Toutes les opérations"),
    TableSortItem(SortAction.flaggedTransactions, "Opérations pointées"),
    TableSortItem(SortAction.unFlaggedTransactions, "Opérations non pointées")
  ];

  static const double amountStateIconSize = 20;
  Icon amountStateIcon = const Icon(
    Icons.remove_circle,
    size: amountStateIconSize,
    color: Colors.red,
  );

  DateTime selectedDate = DateTime.now();
  List<int> clickedRowIndex = <int>[];
  int hoveringRowIndex = -1;
  int accountID = 0;

  TextEditingController dateController = TextEditingController(),
      amountController = TextEditingController(),
      outsiderController = TextEditingController(),
      commentTrController = TextEditingController();

  Account account = Account.none([], []);
  String accountSelectedName = "";
  List<Account> accountList = [];

  static const BoxDecoration rightBorder =
      BoxDecoration(border: Border(right: BorderSide(color: Colors.black)));

  bool changeAllOutsiderName = true;

  @override
  void initState() {
    accountID = super.widget.accountID;
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
    tableHeight = min(
        MediaQuery.of(context).copyWith().size.height -
            rowHeaderHeight -
            rowAdderHeight -
            154,
        account.getCurrentTransactionList().length * rowHeight);
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
                // dropdown, transactions choice and balance
                Row(
                  children: [
                    Expanded(
                        child: Tools.buildAccountDropDown(
                            accountList: accountList,
                            account: account,
                            accountSelectedName: accountSelectedName,
                            update: () => setState(() {}),
                            onSelection: (int acID) {
                              accountID = acID;
                              reloadAccount();
                            })),
                    Expanded(child: _buildSortDropDown()),
                    Expanded(
                        child: Row(
                      children: [
                        Text("Solde pointé : ${account.flaggedBalance}"),
                      ],
                    )),
                    Expanded(
                        child: Text("Solde total : ${account.fullBalance}"))
                  ],
                ),
                _buildHeader(),
                _buildAdderRow(),
                _buildTransactionsRows()
              ],
            ),
          ))
        ],
      ),
    );
  }

  void initControllers({Transactions? tr}) {
    tr ??= Transactions.none();
    changeAllOutsiderName = true;
    selectedDate = tr.date!;
    commentTrController = TextEditingController(text: tr.comment);
    dateController = TextEditingController(
        text: DateFormat("dd/MM/yyyy").format(selectedDate));
    amountController =
        TextEditingController(text: tr.amount == 0 ? "" : tr.amount.toString());
    outsiderController = TextEditingController(
        text: tr.outsider!.isNone() ? "" : tr.outsider!.name);
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      height: rowHeaderHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          InkWell(
              child: Tools.buildTableCell("DATE", rowHeight, dateWidth,
                  alignment: Alignment.center, decoration: rightBorder),
              onTap: () {
                const String currentColName = "date";
                if (colNameList[colNameIndex] == currentColName) {
                  reversed = !reversed;
                } else {
                  reversed = false;
                  colNameIndex = colNameList.indexOf(currentColName);
                }
                account.updateTransactionsList(
                    actionSortList[actionIndexSort].sortAction, currentColName,
                    reversed: reversed);
                clickedRowIndex.clear();
                setState(() {});
              }),
          Tools.buildTableCell("POINTÉ", rowHeight, flaggedWidth,
              decoration: rightBorder, alignment: Alignment.center),
          InkWell(
            child: Tools.buildTableCell("MONTANT", rowHeight, amountWidth,
                decoration: rightBorder, alignment: Alignment.center),
            onTap: () {
              const String currentColName = "amount";
              if (colNameList[colNameIndex] == currentColName) {
                reversed = !reversed;
              } else {
                reversed = false;
                colNameIndex = colNameList.indexOf(currentColName);
              }
              account.updateTransactionsList(
                  actionSortList[actionIndexSort].sortAction, currentColName,
                  reversed: reversed);

              clickedRowIndex.clear();
              setState(() {});
            },
          ),
          Tools.buildTableCell("SOLDE", rowHeight, balanceWidth,
              decoration: rightBorder, alignment: Alignment.center),
          InkWell(
              child: Tools.buildTableCell("TIERS", rowHeight, outsiderWidth,
                  alignment: Alignment.center),
              onTap: () {
                const String currentColName = "outsider";
                if (colNameList[colNameIndex] == currentColName) {
                  reversed = !reversed;
                } else {
                  reversed = false;
                  colNameIndex = colNameList.indexOf(currentColName);
                }
                account.updateTransactionsList(
                    actionSortList[actionIndexSort].sortAction, currentColName,
                    reversed: reversed);
                clickedRowIndex.clear();
                setState(() {});
              })
        ],
      ),
    );
  }

  Widget _buildAdderRow() {
    SDenum sd = SDenum("Tiers",
        m: Tools.getOutsiderListName(oList),
        dft: clickedRowIndex.isEmpty ? null : clickedRowIndex[0]);
    return Container(
      height: rowAdderHeight,
      decoration: const BoxDecoration(
        border: Border(
            left: BorderSide(color: Colors.black),
            bottom: BorderSide(
              color: Colors.red,
              width: 2,
            ),
            right: BorderSide(color: Colors.black)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // date
          Container(
            decoration: rightBorder,
            width: dateWidth,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () async {
                  selectedDate = await Tools.selectDate(
                          context, selectedDate, dateController,
                          setState: () => setState(() {})) ??
                      DateTime.now();
                },
                child: TextFormField(
                  controller: dateController,
                  enabled: false,
                  keyboardType: TextInputType.text,
                ),
              ),
            ),
          ),
          // flagged
          Container(
            decoration: rightBorder,
            width: flaggedWidth,
            child: Align(
              alignment: Alignment.center,
              child: Checkbox(
                value: false,
                onChanged: (bool? value) {},
              ),
            ),
          ), //
          // amount
          Container(
            decoration: rightBorder,
            width: amountWidth,
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Center(
                child: Row(
                  children: [
                    InkWell(onTap: changeAmountState, child: amountStateIcon),
                    SizedBox(
                      width: amountWidth - 31,
                      child: TextField(
                        autofocus: amountAutofocus,
                        textAlign: TextAlign.center,
                        controller: amountController,
                        decoration:
                            const InputDecoration(border: OutlineInputBorder()),
                        onSubmitted: (String? value) async {
                          if (!allWellCompleted()) {
                            amountAutofocus = true;
                            setState(() {});
                            return;
                          }
                          amountAutofocus = false;
                          await addTransactions();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // balance
          Container(
            decoration: rightBorder,
            width: balanceWidth,
          ),
          // outsider
          SizedBox(
            width: outsiderWidth,
            child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Tools.buildSearchBar(
                    controller: outsiderController,
                    sd: sd,
                    width: outsiderWidth - 40,
                    onSelected: (Object? o) {},
                    setState: () => setState(() {}))
                /* TextField(
                controller: outsiderController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                autofocus: outsiderAutofocus,
                onSubmitted: (String? value) async {
                  if (!allWellCompleted()) {
                    outsiderAutofocus = true;
                    setState(() {});
                    return;
                  }
                  outsiderAutofocus = false;
                  await addTransactions();
                },
              ) ,*/
                ),
          )
        ],
      ),
    );
  }

  Widget _buildTransactionsRows() {
    return Container(
        alignment: Alignment.topCenter,
        height: tableHeight,
        width: MediaQuery.of(context).copyWith().size.width,
        decoration: const BoxDecoration(
            border: Border(
                left: BorderSide(color: Colors.black),
                right: BorderSide(color: Colors.black))),
        child: ListView.builder(
          scrollDirection: Axis.vertical,
          itemCount: account.getCurrentTransactionList().length,
          itemBuilder: (BuildContext context, int i) {
            Transactions tr = account.getCurrentTransactionList()[i];
            Color amountColor = tr.amount >= 0 ? Colors.green : Colors.red;
            BoxDecoration? decoration = const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black)));
            if (clickedRowIndex.contains(i)) {
              decoration = const BoxDecoration(
                  color: Colors.indigoAccent,
                  border: Border(bottom: BorderSide(color: Colors.black)));
            } else if (hoveringRowIndex == i) {
              decoration = const BoxDecoration(
                  color: Color(0xffD7D8D8),
                  border: Border(bottom: BorderSide(color: Colors.black)));
            }
            return Container(
                height: rowHeight,
                decoration: decoration,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // date
                    InkWell(
                      onDoubleTap: () =>
                          transactionsDialog("Edition de l'opération", tr),
                      mouseCursor: SystemMouseCursors.basic,
                      onHover: (bool isHovering) {
                        hoveringRowIndex = isHovering ? i : -1;
                        setState(() {});
                      },
                      onTap: () => Tools.manageTableRowClick(
                          i, clickedRowIndex, actionItemList,
                          setState: () => setState(() {})),
                      child: Tools.buildTableCell(
                          tr.formatDate(), rowHeight, dateWidth,
                          alignment: Alignment.center, decoration: rightBorder),
                    ),
                    // checkbox
                    Container(
                      decoration: rightBorder,
                      width: flaggedWidth,
                      height: rowHeight,
                      child: Center(
                        child: Checkbox(
                          value: tr.flagged,
                          onChanged: (bool? value) async {
                            tr
                                .switchFlaggedDB(db, account.id)
                                .then((value) async {
                              if (value <= -1) {
                                Tools.showNormalSnackBar(
                                    context, "Une erreur est survenue");
                              }

                              account.editFlaggedBalance(tr.flagged, tr.amount);
                              setState(() {});
                            });
                          },
                        ),
                      ),
                    ),
                    // amount
                    InkWell(
                      onDoubleTap: () =>
                          transactionsDialog("Edition de l'opération", tr),
                      mouseCursor: SystemMouseCursors.basic,
                      onHover: (bool isHovering) {
                        hoveringRowIndex = isHovering ? i : -1;
                        setState(() {});
                      },
                      onTap: () => Tools.manageTableRowClick(
                          i, clickedRowIndex, actionItemList,
                          setState: () => setState(() {})),
                      child: Tools.buildTableCell(
                          tr.amount.toString(), rowHeight, amountWidth,
                          alignment: Alignment.center,
                          decoration: rightBorder,
                          color: amountColor,
                          fontWeight: FontWeight.bold),
                    ),
                    // balance
                    InkWell(
                      onDoubleTap: () =>
                          transactionsDialog("Edition de l'opération", tr),
                      mouseCursor: SystemMouseCursors.basic,
                      onHover: (bool isHovering) {
                        hoveringRowIndex = isHovering ? i : -1;
                        setState(() {});
                      },
                      onTap: () => Tools.manageTableRowClick(
                          i, clickedRowIndex, actionItemList,
                          setState: () => setState(() {})),
                      child: Tools.buildTableCell(
                          /*tr.acBalance.toString()*/
                          "-",
                          rowHeight,
                          balanceWidth,
                          alignment: Alignment.center,
                          decoration: rightBorder),
                    ),
                    // outsider
                    InkWell(
                      onDoubleTap: () =>
                          transactionsDialog("Edition de l'opération", tr),
                      mouseCursor: SystemMouseCursors.basic,
                      onHover: (bool isHovering) {
                        hoveringRowIndex = isHovering ? i : -1;
                        setState(() {});
                      },
                      onTap: () => Tools.manageTableRowClick(
                          i, clickedRowIndex, actionItemList,
                          setState: () => setState(() {})),
                      child: Tools.buildTableCell(
                          tr.outsider!.name, rowHeight, outsiderWidth,
                          pad: const EdgeInsets.only(left: 8)),
                    )
                  ],
                ));
          },
        ));
  }

  void unHoverAll() {
    for (var element in actionItemList) {
      if (element == null) {
        continue;
      }
      element.isHovering = false;
    }
  }

  DialogError allControllerCompleted() {
    if (double.tryParse(amountController.text.trim()) == null) {
      return DialogError.invalidAmount;
    } else if (outsiderAutofocus.toString().trim().isEmpty) {
      return DialogError.invalidOutsider;
    }
    return DialogError.noError;
  }

  Future<void> addTransactions() async {
    if (!allWellCompleted()) {
      return;
    }

    oList.add(Outsider(0, outsiderController.text.trim()));

    // cannot be null
    double? amount =
        double.tryParse(amountController.text.trim()) == null ? -1 : 1;
    await db.addTransactionsToAccount(
        account.id,
        Transactions(0, amount.abs() * (isDebitIcon() ? -1 : 1), selectedDate,
            Outsider(0, outsiderController.text.trim()), false, 0));
    initControllers();
    await reloadAccountWithCheck();
    initAmountState();
  }

  Future<void> actionItemTapped(ActionItem item) async {
    if (item.text.trim().isEmpty || !item.enable) {
      return;
    }

    switch (item.actionItemEnum) {
      case ActionItemEnum.add:
        await addTransactions();
        clickedRowIndex.clear();
        Tools.initActionItems(actionItemList);
        break;
      case ActionItemEnum.rm:
        bool? v = await Tools.confirmRemoveItem(
            context,
            "Suppression d'opération(s)",
            "le(s) opération(s) sélectionné(s) ?");
        if (v == null || !v) {
          break;
        }
        account.removeTransactionsList(clickedRowIndex, db).then((value) {
          if (value <= -1) {
            Tools.showNormalSnackBar(context,
                "Une erreur est survenue lors de la suppression de(s) occurrence(s)");
          }
          Tools.initActionItems(actionItemList);
          clickedRowIndex.clear();
          reloadAccount();
        });

        break;
      case ActionItemEnum.edit:
        if (clickedRowIndex.length >= 2 || clickedRowIndex.isEmpty) {
          return;
        }
        transactionsDialog("Edition de l'opération",
            account.getCurrentTransactionList()[clickedRowIndex[0]]);
        break;
      case ActionItemEnum.duplicate:
        if (clickedRowIndex.isEmpty) {
          return;
        }

        List<Transactions> trList = [];
        for (int i in clickedRowIndex) {
          trList.add(account.getCurrentTransactionList()[i]);
        }
        account.addTransactionsList(trList, db).then((v) {
          if (v <= -1) {
            Tools.showNormalSnackBar(context, "Une erreur est survenue");
          } else {
            clickedRowIndex.clear();
          }
        });
        reloadAccount();
        break;
      case ActionItemEnum.imp:
        break;
      case ActionItemEnum.replace:
        break;
      case ActionItemEnum.exp:
        break;
      case ActionItemEnum.unSelectAll:
        clickedRowIndex.clear();
        Tools.initActionItems(actionItemList);
        setState(() {});
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
    db.init().then((value) async => {
          reloadAccountWithCheck(),
          await reloadAccountList(),
          await reloadOutsiderList(),
          setState(() {})
        });
  }

  void reloadAccount() {
    db.getAccount(accountID).then((value) => {
          if (value == null)
            {
              Navigator.push(
                  context,
                  PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const HomePage()))
            }
          else
            {account = value, setState(() {})}
        });
  }

  bool isDebitIcon() {
    return amountStateIcon.icon! == Icons.remove_circle;
  }

  void changeAmountState() {
    if (isDebitIcon()) {
      amountStateIcon = const Icon(
        Icons.add_circle,
        size: amountStateIconSize,
        color: Colors.green,
      );
    } else {
      amountStateIcon = const Icon(
        Icons.remove_circle,
        size: amountStateIconSize,
        color: Colors.red,
      );
    }
    setState(() {});
  }

  void initAmountState() {
    if (!isDebitIcon()) {
      changeAmountState();
    }
  }

  void closeTransactionsDialog() {
    Navigator.of(context).pop();
    clickedRowIndex.clear();
    initControllers();
    setState(() {});
  }

  void transactionsDialog(String title, Transactions tr) {
    initControllers(tr: tr);
    double width = 300;
    SDenum sd = SDenum("Tiers", m: Tools.getOutsiderListName(oList));
    if (clickedRowIndex.isNotEmpty) {
      sd.dft = clickedRowIndex[0];
    }
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: SizedBox(
                  height: 200,
                  width: width,
                  child: Column(children: [
                    Row(
                      children: [
                        // date
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextFormField(
                              controller: dateController,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: "Date"),
                            ),
                          ),
                        ),
                        // amount
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextFormField(
                              controller: amountController,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: "Montant"),
                            ),
                          ),
                        )
                      ],
                    ),
                    // outsider
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Tools.buildSearchBar(
                              controller: outsiderController,
                              sd: sd,
                              width: width / 2,
                              onSelected: (Object? o) {},
                              setState: () => setState(() {})),
                        ),
                      ),
                    ),
                    // change all outsiders name
                    Row(
                      children: [
                        Checkbox(
                            value: changeAllOutsiderName,
                            onChanged: (bool? state) {
                              setState(() {
                                if (state == null) return;
                                changeAllOutsiderName = state;
                              });
                            }),
                        const Text(
                            "Modifier tous les tiers portant cette appellation")
                      ],
                    ),
                    // comment
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        controller: commentTrController,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: "Commentaires"),
                      ),
                    ))
                  ])),
              actions: [
                ElevatedButton(
                  onPressed: closeTransactionsDialog,
                  style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.grey)),
                  child: const Text("ANNULER"),
                ),
                ElevatedButton(
                    style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all(Colors.green)),
                    onPressed: () => submitEditTransactionDialog(tr),
                    child: const Text("VALIDER"))
              ],
            ));
  }

  bool allWellCompleted() {
    DialogError d = allControllerCompleted();

    switch (d) {
      case DialogError.invalidAmount:
        Tools.showNormalSnackBar(context, "La valeur du montant est invalide");
        return false;
      case DialogError.invalidOutsider:
        Tools.showNormalSnackBar(context, "L'intitulé du tiers est invalide");
        return false;
      case DialogError.unknown:
      case DialogError.dateBefore:
      case DialogError.dateAfter:
        return false;

      case DialogError.noError:
        return true;
    }
  }

  void submitEditTransactionDialog(Transactions tr) {
    if (!allWellCompleted()) {
      return;
    }

    double? a = double.tryParse(amountController.text.trim());
    if (a == null) {
      Tools.showNormalSnackBar(context, "Montant invalide");
      return;
    }

    if (changeAllOutsiderName &&
        tr.outsider!.name != outsiderController.text.trim()) {
      db
          .updateOutsider(tr.outsider!,
              Outsider(-1, outsiderController.text.trim(), comment: tr.comment))
          .then((value) => {
                if (value <= -1)
                  {
                    Tools.showNormalSnackBar(context,
                        "Une erreur est survenur lors de la modification de tous les tiers, l'opération continue")
                  }
              });
    }

    tr
        .editDB(
            db,
            a,
            dateController.text.trim(),
            outsiderController.text.trim() == tr.outsider!.name
                ? null
                : Outsider(-1, outsiderController.text.trim()),
            account.id,
            commentTrController.text.trim())
        .then((value) => {
              if (value == -1)
                {
                  Tools.showNormalSnackBar(context, "Une erreur est survenue"),
                },
              closeTransactionsDialog(),
              reloadAccount(),
            });
  }

  Widget _buildSortDropDown() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 20, top: 10),
      child: Container(
        alignment: Alignment.topLeft,
        child: DropdownButton(
          value: actionSortList[actionIndexSort].dropDownName,
          items: actionSortList
              .map<DropdownMenuItem<String>>((TableSortItem e) =>
                  DropdownMenuItem<String>(
                      value: e.dropDownName, child: Text(e.dropDownName)))
              .toList(),
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            for (int i = 0; i < actionSortList.length; i++) {
              if (actionSortList[i].dropDownName == value) {
                actionIndexSort = i;
              }
            }

            account.updateTransactionsList(
                actionSortList[actionIndexSort].sortAction,
                colNameList[colNameIndex],
                reversed: reversed);
            //account
            clickedRowIndex.clear();
            setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> reloadOutsiderList({bool reload = false}) async {
    oList = await db.getAllOutsider();
    if (reload) {
      setState(() {});
    }
  }
}
