import 'dart:math';

import 'package:flutter/material.dart';
import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/item_menu.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/models/user_data.dart';
import 'package:money_for_mima/pages/home_page.dart';
import 'package:money_for_mima/pages/settings/outsider_list_view.dart';
import 'package:money_for_mima/utils/tools.dart';
import 'package:money_for_mima/utils/version_manager.dart';

class SettingsPage extends StatefulWidget {
  final int accountID;
  const SettingsPage(this.accountID, {super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  DatabaseManager db = DatabaseManager();

  int accountID = 0;
  // Account account = Account.none([], []);

  List<Account> accountList = [];
  List<Outsider> outsiderList = [];

  double windowWidth = 0;
  // static const double infoHeight = 70;
  static const double popupSettingsWigth = 400;

  UserData userData = UserData.none();
  String packageVersion = "";

  List<int> outsiderIdListUsed = [];

  @override
  void initState() {
    accountID = super.widget.accountID;
    initUserData();
    initAll();
    super.initState();
  }

  Future<void> initUserData() async {
    userData = await UserData().setData();
    packageVersion = userData.packageInfo!.version;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    windowWidth = max(1000, MediaQuery.of(context).size.width);
    return Scaffold(
      appBar: Tools.generateNavBar(PagesEnum.settings, []),
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
                        // table of outsiders
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
                        Column(
                          children: [
                            buildPopupSettings(),
                            InkWell(
                              onTap: () {
                                VersionManager.searchNewVersion(
                                    context: context,
                                    userData: userData,
                                    showCheckBox: false,
                                    showNetworkError: true);
                              },
                              child: const SizedBox(
                                width: 250,
                                child: Row(
                                  children: [
                                    Icon(Icons.refresh),
                                    Text("Rechercher des mises à jour")
                                  ],
                                ),
                              ),
                            )
                          ],
                        )
                        //
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

  Widget buildPopupSettings() {
    return SizedBox(
      height: max(
          400,
          MediaQuery.of(context).size.height -
              8 * 2 -
              Tools.appBarHeight -
              500),
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
                      right: BorderSide(color: Colors.black),
                      left: BorderSide(color: Colors.black))),
              child: const Text(
                "Paramètres relatifs aux messages par popup",
                style: TextStyle(fontSize: 18),
              ),
            ),
            // show new version
            Container(
              decoration: const BoxDecoration(
                  border: Border.symmetric(
                      vertical: BorderSide(color: Colors.black))),
              child: InkWell(
                onTap: () async {
                  userData.switchNewVersionValue();
                  setState(() {});
                },
                child: Row(
                  children: [
                    Checkbox(
                        value: userData.showNewVersion, onChanged: (v) => {}),
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
            ),

            // show error
            Container(
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Colors.black),
                      right: BorderSide(color: Colors.black),
                      left: BorderSide(color: Colors.black))),
              child: InkWell(
                onTap: () async {
                  userData.switchDialogErrorValue();
                  setState(() {});
                },
                child: Row(
                  children: [
                    Checkbox(
                        value: userData.showDialogOnError,
                        onChanged: (v) => {}),
                    const SizedBox(
                        width: popupSettingsWigth - 34,
                        child: Text.rich(
                          TextSpan(
                              text:
                                  "Afficher l'erreur lors de la recherche d'une nouvelle version"),
                          softWrap: true,
                          maxLines: 8,
                          overflow: TextOverflow.ellipsis,
                        ))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> reloadAccount() async {
    if (accountID >= 0) {
      db.getAccount(accountID).then((value) {
        if (value == null) {
          Tools.showNormalSnackBar(context,
              "Une erreur est survenue, impossible de récupérer votre compte");
          Navigator.push(context,
              PageRouteBuilder(pageBuilder: (_, __, ___) => const HomePage()));
        }
      });
    }
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
