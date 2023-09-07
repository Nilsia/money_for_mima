import 'dart:math';

import 'package:flutter/material.dart';
import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/action_item.dart';
import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/due.dart';
import 'package:money_for_mima/models/item_menu.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/pages/home_page.dart';
import 'package:money_for_mima/utils/tools.dart';
import 'package:tuple/tuple.dart';

class DuePage extends StatefulWidget {
  final int accountID;

  const DuePage(this.accountID, {Key? key}) : super(key: key);

  @override
  State<DuePage> createState() => _DuePageState();
}

class _DuePageState extends State<DuePage> {
  int accountID = 0;
  List<Account> accountList = [];
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

  List<Outsider> oList = [];

  static const BoxDecoration rightBorder =
      BoxDecoration(border: Border(right: BorderSide(color: Colors.black)));
  static const double rowHeaderHeight = 38.0;
  static const double rowHeight = 40.0;
  static const double amountWidth = 140,
      outsiderWidth = 300,
      periodicityWidth = 120,
      dateWidth = 100,
      commentWidthDefault = 500;
  double commentWidth = 0;

  static const double amountStateIconSize = 20;
  Icon amountStateIcon = const Icon(
    Icons.remove_circle,
    size: amountStateIconSize,
    color: Colors.red,
  );

  String accountSelectedName = "";
  DatabaseManager db = DatabaseManager();
  Account account = Account.none([], []);

  TextEditingController amountController = TextEditingController(),
      dateController = TextEditingController(),
      outsiderController = TextEditingController(),
      commentTrController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  double tableHeight = 0;

  List<int> clickedRowsList = [];
  int hoveringRowIndex = -1;

  bool changeAllOutsiderName = true;

  @override
  void initState() {
    initAll();
    accountID = super.widget.accountID;
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    tableHeight = min(
        MediaQuery.of(context).copyWith().size.height - rowHeight * 2,
        account.getDueList().length * rowHeight);
    commentWidth = max(
        MediaQuery.of(context).size.width -
            amountWidth -
            outsiderWidth -
            dateWidth -
            Tools.menuWidth -
            periodicityWidth -
            4 -
            16,
        commentWidthDefault);
    return Scaffold(
      appBar: Tools.generateNavBar(PagesEnum.due, [account]),
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
                width: max(
                    1000, MediaQuery.of(context).size.width - Tools.menuWidth),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInformations(),
                      _buildHeader(),
                      _buildDueRows(),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformations() {
    const double infoWidth = 200;
    return SizedBox(
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
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
          ),
          Expanded(
            child: Column(children: [
              Container(
                margin: const EdgeInsets.all(8),
                width: infoWidth,
                child: Row(
                  children: [
                    Text(
                        "Solde pointé : ${(account.flaggedBalance / 100).toString()}"),
                  ],
                ),
              ),
              Container(
                  margin: const EdgeInsets.all(8),
                  width: infoWidth,
                  child: Text(
                      "Solde total : ${(account.fullBalance / 100).toString()}"))
            ]),
          ),
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
          Tools.buildTableCell("DATE", rowHeaderHeight, dateWidth,
              alignment: Alignment.center, decoration: rightBorder),
          Tools.buildTableCell("MONTANT", rowHeaderHeight, amountWidth,
              decoration: rightBorder, alignment: Alignment.center),
          Tools.buildTableCell("PÉRIODICITÉ", rowHeaderHeight, periodicityWidth,
              decoration: rightBorder, alignment: Alignment.center),
          Tools.buildTableCell("TIERS", rowHeaderHeight, outsiderWidth,
              alignment: Alignment.center, decoration: rightBorder),
          Tools.buildTableCell("COMMENTAIRES", rowHeaderHeight, commentWidth,
              alignment: Alignment.center)
        ],
      ),
    );
  }

  Widget _buildDueRows() {
    return Container(
      alignment: Alignment.topCenter,
      height: tableHeight,
      width: MediaQuery.of(context).copyWith().size.width,
      decoration: const BoxDecoration(
          border: Border(
              left: BorderSide(color: Colors.black),
              right: BorderSide(color: Colors.black))),
      child: ListView.builder(
          itemCount: account.getDueList().length,
          scrollDirection: Axis.vertical,
          itemBuilder: (BuildContext context, int i) {
            DateTime date = DateTime.now();
            Outsider outsider =
                account.getDueList()[i].outsider ?? Outsider(0, "erreur");
            Due due = account.getDueList()[i];
            Period? period;
            if (due is DueOnce) {
              date = due.actionDate;
            } else if (due is Periodic) {
              date = due.referenceDate!;
              period = due.period;
            }

            Color amountColor = due.amount >= 0 ? Colors.green : Colors.red;
            BoxDecoration? decoration = const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black)));
            if (clickedRowsList.contains(i)) {
              decoration = const BoxDecoration(
                  color: Colors.indigoAccent,
                  border: Border(bottom: BorderSide(color: Colors.black)));
            } else if (hoveringRowIndex == i) {
              decoration = const BoxDecoration(
                  color: Color(0xffD7D8D8),
                  border: Border(bottom: BorderSide(color: Colors.black)));
            }

            return Container(
              decoration: decoration,
              height: rowHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // date
                  InkWell(
                    onDoubleTap: () => manageTransactionsEdition(due),
                    mouseCursor: SystemMouseCursors.basic,
                    onTap: () => Tools.manageTableRowClick(
                        i, clickedRowsList, actionItemList,
                        setState: () => setState(() {})),
                    onHover: (bool isHovering) {
                      hoveringRowIndex = isHovering ? i : -1;
                      setState(() {});
                    },
                    child: Tools.buildTableCell(
                        Tools.formatDate(date), rowHeight, dateWidth,
                        alignment: Alignment.center, decoration: rightBorder),
                  ),
                  // amount
                  InkWell(
                    onDoubleTap: () => manageTransactionsEdition(due),
                    mouseCursor: SystemMouseCursors.basic,
                    onTap: () => Tools.manageTableRowClick(
                        i, clickedRowsList, actionItemList,
                        setState: () => setState(() {})),
                    onHover: (bool isHovering) {
                      hoveringRowIndex = isHovering ? i : -1;
                      setState(() {});
                    },
                    child: Tools.buildTableCell(
                        (due.amount / 100).toString(), rowHeight, amountWidth,
                        decoration: rightBorder,
                        alignment: Alignment.center,
                        color: amountColor,
                        fontWeight: FontWeight.bold),
                  ),
                  // periodicity
                  InkWell(
                    onDoubleTap: () => manageTransactionsEdition(due),
                    mouseCursor: SystemMouseCursors.basic,
                    onTap: () => Tools.manageTableRowClick(
                        i, clickedRowsList, actionItemList,
                        setState: () => setState(() {})),
                    onHover: (bool isHovering) {
                      hoveringRowIndex = isHovering ? i : -1;
                      setState(() {});
                    },
                    child: Tools.buildTableCell(Tools.periodToString(period),
                        rowHeight, periodicityWidth,
                        decoration: rightBorder, alignment: Alignment.center),
                  ),
                  // outsider
                  InkWell(
                    mouseCursor: SystemMouseCursors.basic,
                    onTap: () => Tools.manageTableRowClick(
                        i, clickedRowsList, actionItemList,
                        setState: () => setState(() {})),
                    onHover: (bool isHovering) {
                      hoveringRowIndex = isHovering ? i : -1;
                      setState(() {});
                    },
                    onDoubleTap: () => manageTransactionsEdition(due),
                    child: Tools.buildTableCell(
                        outsider.name, rowHeight, outsiderWidth,
                        alignment: Alignment.center, decoration: rightBorder),
                  ),
                  // comment
                  Tooltip(
                    message: due.comment,
                    child: InkWell(
                      mouseCursor: SystemMouseCursors.basic,
                      onTap: () => Tools.manageTableRowClick(
                          i, clickedRowsList, actionItemList,
                          setState: () => setState(() {})),
                      onHover: (bool isHovering) {
                        hoveringRowIndex = isHovering ? i : -1;
                        setState(() {});
                      },
                      onDoubleTap: () => manageTransactionsEdition(due),
                      child: Tools.buildTableCell(
                          due.comment, rowHeight, commentWidth,
                          alignment: Alignment.center),
                    ),
                  )
                ],
              ),
            );
          }),
    );
  }

  void initAll() async {
    db.init().then((value) async => {
          reloadAccountWithCheck(),
          await reloadAccountList(),
          await reloadOutsiderList(),
          setState(() {})
        });
    initControllers();
    Tools.initActionItems(actionItemList);
  }

  void initControllers({Due? due}) {
    due ??= Due(0, 0, Outsider.none());
    changeAllOutsiderName = true;
    commentTrController = TextEditingController(text: due.comment);

    DateTime? date;
    if (due is DueOnce) {
      date = due.actionDate;
    } else if (due is Periodic) {
      date = due.referenceDate;
    }

    dateController = TextEditingController(
        text: date != null
            ? Tools.formatDate(date)
            : Tools.formatDate(selectedDate));
    amountController = TextEditingController(
        text: due.amount == 0 ? "" : (due.amount / 100).abs().toString());
    outsiderController = TextEditingController();
    outsiderController = TextEditingController(
        text: due.outsider!.isNone() ? "" : due.outsider!.name);
  }

  Future<void> actionItemTapped(ActionItem item) async {
    switch (item.actionItemEnum) {
      case ActionItemEnum.add:
        initControllers();
        dueDialog("Ajouter une occurrence", "AJOUTER",
            due: null, add: true, edit: false);
        clickedRowsList.clear();
        Tools.initActionItems(actionItemList);
        break;
      case ActionItemEnum.rm:
        bool? v = await Tools.confirmRemoveItem(
            context,
            "Suppression d'occurence(s)",
            "le(s) occurrence(s) sélectionnée(s) ?");
        if (v == null) {
          break;
        }

        if (v) {
          account.removeDueList(clickedRowsList, db).then((value) {
            if (value <= -1) {
              Tools.showNormalSnackBar(context,
                  "Erreur une ou des occurrences n'ont pas été supprimées");
            }
            clickedRowsList.clear();
            Tools.initActionItems(actionItemList);
            setState(() {});
          });
        }
        break;
      case ActionItemEnum.edit:
        if (clickedRowsList.length >= 2 || clickedRowsList.isEmpty) {
          return;
        }
        manageTransactionsEdition(account.getDueList()[clickedRowsList[0]]);

        break;
      case ActionItemEnum.duplicate:
        if (clickedRowsList.isEmpty) {
          return;
        }

        List<Due> dueList = [];

        for (int id in clickedRowsList) {
          dueList.add(account.getDueList()[id]);
        }
        clickedRowsList.clear();
        Tools.initActionItems(actionItemList);
        account.addDueList(db, dueList).then((value) => {
              if (value <= -1)
                {
                  Tools.showNormalSnackBar(context,
                      "Une erreur est survenur lors de la duplications des occurrences.")
                },
              reloadAccount(),
            });

        break;
      case ActionItemEnum.imp:
        break;
      case ActionItemEnum.replace:
        break;
      case ActionItemEnum.exp:
        break;
      case ActionItemEnum.unSelectAll:
        clickedRowsList.clear();
        Tools.initActionItems(actionItemList);
        setState(() {});
        break;
    }
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

  void reloadAccount() {
    BoolPointer updated = BoolPointer();
    db
        .getAccount(accountID,
            haveToGetTrList: false, haveToGetDueList: true, updated: updated)
        .then((value) => {
              if (value == null)
                {
                  Navigator.push(
                      context,
                      PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const HomePage()))
                }
              else
                {account = value, setState(() {})},
              if (updated.i)
                {
                  Tools.showNormalSnackBar(context,
                      "Des transactions ont été ajoutés depuis des occurences"),
                }
            });
  }

  Future<void> reloadAccountList({bool init = false}) async {
    accountList = await db.getAllAccounts();
  }

  Future<void> reloadOutsiderList({bool reload = false}) async {
    oList = await db.getAllOutsider();
    if (reload) {
      setState(() {});
    }
  }

  bool isDebitIcon() {
    return amountStateIcon.icon! == Icons.remove_circle;
  }

  void changeAmountState({void Function()? update}) {
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
    update ?? setState(() {});
  }

  void dueDialog(String title, String validateButton,
      {Due? due, required bool add, required bool edit}) {
    List<Tuple2<String, Period?>> dueTypeList = [
      Tuple2(Tools.periodToString(null), null),
      Tuple2(Tools.periodToString(Period.daily), Period.daily),
      Tuple2(Tools.periodToString(Period.weekly), Period.weekly),
      Tuple2(Tools.periodToString(Period.monthly), Period.monthly),
      Tuple2(Tools.periodToString(Period.quarterly), Period.quarterly),
      Tuple2(Tools.periodToString(Period.biAnnual), Period.biAnnual),
      Tuple2(Tools.periodToString(Period.yearly), Period.yearly)
    ];

    int getIndexFromString(String s) {
      int k = -1;
      dueTypeList.asMap().forEach((int key, Tuple2<String, Period?> value) {
        if (s == value.item1) {
          k = key;
          return;
        }
      });
      return k;
    }

    int getIndexFromPeriod(Period? p) {
      int k = -1;
      dueTypeList.asMap().forEach((int key, Tuple2<String, Period?> value) {
        if (p == value.item2) {
          k = key;
          return;
        }
      });
      return k;
    }

    int dueTypeIndex = 3;

    // set index of dropdown to be a reference to the Due it not null
    if (due != null) {
      Period? p;
      if (due is Periodic) {
        p = due.period;
      }
      dueTypeIndex = getIndexFromPeriod(p);
    }
    if (isDebitIcon()) {
      changeAmountState(update: () => setState(() {}));
    }

    if (due != null) {
      if (due.amount < 0) {
        changeAmountState(update: () => setState(() {}));
      }
      if (due is DueOnce) {
        selectedDate = due.actionDate;
      } else if (due is Periodic) {
        selectedDate = due.referenceDate!;
      }
    }

    String getLabelDateText() {
      return dueTypeIndex != 0 ? "Date de référence" : "Date d'exécution";
    }

    String dateLabelText = getLabelDateText();

    List<Widget> buttonsList = [
      // cancel button
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: closeDueDialog,
          style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.grey)),
          child: const Text("ANNULER"),
        ),
      ),
      // confirm button
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: () => submitDueDialog(dueTypeList[dueTypeIndex].item2, due,
              rm: false, edit: edit, add: add),
          style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.green)),
          child: Text(validateButton),
        ),
      )
    ];

    if (edit && !add) {
      buttonsList.insert(
          0,
          // remove button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                bool? v = await Tools.confirmRemoveItem(
                    context,
                    "Suppression d'une occurrence",
                    "l'occurrence sélectionée ?");
                if (v == null) {
                  return;
                }
                if (v) {
                  account.removeDue(clickedRowsList[0], db).then((value) => {
                        if (value <= -1)
                          {
                            Tools.showNormalSnackBar(context,
                                "Une erreur est survenur lors de la suppresion de l'occurrence"),
                          },
                        closeDueDialog(),
                      });
                }
              },
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.red)),
              child: const Text("SUPPRIMER"),
            ),
          ));
    }

    SDenum sd = SDenum("tiers", map: Tools.getOutsiderListName(oList));

    double width = 400, height = 300;

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  title: Text(title),
                  content: SizedBox(
                    height: height,
                    width: width,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // date
                            Expanded(
                                child: Padding(
                              padding: const EdgeInsets.only(
                                  right: 8.0, top: 8, bottom: 8),
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
                                  decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      labelText: dateLabelText),
                                ),
                              ),
                            )),
                            // plus / minus icon
                            InkWell(
                              onTap: () =>
                                  {changeAmountState(), setState(() {})},
                              child: amountStateIcon,
                            ),
                            // amount
                            Expanded(
                                child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: TextFormField(
                                controller: amountController,
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: "Montant"),
                              ),
                            ))
                          ],
                        ),
                        Row(
                          children: [
                            // dropdown of the periods
                            Expanded(
                                child: DropdownButton<String>(
                              value: dueTypeList[dueTypeIndex].item1,
                              onChanged: (String? s) => {
                                dueTypeIndex = getIndexFromString(s!),
                                dateLabelText = getLabelDateText(),
                                setState(() {})
                              },
                              items: dueTypeList
                                  .map<DropdownMenuItem<String>>(
                                      (Tuple2<String, Period?> e) =>
                                          DropdownMenuItem<String>(
                                              value: e.item1,
                                              child: Text(e.item1)))
                                  .toList(),
                            )),
                            // outsiders
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: width / 2,
                                child: Tools.buildSearchBar(
                                    setState: () => setState(() {}),
                                    onSelected: (Object? s) =>
                                        outsiderOnSelected(s),
                                    controller: outsiderController,
                                    sd: sd,
                                    width: width / 2 - 30),
                              ),
                            ),
                          ],
                        ),
                        // change all outsiders' name
                        if (edit && !add)
                          (Row(
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
                          )),
                        // comment
                        Expanded(
                            child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextFormField(
                            maxLines: 11,
                            controller: commentTrController,
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: "Commentaires"),
                          ),
                        ))
                      ],
                    ),
                  ),
                  actions: buttonsList,
                )));
  }

  void closeDueDialog() {
    Navigator.of(context).pop();
    initControllers();
    setState(() {});
  }

  Future<void> submitDueDialog(Period? period, Due? due,
      {required bool rm, required bool add, required edit}) async {
    DialogError e = allControllerCompleted(period);

    switch (e) {
      case DialogError.dateBefore:
        Tools.showNormalSnackBar(context,
            "La date donnée est invalide, elle doit être après aujourd'hui");
        return;
      case DialogError.invalidAmount:
        Tools.showNormalSnackBar(context, "La valeur du montant est invalide");
        return;
      case DialogError.invalidOutsider:
        Tools.showNormalSnackBar(context, "L'intitulé du tiers est invalide");
        return;
      case DialogError.tooMuchPrecision:
        Tools.showNormalSnackBar(context,
            "Veuillez fournir un montant comportant au maximum 2 chiffres après la virgule.");
        return;
      case DialogError.unknown:
      case DialogError.noError:
      case DialogError.dateAfter:
    }

    // are verified above
    int amount = (double.tryParse(amountController.text.trim())! *
            (isDebitIcon() ? -1 : 1) *
            100)
        .round();

    Due newDue;

    // DueOnce
    if (period == null) {
      if (due == null) {
        newDue = DueOnce(0, amount, Outsider(0, outsiderController.text.trim()),
            selectedDate);
      } else {
        newDue = DueOnce(
            due.id,
            amount,
            Outsider(due.outsider!.id, outsiderController.text.trim()),
            selectedDate);
      }
    }
    // Periodic
    else {
      // set last activation
      DateTime? d = selectedDate;
      if (selectedDate.isAfter(DateTime.now())) {
        // set before date if after because the date will have to be updated at this particulary date
        d = Tools.generateNextDateTime(period, selectedDate, last: -1);
        if (d == null) {
          Tools.showNormalSnackBar(context, "Une erreur est survenue !!");
          return;
        }
      }
      if (due == null) {
        newDue = Periodic(
            0,
            amount,
            Outsider(0, outsiderController.text.trim()),
            selectedDate,
            d,
            period);
      } else {
        newDue = Periodic(
            due.id,
            amount,
            Outsider(due.outsider!.id, outsiderController.text.trim()),
            selectedDate,
            d,
            period);
      }
    }

    newDue.comment = commentTrController.text.trim();
    newDue.outsider!.name = outsiderController.text.trim();

    // add
    if (add && !rm && !edit) {
      account.addDue(db, newDue).then((value) => {
            if (value <= -1)
              {
                Tools.showNormalSnackBar(context,
                    "Une erreur est survenue lors de l'ajout de l'occurrence"),
              },
            reloadAccount()
          });
      oList.add(Outsider(0, outsiderController.text.trim()));
    } else
    // edit
    if (edit && !rm && !add) {
      // check if outsider name changed and edition has to be done one all due / transactions
      if (changeAllOutsiderName &&
          due?.outsider!.name != outsiderController.text.trim()) {
        db.updateOutsider(
            due!.outsider!,
            Outsider(-1, outsiderController.text.trim(),
                comment: due.outsider!.comment));
      }

      db
          .editDue(newDue, due ?? account.getDueList()[clickedRowsList[0]])
          .then((value) => {
                if (value <= -1)
                  {
                    Tools.showNormalSnackBar(context,
                        "Une erreur est survenue lors de la modification de l'occurrence"),
                  },
                reloadAccount()
              });
      oList.add(Outsider(0, outsiderController.text.trim()));
    } else
    // remove
    if (rm && !edit && !add) {
      if (due == null) {
        Tools.showNormalSnackBar(context,
            "Une erreur est survenue lors de la suppression de l'occurrence (1)");
      }
      account.removeDue(due!.id, db).then((value) => {
            if (value <= -1)
              {
                Tools.showNormalSnackBar(context,
                    "Une erreur est survenue lors de la suppression de l'occurrence (2)"),
              },
            reloadAccount(),
          });
    }
    clickedRowsList.clear();
    closeDueDialog();
  }

  int outsiderOnSelected(Object? o) {
    if (o == null || o is! Outsider) {
      return -1;
    }

    return 0;
  }

  DialogError allControllerCompleted(Period? period) {
    // check for double precision old methode was not working
    List<String> amountList = amountController.text.trim().split(".");
    if (amountList.length >= 2 && amountList[1].length > 2) {
      return DialogError.tooMuchPrecision;
    }
    double? amountTMP = double.tryParse(amountController.text.trim());
    if (amountTMP == null) {
      return DialogError.invalidAmount;
    }
    if (period == null &&
        (Tools.areSameDay(DateTime.now(), selectedDate) ||
            selectedDate.isBefore(DateTime.now()))) {
      return DialogError.dateBefore;
    } else if ((outsiderController.text.trim().isEmpty)) {
      return DialogError.invalidOutsider;
    }
    return DialogError.noError;
  }

  void manageTransactionsEdition(Due? due) {
    initControllers(due: due);
    dueDialog("Édition d'une occurrence", "MODIFIER",
        due: due, add: false, edit: true);
  }
}
