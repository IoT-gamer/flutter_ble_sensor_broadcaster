part of 'orientation_cubit.dart';

class OrientationState extends Equatable {
  final double pitch;
  final double roll;
  final double yaw;

  const OrientationState({
    required this.pitch,
    required this.roll,
    required this.yaw,
  });

  // Initial state with all values at 0
  factory OrientationState.initial() {
    return const OrientationState(pitch: 0.0, roll: 0.0, yaw: 0.0);
  }

  @override
  List<Object> get props => [pitch, roll, yaw];

  // Helper to format data for display or logging
  @override
  String toString() =>
      'Pitch: ${pitch.toStringAsFixed(2)}, Roll: ${roll.toStringAsFixed(2)}, Yaw: ${yaw.toStringAsFixed(2)}';

  // Helper to format data for BLE characteristic
  String toCharacteristicString() =>
      '${pitch.toStringAsFixed(4)},${roll.toStringAsFixed(4)},${yaw.toStringAsFixed(4)}';
}
