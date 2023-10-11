import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/utils/tools.dart';

class Transactions {
  int id;
  int amount, acBalance;
  DateTime? date;
  Outsider? outsider;
  bool flagged;
  int dueID, accountID;
  String comment = "";

  Transactions(this.id, this.amount, this.date, this.outsider, this.flagged,
      this.acBalance,
      {this.dueID = -1, this.comment = "", this.accountID = -1});

  String formatDate() {
    return Tools.formatDate(date!);
  }

  Transactions.none(
      {this.id = -1,
      this.amount = 0,
      this.date,
      this.outsider,
      this.flagged = false,
      this.acBalance = 0,
      this.dueID = -1,
      this.accountID = -1,
      this.comment = ""}) {
    date ??= DateTime.now();
    outsider ??= Outsider.none();
  }

  static Transactions? fromMap(Map<String, Object?> map) {
    Transactions tr = Transactions.none();
    if (map.containsKey("amount")) {
      tr.amount = int.parse(map["amount"].toString());
    } else {
      return null;
    }

    if (map.containsKey("year") &&
        map.containsKey("month") &&
        map.containsKey("dayOfMonth")) {
      tr.date = DateTime(
          int.parse(map["year"].toString()),
          int.parse(map["month"].toString()),
          int.parse(map["dayOfMonth"].toString()));
    } else {
      tr.date = DateTime.now();
    }

    if (map.containsKey("flagged")) {
      tr.flagged = Tools.stringToBool(map["flagged"].toString());
    } else {
      tr.flagged = false;
    }

    if (map.containsKey("id")) {
      try {
        tr.id = int.parse(map["id"].toString());
      } catch (e) {
        return null;
      }
    } else {
      return null;
    }

    if (map.containsKey("balanceAcInMoment")) {
      tr.acBalance = int.tryParse(
            map["balanceAcInMoment"].toString(),
          ) ??
          0;
    } else {
      tr.acBalance = 0;
    }

    if (map.containsKey("dueID")) {
      tr.dueID = int.tryParse(map["dueID"].toString()) ?? -1;
    }

    if (map.containsKey("accountID")) {
      tr.accountID = int.tryParse(map["accountID"].toString()) ?? -1;
    }

    if (map.containsKey("comment")) {
      tr.comment = map["comment"].toString();
    }

    return tr;
  }

  Map<String, Object?> toMapForDB() => {
        "used": "true",
        "amount": amount.toString(),
        "flagged": flagged.toString(),
        "dueID": _getDueID().toString(),
        "year": date!.year.toString(),
        "month": date!.month.toString(),
        "dayOfMonth": date!.day.toString(),
        "outsiderID": _getOutsiderID(),
        "balanceAcInMoment": acBalance,
        "comment": comment,
        "accountID": accountID.toString(),
      };

  int _getOutsiderID() {
    if (outsider == null) {
      return -1;
    }
    return outsider!.id;
  }

  int _getDueID() {
    return dueID;
  }

  Future<int> switchFlaggedDB(DatabaseManager db, int acID) async {
    switchFlagged();
    final int res = await db.setTransactionsFlagged(this, acID);

    // no errors
    if (res == -1) {
      switchFlagged();
    }
    return res;
  }

  void switchFlagged() {
    flagged = !flagged;
  }

  Future<int> editDB(DatabaseManager db, int? newAmount, DateTime newDate,
      Outsider? newOutsider, int acID, String? newComment) async {
    return await db.editTransaction(
        trID: id,
        newAmount: newAmount ?? amount,
        newDate: newDate,
        outsider: newOutsider,
        acID: acID,
        flagged: flagged,
        oldAmount: amount,
        comment: newComment != comment ? newComment : null,
        oldDate: date!);
  }
}
