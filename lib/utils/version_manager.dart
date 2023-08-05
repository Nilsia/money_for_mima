import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:money_for_mima/utils/tools.dart';
import 'package:observe_internet_connectivity/observe_internet_connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VersionManager {
  static void searchNewVersion(
      {SharedPreferences? prefs,
      required BuildContext context,
      required bool showNewVersionDialog,
      required bool showErrorFetching,
      bool showCheckBox = true}) async {
    InternetConnectivity().hasInternetConnection.then((hasInternet) {
      if (hasInternet) {
        var github = GitHub();
        github.repositories
            .listReleases(RepositorySlug('Nilsia', 'money_for_mima'))
            .take(1)
            .toList()
            .then((repositories) async {
          String? lastVersion = repositories[0].tagName;
          if (lastVersion == null) {
            await _showDialogOnErrorVersionGetting(
                showErrorFetching,
                context,
                "Impossible de récupérer la version distante, veuillez référer cette erreur aux développeurs.",
                showCheckBox);
            return;
          }
          final File configFile = File("./config.json");

          const JsonDecoder decoder = JsonDecoder();
          try {
            Map<String, dynamic> localConfig =
                decoder.convert(configFile.readAsStringSync());
            if (!localConfig.containsKey("version")) {
              await _showDialogOnErrorVersionGetting(
                  showErrorFetching,
                  context,
                  "Le fichier de configuration n'est pas valide, veuillez exécuter upgrade dans le dossier ${Directory.current} afin de résoudre le problème.",
                  showCheckBox);
              return;
            }

            String localVersion = localConfig["version"];

            if (localVersion != lastVersion) {
              await _showDialogNewVersion(showNewVersionDialog, context,
                  lastVersion, localVersion, showCheckBox);
            } else {
              await _showDialogAlreadyUpToDate(context);
            }
          } on Exception {
            await _showDialogOnErrorVersionGetting(
                showErrorFetching,
                context,
                "Le fichier de configuration n'a pas été trouvé, veuillez lancer Money For Mima dans le bon dossier.",
                showCheckBox);
          }
        });
      }
    });
  }

  static Future<void> _showDialogOnErrorVersionGetting(bool showErrorFetching,
      BuildContext context, String text, bool showCheckBox) async {
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Erreur récupération nouvelle version"),
              content: SizedBox(
                width: 400,
                height: 150,
                child: Column(
                  children: [
                    Text(text),
                    const SizedBox(
                      height: 30,
                    ),
                    if (showCheckBox)

                      /// TODO manage value change on checkbox
                      const Row(
                        children: [
                          Checkbox(value: false, onChanged: null),
                          Text("Ne plus afficher le message "),
                        ],
                      )
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("OK"))
              ],
            ));
  }

  static Future<void> _showDialogAlreadyUpToDate(BuildContext context) async {
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Déjà à jour"),
              content: const SizedBox(
                width: 400,
                height: 50,
                child: Column(
                  children: [
                    Text("VOtre version de Money For Mima est déjà à jour."),
                    SizedBox(
                      height: 30,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("OK"))
              ],
            ));
  }

  static Future<void> _showDialogNewVersion(
      bool showNewVersionDialog,
      BuildContext context,
      String newVersion,
      String currentVersion,
      bool showCheckBox) async {
    if (!showNewVersionDialog) {
      return;
    }
    bool doNotShowAgain = false;
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  title: const Text("Nouvelle version"),
                  content: SizedBox(
                      width: 400,
                      height: 300,
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                                "Vous êtes actuellement à la version $currentVersion, la nouvelle version $newVersion est disponible."),
                            Text(
                                "\nSi vous souhaitez mettre à jour Money For Mima, suivez les instructions suivantes : \n1) Allez dans le dossier ${Directory.current},\n2) Fermez l'application Money For Mima (très important)\n3) Exécutez avec un double clic upgrade(.exe)"),
                            const SizedBox(
                              height: 10,
                            ),
                            if (showCheckBox)
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Row(
                                    children: [
                                      Checkbox(
                                          value: doNotShowAgain,
                                          onChanged: (bool? v) async {
                                            if (v != null) {
                                              doNotShowAgain = !await Tools
                                                  .setShowNewVersion(!v,
                                                      sharedPreferences: null);
                                              setState(() {});
                                            }
                                          }),
                                      const Text("Ne plus afficher ce message")
                                    ],
                                  ),
                                ),
                              )
                          ],
                        ),
                      )),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("OK")),
                    /* TextButton(
                            onPressed: () async {
                              var executable = './upgrade';
                              if (Platform.isWindows) {
                                executable = '$executable.exe';
                              }

                              final arguments = <String>["--force"];

                              final process = await Process.start(
                                  executable, arguments,
                                  runInShell: true);
                              await stdout.addStream(process.stdout);
                              await stderr.addStream(process.stderr);
                              final exitCode = await process.exitCode;
                            },
                            child: const Text("Mettre à jour")) */
                  ],
                )));
  }
}
