import 'package:flutter/material.dart';

extension CustomColorScheme on ColorScheme {
  Color get backgroundListDistinct1 => brightness == Brightness.light
      ? const Color.fromARGB(255, 224, 224, 224)
      : const Color.fromARGB(255, 97, 97, 97);

  Color get backgroundListDistinct2 => brightness == Brightness.light
      ? const Color.fromARGB(255, 209, 208, 208)
      : const Color.fromARGB(255, 117, 117, 117);

  Color get aroundColor => brightness == Brightness.light
      ? const Color.fromARGB(255, 64, 175, 226)
      : const Color.fromARGB(255, 235, 152, 119);

  Color get borderAroundColor => brightness == Brightness.light
      ? const Color.fromARGB(120, 38, 103, 223)
      : const Color.fromARGB(255, 226, 79, 20);
}
