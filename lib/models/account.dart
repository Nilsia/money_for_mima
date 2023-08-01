import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/due.dart';
import 'package:money_for_mima/models/table_sort_item.dart';
import 'package:money_for_mima/models/transactions.dart';
import 'package:money_for_mima/utils/tools.dart';

class Account {
  int id;
  String designation, comment;
  bool onlyNth = true, generatedFastly = false, selected;
  bool favorite;
  double fullBalance, initialBalance, flaggedBalance;
  List<Transactions> _currentTransactionsList, _fullTransactionList = [];
  Map<String, List<Transactions>> trListMap = {};
  List<Due> _dueList;
  DateTime? creationDate;

  final String _dateFlaggedKey = "dateFlagged",
      _dateUnFlaggedKey = "dateUnFlagged",
      _dateAllKey = "dateAll",
      _amountFlaggedKey = "amountFlagged",
      _amountUnFlaggedKey = "amountUnFlagged",
      _amountAllKey = "amountAll",
      _outsiderFlaggedKey = "outsiderFlagged",
      _outsiderUnFlaggedKey = "outsiderUnFlagged",
      _outsiderAllKey = "outsiderAll";

  Account(
      this.id,
      this.designation,
      this.fullBalance,
      this.initialBalance,
      this.flaggedBalance,
      this.favorite,
      this._currentTransactionsList,
      this._dueList,
      this.selected,
      {this.onlyNth = true,
      this.generatedFastly = false,
      this.comment = "",
      this.creationDate}) {
    creationDate ??= DateTime.now();
    //generateOtherLists();
  }

  Account.none(this._currentTransactionsList, this._dueList,
      {this.id = -1,
      this.designation = "",
      this.fullBalance = 0,
      this.initialBalance = 0,
      this.flaggedBalance = 0,
      this.favorite = false,
      this.selected = false,
      this.onlyNth = true,
      this.generatedFastly = false,
      this.comment = "",
      this.creationDate});

  void setTransactionListDateSorted(List<Transactions> l) {
    _currentTransactionsList = l;
    _fullTransactionList = l;
    _buildSortedListTransactions(_dateAllKey,
        compare: isBeforeByDate, reversed: true, all: true, flagged: true);
  }

  void _buildSortedListTransactions(String key,
      {required bool Function(Transactions, Transactions) compare,
      required bool reversed,
      required bool all,
      required bool flagged}) {
    if (trListMap.containsKey(key)) {
      _currentTransactionsList =
          reversed ? trListMap[key]!.reversed.toList() : trListMap[key]!;
      return;
    }
    // sort now

    List<Transactions> trList =
        copyTransactionsList(all: all, flagged: flagged);
    for (int i = 1; i < trList.length; i++) {
      if (!compare(trList[i - 1], trList[i])) {
        int j = i - 2;
        Transactions save = trList[i];
        trList[i] = trList[i - 1];
        while (j >= 0 && compare(save, trList[j])) {
          trList[j + 1] = trList[j];
          j--;
        }
        trList[j + 1] = save;
      }
    }
    _currentTransactionsList = reversed ? trList.reversed.toList() : trList;
    trListMap[key] = getCurrentTransactionList();
  }

  List<Transactions> copyTransactionsList(
      {required bool all, required bool flagged}) {
    List<Transactions> trList = [];
    for (Transactions tr in _fullTransactionList) {
      if (all || tr.flagged == flagged) {
        trList.add(tr);
      }
    }
    return trList;
  }

  // sorted by date growing
  bool isBeforeByDate(Transactions tr1, Transactions tr2) {
    return tr1.date!.isBefore(tr2.date!);
  }

  // sorted by amount growing
  bool isMoreByAmount(Transactions tr1, Transactions tr2) {
    return tr1.amount > tr2.amount;
  }

  // sorted by alphabet
  bool isBeforeByOutsider(Transactions tr1, Transactions tr2) {
    return tr1.outsider!.name.compareTo(tr2.outsider!.name) < 0;
  }

  void updateTransactionsList(SortAction sortAction, String col,
      {required bool reversed}) {
    switch (sortAction) {
      case SortAction.allTransactions:
        switch (col) {
          case "date":
            _buildSortedListTransactions(_dateAllKey,
                compare: isBeforeByDate,
                reversed: reversed,
                all: true,
                flagged: true);
            break;
          case "outsider":
            _buildSortedListTransactions(_outsiderAllKey,
                compare: isBeforeByOutsider,
                reversed: reversed,
                all: true,
                flagged: true);
            break;
          case "amount":
            _buildSortedListTransactions(_amountAllKey,
                compare: isMoreByAmount,
                reversed: reversed,
                all: true,
                flagged: true);
        }
        break;
      case SortAction.flaggedTransactions:
        switch (col) {
          case "date":
            _buildSortedListTransactions(_dateFlaggedKey,
                compare: isBeforeByDate,
                reversed: reversed,
                all: false,
                flagged: true);
            break;
          case "outsider":
            _buildSortedListTransactions(_outsiderFlaggedKey,
                compare: isBeforeByOutsider,
                reversed: reversed,
                all: false,
                flagged: true);
            break;
          case "amount":
            _buildSortedListTransactions(_amountFlaggedKey,
                compare: isMoreByAmount,
                reversed: reversed,
                all: false,
                flagged: true);
        }
        break;
      case SortAction.unFlaggedTransactions:
        switch (col) {
          case "date":
            _buildSortedListTransactions(_dateUnFlaggedKey,
                compare: isBeforeByDate,
                reversed: reversed,
                all: false,
                flagged: false);
            break;
          case "outsider":
            _buildSortedListTransactions(_outsiderUnFlaggedKey,
                compare: isBeforeByOutsider,
                reversed: reversed,
                all: false,
                flagged: false);
            break;
          case "amount":
            _buildSortedListTransactions(_amountUnFlaggedKey,
                compare: isMoreByAmount,
                reversed: reversed,
                all: false,
                flagged: false);
        }
    }
  }

  List<Transactions> getCurrentTransactionList() => _currentTransactionsList;

  Map<String, String> toMapForDB() => {
        "used": "true",
        "fullBalance": fullBalance.toString(),
        "flaggedBalance": flaggedBalance.toString(),
        "initBalance": initialBalance.toString(),
        "favorite": favorite.toString(),
        "dueList": "",
        "transactionsList": "",
        "nth_transactions": "20",
        "comment": comment,
        "selected": selected.toString(),
        "dateCreation": creationDate.toString(),
        "designation": designation,
      };

  static Account? fromMap(Map<String, Object?> map) {
    Account ac = Account.none([], []);
    if (map.containsKey("id")) {
      ac.id = int.parse(map["id"].toString());
    } else {
      return null;
    }

    if (map.containsKey("designation")) {
      ac.designation = map["designation"].toString();
    } else {
      return null;
    }
    if (map.containsKey("favorite")) {
      ac.favorite = Tools.stringToBool(map["favorite"].toString());
    } else {
      ac.favorite = false;
    }

    if (map.containsKey("initBalance")) {
      try {
        ac.initialBalance = double.parse(map["initBalance"].toString());
      } catch (e) {
        return null;
      }
    } else {
      return null;
    }

    if (map.containsKey("fullBalance")) {
      try {
        ac.fullBalance = double.parse(map["fullBalance"].toString());
      } catch (e) {
        return null;
      }
    } else {
      return null;
    }

    if (map.containsKey("flaggedBalance")) {
      try {
        ac.flaggedBalance = double.parse(map["flaggedBalance"].toString());
      } catch (e) {
        return null;
      }
    } else {
      return null;
    }

    if (map.containsKey("dueList")) {
      ac._dueList = [];
    } else {
      ac._dueList = [];
    }

    /* if (map.containsKey("transactionsList")) {
      ac.setTransactionListDateSorted([]);
    } else {
      ac.setTransactionListDateSorted([]);
    } */

    if (map.containsKey("comment")) {
      ac.comment = map["comment"].toString();
    } else {
      ac.comment = "";
    }

    if (map.containsKey("selected")) {
      ac.selected = Tools.stringToBool(map["selected"].toString());
    } else {
      ac.selected = false;
    }

    if (map.containsKey("dateCreation")) {
      ac.creationDate = DateTime.parse(map["dateCreation"].toString());
    } else {
      ac.creationDate = DateTime.now();
    }

    return ac;
  }

  @override
  String toString() {
    return "Account(id: $id, designation: $designation, balance: $fullBalance, creationDate: ${creationDate.toString()})";
  }

  /// return -1 in case of an error
  Future<int> setSelectionDB(DatabaseManager db, bool selected) async {
    if (selected == this.selected) {
      return 0;
    }

    final int res = await db.setAccountSelected(this, selected);
    if (res >= 0) {
      this.selected = selected;
    }
    return res;
  }

  bool isNone() {
    return designation.isEmpty;
  }

  void switchSelected() {
    selected = !selected;
  }

  /// return -1 in case of an error
  /// return 0 if successful
  /// return 1 if it is same value
  Future<int> setFavoriteDB(DatabaseManager db, bool favorite) async {
    if (favorite == this.favorite) {
      return 1;
    }

    return await db.setFavorite(id, favorite);
  }

  void editFlaggedBalance(bool flagged, double amount) {
    final int coef = flagged == true ? 1 : -1;
    flaggedBalance += amount * coef;
  }

  /// return the id of the Due added
  /// on error -1 is returned
  Future<int> addDue(DatabaseManager db, Due due) async {
    int res = -1;
    if (due is DueOnce) {
      res = await db.addDueOnceToAccount(id, due);
    } else if (due is Periodic) {
      res = await db.addDuePeriodicToAccount(id, due);
    }
    _dueList.add(due);
    return res;
  }

  Future<int> addDueList(DatabaseManager db, List<Due> dueList) async {
    int res = 0;
    for (Due due in dueList) {
      int a = await addDue(db, due);
      if (res >= 0) {
        res = a;
      }
    }
    return res;
  }

  Future<int> removeDue(int indexIntList, DatabaseManager db) async {
    if (indexIntList >= _dueList.length) {
      return -1;
    }
    Due dueRemoved = _dueList.removeAt(indexIntList);
    return await db.removeDueOfAccount(dueRemoved.id, id);
  }

  Future<int> removeDueList(List<int> indexList, DatabaseManager db) async {
    int res = 0, tmp;
    for (int i = 0; i < indexList.length; i++) {
      tmp = await removeDue(indexList[i] - i, db);
      if (res == 0) {
        res = tmp;
      }
    }
    return res;
  }

  List<Due> getDueList() {
    return _dueList;
  }

  Future<bool> setDueList(List<Due> dueList, DatabaseManager db) async {
    DateTime now = DateTime.now();
    bool updated = false;
    _dueList = dueList;
    List<int> idToRemove = [];
    // check for each if there is an update done
    _dueList.asMap().forEach((key, value) async {
      Due due = _dueList[key];

      // manage DueOnce => same day or after now
      if (due is DueOnce &&
          (Tools.areSameDay(due.actionDate, now) ||
              now.isAfter(due.actionDate))) {
        idToRemove.add(key);
        updated = true;
        db.addTransactionsToAccount(
            id,
            Transactions(
                0, due.amount, now, due.outsider!, false, fullBalance));
      }

      // Periodic
      else if (due is Periodic) {
        DateTime? d;

        do {
          d = Tools.generateNextDateTime(due.period, due.lastActivated!,
              referenceDate: due.referenceDate);
          if (d == null) {
            updated = false;
            break;
          }
          if (Tools.areSameDay(d, now) || now.isAfter(d)) {
            updated = true;
            if (await due.setLastActivatedDB(d, db) <= -1) {
              updated = false;
              break;
            }
            if (await db.addTransactionsToAccount(
                    id,
                    Transactions(
                        0, due.amount, d, due.outsider, false, fullBalance,
                        comment: "Opérations provenant d'une occurrence",
                        dueID: due.id)) <=
                -1) {
              updated = false;
              break;
            }
          }
        } while (now.isAfter(d!));
      }
    });

    // delete DueOnce executed
    for (int i = 0; i < idToRemove.length; i++) {
      db.removeDueOfAccount(_dueList.removeAt(idToRemove[i] - i).id, id);
    }
    return updated;
  }

  Future<int> addTransactionsList(
      List<Transactions> trList, DatabaseManager db) async {
    return db.addTransactionsListToAccount(id, trList);
  }

  Future<int> setDesignationDB(
      String newAccountName, DatabaseManager db) async {
    return db.setAccountDesignation(id, newAccountName);
  }

  Future<int> setCreationDate(DateTime accountDate, DatabaseManager db) async {
    return db.setAccountCreationDate(id, accountDate);
  }

  /// search Transaction in currentTrList which has the same id than [trID]
  int? indexOfTransaction(int trID) {
    for (int i = 0; i < getCurrentTransactionList().length; i++) {
      if (getCurrentTransactionList()[i].id == trID) {
        return i;
      }
    }
    return null;
  }

  Future<int> removeTransaction(int indexInList, DatabaseManager db) async {
    return await db.removeTransactionsOfAccount(
        id, getCurrentTransactionList().removeAt(indexInList).id);
  }

  Future<int> removeTransactionsList(
      List<int> trIDList, DatabaseManager db) async {
    int res = 0, tmp;
    for (int i = 0; i < trIDList.length; i++) {
      tmp = await removeTransaction(trIDList[i] - i, db);
      if (res == 0) {
        res = tmp;
      }
    }
    return res;
  }
}
