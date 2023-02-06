import 'dart:async';

import 'package:money_for_mima/models/account.dart';
import 'package:money_for_mima/models/due.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/models/transactions.dart';
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
  final String _acActualBalance = "balance";
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

  // Due (Écheance/ Occurence)
  final String _deAmount = "amount";
  final String _deCreationDate = "date";
  final String _deType = "type"; // Periodic / DueOnce
  final String _deJsonClass = "jsonClass";
  final String _deAccountID = "accountID";

  late Future<Database> database;
  bool _initDone = false;

  Future<void> init() async {
    database = openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      join(await getDatabasesPath(), 'money_for_mima_DB.db'),
      // When the database is first created, create a table to store dogs.
      onCreate: (db, version) => createDb(db),
      version: 1,
    );
    _initDone = true;
  }

  void createDb(Database db) {
    String createTB = "CREATE TABLE IF NOT EXISTS";
    String idColDef = "INTEGER PRIMARY KEY AUTOINCREMENT";
    db.execute(
        '$createTB $_tbNameOutsiders($_id $idColDef, $_used TEXT, $_outsiderName TEXT, $_comment TEXT);');
    db.execute(
        '$createTB $_tbNameAccounts($_id $idColDef, $_used TEXT, $_acDesignation TEXT, $_acActualBalance REAL, $_acFavorite TEXT, $_acInitialBalance REAL, $_acDueList TEXT, $_acTrList TEXT, $_acNthTr TEXT, $_comment TEXT, $_acSelected TEXT, $_acDateCreation TEXT);');
    db.execute(
        "$createTB $_tbNameTransactions($_id $idColDef, $_used TEXT, $_trAmount READ, $_trYear INT, $_trMonth INT, $_trDOM INT, $_trOutsiderID INTEGER, $_trFlagged TEXT, $_trDueID REAL, $_comment TEXT, $_trAccountID INTEGER)");
    db.execute(
        '$createTB $_tbNameDue($_id $idColDef, $_used TEXT, $_deAmount REAL, $_deCreationDate TEXT, $_deType TEXT, $_deJsonClass TEXT, $_comment TEXT, $_deAccountID INTEGER);');
  }

  Future<bool> initDone() async {
    return _initDone;
  }

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

  Future<Account> addAccount(String name, double initBalance, String comment,
      DateTime creationDate) async {
    Account ac = Account(
        -1, name, initBalance, initBalance, false, [], [], true,
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

  Future<Due?> getDue(int dueID) async {
    final db = await database;

    List<Map<String, Object?>> res = await db.query(_tbNameDue,
        limit: 1,
        where: "$_used = ? AND $_id = ?",
        whereArgs: ["true", dueID],
        columns: ["*"]);
    if (res.isEmpty) {
      return null;
    }

    return Due.fromMap(res.first);
  }

  // get outsider from Name
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

  Future<Transactions?> getTransactions(int trID,
      {Map<String, Object?>? map}) async {
    final Database db = await database;
    if (map == null) {
      List<Map<String, Object?>> res = await db.query(_tbNameTransactions,
          limit: 1,
          where: "$_used = ? AND $_id = ?",
          whereArgs: ["true", trID],
          columns: ["*"]);

      if (res.isEmpty) {
        return null;
      }
      map = res.first;
    }

    Transactions? tr = Transactions.fromMap(map);
    if (tr == null) {
      return null;
    }

    tr.outsider =
        await getOutsiderFromID(int.parse(map[_trOutsiderID].toString()));
    return tr;
  }

  Future<List<Account>> getAllAccounts() async {
    List<Account> acL = [];
    final Database db = await database;

    List<Map<String, Object?>> allList = await db.query(_tbNameAccounts,
        columns: ["*"], where: "$_used = ?", whereArgs: ["true"]);

    for (var map in allList) {
      Account? ac = Account.fromMap(map);
      if (ac != null) {
        acL.add(ac);
      }
    }

    return acL;
  }

  Future<List<Transactions>> getTransactionList(
      String strList, int nb, int acID) async {
    List<Transactions> trList = [];
    final db = await database;

    // get all tr un-flagged related to the account
    List<Map<String, Object?>> res = await db.query(_tbNameTransactions,
        where: "$_used = ? AND $_trFlagged = ? AND $_trAccountID = ?",
        whereArgs: ["true", "false", acID],
        columns: ["*"]);

    // construct list of tr
    for (var map in res) {
      Transactions? tr_ =
          await getTransactions(int.parse(map[_id].toString()), map: map);
      if (tr_ == null) {
        continue;
      }
      trList.add(tr_);
    }

    return trList;
  }

  Future<List<Due>> getDueList(String strList, int acID) async {
    List<Due> dueList = [];
    final Database db = await database;

    List<Map<String, Object?>> res = await db.query(_tbNameTransactions,
        columns: ["*"],
        where: "$_used = ? AND $_deAccountID = ?",
        whereArgs: ["true", acID]);

    for (var map in res) {
      Due? due = Due.fromMap(map);
      if (due == null) {
        continue;
      }

      dueList.add(due);
    }

    return dueList;
  }

  /*
  return id of tr
  -1 -> error*/
  Future<int> addTransactionsToAccount(int acID, Transactions tr) async {
    final Database db = await database;

    // verify that the account related to the tr exists and get list of item
    final List<Map<String, Object?>> resAc = await db.query(_tbNameAccounts,
        limit: 1,
        where: "$_used = ? AND $_id = ?",
        whereArgs: ["true", acID],
        columns: [_acTrList]);
    if (resAc.isEmpty) {
      return -1;
    }

    // check there is an empty row
    final List<Map<String, Object?>> resTr = await db.query(_tbNameTransactions,
        columns: [_id], where: "$_used = ?", whereArgs: ["false"], limit: 1);

    final int id;

    // manage outsider
    Outsider? o = await getOutsiderFromName(tr.outsider!.name);
    o ??= await insertOutsider(tr.outsider!);
    if (o == null) {
      return -1;
    }

    tr.outsider = o;

    Map<String, Object?> trMap = tr.toMapForDB();

    // add accountID
    trMap[_trAccountID] = acID.toString();

    if (resTr.isEmpty) {
      // no space available add one line
      id = await db.insert(_tbNameTransactions, trMap);
    } else {
      // update an empty line
      id = int.parse(resTr.first[_id].toString());
      await db.update(_tbNameTransactions, trMap,
          where: "$_id = ? AND $_used = ?", whereArgs: [id, "false"]);
    }
    tr.id = id;
    final int resB = await addAccountCurrentBalance(acID, tr.amount);
    if (resB == -1) {
      return -1;
    }
    return id;
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

  Future<int> addAccountCurrentBalance(int acID, double balance) async {
    final Database db = await database;

    final Map<String, Object?>? map =
        await getAccountMap(acID, cols: [_acActualBalance]);
    if (map == null) {
      return -1;
    }

    final double newBalance =
        double.parse(map[_acActualBalance].toString()) + balance;

    final int res = await db.update(
        _tbNameAccounts, {_acActualBalance: newBalance},
        where: "$_id = ? AND $_used = ?", whereArgs: [acID, "true"]);

    if (res == 0) {
      return -1;
    }

    return 0;
  }

  Future<int> setAccountInitialBalance(int acID, double balance) async {
    final Database db = await database;

    final Map<String, Object?>? map =
        await getAccountMap(acID, cols: [_acActualBalance]);
    if (map == null) {
      return -1;
    }

    final int res = await db.update(
        _tbNameAccounts, {_acInitialBalance: balance.toString()},
        where: "$_id = ? AND $_used = ?", whereArgs: [acID, "true"]);

    return 0;
  }

  Future<Account?> getAccount(int acID) async {
    final db = await database;

    List<Map<String, Object?>> res = await db.query(_tbNameAccounts,
        limit: 1,
        columns: ["*"],
        where: "$_id = ? AND $_used = ?",
        whereArgs: [acID.toString(), "true"]);

    if (res.isEmpty) {
      return null;
    }

    Account? ac_ = Account.fromMap(res.first);
    if (ac_ == null) {
      return null;
    }

    Account ac = ac_;
    ac.transactionsList = await getTransactionList(
        res.first[_acTrList].toString(),
        int.parse(res.first[_acNthTr].toString()),
        acID);
    ac.dueList = await getDueList(res.first[_acDueList].toString(), acID);

    return ac;
  }

  Future<int> setTransactionsFlagged(Transactions tr) async {
    final Database db = await database;

    List<Map<String, Object?>> res = await db.query(_tbNameTransactions,
        limit: 1,
        columns: [_id],
        where: "$_used = ? AND $_id = ?",
        whereArgs: ["true", tr.id]);

    if (res.isEmpty) {
      return -1;
    }

    final int updated = await db
        .update(_tbNameTransactions, {_trFlagged: tr.flagged.toString()});
    if (updated == 0) {
      return -1;
    }
    return 0;
  }

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

    if (r == 0) {
      return -1;
    }

    return 0;
  }
}
