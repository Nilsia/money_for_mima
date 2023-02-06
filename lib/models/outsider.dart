class Outsider {
  int id;
  String name, comment;

  Outsider(this.id, this.name, {this.comment = ""});

  Outsider.none({this.id = -1, this.name = "", this.comment = ""});

  static Outsider? fromMap(Map<String, Object?> map) {
    Outsider outsider = Outsider.none();
    if (map.containsKey("name")) {
      outsider.name = map["name"].toString();
    } else {
      return null;
    }

    if (map.containsKey("id")) {
      outsider.id = int.parse(map["id"].toString());
    } else {
      return null;
    }

    if (map.containsKey("comment")) {
      outsider.comment = map["comment"].toString();
    }

    return outsider;
  }

  Map<String, Object?> toMapForDB() => {
    "used": "true",
    "name": name,
    "comment": comment
  };

  @override
  String toString() {
    // TODO: implement toString
    return "Outsider(id: $id, name: $name, comment: $comment)";
  }

}