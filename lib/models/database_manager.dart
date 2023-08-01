import 'dart:async';
import 'dart:math';

import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/due.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/models/transactions.dart';
import 'package:money_for_mima/utils/tools.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseManager {
  DatabaseManager({hasToInit = false}) {
    if (hasToInit) {
      init();
    }
  }

  final String _tbNameOutsiders = "Outsiders";
  final String _tbNameAccounts = "Accounts";
  final String _tbNameTransactions = "Transactions";
  final String _tbNameDue = "Due";

  final String _id = "id";
  final String _used = "used";
  final String _comment = "comment";

  //Outsiders
  final String _outsiderName = "name";

  // Account
  final String _acDesignation = "designation";
  final String _acFullBalance = "fullBalance";
  final String _acFlaggedBalance = "flaggedBalance";
  final String _acInitialBalance = "initBalance";
  final String _acFavorite = "favorite";
  final String _acTrList = "transactionsList";
  final String _acDueList = "dueList";
  final String _acNthTr = "nth_transactions";
  final String _acSelected = "selected";
  final String _acDateCreation = "dateCreation";

  // Transaction
  final String _trAmount = "amount";
  final String _trDOM = "dayOfMonth";
  final String _trMonth = "month";
  final String _trYear = "year";
  final String _trOutsiderID = "outsiderID";
  final String _trFlagged = "flagged"; // -> true / false
  final String _trDueID = "dueID"; // -1 -> not a due, -2 -> deleted
  final String _trAccountID = "accountID";
  final String _trBalanceAcMoment = "balanceAcInMoment";

  // Due (Écheance/ Occurrence)
  final String _deAmount = "amount";
  final String _deType = "type"; // Periodic / DueOnce
  final String _deJsonClass = "jsonClass";
  final String _deAccountID = "accountID";
  final String _deOutsiderID = "outsiderID";

  static const int nth = 20;

  late Future<Database> database;
  bool _initDone = false;

  Future<void> init() async {
    /* Directory dir = await getApplicationDocumentsDirectory();
    String appDocDir = dir.path; */
    database = openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      join(await getDatabasesPath(), 'money_for_mima_DB.db'),
      // When the database is first created, create a table to store all data.
      onCreate: (db, version) => createDb(db),
      version: 1,
    );
    _initDone = true;
  }

  void createDb(Database db) {
    String createTB = "CREATE TABLE IF NOT EXISTS";
    String idColDef = "INTEGER PRIMARY KEY AUTOINCREMENT";
    String nn = "NOT NULL";
    db.execute(
        '$createTB $_tbNameOutsiders($_id $idColDef $nn, $_used TEXT $nn, $_outsiderName TEXT $nn, $_comment TEXT $nn);');
    db.execute(
        '$createTB $_tbNameAccounts($_id $idColDef $nn, $_used TEXT $nn, $_acDesignation TEXT $nn, $_acFullBalance INTEGER $nn, $_acFavorite TEXT $nn, $_acInitialBalance INTEGER $nn, $_acDueList TEXT $nn, $_acTrList TEXT $nn, $_acNthTr TEXT $nn, $_comment TEXT $nn, $_acSelected TEXT $nn, $_acDateCreation TEXT $nn, $_acFlaggedBalance INTEGER $nn);');
    db.execute(
        "$createTB $_tbNameTransactions($_id $idColDef $nn, $_used TEXT $nn, $_trAmount READ $nn, $_trYear INTEGER $nn, $_trMonth INT $nn, $_trDOM INTEGER $nn, $_trOutsiderID INTEGER $nn, $_trFlagged TEXT $nn, $_trDueID INTEGER $nn, $_comment TEXT $nn, $_trAccountID INTEGER $nn, $_trBalanceAcMoment INTEGER $nn)");
    db.execute(
        '$createTB $_tbNameDue($_id $idColDef $nn, $_used TEXT $nn, $_deAmount INTEGER $nn, $_deType TEXT $nn, $_deJsonClass TEXT $nn, $_comment TEXT $nn, $_deAccountID INTEGER $nn, $_deOutsiderID INTEGER $nn);');
  }

  Future<bool> initDone() async {
    return _initDone;
  }

  /// insert outsider and return it, if an error occured, null is returned
  Future<Outsider?> insertOutsider(Outsider o) async {
    if (o.name.isEmpty) {
      return null;
    }
    final db = await database;
    final int id = await db.insert(_tbNameOutsiders, o.toMapForDB());
    if (id == 0) {
      return null;
    }
    o.id = id;
    return o;
  }

  Future<Account> addAccount(String name, int initBalance, String comment,
      DateTime creationDate) async {
    Account ac = Account(
        -1, name, initBalance, initBalance, initBalance, false, [], [], true,
        comment: comment, creationDate: creationDate);

    Database db = await database;

    List<Map<String, Object?>> res = await db.query(_tbNameAccounts,
        limit: 1, columns: [_id], where: "$_used = ?", whereArgs: ["false"]);
    final int id;
    // no empty space
    if (res.isEmpty) {
      id = await db.insert(_tbNameAccounts, ac.toMapForDB());
    } else {
      id = int.parse(res.first[_id].toString());
      await db.update(_tbNameAccounts, ac.toMapForDB(),
          where: "$_id = ? AND $_used = ?",
          whereArgs: [id.toString(), "false"]);
    }

    ac.id = id;

    return ac;
  }

  Future<List<Due>> getDueList(List<String> dueIDList) async {
    final Database db = await database;

    if (dueIDList.isEmpty) {
      return [];
    }

    List<String> validIDList = [];

    // build id list for DB
    String e = "?";
    String idTuple = e;
    int? x = int.tryParse(dueIDList[0]);
    if (x == null) {
      return [];
    }
    validIDList.add(x.toString());
    for (int i = 1; i < dueIDList.length; i++) {
      int? x = int.tryParse(dueIDList[i]);
      if (x != null) {
        validIDList.add(x.toString());
        idTuple = "$idTuple, $e";
      }
    }

    // build if conditions
    List<Object?> argsList = ["true"];
    argsList.addAll(validIDList);

    List<Map<String, Object?>> res = await db.query(_tbNameDue,
        limit: validIDList.length,
        where: "$_used = ? AND $_id IN ($idTuple)",
        whereArgs: argsList,
        columns: ["*"]);

    List<Due> dueList = [];
    for (Map<String, Object?> map in res) {
      Due? due = await Due.fromMapDB(map, this);
      if (due == null) {
        continue;
      }
      dueList.add(due);
    }

    return dueList;
  }

  /// get outsider from [oName] returning Outsider if found else null
  Future<Outsider?> getOutsiderFromName(String oName) async {
    if (oName.isEmpty) {
      return null;
    }
    final Database db = await database;

    List<Map<String, Object?>> res = await db.query(_tbNameOutsiders,
        columns: ["*"],
        where: "$_used = ? AND $_outsiderName = ?",
        whereArgs: ["true", oName],
        limit: 1);

    if (res.isNotEmpty) {
      return Outsider.fromMap(res.first);
    }

    return null;
  }

  // get outsider from ID
  Future<Outsider?> getOutsiderFromID(int oID) async {
    Database db = await database;

    List<Map<String, Object?>> res = await db.query(_tbNameOutsiders,
        columns: ["*"],
        where: "$_used = ? AND $_id = ?",
        whereArgs: ["true", oID],
        limit: 1);

    if (res.isNotEmpty) {
      return Outsider.fromMap(res.first);
    }

    return null;
  }

  Future<Transactions?> getTransactions(
      {required int? trID, required Map<String, Object?>? map}) async {
    if (trID != null && map == null) {
      map = await getTransactionsMap(trID);
      if (map == null) {
        return null;
      }
    } else if (map == null) {
      return null;
    }

    Transactions? tr = Transactions.fromMap(map);
    if (tr == null) {
      return null;
    }

    tr.outsider =
        await getOutsiderFromID(int.parse(map[_trOutsiderID].toString()));
    return tr;
  }

  Future<Map<String, Object?>?> getTransactionsMap(int trID,
      {List<String>? cols}) async {
    final Database db = await database;

    List<Map<String, Object?>> res = await db.query(_tbNameTransactions,
        limit: 1,
        where: "$_used = ? AND $_id = ?",
        whereArgs: ["true", trID],
        columns: cols);

    if (res.isEmpty) {
      return null;
    }

    return res.first;
  }

  Future<List<Account>> getAllAccounts(
      {BoolPointer? updated,
      bool haveToGetTransactions = false,
      haveToGetDueList = false}) async {
    List<Account> acL = [];
    final Database db = await database;

    // get all accounts
    List<Map<String, Object?>> allList = await db.query(_tbNameAccounts,
        columns: ["*"], where: "$_used = ?", whereArgs: ["true"]);

    for (var map in allList) {
      int? id = int.tryParse(map[_id].toString());
      if (id == null) {
        continue;
      }
      Account? ac = await getAccount(id,
          map: [map],
          haveToGetDueList: haveToGetDueList,
          updated: updated,
          haveToGetTrList: haveToGetTransactions);
      if (ac != null) {
        acL.add(ac);
      }
    }

    return acL;
  }

  Future<int> nbUnFlagged(int acID) async {
    final Database db = await database;
    String query =
        "SELECT COUNT($_id) as count FROM $_tbNameTransactions WHERE $_used = 'true' AND $_trAccountID = $acID AND $_trFlagged = 'false'";
    List<Map<String, Object?>> l = await db.rawQuery(query);
    if (l.isEmpty) {
      return -1;
    }
    int? i = int.tryParse(l.first["count"].toString());
    return i ?? -1;
  }

  Future<int> nbOfTransactions(int acID) async {
    final Database db = await database;
    String query =
        "SELECT COUNT($_id) as count FROM $_tbNameTransactions WHERE $_used = 'true' AND $_trAccountID = $acID";
    final List<Map<String, Object?>> res = await db.rawQuery(query);
    if (res.isEmpty) {
      return -1;
    }

    int? i = int.tryParse(res.first["count"].toString());
    return i ?? -1;
  }

  Future<List<Transactions>> getTransactionList(
      List<String> trIDList, int? nb, int acID) async {
    final Database db = await database;
    if (nb == null) {
      final int nbTr = await nbOfTransactions(acID);
      if (nbTr <= -1) {
        return [];
      }
      nb = nbTr;
    }
    int maxTr = nb;
    int inc = nb;
    nb = 0;

    List<String> validIDList = [];
    List<Transactions> trList = [];
    String e = "?";
    String idTuple = "";

    if (trIDList.isEmpty) {
      return trList;
    }

    int countUnflagged = 0, count = 0;
    // build id list for DB
    int buildItems(int start, int nbF) {
      if (trIDList.length <= start) {
        return -1;
      }
      int? x = int.tryParse(trIDList[start]);
      if (x == null) {
        return -1;
      }
      validIDList.add(x.toString());
      count++;
      if (idTuple.isEmpty) {
        idTuple = e;
      } else {
        idTuple = "$idTuple, $e";
      }
      int i = start + 1;
      while (i < min(trIDList.length, nbF)) {
        x = int.tryParse(trIDList[i]);
        if (x != null) {
          validIDList.add(x.toString());
          count++;
          idTuple = "$idTuple, $e";
        }
        i++;
      }
      return 0;
    }

    final int nbTrUnFlagged = await nbUnFlagged(acID);
    while (countUnflagged < nbTrUnFlagged || count < maxTr) {
      if (buildItems(nb!, nb + inc) <= -1) {
        return trList;
      }

      List<Object?> argsList = ["true"];
      argsList.addAll(validIDList);

      List<Map<String, Object?>> res = await db.query(_tbNameTransactions,
          limit: validIDList.length,
          where: "$_used = ? AND $_id IN ($idTuple)",
          whereArgs: argsList,
          columns: ["*"]);

      for (Map<String, Object?> map in res) {
        Transactions? tr = await getTransactions(trID: null, map: map);
        if (tr == null) {
          continue;
        }
        trList.add(tr);
        if (!tr.flagged) {
          countUnflagged++;
        }
      }
      nb += inc;
      idTuple = "";
      validIDList.clear();
    }
    return trList;

    /* List<String> idList = strList.split(",");

    while ((nbUnFlaggedAdded < nbTrUnFlagged || trList.length < nth) &&
        count < idList.length) {
      if (idList[count].isEmpty) {
        count++;
        continue;
      }
      Transactions? tr_ = await getTransactions(int.parse(idList[count]));
      if (tr_ != null) {
        trList.add(tr_);
      }
      count++;
    }

    return trList.reversed.toList(); */
  }

  Future<Due?> getDueFromID(int dueID) async {
    final Database db = await database;

    List<Map<String, Object?>> res = await db.query(_tbNameDue,
        columns: ["*"],
        where: "$_used = ? AND $_id = ?",
        whereArgs: ["true", dueID]);
    if (res.isEmpty) {
      return null;
    }

    return Due.fromMapDB(res.first, this);

    /*for (String idStr in strList.split(",")) {
      int? id = int.tryParse(idStr);
      if (id == null) {
        continue;
      }

      Due? due = await getDue(id);
      if (due == null) {
        continue;
      }
      dueList.add(due);
    }

    return dueList;*/
  }

  /// update outsider from name OR from id
  /// if both -1 is returned
  Future<Outsider?> manageOutsider(
      {required Outsider? outsider, required int? oID}) async {
    if (outsider == null && oID != null) {
      return await getOutsiderFromID(oID);
    } else if (outsider != null && oID == null) {
      Outsider? o = await getOutsiderFromName(outsider.name);
      o ??= await insertOutsider(outsider);
      if (o == null) {
        return null;
      }
      return o;
    }

    return null;
  }

  ///return id of tr
  ///-1 -> error
  Future<int> addTransactionsToAccount(int acID, Transactions tr,
      {int? freeRowID}) async {
    final Database db = await database;

    // verify that the account related to the tr exists and get list of item
    final List<Map<String, Object?>> resAc = await db.query(_tbNameAccounts,
        limit: 1,
        where: "$_used = ? AND $_id = ?",
        whereArgs: ["true", acID],
        columns: [_acTrList, _acInitialBalance, _acDateCreation]);
    if (resAc.isEmpty) {
      return -1;
    }

    // first Transactions so we have to add it with the initial balance
    if (resAc.first[_acTrList].toString().isEmpty) {
      tr.acBalance =
          (int.tryParse(resAc.first[_acInitialBalance].toString()) ?? 0) +
              tr.amount;
    }

    // manage outsider
    Outsider? o = await manageOutsider(outsider: tr.outsider, oID: null);
    if (o == null) {
      return -1;
    }
    tr.outsider = o;

    Map<String, Object?> trMap = tr.toMapForDB();
    // add accountID
    trMap[_trAccountID] = acID.toString();

    final int id;
    // check there is an empty row for TR

    if (freeRowID == null) {
      // no space available add one line
      id = await db.insert(_tbNameTransactions, trMap);
    } else {
      // update an empty line
      id = freeRowID;
      await db.update(_tbNameTransactions, trMap,
          where: "$_id = ? AND $_used = ?", whereArgs: [id, "false"]);
    }
    tr.id = id;

    DateTime? acDateCreation =
        DateTime.tryParse(resAc.first[_acDateCreation].toString());
    if (acDateCreation == null) {
      return -1;
    }

    if (tr.date!.isBefore(acDateCreation) &&
        !Tools.areSameDay(tr.date!, acDateCreation)) {
      if (await updateFlaggedFullBalanceAccount(acID, -tr.amount,
              flagged: true, full: false) <=
          -1) {
        return -1;
      }
    } else {
      final int resB = await updateFlaggedFullBalanceAccount(acID, tr.amount,
          full: true, flagged: false);
      if (resB == -1) {
        return -1;
      }
    }

    // add Transactions to Account
    List<String> idList = <String>[];
    int i = 0;
    if (resAc.first[_acTrList].toString().isNotEmpty) {
      idList = resAc.first[_acTrList].toString().split(",");
      bool added = false;
      for (i = 0; i < idList.length && !added; i++) {
        Transactions? tr_ =
            await getTransactions(trID: int.parse(idList[i]), map: null);
        if (tr_ == null) {
          return -1;
        }

        // diff > 0 => tr.date after tr_.date (new Tr after old tr_)
        DateTime dateTr = DateTime(tr.date!.year, tr.date!.month, tr.date!.day);
        final Duration diff = tr.date!.difference(tr_.date!);
        // check if the DateTime nb of day between is less than one day and the date are equal in terms of day/month/year OR new date after date
        if (dateTr.toUtc().isAfter(tr_.date!.toUtc()) ||
            (diff.inDays < 1 &&
                Tools.areSameDay(dateTr.toUtc(), tr_.date!.toUtc()))) {
          idList.insert(i, tr.id.toString());
          if (i == idList.length - 1) {
            int bal =
                int.tryParse(resAc.first[_acInitialBalance].toString()) ?? 0;
            tr.acBalance = bal + tr.amount;
          } else {
            Map<String, Object?>? map = await getTransactionsMap(
                int.tryParse(idList[i + 1]) ?? -1,
                cols: [_trBalanceAcMoment]);
            if (map == null) {
              return -1;
            }
            tr.acBalance =
                int.tryParse(map[_trBalanceAcMoment].toString())! + tr.amount;
            if (await editTransactionAccountCurrentBalance(tr.id, tr.acBalance,
                    set: true, add: false) ==
                -1) {
              return -1;
            }
          }
          added = true;
        }
      }
      if (!added) {
        idList.add(tr.id.toString());
      }
    } else {
      idList.add(tr.id.toString());
    }

    // edit all other transactions which are after the new transactions (more recent)
    /*for (int j = 0; j < i - 1; j++) {
      if (await editTransactionAccountCurrentBalance(tr.id, tr.amount, set: false, add: true) ==
          -1) {
        print("An error occured");
      }
    }*/

    // edit tr list in account
    final res2 = await editTransactionsList(idList, acID);
    if (res2 == -1) {
      return -1;
    }

    return id;
  }

  Future<int> addTransactionsListToAccount(
      int acID, List<Transactions> trList) async {
    int res = 0, tmp;
    List<int> free = await getFreeRows(trList.length, _tbNameTransactions);
    int counter = 0;
    while (counter < free.length) {
      tmp = await addTransactionsToAccount(acID, trList[counter],
          freeRowID: free[counter]);
      if (res == 0) {
        res = tmp;
      }
      counter++;
    }

    while (counter < trList.length) {
      tmp = await addTransactionsToAccount(acID, trList[counter]);
      if (res == 0) {
        res = tmp;
      }
      counter++;
    }

    return res;
  }

  Future<List<int>> getFreeRows(int nb, String table) async {
    final Database db = await database;
    List<int> idList = [];
    List<Map<String, Object?>> res = await db.query(table,
        limit: nb, where: "$_used = ?", whereArgs: ["false"], columns: [_id]);

    idList.addAll(res.map((e) => int.tryParse(e[_id].toString())!));
    return idList;
  }

  Future<int> editTransactionAccountCurrentBalance(int trID, int balance,
      {required bool set, required bool add}) async {
    final Database db = await database;

    Map<String, Object?>? map =
        await getTransactionsMap(trID, cols: [_trBalanceAcMoment]);
    if (map == null) {
      return -1;
    }

    int newValue = 0;
    if (set && !add) {
      newValue = balance;
    } else if (!set && add) {
      final int? oldValue = int.tryParse(map[_trBalanceAcMoment].toString());
      if (oldValue == null) {
        return -1;
      }
      newValue = oldValue + balance;
    } else {
      return -1;
    }

    final int res = await db.update(
        _tbNameTransactions, {_trBalanceAcMoment: newValue},
        where: "$_id = ? AND $_used = ?", whereArgs: [trID, "true"]);
    return res == 0 ? -1 : 0;
  }

  Future<int> removeTransactionsOfAccount(int acID, int trID) async {
    final Database db = await database;

    Transactions? tr = await getTransactions(trID: trID, map: null);
    if (tr == null) {
      return -1;
    }

    Map<String, Object?>? mapAc = await getAccountMap(acID,
        cols: [_acTrList, _acFlaggedBalance, _acFullBalance, _acDateCreation]);
    if (mapAc == null) {
      return -1;
    }
    DateTime? acDateCreation =
        DateTime.tryParse(mapAc[_acDateCreation].toString());
    if (acDateCreation == null) {
      return -1;
    }

    bool found = false;
    List<String> idList = mapAc[_acTrList].toString().split(",");
    for (int i = 0; i < idList.length && !found; i++) {
      if (int.parse(idList[i]) == trID) {
        found = true;
        idList.removeAt(i);
      }
    }

    if (!found) {
      return -1;
    }

    final res = await db.update(_tbNameTransactions, {_used: "false"},
        where: "$_id = ? AND $_used = ?", whereArgs: [trID, "true"]);

    if (res == 0) {
      return -1;
    }

    int? flaggedBalance = int.tryParse(mapAc[_acFlaggedBalance].toString()),
        fullBalance = int.tryParse(mapAc[_acFullBalance].toString());
    if (fullBalance == null || flaggedBalance == null) {
      return -1;
    }

    Map<String, Object?> map = {};

    if (acDateCreation.isAfter(tr.date!) &&
        !Tools.areSameDay(acDateCreation, tr.date!)) {
      if (!tr.flagged) {
        map[_acFlaggedBalance] = flaggedBalance + tr.amount;
      }
    } else {
      map[_acFullBalance] = fullBalance - tr.amount;

      if (tr.flagged) {
        map[_acFlaggedBalance] = flaggedBalance - tr.amount;
      }
    }

    final resAC = await editTransactionsList(idList, acID, mapValues: map);
    return resAC <= -1 ? -1 : 0;
  }

  Future<int> editAccountBalanceFromTransactions(
      {required int acID,
      required bool flagged,
      required int oldAmount,
      required int newAmount,
      required DateTime accountCreationDate,
      required DateTime oldTransactionDate,
      required DateTime newTransactionDate}) async {
    Map<String, Object?>? mapAc =
        await getAccountMap(acID, cols: [_acFullBalance, _acFlaggedBalance]);
    if (mapAc == null) {
      return -1;
    }

    // oldDate ||| creationDate =|= newDate => oldDate is before creation and newDate is after or same date then creation
    if (accountCreationDate.isAfter(oldTransactionDate) &&
        !Tools.areSameDay(accountCreationDate, oldTransactionDate) &&
        (accountCreationDate.isBefore(newTransactionDate) ||
            Tools.areSameDay(accountCreationDate, newTransactionDate))) {
      // so add amount to full balance and to flagged balance, if same values
      if (oldAmount == newAmount) {
        return await updateFlaggedFullBalanceAccount(acID, oldAmount,
            flagged: true, full: true);
      } else {
        await updateFlaggedFullBalanceAccount(
            acID, oldAmount + (flagged ? (newAmount - oldAmount) : 0),
            flagged: true, full: false);
        return await updateFlaggedFullBalanceAccount(acID, newAmount,
            flagged: false, full: true);
      }
    }
    // newDate ||| creationDate =|= oldDate
    else if ((accountCreationDate.isBefore(oldTransactionDate) ||
            Tools.areSameDay(accountCreationDate, oldTransactionDate)) &&
        accountCreationDate.isAfter(newTransactionDate) &&
        !Tools.areSameDay(newTransactionDate, accountCreationDate)) {
      if (oldAmount == newAmount) {
        return await updateFlaggedFullBalanceAccount(acID, -oldAmount,
            full: true, flagged: true);
      } else {
        await updateFlaggedFullBalanceAccount(
            acID, flagged ? -oldAmount : -newAmount,
            flagged: true, full: false);
        return await updateFlaggedFullBalanceAccount(acID, -oldAmount,
            flagged: false, full: true);
      }
    } // createDate not between them
    else {
      int diff = newAmount - oldAmount;
      if (oldTransactionDate.isAfter(accountCreationDate) ||
          Tools.areSameDay(oldTransactionDate, accountCreationDate)) {
        await updateFlaggedFullBalanceAccount(acID, diff,
            flagged: flagged, full: true);
      } else {
        if (!flagged) {
          await updateFlaggedFullBalanceAccount(acID, -diff,
              flagged: true, full: false);
        }
      }
    }
    return 0;
  }

  String buildIdListStr(List<String> idList) {
    String strList = "";
    for (int i = 0; i < idList.length - 1; i++) {
      strList = "$strList${idList[i]},";
    }
    if (idList.isNotEmpty) {
      strList = "$strList${idList.last}";
    }
    return strList;
  }

  Future<int> editTransactionsList(List<String> idList, int acID,
      {bool check = false, Map<String, Object?>? mapValues}) async {
    final Database db = await database;
    if (!check) {
      final Map<String, Object?>? map = await getAccountMap(acID);
      if (map == null) {
        return -1;
      }
    }

    String strList = buildIdListStr(idList);
    mapValues ??= {};
    mapValues[_acTrList] = strList;

    final int res = await db.update(_tbNameAccounts, mapValues,
        where: "$_id = ? AND $_used = ?", whereArgs: [acID, "true"]);

    return res >= 1 ? 0 : -1;
  }

  Future<Map<String, Object?>?> getAccountMap(int acID,
      {List<String>? cols}) async {
    final Database db = await database;
    cols ??= ["*"];
    final List<Map<String, Object?>> res = await db.query(_tbNameAccounts,
        limit: 1,
        columns: cols,
        where: "$_id = ? AND $_used = ?",
        whereArgs: [acID, "true"]);
    return res.isEmpty ? null : res.first;
  }

  Future<int> setAccountInitialBalance(int acID, int balance) async {
    final Database db = await database;

    final Map<String, Object?>? map = await getAccountMap(acID,
        cols: [_acFullBalance, _acFlaggedBalance, _acInitialBalance]);
    if (map == null) {
      return -1;
    }

    int? initB = int.tryParse(map[_acInitialBalance].toString());
    int? fullB = int.tryParse(map[_acFullBalance].toString());
    int? flaggedB = int.tryParse(map[_acFlaggedBalance].toString());

    if (initB == null || fullB == null || flaggedB == null) {
      return -1;
    }

    int diff = balance - initB;

    int newFullB = fullB + diff;
    int newFlaggedBalance = flaggedB + diff;

    final int res = await db.update(
        _tbNameAccounts,
        {
          _acInitialBalance: balance.toString(),
          _acFullBalance: newFullB,
          _acFlaggedBalance: newFlaggedBalance
        },
        where: "$_id = ? AND $_used = ?",
        whereArgs: [acID, "true"]);

    if (res == 0) {
      return -1;
    }

    return 0;
  }

  Future<Account?> getAccount(int acID,
      {bool haveToGetTrList = false,
      bool haveToGetDueList = false,
      List<Map<String, Object?>>? map,
      BoolPointer? updated,
      int? nbTr}) async {
    final db = await database;

    map ??= await db.query(_tbNameAccounts,
        limit: 1,
        columns: ["*"],
        where: "$_id = ? AND $_used = ?",
        whereArgs: [acID.toString(), "true"]);

    if (map.isEmpty) {
      return null;
    }

    Account? ac = Account.fromMap(map.first);
    if (ac == null) {
      return null;
    }

    ac.setTransactionListDateSorted(haveToGetTrList
        ? await getTransactionList(
            map.first[_acTrList].toString().split(","), nbTr ?? nth, acID)
        : []);
    //int.parse(map.first[_acNthTr].toString())

    bool ret = await ac.setDueList(
        haveToGetDueList
            ? await getDueList(map.first[_acDueList].toString().split(","))
            : [],
        this);

    if (updated != null) {
      updated.i = ret;
    }

    return ac;
  }

  Future<int> setTransactionsFlagged(Transactions tr, int acID) async {
    final Database db = await database;

    List<Map<String, Object?>> res = await db.query(_tbNameTransactions,
        limit: 1,
        columns: [_id],
        where: "$_used = ? AND $_id = ?",
        whereArgs: ["true", tr.id]);

    Map<String, Object?>? map =
        await getAccountMap(acID, cols: [_acFlaggedBalance]);
    if (map == null) {
      return -1;
    }

    final int? flaggedBalance = int.tryParse(map[_acFlaggedBalance].toString());
    if (flaggedBalance == null) {
      return -1;
    }

    if (res.isEmpty) {
      return -1;
    }

    if (await db.update(
            _tbNameTransactions, {_trFlagged: tr.flagged.toString()},
            where: "$_used = ? AND $_id = ?", whereArgs: ["true", tr.id]) ==
        0) {
      return -1;
    }

    final int coef = tr.flagged ? 1 : -1;

    if (await db.update(_tbNameAccounts,
            {_acFlaggedBalance: flaggedBalance + tr.amount * coef},
            where: "$_used = ? AND $_id = ?", whereArgs: ["true", acID]) ==
        0) {
      return -1;
    }

    return 0;
  }

  /// return -1 in case of an error
  Future<int> setAccountSelected(Account ac, bool selected) async {
    final Database db = await database;
    List<Map<String, Object?>> res = await db.query(_tbNameAccounts,
        columns: [_acSelected],
        where: "$_id = ? AND $_used = ?",
        whereArgs: [ac.id, "true"],
        limit: 1);

    if (res.isEmpty) {
      return -1;
    }

    final int r = await db.update(
        _tbNameAccounts, {_acSelected: selected.toString()},
        where: "$_id = ? AND $_used = ?", whereArgs: [ac.id, "true"]);

    return r == 0 ? -1 : 0;
  }

  Future<int> setFavorite(int acID, bool favorite) async {
    final Database db = await database;

    Map<String, Object?>? mapAc = await getAccountMap(acID);
    if (mapAc == null) {
      return -1;
    }

    final res = await db.update(
        _tbNameAccounts, {_acFavorite: favorite.toString()},
        where: "$_used = ? AND $_id = ?", whereArgs: ["true", acID]);

    return res == 0 ? -1 : 0;
  }

  Future<int> editTransaction(
      {required int trID,
      required int newAmount,
      required DateTime newDate,
      required Outsider? outsider,
      required int acID,
      required bool flagged,
      required int oldAmount,
      required DateTime oldDate,
      required String? comment}) async {
    final Database db = await database;
    Map<String, Object?>? map = await getTransactionsMap(trID, cols: [_id]);
    if (map == null) {
      return -1;
    }

    Map<String, Object?>? mapA =
        await getAccountMap(acID, cols: [_id, _acDateCreation]);
    if (mapA == null) {
      return -1;
    }
    DateTime? creationDate =
        DateTime.tryParse(mapA[_acDateCreation].toString());
    if (creationDate == null) {
      return -1;
    }

    Map<String, String> m = {};
    bool sameMoment = newDate.isAtSameMomentAs(oldDate);
    if (newAmount != oldAmount || !sameMoment) {
      if (!sameMoment) {
        m[_trDOM] = newDate.day.toString();
        m[_trMonth] = newDate.month.toString();
        m[_trYear] = newDate.year.toString();
      }
      if (await editAccountBalanceFromTransactions(
              acID: acID,
              flagged: flagged,
              oldAmount: oldAmount,
              newAmount: newAmount,
              accountCreationDate: creationDate,
              oldTransactionDate: oldDate,
              newTransactionDate: newDate) ==
          -1) {
        return -1;
      }
      m[_trAmount] = newAmount.toString();
    }

    if (outsider != null) {
      Outsider? o = await getOutsiderFromName(outsider.name);
      if (o == null) {
        o = await insertOutsider(outsider);
        if (o == null) {
          return -1;
        }
      }
      m[_trOutsiderID] = o.id.toString();
    }

    if (comment != null) {
      m[_comment] = comment;
    }

    if (m.isEmpty) {
      return 0;
    }

    await db.update(_tbNameTransactions, m,
        where: "$_used = ? AND $_id = ?", whereArgs: ["true", trID]);

    return 0;
  }

  /// return id of the new due added
  /// on error -1 is returned
  Future<int> addDueToDB(int acID, List<Map<String, Object?>> mapSpaceList,
      Map<String, String> dueMap, String outsiderName) async {
    final Database db = await database;

    Outsider? o = await getOutsiderFromName(outsiderName);
    if (o == null) {
      o = await insertOutsider(Outsider(0, outsiderName));
      if (o == null) {
        return -1;
      }
    }

    dueMap[_deOutsiderID] = o.id.toString();

    final int res;
    final int? dueID;
    dueMap[_deAccountID] = acID.toString();
    dueMap[_used] = "true";
    if (mapSpaceList.isEmpty) {
      res = await db.insert(_tbNameDue, dueMap);
      dueID = res;
    } else {
      dueID = int.tryParse(mapSpaceList.first[_id].toString());
      if (dueID == null) {
        return -1;
      }
      res = await db.update(_tbNameDue, dueMap,
          where: "$_id = ? AND $_used = ?",
          whereArgs: [dueID.toString(), "false"]);
    }
    return res == 0 ? -1 : dueID;
  }

  /// return id of the new due added
  /// on error -1 is returned
  Future<int> addDueToAccount(
      int acID, Map<String, String> dueMap, String outsiderName) async {
    final Database db = await database;

    Map<String, Object?>? acMap = await getAccountMap(acID, cols: [_acDueList]);
    if (acMap == null) {
      return -1;
    }

    // get free spaces
    final List<Map<String, Object?>> resSpace = await db.query(_tbNameDue,
        columns: [_id], where: "$_used = ?", whereArgs: ["false"]);

    // add / update Due
    final int dueID = await addDueToDB(acID, resSpace, dueMap, outsiderName);
    if (dueID <= -1) {
      return -1;
    }

    // update idList locally
    List<String> idList = [];
    if (acMap[_acDueList].toString().isNotEmpty) {
      idList = acMap[_acDueList].toString().split(",");
    }
    idList.add(dueID.toString());

    String idListStr = buildIdListStr(idList);
    // update id List in db
    final r = await db.update(_tbNameAccounts, {_acDueList: idListStr},
        where: "$_used = ? AND $_id = ?", whereArgs: ["true", acID]);

    return r == 0 ? -1 : dueID;
  }

  Future<int> addDueOnceToAccount(int acID, DueOnce due) async {
    return addDueToAccount(acID, due.toJsonForDB(), due.outsider!.name);
  }

  Future<int> addDuePeriodicToAccount(int acID, Periodic due) async {
    return addDueToAccount(acID, due.toJsonForDB(), due.outsider!.name);
  }

  Future<int> removeDueOfAccount(int dueID, int acID) async {
    final Database db = await database;
    Map<String, Object?>? res = await getAccountMap(acID, cols: [_acDueList]);
    if (res == null) {
      return -1;
    }

    List<String> newIDList = res[_acDueList].toString().split(",");
    newIDList.removeWhere((String e) => e.isEmpty || e == dueID.toString());

    String strBuild = buildIdListStr(newIDList);

    // update accounts
    final int r = await db.update(_tbNameAccounts, {_acDueList: strBuild},
        where: "$_used = ? AND $_id = ?", whereArgs: ["true", acID]);
    if (r == 0) {
      return -1;
    }

    // update due
    final int r1 = await db.update(_tbNameDue, {_used: "false"},
        where: "$_used = ? AND $_id = ?", whereArgs: ["true", dueID]);

    return r1 == 0 ? -1 : 0;
  }

  Future<int> editDue(Due newDue, Due initialDue) async {
    int res = -1;
    // outsider updated
    if (!newDue.outsider!.areSame(initialDue.outsider!)) {
      Outsider? o = await manageOutsider(outsider: newDue.outsider!, oID: null);
      if (o == null) {
        return -1;
      }
      newDue.outsider = o;
      initialDue.outsider = o;
    }

    if ((newDue is DueOnce && initialDue is DueOnce)) {
      //await newDue.buildComparativeMap(initialDue);
      res = await updateDueOnce(newDue, map: newDue.toJsonForDB());
    } else if ((newDue is Periodic && initialDue is Periodic)) {
      res = await updatePeriodic(newDue, map: newDue.toJsonForDB());
    } else if (initialDue is Periodic && newDue is DueOnce) {
      res =
          await convertPeriodicToDueOnce(initialDue, newDue.actionDate) == null
              ? -1
              : 0;
    } else if (initialDue is DueOnce && newDue is Periodic) {
      res = await convertDueOnceToPeriodic(
                  initialDue, newDue.referenceDate!, newDue.period) ==
              null
          ? -1
          : 0;
    }
    return res;
  }

  Future<int> updateDue(Map<String, Object> map, int dueID) async {
    final Database db = await database;

    final res = await db.update(_tbNameDue, map,
        where: "$_used = ? AND $_id = ?", whereArgs: ["true", dueID]);
    return res == 0 ? -1 : 0;
  }

  Future<int> updateDueOnce(DueOnce dueOnce, {Map<String, Object>? map}) async {
    return await updateDue(map ?? dueOnce.toJsonForDB(), dueOnce.id);
  }

  Future<int> updatePeriodic(Periodic periodic,
      {Map<String, Object>? map}) async {
    return await updateDue(map ?? periodic.toJsonForDB(), periodic.id);
  }

  /// convert a Periodic to a DueOnce
  /// this conversion updates the database
  /// The given outsider IS NOT updated
  Future<DueOnce?> convertPeriodicToDueOnce(
      Periodic periodic, DateTime actionDate) async {
    DueOnce dueOnce =
        DueOnce(periodic.id, periodic.amount, periodic.outsider, actionDate);
    if (await updateDueOnce(dueOnce) == -1) {
      return null;
    }
    return dueOnce;
  }

  /// convert a DueOnce to a Periodic
  /// this conversion updates the database
  /// The given outsider IS NOT updated
  Future<Periodic?> convertDueOnceToPeriodic(
      DueOnce dueOnce, DateTime referenceDate, Period period) async {
    Periodic periodic = Periodic(dueOnce.id, dueOnce.amount, dueOnce.outsider,
        referenceDate, referenceDate, period);
    if (await updatePeriodic(periodic) == -1) {
      return null;
    }
    return periodic;
  }

  Future<List<Outsider>> getAllOutsider() async {
    final Database db = await database;
    List<Map<String, Object?>> res = await db.query(_tbNameOutsiders,
        columns: ["*"], where: "$_used = ?", whereArgs: ["true"]);

    List<Outsider> oList = [];
    for (var map in res) {
      Outsider? o = Outsider.fromMap(map);
      if (o != null) {
        oList.add(o);
      }
    }

    return oList;
  }

  /// map the new Outsider [newO] and update the values that the id of the old Outsider [oldO] is linked to
  /// return -1 in error and 0 on success
  Future<int> updateOutsider(Outsider oldO, Outsider newO) async =>
      (await (await database).update(_tbNameOutsiders, newO.toMapForDB(),
                  where: "$_used = ? AND $_outsiderName = ?",
                  whereArgs: ["true", oldO.name])) ==
              0
          ? -1
          : 0;

  Future<int> setAccountDesignation(int id, String newAccountName) async {
    final Database db = await database;
    final res = await getAccountMap(id, cols: [_acDesignation]);
    if (res == null) {
      return -1;
    }

    final r = await db.update(_tbNameAccounts, {_acDesignation: newAccountName},
        where: "$_used = ? AND $_id = ?", whereArgs: ["true", id]);

    return r == 0 ? -1 : 0;
  }

  Future<int> setAccountCreationDate(int id, DateTime newDate) async {
    final Database db = await database;
    final res = await getAccountMap(id, cols: [_acDateCreation, _acTrList]);
    if (res == null) {
      return -1;
    }

    DateTime? oldDate = DateTime.tryParse(res[_acDateCreation].toString());
    if (oldDate == null) {
      return -1;
    }

    final r = await db.update(
        _tbNameAccounts, {_acDateCreation: newDate.toString()},
        where: "$_used = ? AND $_id = ?", whereArgs: ["true", id]);
    if (r == 0) {
      return -1;
    }

    // get all transactions
    List<Transactions> trList = await getTransactionList(
        res[_acTrList].toString().split(','), null, id);

    if (Tools.areSameDay(newDate, oldDate)) {
      return 0;
    }

    if (newDate.isBefore(oldDate)) {
      for (Transactions tr in trList) {
        DateTime d = tr.date!;
        // between the two new dates, that will impact the balance of the account
        if ((d.isAfter(newDate) &&
                d.isBefore(oldDate) &&
                !Tools.areSameDay(d, oldDate)) ||
            Tools.areSameDay(d, newDate)) {
          final resAc = await getAccountMap(id,
              cols: [_acFullBalance, _acFlaggedBalance]);
          if (resAc == null) {
            return -1;
          }
          int? fullBalance = int.tryParse(resAc[_acFullBalance].toString()),
              flaggedBalance =
                  int.tryParse(resAc[_acFlaggedBalance].toString());
          if (fullBalance == null || flaggedBalance == null) {
            return -1;
          }

          final res2 = await db.update(
              _tbNameAccounts,
              {
                _acFullBalance: fullBalance + tr.amount,
                _acFlaggedBalance: flaggedBalance + tr.amount
              },
              where: "$_used = ? AND $_id = ?",
              whereArgs: ["true", id]);
          if (res2 == 0) {
            return -1;
          }
        }
      }
    } else {
      for (Transactions tr in trList) {
        DateTime d = tr.date!;
        // between the two new dates, that will impact the balance of the account
        if ((d.isAfter(oldDate) &&
                d.isBefore(newDate) &&
                !Tools.areSameDay(d, newDate)) ||
            Tools.areSameDay(d, oldDate)) {
          final resAc = await getAccountMap(id,
              cols: [_acFullBalance, _acFlaggedBalance]);
          if (resAc == null) {
            return -1;
          }
          int? fullBalance = int.tryParse(resAc[_acFullBalance].toString()),
              flaggedBalance =
                  int.tryParse(resAc[_acFlaggedBalance].toString());
          if (fullBalance == null || flaggedBalance == null) {
            return -1;
          }

          final res2 = await db.update(
              _tbNameAccounts,
              {
                _acFullBalance: fullBalance - tr.amount,
                _acFlaggedBalance: flaggedBalance - tr.amount
              },
              where: "$_used = ? AND $_id = ?",
              whereArgs: ["true", id]);
          if (res2 == 0) {
            return -1;
          }
        }
      }
    }
    return 0;
  }

  Future<int> removeAccount(int acID) async {
    final Database db = await database;
    final Map<String, Object?>? res =
        await getAccountMap(acID, cols: [_acDueList, _acTrList]);
    if (res == null) {
      return -1;
    }

    // remove all transactions
    await db.update(_tbNameTransactions, {_used: "false"},
        where: "$_used = ? AND $_trAccountID = ?", whereArgs: ["true", acID]);

    await db.update(_tbNameDue, {_used: "false"},
        where: "$_used = ? AND $_deAccountID= ?", whereArgs: ["true", acID]);

    final res3 = await db.update(_tbNameAccounts, {_used: "false"},
        where: "$_used = ? AND $_id = ?", whereArgs: ["true", acID]);

    return res3 == 0 ? -1 : 0;
  }

// return -1 en cas de failure, -2 en cas d'existence du tiers, et 0 en cas de succès
  Future<int> removeOutsider(int outsiderID) async {
    final Database db = await database;

    final res = await db.query(_tbNameTransactions,
        limit: 1,
        columns: [_id],
        where: "$_used = ? AND $_trOutsiderID = ?",
        whereArgs: ["true", outsiderID]);

    if (res.isNotEmpty) {
      return -2;
    }

    return (await db.update(_tbNameOutsiders, {_used: 'false'},
                where: "$_used = ? AND $_id = ?",
                whereArgs: ['true', outsiderID])) >=
            1
        ? 0
        : -1;
  }

  Future<List<int>> getAllOutsiderIdUsed() async {
    final Database db = await database;
    List<int?> res = (await db.query(_tbNameTransactions,
            distinct: true,
            columns: [_trOutsiderID],
            where: "$_used = ?",
            whereArgs: ["true"]))
        .map<int?>((e) => int.tryParse(e[_trOutsiderID].toString()))
        .toList();
    res.addAll((await db.query(_tbNameDue,
            distinct: true,
            columns: [_deOutsiderID],
            where: "$_used = ?",
            whereArgs: ["true"]))
        .map<int?>((e) => int.tryParse(e[_deOutsiderID].toString())));
    return Tools.nullFilter(res.toSet().toList());
  }

  Future<int> updateFlaggedFullBalanceAccount(int acID, int amount,
      {bool set = false, required bool flagged, required bool full}) async {
    final Database db = await database;
    final res =
        await getAccountMap(acID, cols: [_acFullBalance, _acFlaggedBalance]);
    if (res == null) {
      return -1;
    }
    Map<String, Object> map = {};

    if (full) {
      int? fullBalance = int.tryParse(res[_acFullBalance].toString());
      if (fullBalance == null) {
        return -2;
      }
      map[_acFullBalance] = fullBalance + amount;
    }

    if (flagged) {
      int? flaggedBalance = int.tryParse(res[_acFlaggedBalance].toString());
      if (flaggedBalance == null) {
        return -2;
      }
      map[_acFlaggedBalance] = flaggedBalance + amount;
    }

    return (await db.update(_tbNameAccounts, map,
                where: "$_id = ? AND $_used = ?", whereArgs: [acID, "true"])) ==
            0
        ? -3
        : 0;
  }

  Future<int?> getIdOfSelectedAccount() async {
    final Database db = await database;
    List<Map<String, Object?>> res = await db.query(_tbNameAccounts,
        where: "$_used = ? AND $_acSelected = ?",
        whereArgs: ["true", "true"],
        columns: [_id],
        limit: 1);
    if (res.isEmpty) {
      return null;
    }

    return int.tryParse(res.first[_id].toString());
  }
}
