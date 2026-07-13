enum NavigationState {
  idle,
  running,
  arrived,
  failed,
  paused;

  static NavigationState fromString(String value) {
    return NavigationState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => NavigationState.idle,
    );
  }
}

class NavigationStatus {
  const NavigationStatus({
    required this.status,
    this.currentTargetId,
    this.currentTargetName,
    this.message,
    this.updatedAt,
  });

  final NavigationState status;
  final String? currentTargetId;
  final String? currentTargetName;
  final String? message;
  final String? updatedAt;

  factory NavigationStatus.fromJson(Map<String, dynamic> json) {
    return NavigationStatus(
      status: NavigationState.fromString('${json['status'] ?? ''}'),
      currentTargetId: json['currentTargetId'] as String?,
      currentTargetName: json['currentTargetName'] as String?,
      message: json['message'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'currentTargetId': currentTargetId,
      'currentTargetName': currentTargetName,
      'message': message,
      'updatedAt': updatedAt,
    };
  }
}
