import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        "Déslectionner",
        Icons.select_all,
        false,
        ActionItemEnum
            .unSelectAll) /* ,
    null,
    ActionItem("Importer", Icons.import_contacts, true, ActionItemEnum.imp) */
  ];
  final double rowHeaderHeight = 38.0;
  static const double rowAdderHeight = 65;
  static const double rowHeight = 40.0;
  // static const double infoHeigth = 70;
  DatabaseManager db = DatabaseManager();

  double tableHeight = 0;
  bool amountAutofocus = false, outsiderAutofocus = false;
  FocusNode amountFocus = FocusNode(), outsiderFocus = FocusNode();

  List<Outsider> oList = [];

  static const double dateWidth = 100,
      flaggedWidth = 70,
      amountWidth = 140,
      // balanceWidth = 200,
      outsiderWidth = 300,
      commentWidthDefault = 500;
  double commentWidth = 500;

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
  Icon amountStateIconRow = const Icon(
    Icons.remove_circle,
    size: amountStateIconSize,
    color: Colors.red,
  );
  Icon amountStateIconDialog = const Icon(
    Icons.remove_circle,
    size: amountStateIconSize,
    color: Colors.red,
  );

  DateTime today = DateTime.now();
  DateTime selectedDate = DateTime(2023);
  List<int> clickedRowIndex = <int>[];
  int hoveringRowIndex = -1;
  int accountID = 0;

  TextEditingController dateController = TextEditingController(),
      amountController = TextEditingController(),
      outsiderRowController = TextEditingController(),
      outsiderDialogController = TextEditingController(),
      commentDialogController = TextEditingController(),
      commentRowController = TextEditingController(),
      nbTransactionsController = TextEditingController();

  Account account = Account.none([], []);
  String accountSelectedName = "";
  List<Account> accountList = [];
  int nbTr = DatabaseManager.nth;

  static const BoxDecoration rightBorder =
      BoxDecoration(border: Border(right: BorderSide(color: Colors.black)));

  bool changeAllOutsiderName = false;

  @override
  void initState() {
    accountID = super.widget.accountID;

    today = DateTime(today.year, today.month, today.day);
    selectedDate = today;
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
    commentWidth = max(
        MediaQuery.of(context).size.width -
            flaggedWidth -
            amountWidth -
            outsiderWidth -
            dateWidth -
            Tools.menuWidth -
            4 -
            16,
        commentWidthDefault);
    return Scaffold(
      appBar: Tools.generateNavBar(PagesEnum.transaction, [account]),
      body: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Tools.generateMenu(actionItemList,
                  update: () => setState(() {}),
                  actionItemTapped: (ActionItem item) =>
                      actionItemTapped(item)),
              SizedBox(
                  width: max(1000,
                      MediaQuery.of(context).size.width - Tools.menuWidth),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // dropdown, transactions choice and balance
                        _buildInformations(),
                        _buildHeader(),
                        _buildAdderRow(),
                        _buildTransactionsRows()
                      ],
                    ),
                  ))
            ],
          ),
        ),
      ),
    );
  }

  void initAmountState() {
    if (!isDebitIconRow()) {
      changeAmountStateRow();
    }
  }

  void initAll() async {
    db.init().then((value) async => {
          reloadAccountWithCheck(),
          await reloadAccountList(),
          await reloadOutsiderList(),
          setState(() {})
        });
  }

  void initControllers({Transactions? tr}) {
    tr ??= Transactions.none();
    String outsiderContent = tr.outsider!.isNone() ? "" : tr.outsider!.name;
    changeAllOutsiderName = false;
    selectedDate = tr.date!;

    commentRowController.text = tr.comment;
    commentDialogController = TextEditingController(text: tr.comment);

    dateController = TextEditingController(
        text: DateFormat("dd/MM/yyyy").format(selectedDate));

    amountController = TextEditingController(
        text: tr.amount == 0 ? "" : tr.amount.abs().toString());

    outsiderDialogController = TextEditingController(text: outsiderContent);
    outsiderRowController.text = outsiderContent;

    nbTransactionsController = TextEditingController();
  }

  Widget _buildInformations() {
    const double infoWidth = 200;
    return SizedBox(
      child: Row(
        children: [
          SizedBox(
              width: infoWidth,
              child: Tools.buildAccountDropDown(
                  accountList: accountList,
                  account: account,
                  accountSelectedName: accountSelectedName,
                  update: () => setState(() {}),
                  onSelection: (int acID) {
                    accountID = acID;
                    reloadAccount();
                  })),
          SizedBox(
            width: infoWidth + 100,
            child: _buildSortDropDown(),
          ),
          Column(children: [
            Container(
              margin: const EdgeInsets.all(8),
              width: infoWidth,
              child: Row(
                children: [
                  Text(
                      "Solde pointé : ${account.flaggedBalance.toStringAsFixed(2)}"),
                ],
              ),
            ),
            Container(
                margin: const EdgeInsets.all(8),
                width: infoWidth,
                child: Text(
                    "Solde total : ${account.fullBalance.toStringAsFixed(2)}"))
          ]),
          SizedBox(
            width: 100,
            child: Tools.buildIntChoice(
              [10, 20, 30, 40, 50, 100],
              1,
              width: infoWidth,
              controller: nbTransactionsController,
              label: "Nombre de transactions",
              onSelected: (int? value) {
                if (value == null) {
                  return;
                }
                nbTr = value;
                reloadAccount();
              },
            ),
          )
        ],
      ),
    );
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
          /* Tools.buildTableCell("SOLDE", rowHeight, balanceWidth,
              decoration: rightBorder, alignment: Alignment.center), */
          InkWell(
              child: Tools.buildTableCell("TIERS", rowHeight, outsiderWidth,
                  alignment: Alignment.center, decoration: rightBorder),
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
              }),
          Tools.buildTableCell("COMMENTAIRES", rowHeight, commentWidth,
              alignment: Alignment.center)
        ],
      ),
    );
  }

  Widget _buildAdderRow() {
    SDenum sd = SDenum("Tiers",
        map: Tools.getOutsiderListName(oList),
        defaultt: clickedRowIndex.isEmpty ? null : clickedRowIndex[0]);
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
                      today;
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
            child: const Align(
              alignment: Alignment.center,
              child: Checkbox(
                value: false,
                onChanged: null,
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
                    // icon + / -
                    InkWell(
                        onTap: () => changeAmountStateRow(),
                        child: amountStateIconRow),
                    // text input for amount
                    SizedBox(
                      width: amountWidth - 31,
                      child: TextField(
                        autofocus: amountAutofocus,
                        focusNode: amountFocus,
                        textAlign: TextAlign.center,
                        controller: amountController,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(), labelText: "montant"),
                        onSubmitted: (String? value) async {
                          /* FocusScope.of(context).requestFocus(outsiderFocus);
                          outsiderFocus.requestFocus();
                          print(outsiderFocus.hasFocus);
                          amountFocus.requestFocus();
                          FocusScope.of(context).requestFocus(amountFocus); */

                          print(amountFocus.hasFocus);
                          if (!allWellCompleted(isRowAdder: true)) {
                            amountAutofocus = true;
                            setState(() {});
                            return;
                          }
                          amountAutofocus = false;
                          await addTransactions(isRowAdder: true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // balance
          /* Container(
            decoration: rightBorder,
            width: balanceWidth,
          ), */
          // outsider
          Focus(
            focusNode: outsiderFocus,
            child: Container(
              decoration: rightBorder,
              width: outsiderWidth,
              child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Tools.buildSearchBar(
                    controller: outsiderRowController,
                    sd: sd,
                    width: outsiderWidth - 40 - 1,
                    onSelected: (Object? o) {},
                    setState: () =>
                        setState(() {}), /* focusNode: outsiderFocus */
                  )
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
            ),
          ),
          // commet
          SizedBox(
            width: commentWidth,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), labelText: "Commentaires"),
                  controller: commentRowController,
                  textAlign: TextAlign.center,
                  onSubmitted: (String? value) async {
                    if (!allWellCompleted(isRowAdder: true)) {
                      return;
                    }
                    await addTransactions(isRowAdder: true);
                  }),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTransactionsRows() {
    return Container(
        height: tableHeight,
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
            String comment = "-";
            Alignment a = Alignment.center;
            if (tr.comment.isNotEmpty) {
              comment = tr.comment;
              a = Alignment.centerLeft;
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
                          onChanged: tr.date!.isAfter(today)
                              ? null
                              : (bool? value) async {
                                  tr
                                      .switchFlaggedDB(db, account.id)
                                      .then((value) async {
                                    if (value <= -1) {
                                      Tools.showNormalSnackBar(
                                          context, "Une erreur est survenue");
                                    }

                                    account.editFlaggedBalance(
                                        tr.flagged, tr.amount);
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
                    /* InkWell(
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
                    ), */
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
                          pad: const EdgeInsets.only(left: 8),
                          decoration: rightBorder),
                    ),
                    // comment
                    InkWell(
                      onDoubleTap: () =>
                          transactionsDialog("Édition de l'opération", tr),
                      mouseCursor: SystemMouseCursors.basic,
                      onHover: (bool isHovering) {
                        setState(() {
                          hoveringRowIndex = isHovering ? i : -1;
                        });
                      },
                      onTap: () => Tools.manageTableRowClick(
                          i, clickedRowIndex, actionItemList,
                          setState: () => setState),
                      child: Tooltip(
                        waitDuration: const Duration(milliseconds: 500),
                        height: 20,
                        margin: const EdgeInsets.all(16),
                        message: comment,
                        child: Tools.buildTableCell(
                            comment, rowHeight, commentWidth,
                            alignment: a, pad: const EdgeInsets.only(left: 8)),
                      ),
                    )
                  ],
                ));
          },
        ));
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

  void nbTrOnSelected(int? value) {
    if (value == null) {
      return;
    }
  }

  void unHoverAll() {
    for (var element in actionItemList) {
      if (element == null) {
        continue;
      }
      element.isHovering = false;
    }
  }

  bool allWellCompleted({required bool isRowAdder, bool showMessage = true}) {
    DialogError d = allControllerCompleted(isRowAdder: isRowAdder);

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

  DialogError allControllerCompleted({required bool isRowAdder}) {
    if (double.tryParse(amountController.text.trim()) == null) {
      return DialogError.invalidAmount;
    } else if ((isRowAdder && outsiderRowController.text.trim().isEmpty) ||
        (!isRowAdder && outsiderDialogController.text.trim().isEmpty)) {
      return DialogError.invalidOutsider;
    }
    return DialogError.noError;
  }

  Future<void> addTransactions({required bool isRowAdder}) async {
    if (!allWellCompleted(isRowAdder: isRowAdder)) {
      return;
    }
    String outsiderName = getOutsiderControllerText(isRowAdder: isRowAdder);
    String comment = getCommentContent(isRowAdder: isRowAdder);

    oList.add(Outsider(0, outsiderName));

    // cannot be null
    double? amount = double.tryParse(amountController.text.trim())!;
    await db.addTransactionsToAccount(
        account.id,
        Transactions(0, amount.abs() * (isDebitIconRow() ? -1 : 1),
            selectedDate, Outsider(0, outsiderName), false, 0,
            comment: comment));
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
        await addTransactions(isRowAdder: true);
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
          }
          clickedRowIndex.clear();
          Tools.initActionItems(actionItemList);
          reloadAccount();
        });
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

  bool isDebitIconRow() {
    return amountStateIconRow.icon! == Icons.remove_circle;
  }

  void changeAmountStateRow() {
    if (isDebitIconRow()) {
      amountStateIconRow = const Icon(
        Icons.add_circle,
        size: amountStateIconSize,
        color: Colors.green,
      );
    } else {
      amountStateIconRow = const Icon(
        Icons.remove_circle,
        size: amountStateIconSize,
        color: Colors.red,
      );
    }
    setState(() {});
  }

  bool isDebitIconDialog() {
    return amountStateIconDialog.icon! == Icons.remove_circle;
  }

  void changeAmountStateDialog({required void Function() update}) {
    if (isDebitIconDialog()) {
      amountStateIconDialog = const Icon(
        Icons.add_circle,
        size: amountStateIconSize,
        color: Colors.green,
      );
    } else {
      amountStateIconDialog = const Icon(
        Icons.remove_circle,
        size: amountStateIconSize,
        color: Colors.red,
      );
    }
    update();
  }

  void transactionsDialog(String title, Transactions tr) {
    initControllers(tr: tr);
    if ((tr.amount < 0 && !isDebitIconDialog()) ||
        (tr.amount > 0 && isDebitIconDialog())) {
      changeAmountStateDialog(update: () => setState(() {}));
    }
    const double width = 350;
    const double height = 250;
    SDenum sd = SDenum("Tiers", map: Tools.getOutsiderListName(oList));
    if (clickedRowIndex.isNotEmpty) {
      sd.defaultt = clickedRowIndex[0];
    }

    List<Widget> actions = [
      // cancel button
      ElevatedButton(
        onPressed: closeTransactionsDialog,
        style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.grey)),
        child: const Text("ANNULER"),
      ),
      // validate button
      ElevatedButton(
          style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.green)),
          onPressed: () => submitEditTransactionDialog(tr),
          child: const Text("VALIDER")),
      // remove button
      ElevatedButton(
        onPressed: () async {
          await Tools.confirmRemoveItem(context, "Suppression d'une occurrence",
                  "l'occurrence sélectionée ?")
              .then((bool? v) {
            if (v == null) {
              return;
            }
            if (v) {
              int? trIndex = account.indexOfTransaction(tr.id);
              if (trIndex == null) {
                Tools.showNormalSnackBar(context,
                    "Une erreur est survenue, il se peut que l'opération ne soit pas supprimée.");
                return;
              }
              account.removeTransaction(trIndex, db).then((value) => {
                    if (value <= -1)
                      {
                        Tools.showNormalSnackBar(context,
                            "Une erreur est survenur lors de la suppresion de l'occurrence"),
                      },
                    closeTransactionsDialog(),
                  });
            }
          });
        },
        style:
            ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.red)),
        child: const Text("SUPPRIMER"),
      )
    ];

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  title: Text(title),
                  content: SizedBox(
                      height: height,
                      width: width,
                      child: Column(children: [
                        Row(
                          children: [
                            // date
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: InkWell(
                                  onTap: () async {
                                    selectedDate = await Tools.selectDate(
                                            context,
                                            selectedDate,
                                            dateController,
                                            setState: () => setState(() {})) ??
                                        today;
                                  },
                                  child: TextFormField(
                                    controller: dateController,
                                    decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: "Date"),
                                    enabled: false,
                                  ),
                                ),
                              ),
                            ),
                            // icon to say plus or minus
                            InkWell(
                              onTap: () => {
                                changeAmountStateDialog(
                                  update: () => setState(() {}),
                                ),
                              },
                              child: amountStateIconDialog,
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
                                  controller: outsiderDialogController,
                                  sd: sd,
                                  width: width / 2,
                                  onSelected: (Object? o) {},
                                  setState: () => setState(() {})),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 5,
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
                            const Flexible(
                              child: Text(
                                  "Modifier tous les tiers portant cette appellation"),
                            )
                          ],
                        ),
                        // comment
                        Expanded(
                            child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextFormField(
                            controller: commentDialogController,
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: "Commentaires"),
                          ),
                        ))
                      ])),
                  actions: actions,
                )));
  }

  void closeTransactionsDialog() {
    Navigator.of(context).pop();
    Tools.initActionItems(actionItemList);
    clickedRowIndex.clear();
    initControllers();
    setState(() {});
  }

  void submitEditTransactionDialog(Transactions tr) {
    if (!allWellCompleted(isRowAdder: false)) {
      return;
    }

    String outsiderName = getOutsiderControllerText(isRowAdder: false);

    // check before
    double newAmount = double.tryParse(amountController.text.trim())!;

    if (isDebitIconDialog()) {
      newAmount *= -1;
    }

    if (changeAllOutsiderName &&
        tr.outsider!.name != getOutsiderControllerText(isRowAdder: false)) {
      db
          .updateOutsider(
              tr.outsider!, Outsider(-1, outsiderName, comment: tr.comment))
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
            newAmount,
            selectedDate,
            outsiderName == tr.outsider!.name
                ? null
                : Outsider(-1, outsiderName),
            account.id,
            commentDialogController.text.trim())
        .then((value) => {
              if (value == -1)
                {
                  Tools.showNormalSnackBar(context, "Une erreur est survenue"),
                },
              closeTransactionsDialog(),
              reloadAccount(),
              initControllers()
            });
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

  Future<void> reloadOutsiderList({bool reload = false}) async {
    oList = await db.getAllOutsider();
    if (reload) {
      setState(() {});
    }
  }

  Future<void> reloadAccountList({bool init = false}) async {
    accountList = await db.getAllAccounts();
  }

  void reloadAccount() {
    final duration = Stopwatch()..start();
    db.getAccount(accountID, nbTr: nbTr, haveToGetTrList: true).then((value) {
      if (value == null) {
        Tools.showNormalSnackBar(context,
            "Une erreur est survenuem, impossible de récupérer votre compte");
        Navigator.push(context,
            PageRouteBuilder(pageBuilder: (_, __, ___) => const HomePage()));
      } else {
        account = value;
        if (duration.elapsed.inMilliseconds >= 500) {
          Tools.buildSimpleAlertDialog(context, "Indications importantes",
              "Ce message intervient car la récupération des opérations est lente, il serait alors préférable de contacter la personne qui a développé le logiciel afin qu'elle remédie au problème");
        }
        setState(() {});
      }
    });
  }

  String getOutsiderControllerText({required bool isRowAdder}) {
    return isRowAdder
        ? outsiderRowController.text.trim()
        : outsiderDialogController.text.trim();
  }

  String getCommentContent({required bool isRowAdder}) {
    return isRowAdder
        ? commentRowController.text.trim()
        : commentDialogController.text.trim();
  }
}
