import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserData {
  bool showNewVersion = true;
  bool showDialogOnError = true;

  SharedPreferences? sharedPreferences;
  PackageInfo? packageInfo;

  UserData({this.sharedPreferences, this.packageInfo});
  UserData.none();

  Future<UserData> setData() async {
    sharedPreferences ??= await SharedPreferences.getInstance();
    packageInfo ??= await PackageInfo.fromPlatform();
    showDialogOnError = sharedPreferences!.getBool("showDialogOnError") ?? true;
    showNewVersion = sharedPreferences!.getBool("showNewVersion") ?? true;
    return this;
  }

  /// takes the value [state] and put it into shared preferences, the function
  ///  return [state]
  Future<bool> setShowDialogOnError(
    bool state,
  ) async {
    await sharedPreferences!.setBool("showDialogOnError", state);
    return state;
  }

  /// takes the value [state] and put it into shared preferences, the function
  ///  return [state]
  Future<bool> setShowNewVersion(bool state) async {
    await sharedPreferences!.setBool("showNewVersion", state);
    return state;
  }

  Future<bool> switchNewVersionValue() async {
    showNewVersion = await setShowNewVersion(!showNewVersion);
    return showNewVersion;
  }

  Future<bool> switchDialogErrorValue() async {
    showDialogOnError = await setShowDialogOnError(!showDialogOnError);
    return showDialogOnError;
  }
}
