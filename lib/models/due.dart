import 'dart:convert';

import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/outsider.dart';

class Due {
  int id;
  int amount;
  String comment = "";
  Outsider? outsider;

  Due(this.id, this.amount, this.outsider, {this.comment = ""});

  Due.none({this.id = -1, this.amount = 0, this.outsider, this.comment = ""}) {
    outsider = Outsider.none();
  }

  static Due? fromMap(Map<String, Object?> map, Outsider outsider) {
    int id;
    int amount;
    String comment = "";
    if (map.containsKey("id")) {
      id = int.parse(map["id"].toString());
    } else {
      return null;
    }

    if (map.containsKey("amount")) {
      amount = int.parse(map["amount"].toString());
    } else {
      return null;
    }

    if (map.containsKey("comment")) {
      comment = map["comment"].toString();
    }

    if (!map.containsKey("type")) {
      return null;
    }

    if (!map.containsKey("jsonClass")) {
      return null;
    }

    final String jsonStr = map["jsonClass"].toString();

    // Periodic
    if (map["type"].toString() == "Periodic") {
      return Periodic.fromJson(jsonStr, id, amount, comment, outsider);
    }
    // DueOnce
    else if (map["type"].toString() == "DueOnce") {
      return DueOnce.fromJson(jsonStr, id, amount, comment, outsider);
    }

    return null;
  }

  Map<String, String> toJson() => {
        "amount": amount.toString(),
        "comment": comment,
        "outsiderID": outsider!.id.toString()
      };

  static Future<Due?> fromMapDB(
      Map<String, Object?> map, DatabaseManager db) async {
    int? i = int.tryParse(map["outsiderID"].toString());
    if (i == null) {
      return null;
    }

    Outsider? o = await db.getOutsiderFromID(i);
    if (o == null) {
      return null;
    }

    return fromMap(map, o);
  }
}

enum Period {
  daily, // quotidien
  weekly, // hebdomadaire
  monthly, // mensuel
  quarterly, // trimestriel (tous les 3 mois)
  biAnnual, // semestriel
  yearly // annuel
}

class Periodic extends Due {
  Period period;
  DateTime? lastActivated;
  DateTime? referenceDate;

  Periodic(super.id, super.amount, super.outsider, this.referenceDate,
      this.lastActivated, this.period,
      {super.comment = ""});

  Periodic.none(super.id, super.amount, super.outsider, this.referenceDate,
      {this.period = Period.biAnnual, this.lastActivated}) {
    outsider ??= Outsider.none();
    lastActivated ??= DateTime.now();
    referenceDate ??= DateTime.now();
  }

  @override
  Map<String, String> toJson() {
    Map<String, String> m = toJsonLight();
    m.addAll(toJson());
    return m;
  }

  Map<String, String> toJsonLight() => {
        "period": period.index.toString(),
        "lastActivated": lastActivated!.toString(),
        "referenceDate": referenceDate.toString()
      };

  Map<String, String> toJsonForDB() {
    Map<String, String> m = super.toJson();
    m["jsonClass"] = json.encode(toJsonLight());
    m["type"] = "Periodic";
    return m;
  }

  static Periodic? fromJson(
      String jsonStr, int id, int amount, String comment, Outsider outsider) {
    final dynamic jsonClass = json.decode(jsonStr);
    DateTime? refDate = DateTime.tryParse(jsonClass["referenceDate"]);
    DateTime? lastActivatedDate = DateTime.tryParse(jsonClass["lastActivated"]);
    int? index = int.tryParse(jsonClass["period"]);

    if (refDate == null || lastActivatedDate == null || index == null) {
      return null;
    }

    Period p = Period.values[index];

    Periodic periodic = Periodic(
        id, amount, outsider, refDate, lastActivatedDate, p,
        comment: comment);
    return periodic;
  }

  /// return the new Values as a Map
  /// how to compare : newDue.buildComparativeMap(oldDue)
  Future<Map<String, Object>?> buildComparativeMap(Periodic initialDue,
      {DatabaseManager? db}) async {
    Map<String, Object> map = {};
    if (initialDue.amount != amount) {
      map["amount"] = amount;
    }

    if (referenceDate!.isAtSameMomentAs(initialDue.referenceDate!) ||
        period.index != initialDue.period.index) {
      map["jsonClass"] = json.encode(toJsonLight());
    }

    if (initialDue.comment != comment) {
      map["comment"] = comment;
    }

    if (!initialDue.outsider!.areSame(outsider!)) {
      if (db == null) {
        return null;
      }
      Outsider? o = await db.manageOutsider(outsider: outsider, oID: null);
      if (o == null) {
        return null;
      }
      map["outsiderID"] = o.id.toString();
    }
    return map;
  }

  Future<int> setLastActivatedDB(
      DateTime newLastActivated, DatabaseManager db) async {
    lastActivated = newLastActivated;
    return await db.updatePeriodic(this, map: toJsonForDB());
  }
}

class DueOnce extends Due {
  DateTime actionDate;

  DueOnce(super.id, super.amount, super.outsider, this.actionDate,
      {super.comment = ""});

  Map<String, String> toJsonLight() => {"actionDate": actionDate.toString()};

  Map<String, String> toJsonForDB() {
    Map<String, String> m = super.toJson();
    m["jsonClass"] = json.encode(toJsonLight());
    m["type"] = "DueOnce";
    return m;
  }

  @override
  Map<String, String> toJson() {
    Map<String, String> m = toJsonLight();
    m.addAll(toJson());
    return m;
  }

  static DueOnce? fromJson(
      String jsonStr, int id, int amount, String comment, Outsider outsider) {
    final dynamic jsonClass = json.decode(jsonStr);
    DateTime? dateTime = DateTime.tryParse(jsonClass["actionDate"]);
    return dateTime != null
        ? DueOnce(id, amount, outsider, dateTime, comment: comment)
        : null;
  }

  /// return the new Values as a Map
  /// how to compare : newDue.buildComparativeMap(oldDue)
  Future<Map<String, Object>?> buildComparativeMap(DueOnce initialDue,
      {DatabaseManager? db}) async {
    Map<String, Object> map = {};
    if (initialDue.amount != amount) {
      map["amount"] = amount;
    }

    if (actionDate.isAtSameMomentAs(initialDue.actionDate)) {
      map["jsonClass"] = json.encode(toJsonLight());
    }

    if (initialDue.comment != comment) {
      map["comment"] = comment;
    }

    if (!initialDue.outsider!.areSame(outsider!)) {
      if (db == null) {
        return null;
      }
      Outsider? o = await db.manageOutsider(outsider: outsider, oID: null);
      if (o == null) {
        return null;
      }
      map["outsiderID"] = o.id.toString();
    }
    return map;
  }
}
