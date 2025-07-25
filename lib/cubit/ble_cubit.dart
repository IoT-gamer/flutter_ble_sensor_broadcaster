import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../repositories/ble_repository.dart';

part 'ble_state.dart';

class BleCubit extends Cubit<BleState> {
  final BleRepository _bleRepository;
  StreamSubscription? _bleEventSubscription;

  BleCubit(this._bleRepository) : super(BleState.initial());

  Future<void> init() async {
    await _requestPermissionsAndInitialize();
  }

  Future<void> _requestPermissionsAndInitialize() async {
    final permissionsGranted = await _bleRepository.requestPermissions();
    if (permissionsGranted) {
      emit(
        state.copyWith(
          permissionsGranted: true,
          statusMessage: 'Permissions granted. Initializing BLE...',
        ),
      );
      await _initializeBle();
    } else {
      emit(
        state.copyWith(
          permissionsGranted: false,
          statusMessage:
              'Bluetooth permissions are required to use this feature.',
        ),
      );
    }
  }

  Future<void> _initializeBle() async {
    try {
      await _bleRepository.initialize();
      _bleEventSubscription = _bleRepository.bleEvents.listen(_handleBleEvent);
      await _bleRepository.addService();
      emit(
        state.copyWith(isBleReady: true, statusMessage: 'BLE Service Ready.'),
      );
    } catch (e) {
      print("Error initializing BLE: $e");
      emit(state.copyWith(statusMessage: "BLE Initialization Failed: $e"));
    }
  }

  void _handleBleEvent(dynamic event) {
    if (isClosed) return;
    if (event is ConnectionEvent) {
      emit(
        state.copyWith(
          isConnected: event.connected,
          isSubscribed: event.connected ? state.isSubscribed : false,
          statusMessage: event.connected
              ? 'Device Connected'
              : 'Device Disconnected',
        ),
      );
    } else if (event is SubscriptionEvent) {
      emit(
        state.copyWith(
          isSubscribed: event.isSubscribed,
          statusMessage: event.isSubscribed
              ? 'Client Subscribed'
              : 'Client Unsubscribed',
        ),
      );
    } else if (event is AdvertisingEvent) {
      if (event.error != null) {
        print("Advertising Error: ${event.error}");
        emit(
          state.copyWith(
            isAdvertising: false,
            statusMessage: "Advertising Error: ${event.error}",
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          isAdvertising: event.advertising,
          statusMessage: event.advertising
              ? 'Broadcasting sensor data...'
              : 'Broadcasting stopped.',
        ),
      );
    }
  }

  Future<void> startAdvertising() async {
    if (state.isAdvertising || !state.isBleReady) return;

    // Add a short delay to work around a potential initialization race condition
    await Future.delayed(const Duration(milliseconds: 500));

    // Check again in case the user stopped it during the delay
    if (isClosed || !state.isBleReady) return;

    await _bleRepository.startAdvertising();
  }

  Future<void> stopAdvertising() async {
    if (!state.isAdvertising) return;
    await _bleRepository.stopAdvertising();
  }

  Future<void> updateCharacteristic(String data) async {
    if (!state.isAdvertising || !state.isSubscribed) return;
    await _bleRepository.updateCharacteristic(data);
  }

  Future<void> grantPermissions() async {
    await _requestPermissionsAndInitialize();
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  @override
  Future<void> close() {
    stopAdvertising();
    _bleEventSubscription?.cancel();
    return super.close();
  }
}
