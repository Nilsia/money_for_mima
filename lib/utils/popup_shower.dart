import 'package:flutter/material.dart';
import 'package:money_for_mima/models/outsider.dart';
import 'package:money_for_mima/utils/tools.dart';

class PopupShower {
  static Future<void> showOutsiderPopup(BuildContext context, String title,
      {List<PopupAction>? popupActionList,
      required Future<bool> Function(PopupAction, String, String) callback,
      required Outsider outsider}) async {
    await showDialog(
        context: context,
        builder: (context) {
          TextEditingController outsiderName =
                  TextEditingController(text: outsider.name),
              outsiderComment = TextEditingController(text: outsider.comment);
          popupActionList ??= [PopupAction.delete, PopupAction.edit];

          List<Widget> actions = [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancel")),
          ];

          // delete
          if (popupActionList!.contains(PopupAction.delete)) {
            actions.add(TextButton(
                onPressed: () async {
                  callback(PopupAction.delete, outsiderName.text.trim(),
                          outsiderComment.text.trim())
                      .then((value) {
                    if (value) {
                      Navigator.of(context).pop();
                    }
                  });
                },
                child: const Text("Supprimer")));
          }

          //edit
          if (popupActionList!.contains(PopupAction.edit)) {
            actions.add(TextButton(
                onPressed: () async {
                  if (outsiderName.text.trim().isEmpty) {
                    Tools.showNormalSnackBar(
                        context, "Veuillez remplir l'élément du nom du tiers");
                    return;
                  }
                  callback(PopupAction.edit, outsiderName.text.trim(),
                          outsiderComment.text.trim())
                      .then((value) {
                    if (value) {
                      Navigator.of(context).pop();
                    }
                  });
                },
                child: const Text("Modifier")));
          }

          return StatefulBuilder(
              builder: ((context, setState) => AlertDialog(
                    title: Text(title),
                    content: SizedBox(
                      height: 200,
                      width: 300,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              // outsider name
                              TextFormField(
                                decoration: const InputDecoration(
                                    labelText: "Nom du tiers"),
                                controller: outsiderName,
                              ),

                              // outsider comment
                              TextField(
                                controller: outsiderComment,
                                decoration: const InputDecoration(
                                    labelText: "Commentaires"),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    actions: actions,
                  )));
        });
  }
}
