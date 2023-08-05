import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:intl/intl.dart';
import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/action_item.dart';
import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/item_menu.dart';
import 'package:money_for_mima/pages/due_page.dart';
import 'package:money_for_mima/pages/transaction_page.dart';
import 'package:money_for_mima/utils/tools.dart';
import 'package:money_for_mima/utils/version_manager.dart';
import 'package:observe_internet_connectivity/observe_internet_connectivity.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DatabaseManager db = DatabaseManager();
  PagesEnum currentPage = PagesEnum.home;
  List<Account> accountList = [];

  DateTime accountDate = DateTime.now();
  TextEditingController acNameCont = TextEditingController(),
      acBalanceCont = TextEditingController(),
      acDateCont = TextEditingController();

  static const Color accountsBorderColor = Colors.black;
  static const double accountsListWidth = 300;
  bool hasInit = false;

  List<ActionItem> actionItemList = [
    ActionItem("Ajouter", Icons.add, true, ActionItemEnum.add)
  ];

  Offset _tapPosition = Offset.zero;

  bool hasInternet = false;

  SharedPreferences? prefs;
  PackageInfo? packageInfo;
  bool showNewVersionDialog = true;
  bool showErrorFetching = true;

  @override
  void initState() {
    initSPPI().then((value) {
      VersionManager.searchNewVersion(
          context: context,
          showNewVersionDialog: showNewVersionDialog,
          showErrorFetching: showErrorFetching);
    });
    reloadAccountListSecure();
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
              decoration: const BoxDecoration(
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
                    final RenderObject? overlay =
                        Overlay.of(context).context.findRenderObject();

                    List<PopupMenuItem> items = [
                      const PopupMenuItem(
                        value: "transactions",
                        child: Text("Opérations"),
                      ),
                      const PopupMenuItem(
                        value: "due",
                        child: Text("Occurences"),
                      ),
                      const PopupMenuItem(
                        value: "edit",
                        child: Text("Modifier"),
                      ),
                      const PopupMenuItem(
                          value: "remove", child: Text("Supprimer"))
                    ];

                    if (!ac.selected) {
                      items.add(const PopupMenuItem(
                        value: "select",
                        child: Text("Sélectionner pour les autres fois"),
                      ));
                    }

                    if (!ac.favorite) {
                      items.add(const PopupMenuItem(
                        value: "favorite",
                        child: Text("Marquer comme favori"),
                      ));
                    } else {
                      items.add(const PopupMenuItem(
                        value: "favorite",
                        child: Text("Enlever des favoris"),
                      ));
                    }

                    return InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onSecondaryTapDown: _getTapPosition,
                        onSecondaryTap: () async {
                          await showMenu(
                                  context: context,
                                  position: RelativeRect.fromRect(
                                      Rect.fromLTWH(_tapPosition.dx,
                                          _tapPosition.dy, 30, 30),
                                      Rect.fromLTWH(
                                          0,
                                          0,
                                          overlay!.paintBounds.size.width,
                                          overlay.paintBounds.size.height)),
                                  items: items)
                              .then((res) async {
                            switch (res) {
                              case "select":
                                // item selected
                                if (ac.selected) {
                                  Tools.showNormalSnackBar(context,
                                      "Vous ne pouvez pas désélectionner celui qui est sélectionné");
                                  return;
                                }

                                unSelectAllAcounts().then((value) {
                                  if (value <= -1) {
                                    Tools.showNormalSnackBar(
                                        context, "Une erreur est survenue");
                                  }
                                  ac.setSelectionDB(db, true).then((value) {
                                    if (value <= -1) {
                                      Tools.showNormalSnackBar(context,
                                          "Une erreur est survenue lors de la sélection du compte");
                                    }
                                    setState(() {});
                                  });
                                });

                                break;
                              case "favorite":
                                ac
                                    .setFavoriteDB(db, !ac.favorite)
                                    .then((value) {
                                  if (value == -1) {
                                    Tools.showNormalSnackBar(context,
                                        "Une erreur est survenue lors de la modification");
                                    return;
                                  }
                                  reloadAccountList();
                                });
                                break;
                              case "edit":
                                //goToEditAccount(ac.id, PagesEnum.home);
                                showAccountDialog(
                                    ac: ac, edit: true, add: false, rm: false);
                                break;
                              case "transactions":
                                goToEditAccount(ac.id, PagesEnum.transaction);
                                break;
                              case "due":
                                goToEditAccount(ac.id, PagesEnum.due);
                                break;
                              case "remove":
                                final bool? v = await Tools.confirmRemoveItem(
                                    context,
                                    "Suppression d'un compte",
                                    "le compte ${ac.designation}");
                                if (v == null || !v) {
                                  return;
                                }
                                db.removeAccount(ac.id).then((value) {
                                  Future.delayed(
                                      const Duration(milliseconds: 3000));
                                  if (value <= -1) {
                                    Tools.showNormalSnackBar(context,
                                        "La suppression du compte a échoué");
                                  } else {
                                    accountList.removeAt(i);
                                    Account? selectedAccount =
                                        getSelectedAccount();
                                    if (selectedAccount == null) {
                                      reloadAccountList().then((value) {
                                        if (accountList.isNotEmpty) {
                                          accountList[0]
                                              .setSelectionDB(db, true)
                                              .then((value) {
                                            if (value <= -1) {
                                              Tools.showNormalSnackBar(context,
                                                  "Une erreur est survenue");
                                            }
                                            setState(() {});
                                          });
                                        }
                                      });
                                    } else {
                                      setState(() {});
                                    }
                                  }
                                });
                            }
                          });
                        },
                        onTap: () {
                          goToEditAccount(ac.id, PagesEnum.transaction);
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
              (ac.fullBalance / 100).toString(),
              style: TextStyle(
                  color: ac.fullBalance >= 0 ? Colors.green : Colors.red,
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

  void showAccountDialog(
      {Account? ac, required bool edit, required bool rm, required bool add}) {
    initTextFieldsDialog(ac: ac);
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(
                  ac == null ? "Ajout d'un compte" : "Modification du compte"),
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
                                    border: OutlineInputBorder(),
                                    labelText: "Solde initial",
                                    enabled: true),
                              ),
                            )),
                        // date
                        Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: InkWell(
                                onTap: () async {
                                  accountDate = await Tools.selectDate(
                                          context, accountDate, acDateCont,
                                          setState: () => setState(() {})) ??
                                      DateTime.now();
                                },
                                child: TextField(
                                  controller: acDateCont,
                                  decoration: const InputDecoration(
                                      labelText: "Date",
                                      enabled: false,
                                      border: OutlineInputBorder()),
                                ),
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
                                  onPressed: () => submitNewAccountDialog(ac,
                                      add: add, rm: rm, edit: edit),
                                  child: Text(
                                      ac == null ? "AJOUTER" : "MODIFIER")),
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

  Future<void> submitNewAccountDialog(Account? acParam,
      {required bool edit, required bool rm, required bool add}) async {
    if (rm && !add && !edit) {
      bool? res = await Tools.confirmRemoveItem(context,
          "Suppression d'un compte", "le compte '${acParam?.designation}' ?");
      if (res == null || !res) {
        return;
      }
      db.removeAccount(acParam!.id).then((v) {
        if (v <= -1) {
          Tools.showNormalSnackBar(context,
              "Une erreur est survenue lors de la suppresion du compte");
        }
      });
      return;
    }

    if (acDateCont.text.trim().isEmpty ||
        acBalanceCont.text.trim().isEmpty ||
        acNameCont.text.trim().isEmpty) {
      SnackBar snackBar = const SnackBar(
          content: Text("Les données fournies ne sont pas valides"));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }

    double? balanceDouble = double.tryParse(acBalanceCont.text.trim());
    if (balanceDouble == null) {
      SnackBar snackBar = const SnackBar(content: Text("Solde founi invalide"));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }

    balanceDouble *= 100;
    if (balanceDouble.toInt() != balanceDouble) {
      Tools.showNormalSnackBar(context,
          "Veuillez fournir un montant initial possédant au maximum 2 décimales.");
    }
    int balance = balanceDouble.toInt();

    // new account
    if (acParam == null) {
      // check if name of account is already used
      for (var ac in accountList) {
        if (ac.designation == acNameCont.text.trim()) {
          SnackBar snackBar = const SnackBar(
              content: Text("Ce nom de compte est déjà utilisé !"));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
          return;
        }
      }

      // unselect all accounts
      await unSelectAllAcounts();

      // this function this new account selected
      Account ac =
          await db.addAccount(acNameCont.text.trim(), balance, "", accountDate);
      accountList.add(ac);
      setState(() {});
    }
    // account edition
    else {
      if (balance != acParam.initialBalance) {
        db.setAccountInitialBalance(acParam.id, balance).then((value) {
          if (value <= -1) {
            Tools.showNormalSnackBar(
                context, "Une erreur est survenue lors d'une modification (1)");
          } else {
            reloadAccountList();
          }
        });
      }
      if (acNameCont.text.trim() != acParam.designation) {
        // check if name of account is already used
        for (var ac in accountList) {
          if (ac.designation == acNameCont.text.trim() &&
              acParam.designation != ac.designation) {
            SnackBar snackBar = const SnackBar(
                content: Text("Ce nom de compte est déjà utilisé !"));
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
            return;
          }
        }
        acParam.setDesignationDB(acNameCont.text.trim(), db).then((value) {
          if (value <= -1) {
            Tools.showNormalSnackBar(
                context, "Une erreur est survenue lors d'une modification (2)");
          } else {
            reloadAccountList();
          }
        });
      }
      if (!Tools.areSameDay(accountDate, acParam.creationDate!)) {
        acParam.setCreationDate(accountDate, db).then((value) {
          if (value <= -1) {
            Tools.showNormalSnackBar(
                context, "Une erreur est survenue lors d'une modification (3)");
          } else {
            reloadAccountList();
          }
        });
      }
    }

    closeNewAccountDialog();
  }

  void manageOnTapItemMenu(ActionItem item) {
    switch (item.actionItemEnum) {
      case ActionItemEnum.add:
        showAccountDialog(add: true, edit: false, rm: false);
        break;
      case ActionItemEnum.rm:
        break;
      case ActionItemEnum.edit:
        break;
      case ActionItemEnum.duplicate:
        break;
      case ActionItemEnum.imp:
        break;
      case ActionItemEnum.replace:
        break;
      case ActionItemEnum.exp:
        break;
      case ActionItemEnum.unSelectAll:
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

  Future<int> unSelectAllAcounts() async {
    int res = 0, tmp;
    for (Account ac in accountList) {
      if (ac.selected) {
        tmp = await ac.setSelectionDB(db, false);
        if (res == 0) {
          res = tmp;
        }
      }
    }
    return res;
  }

  void initTextFieldsDialog({Account? ac}) {
    acDateCont.text = DateFormat("dd/MM/yyyy")
        .format(ac == null ? accountDate : ac.creationDate!);
    acBalanceCont = TextEditingController(
        text: ac == null ? "" : ac.initialBalance.toString());
    acNameCont = TextEditingController(text: ac == null ? "" : ac.designation);
    accountDate = ac == null ? DateTime.now() : ac.creationDate!;
  }

  void _getTapPosition(TapDownDetails details) {
    final RenderBox referenceBox = context.findRenderObject() as RenderBox;
    setState(() {
      _tapPosition = referenceBox.globalToLocal(details.globalPosition);
    });
  }

  void reloadAccountListSecure() {
    db.init().then((value) async {
      reloadAccountList();
    });
  }

  Future<void> reloadAccountList() async {
    BoolPointer updated = BoolPointer();
    db
        .getAllAccounts(updated: updated, haveToGetDueList: true)
        .then((value) => {
              if (updated.i)
                {
                  Tools.showNormalSnackBar(context,
                      "Des transactions ont été ajoutées depuis des occurrences")
                },
              accountList = value,
              setState(() {})
            });
  }

  void goToEditAccount(int acID, PagesEnum e) {
    switch (e) {
      case PagesEnum.home:
        Navigator.push(context,
            PageRouteBuilder(pageBuilder: (_, __, ___) => const HomePage()));
        break;
      case PagesEnum.due:
        Navigator.push(context,
            PageRouteBuilder(pageBuilder: (_, __, ___) => DuePage(acID)));
        break;
      case PagesEnum.transaction:
        Navigator.push(
            context,
            PageRouteBuilder(
                pageBuilder: (_, __, ___) => TransactionPage(acID)));
        break;
      case PagesEnum.settings:
        break;
    }
  }

  Future<void> initSPPI() async {
    prefs = await Tools.getSP();
    packageInfo = await Tools.getPackageInfo();
    showNewVersionDialog =
        await Tools.getShowNewVersion(sharedPreferences: prefs);
    showErrorFetching =
        await Tools.getShowDialogOnError(sharedPreferences: prefs);
  }
}
