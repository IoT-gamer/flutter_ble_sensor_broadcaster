part of 'ble_cubit.dart';

// State for the BLE peripheral
class BleState extends Equatable {
  final bool isAdvertising;
  final bool isConnected;
  final String statusMessage;
  final bool isBleReady;
  final bool permissionsGranted;
  final bool isSubscribed; // New state to track characteristic subscription

  const BleState({
    required this.isAdvertising,
    required this.isConnected,
    required this.statusMessage,
    required this.isBleReady,
    required this.permissionsGranted,
    required this.isSubscribed,
  });

  // Initial state for the BLE service
  factory BleState.initial() {
    return const BleState(
      isAdvertising: false,
      isConnected: false,
      statusMessage: 'Requesting permissions...',
      isBleReady: false,
      permissionsGranted: false,
      isSubscribed: false,
    );
  }

  // CopyWith method to easily create a new state from the old one
  BleState copyWith({
    bool? isAdvertising,
    bool? isConnected,
    String? statusMessage,
    bool? isBleReady,
    bool? permissionsGranted,
    bool? isSubscribed,
  }) {
    return BleState(
      isAdvertising: isAdvertising ?? this.isAdvertising,
      isConnected: isConnected ?? this.isConnected,
      statusMessage: statusMessage ?? this.statusMessage,
      isBleReady: isBleReady ?? this.isBleReady,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }

  @override
  List<Object> get props => [
    isAdvertising,
    isConnected,
    statusMessage,
    isBleReady,
    permissionsGranted,
    isSubscribed,
  ];
}
