import 'dart:convert';

class Due {
  int id;
  double amount;
  DateTime? creationDate;

  Due(this.id, this.amount, this.creationDate);

  Due.none({this.id = -1, this.amount = 0, this.creationDate}) {
    creationDate = DateTime.now();
  }

  static Due? fromMap(Map<String, Object?> map) {
    int id;
    double amount;
    DateTime creationDate;
    if (map.containsKey("id")) {
      id = int.parse(map["id"].toString());
    } else {
      return null;
    }

    if (map.containsKey("amount")) {
      amount = double.parse(map["id"].toString());
    } else {
      return null;
    }

    if (map.containsKey("date")) {
      creationDate = DateTime.parse(map["date"].toString());
    } else {
      return null;
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
      return Periodic.fromJson(jsonStr, id, amount, creationDate);
    }
    // DueOnce
    else if (map["type"].toString() == "DueOnce") {
      return DueOnce.fromJson(jsonStr, id, amount, creationDate);
    }
    return null;
  }
}

enum Period {
  daily, // quotidien
  weekly, // hebdomadaire
  monthly, // mensuel
  bimonthly, // bimensuel
  quarterly, // trimestriel (3x par mois)
  biAnnual, // semestriel
  yearly // annuel
}

class Periodic extends Due {
  int nbInMonth;
  Period period;

  Periodic(
      super.id, super.amount, super.creationDate, this.nbInMonth, this.period);

  Periodic.none(super.id, super.amount, super.creationDate,
      {this.nbInMonth = 1, this.period = Period.biAnnual});

  Map toJson() =>
      {"nbInMonth": nbInMonth.toString(), "period": period.index.toString()};

  static Periodic? fromJson(
      String jsonStr, int id, double amount, DateTime creationDate) {
    final dynamic jsonClass = json.decode(jsonStr);

    Periodic periodic = Periodic(
        id, amount, creationDate, jsonClass["nbInMonth"], jsonClass["period"]);
    return periodic;
  }
}

class DueOnce extends Due {
  DateTime actionDate;

  DueOnce(super.id, super.amount, super.creationDate, this.actionDate);

  Map toJson() => {"actionDate": actionDate.toString()};

  static DueOnce? fromJson(
      String jsonStr, int id, double amount, DateTime creationDate) {
    final dynamic jsonClass = json.decode(jsonStr);
    return DueOnce(id, amount, creationDate, jsonClass["actionDate"]);
  }
}
