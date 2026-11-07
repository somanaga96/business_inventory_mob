import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppSession {
  static Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}inventorypro_session.txt');
  }

  static Future<String?> readUsername() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final value = (await file.readAsString()).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUsername(String username) async {
    try {
      await (await _file()).writeAsString(username, flush: true);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
