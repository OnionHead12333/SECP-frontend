import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:flutter/material.dart';

import 'app/smart_elderly_care_app.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.useMockLocation) {
    AMapFlutterLocation.setApiKey(AppConfig.amapAndroidKey, AppConfig.amapIosKey);
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);
  }
  runApp(const SmartElderlyCareApp());
}
