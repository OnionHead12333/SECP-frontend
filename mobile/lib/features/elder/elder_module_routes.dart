import 'package:flutter/material.dart';

import 'presentation/elder_binding_status_page.dart';
import 'presentation/elder_emergency_contacts_page.dart';
import 'presentation/elder_home_page.dart';
import 'presentation/elder_location_status_page.dart';
import 'presentation/elder_profile_edit_page.dart';
import 'presentation/elder_register_page.dart';

/// 老人端模块对外暴露的路由常量与路由表。
final class ElderModuleRoutes {
  ElderModuleRoutes._();

  static const String elderRegister = '/elder/register';
  static const String elderHome = '/elder/home';
  static const String elderBinding = '/elder/binding';
  static const String elderEmergencyContacts = '/elder/emergency-contacts';
  static const String elderLocationStatus = '/elder/location-status';
  static const String elderProfile = '/elder/profile';

  static Map<String, WidgetBuilder> routes() {
    return {
      elderRegister: (_) => const ElderRegisterPage(),
      elderHome: (_) => const ElderHomePage(),
      elderBinding: (_) => const ElderBindingStatusPage(),
      elderEmergencyContacts: (_) => const ElderEmergencyContactsPage(),
      elderLocationStatus: (_) => const ElderLocationStatusPage(),
      elderProfile: (_) => const ElderProfileEditPage(),
    };
  }
}
