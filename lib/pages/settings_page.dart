import 'dart:math';

import 'package:flutter/material.dart';
import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/item_menu.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/pages/home_page.dart';
import 'package:money_for_mima/pages/settings/outsider_list_view.dart';
import 'package:money_for_mima/utils/tools.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final int accountID;
  const SettingsPage(this.accountID, {super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  DatabaseManager db = DatabaseManager();

  int accountID = 0;
  Account account = Account.none([], []);

  List<Account> accountList = [];
  List<Outsider> outsiderList = [];

  double windowWidth = 0;
  // static const double infoHeight = 70;
  static const double popupSettingsWigth = 400;

  SharedPreferences? prefs;
  String packageVersion = "";
  PackageInfo? packageInfo;
  bool showNewVersionDialog = true;
  bool showErrorFetching = true;

  List<int> outsiderIdListUsed = [];

  @override
  void initState() {
    accountID = super.widget.accountID;
    initSPPI();
    initAll();
    super.initState();
  }

  Future<void> initSPPI() async {
    prefs = await Tools.getSP();
    packageInfo = await Tools.getPackageInfo();
    showNewVersionDialog =
        await Tools.getShowNewVersion(sharedPreferences: prefs);
    showErrorFetching =
        await Tools.getShowDialogOnError(sharedPreferences: prefs);
    packageVersion = packageInfo!.version;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    windowWidth = max(1000, MediaQuery.of(context).size.width);
    return Scaffold(
      appBar: Tools.generateNavBar(PagesEnum.settings, [account]),
      body: SafeArea(
          child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          SizedBox(
              width: windowWidth,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    /* SizedBox(
                      height: infoHeight,
                      width: windowWidth,
                      child: Tools.buildAccountDropDown(
                          accountList: accountList,
                          account: account,
                          accountSelectedName: account.designation,
                          update: () => setState(() {}),
                          onSelection: (int selection) {},
                          isExpanded: false),
                    ), */
                    // settings container
                    SizedBox(
                      width: windowWidth,
                      child: Row(children: [
                        OutsiderListView(
                          allOutsiderIdUsed: outsiderIdListUsed,
                          backgroundList: Tools.getBackgroundList(context),
                          update: () {
                            reloadOutsiderList()
                                .then((value) => setState(() {}));
                          },
                          outsiderList: outsiderList,
                          db: db,
                        ),
                        const SizedBox(
                          width: 20,
                        ),
                        SizedBox(
                          height: max(
                              400,
                              MediaQuery.of(context).size.height -
                                  8 * 2 -
                                  Tools.appBarHeight),
                          child: SizedBox(
                            width: popupSettingsWigth,
                            child: ListView(
                              scrollDirection: Axis.vertical,
                              children: [
                                // title
                                Container(
                                  padding: const EdgeInsets.all(8.0),
                                  decoration: const BoxDecoration(
                                      border: Border(
                                          top: BorderSide(color: Colors.black),
                                          right:
                                              BorderSide(color: Colors.black),
                                          left:
                                              BorderSide(color: Colors.black))),
                                  child: const Text(
                                    "Paramètres relatifs aux messages par popup",
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                                // show new version
                                Container(
                                  decoration: const BoxDecoration(
                                      border: Border.symmetric(
                                          vertical:
                                              BorderSide(color: Colors.black))),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                          value: showNewVersionDialog,
                                          onChanged: ((value) async {
                                            if (value != null) {
                                              showNewVersionDialog =
                                                  await Tools.setShowNewVersion(
                                                value,
                                                sharedPreferences: prefs,
                                              );
                                              setState(() {});
                                            }
                                          })),
                                      const SizedBox(
                                        width: popupSettingsWigth - 34,
                                        child: Text(
                                          "Afficher le message de nouvelle version",
                                          softWrap: true,
                                          maxLines: 8,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    ],
                                  ),
                                ),

                                // show error
                                Container(
                                  decoration: const BoxDecoration(
                                      border: Border(
                                          bottom:
                                              BorderSide(color: Colors.black),
                                          right:
                                              BorderSide(color: Colors.black),
                                          left:
                                              BorderSide(color: Colors.black))),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                          value: showErrorFetching,
                                          onChanged: (v) async {
                                            if (v != null) {
                                              showErrorFetching = await Tools
                                                  .setShowDialogOnError(v,
                                                      sharedPreferences: prefs);
                                              setState(() {});
                                            }
                                          }),
                                      const SizedBox(
                                          width: popupSettingsWigth - 34,
                                          child: Text.rich(
                                            TextSpan(
                                                text:
                                                    "Afficher d'erreur lors de la recherche d'une nouvelle version"),
                                            softWrap: true,
                                            maxLines: 8,
                                            overflow: TextOverflow.ellipsis,
                                          ))
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      ]),
                    )
                  ],
                ),
              ))
        ]),
      )),
    );
  }

  void initAll() {
    db.init().then((value) async {
      await reloadAccount();
      await reloadAccountList();
      await reloadOutsiderList();
      await reloadOutsiderIdListUsed();
      setState(() {});
    });
  }

  Future<void> reloadAccount() async {
    db.getAccount(accountID).then((value) {
      if (value == null) {
        Tools.showNormalSnackBar(context,
            "Une erreur est survenue, impossible de récupérer votre compte");
        Navigator.push(context,
            PageRouteBuilder(pageBuilder: (_, __, ___) => const HomePage()));
      }
    });
  }

  Future<void> reloadOutsiderList() async {
    outsiderList = await db.getAllOutsider();
  }

  Future<void> reloadAccountList() async {
    accountList = await db.getAllAccounts();
  }

  Future<void> reloadOutsiderIdListUsed() async {
    outsiderIdListUsed = await db.getAllOutsiderIdUsed();
  }
}
