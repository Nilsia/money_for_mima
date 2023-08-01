import 'dart:math';

import 'package:flutter/material.dart';
import 'package:money_for_mima/models/database_manager.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/utils/popup_shower.dart';
import 'package:money_for_mima/utils/tools.dart';

class OutsiderListView extends StatelessWidget {
  final List<Outsider> outsiderList;
  final DatabaseManager db;
  final void Function() update;
  final List<Color> backgroundList;
  final List<int> allOutsiderIdUsed;
  const OutsiderListView(
      {super.key,
      required this.outsiderList,
      required this.db,
      required this.update,
      required this.backgroundList,
      required this.allOutsiderIdUsed});

  static const double outsiderListWitdh = 200;
  static const double outsiderListTitleHeight = 50;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // title
        Container(
          width: outsiderListWitdh,
          decoration: const BoxDecoration(
              border: Border(
                  left: BorderSide(color: Colors.black),
                  right: BorderSide(color: Colors.black),
                  top: BorderSide(color: Colors.black))),
          height: outsiderListTitleHeight,
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
                child: Text(
              "Liste des tiers",
              style: TextStyle(fontSize: 18),
            )),
          ),
        ),
        // outsider item list
        Container(
          height: max(
              400,
              MediaQuery.of(context).size.height -
                  8 * 2 -
                  outsiderListTitleHeight -
                  Tools.appBarHeight /* - infoHeight */),
          width: outsiderListWitdh,
          decoration: BoxDecoration(border: Border.all(color: Colors.black)),
          child: ListView.builder(
              itemCount: outsiderList.length,
              itemBuilder: (BuildContext context, int i) {
                Outsider o = outsiderList[i];
                const borderBetween = BorderSide(color: Colors.grey);
                List<PopupAction> popupActionList = [PopupAction.edit];
                print(allOutsiderIdUsed);
                if (!allOutsiderIdUsed.contains(o.id)) {
                  popupActionList.add(PopupAction.delete);
                }
                return InkWell(
                  onTap: () {
                    PopupShower.showOutsiderPopup(
                        popupActionList: popupActionList,
                        outsider: o,
                        context,
                        "Modification d'un tiers",
                        callback:
                            (PopupAction p, String name, String comment) =>
                                outsiderPopupCallback(
                                    p, name, comment, o, context));
                  },
                  child: Container(
                    height: 50,
                    width: outsiderListWitdh,
                    decoration: BoxDecoration(
                        color: backgroundList[i % 2],
                        border: const Border(bottom: borderBetween)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      child: Column(
                        children: [
                          Text(o.name),
                          if (o.comment.isNotEmpty) Text(o.comment)
                        ],
                      ),
                    ),
                  ),
                );
              }),
        )
      ],
    );
  }

  Future<bool> outsiderPopupCallback(PopupAction popupAction, String name,
      String comment, Outsider o, BuildContext context) async {
    switch (popupAction) {
      case PopupAction.delete:
        return db.removeOutsider(o.id).then((value) {
          update();
          switch (value) {
            case 0:
              return true;
            case -1:
              Tools.showNormalSnackBar(context,
                  "Une erreur est survenue lors de la suppression du tiers");
              return true;
            case -2:
              Tools.showNormalSnackBar(context, "Le tiers est utilisé");
              return false;
            default:
              return true;
          }
        });
      case PopupAction.edit:
        return await db
            .updateOutsider(o, Outsider(0, name, comment: comment))
            .then((value) {
          update();
          if (value <= -1) {
            Tools.showNormalSnackBar(context,
                "Une erreur est survenue lors de le modification du tiers");
            return false;
          }
          return true;
        });
      default:
        return true;
    }
  }
}
