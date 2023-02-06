import 'package:intl/intl.dart';
import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/due.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/utils/tools.dart';
import 'package:sqflite/sqflite.dart';

class Transactions {
  int id;
  double amount;
  DateTime? date;
  Outsider? outsider;
  bool flagged;
  Due? due;

  Transactions(this.id, this.amount, this.date, this.outsider, this.flagged,
      {this.due});

  String formatDate() {
    return DateFormat("dd/MM/yyyy").format(date!);
  }

  Transactions.none(
      {this.id = -1,
      this.amount = 0,
      this.date,
      this.outsider,
      this.flagged = false,
      this.due}) {
    date = DateTime.now();
    outsider = Outsider.none();
  }

  static Transactions? fromMap(Map<String, Object?> map) {
    Transactions tr = Transactions.none();
    if (map.containsKey("amount")) {
      tr.amount = double.parse(map["amount"].toString());
    } else {
      return null;
    }

    if (map.containsKey("year") &&
        map.containsKey("month") &&
        map.containsKey("DayOfMonth")) {
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
      tr.id = int.parse(map["id"].toString());
    } else {
      return null;
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
      };

  int _getOutsiderID() {
    if (outsider == null) {
      return -1;
    }
    return outsider!.id;
  }

  int _getDueID() {
    if (due == null) {
      return -1;
    }
    return due!.id;
  }

  Future<int> setFlaggedDB(DatabaseManager db) async {
    final res = await db.setTransactionsFlagged(this);

    // no errors
    if (res != -1) {
      switchFlagged();
    }
    return res;
  }

  void switchFlagged() {
    if (flagged) {
      flagged = false;
    } else {
      flagged = true;
    }
  }
}
