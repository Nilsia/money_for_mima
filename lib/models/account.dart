import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/due.dart';
import 'package:money_for_mima/models/transactions.dart';
import 'package:money_for_mima/utils/tools.dart';

class Account {
  int id;
  String designation, comment;
  bool onlyNth = true, generatedFastly = false, selected;
  bool favorite;
  double balance, initialBalance;
  List<Transactions> transactionsList,
      transactionListUnFlagged = [],
      transactionListFlagged = [];
  List<Due> dueList;
  DateTime? creationDate;

  Account(this.id, this.designation, this.balance, this.initialBalance,
      this.favorite, this.transactionsList, this.dueList, this.selected,
      {this.onlyNth = true,
      this.generatedFastly = false,
      this.comment = "",
      this.creationDate}) {
    creationDate ??= DateTime.now();
    generateOtherLists();
  }

  Account.none(this.transactionsList, this.dueList,
      {this.id = -1,
      this.designation = "",
      this.balance = 0,
      this.initialBalance = 0,
      this.favorite = false,
      this.selected = false,
      this.onlyNth = true,
      this.generatedFastly = false,
      this.comment = "",
      this.creationDate});

  generateOtherLists() {
    for (var element in transactionsList) {
      if (element.flagged) {
        transactionListFlagged.add(element);
      } else {
        transactionListUnFlagged.add(element);
      }
    }
  }

  Map<String, String> toMapForDB() => {
        "used": "true",
        "balance": balance.toString(),
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
      ac.initialBalance = double.parse(map["initBalance"].toString());
    } else {
      return null;
    }

    if (map.containsKey("balance")) {
      ac.balance = double.parse(map["balance"].toString());
    } else {
      return null;
    }

    if (map.containsKey("dueList")) {
      ac.dueList = [];
    } else {
      ac.dueList = [];
    }

    if (map.containsKey("transactionsList")) {
      ac.transactionsList = [];
    } else {
      ac.transactionsList = [];
    }

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
    return "Account(id: $id, designation: $designation, balance: $balance, creationDate: ${creationDate.toString()})";
  }

  Future<int> setSelectionDB(DatabaseManager db, bool selected) async {
    if (selected == this.selected) {
      return 0;
    }

    final int res = await db.setAccountSelected(this, selected);
    if (res != -1) {
      this.selected = selected;
    }
    return res;
  }
}
