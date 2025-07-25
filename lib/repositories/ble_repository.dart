import 'dart:convert';
import 'dart:io';

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/ble_constants.dart';

// Abstract base class for BLE events.
abstract class BleEvent {}

// Event for connection state changes.
class ConnectionEvent extends BleEvent {
  final String deviceId;
  final bool connected;
  ConnectionEvent(this.deviceId, this.connected);
}

// Event for characteristic subscription changes.
class SubscriptionEvent extends BleEvent {
  final String deviceId;
  final String characteristicId;
  final bool isSubscribed;
  final String? name;
  SubscriptionEvent(
    this.deviceId,
    this.characteristicId,
    this.isSubscribed,
    this.name,
  );
}

// Event for advertising state changes.
class AdvertisingEvent extends BleEvent {
  final bool advertising;
  final String? error;
  AdvertisingEvent(this.advertising, this.error);
}

class BleRepository {
  // Define unique names for the method and event channels.
  static const _methodChannel = MethodChannel(
    'com.example.flutter_sensor_ble/method',
  );
  static const _eventChannel = EventChannel(
    'com.example.flutter_sensor_ble/event',
  );

  final _streamController = StreamController<BleEvent>.broadcast();
  Stream<BleEvent> get bleEvents => _streamController.stream;

  // --- Permission Handling (using permission_handler) ---
  Future<bool> requestPermissions() async {
    List<Permission> permissionsToRequest = [];
    if (Platform.isAndroid) {
      permissionsToRequest.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ]);
    } else if (Platform.isIOS) {
      permissionsToRequest.add(Permission.bluetooth);
    }

    Map<Permission, PermissionStatus> statuses = await permissionsToRequest
        .request();
    return statuses.values.every((status) => status.isGranted);
  }

  // --- Method Channel Communication ---

  /// Initializes the native BLE peripheral manager and sets up the event listener.
  Future<void> initialize() async {
    // Listen for events from the native side.
    _eventChannel.receiveBroadcastStream().listen(_onEvent, onError: _onError);
    // Call the native `initialize` method.
    await _methodChannel.invokeMethod('initialize');
  }

  /// Tells the native side to add the GATT service.
  Future<void> addService() async {
    await _methodChannel.invokeMethod('addService', {
      'serviceUuid': BleConstants.serviceUuid,
      'characteristicUuid': BleConstants.characteristicUuid,
    });
  }

  /// Tells the native side to start advertising.
  Future<void> startAdvertising() async {
    // The native Android side can get the UUID from the service it already has,
    // so we only need to pass the device name.
    await _methodChannel.invokeMethod('startAdvertising', {
      'deviceName': BleConstants.deviceName,
    });
  }

  /// Tells the native side to stop advertising.
  Future<void> stopAdvertising() async {
    await _methodChannel.invokeMethod('stopAdvertising');
  }

  /// Sends data to the native side to update the characteristic value.
  Future<void> updateCharacteristic(String data) async {
    final bytes = utf8.encode(data);
    await _methodChannel.invokeMethod('updateCharacteristic', {
      'characteristicUuid': BleConstants.characteristicUuid,
      'value': Uint8List.fromList(bytes),
    });
  }

  // --- Event Handling from Native ---

  /// Handles events coming from the native EventChannel.
  void _onEvent(dynamic event) {
    if (event is Map) {
      final String eventType = event['event'];
      switch (eventType) {
        case 'advertisingStatus':
          _streamController.add(
            AdvertisingEvent(event['isAdvertising'], event['error']),
          );
          break;
        case 'connectionState':
          _streamController.add(
            ConnectionEvent('nativeDevice', event['isConnected']),
          );
          break;
        case 'subscriptionState':
          _streamController.add(
            SubscriptionEvent(
              'nativeDevice',
              BleConstants.characteristicUuid,
              event['isSubscribed'],
              'Native Device',
            ),
          );
          break;
      }
    }
  }

  /// Handles errors from the EventChannel.
  void _onError(dynamic error) {
    print("Error on BLE Event Channel: $error");
    _streamController.add(
      AdvertisingEvent(false, "Native channel error: $error"),
    );
  }
}
