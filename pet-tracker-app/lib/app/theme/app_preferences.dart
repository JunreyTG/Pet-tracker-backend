import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences._();

  static final themeMode = ThemeMode.system.obs;
  static final showAlertBanners = true.obs;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode.value = ThemeMode.values.firstWhere(
      (mode) => mode.name == prefs.getString('pet_tracker_appearance'),
      orElse: () => ThemeMode.system,
    );
    showAlertBanners.value = prefs.getBool('pet_tracker_alert_banners') ?? true;
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    await (await SharedPreferences.getInstance()).setString(
      'pet_tracker_appearance',
      mode.name,
    );
  }

  static Future<void> setAlertBanners(bool enabled) async {
    showAlertBanners.value = enabled;
    await (await SharedPreferences.getInstance()).setBool(
      'pet_tracker_alert_banners',
      enabled,
    );
  }
}
