import 'package:flutter/material.dart';

import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/homa_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // بارگذار SQLite را پیش از ساخت سرویس‌های ذخیره‌سازی فعال می‌کنیم.
  sqfliteFfiInit();
  runApp(const HomaApp());
}
