import 'package:flutter/material.dart';

import '../../inspection_map/presentation/inspection_map_ros_page.dart';

class EmployeeRobotInspectionPage extends StatelessWidget {
  const EmployeeRobotInspectionPage({
    super.key,
    this.onStartRobotServices,
  });

  final Future<void> Function()? onStartRobotServices;

  @override
  Widget build(BuildContext context) {
    return InspectionMapRosPage(
      experience: InspectionMapExperience.employee,
      onStartRobotServices: onStartRobotServices,
    );
  }
}
