package com.example.flutter_ble_sensor_broadcaster;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattServer;
import android.bluetooth.BluetoothGattServerCallback;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.AdvertiseCallback;
import android.bluetooth.le.AdvertiseData;
import android.bluetooth.le.AdvertiseSettings;
import android.bluetooth.le.BluetoothLeAdvertiser;
import android.content.Context;
import android.os.ParcelUuid;
import android.util.Log;

import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

public class MainActivity extends FlutterActivity {
    private static final String METHOD_CHANNEL = "com.example.flutter_sensor_ble/method";
    private static final String EVENT_CHANNEL = "com.example.flutter_sensor_ble/event";
    private static final String TAG = "BlePeripheral";

    private BluetoothManager bluetoothManager;
    private BluetoothAdapter bluetoothAdapter;
    private BluetoothLeAdvertiser bluetoothLeAdvertiser;
    private BluetoothGattServer bluetoothGattServer;

    private EventChannel.EventSink eventSink;
    private final Set<BluetoothDevice> registeredDevices = new HashSet<>();
    private BluetoothGattService gattService;
    private BluetoothGattCharacteristic gattCharacteristic;

    // Standard Bluetooth UUID for Client Characteristic Configuration Descriptor (CCCD)
    private static final UUID CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // --- Event Channel Setup ---
        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), EVENT_CHANNEL).setStreamHandler(
            new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object arguments, EventChannel.EventSink events) {
                    eventSink = events;
                }

                @Override
                public void onCancel(Object arguments) {
                    eventSink = null;
                }
            }
        );

        // --- Method Channel Setup ---
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), METHOD_CHANNEL).setMethodCallHandler(
            (call, result) -> {
                // By adding curly braces {} to each case, we create a new scope for variables,
                // which prevents naming conflicts like the one causing the error.
                switch (call.method) {
                    case "initialize": {
                        initializeBle();
                        result.success(null);
                        break;
                    }
                    case "addService": {
                        String serviceUuid = call.argument("serviceUuid");
                        String characteristicUuid = call.argument("characteristicUuid");
                        addService(serviceUuid, characteristicUuid);
                        result.success(null);
                        break;
                    }
                    /*
                     The erroneous, unreachable code block that was here has been removed.
                     It was redeclaring 'serviceUuid', which caused the compilation error.
                    */
                    case "startAdvertising": {
                        String deviceName = call.argument("deviceName");
                        startAdvertising(deviceName);
                        result.success(null);
                        break;
                    }
                    case "stopAdvertising": {
                        stopAdvertising();
                        result.success(null);
                        break;
                    }
                    case "updateCharacteristic": {
                        byte[] value = call.argument("value");
                        updateCharacteristic(value);
                        result.success(null);
                        break;
                    }
                    default: {
                        result.notImplemented();
                        break;
                    }
                }
            }
        );
    }

    private void initializeBle() {
        bluetoothManager = (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);
        bluetoothAdapter = bluetoothManager.getAdapter();
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled()) {
            Log.e(TAG, "Bluetooth is not enabled or not available.");
            sendEvent("advertisingStatus", new HashMap<String, Object>() {{
                put("isAdvertising", false);
                put("error", "Bluetooth not enabled");
            }});
            return;
        }
        bluetoothLeAdvertiser = bluetoothAdapter.getBluetoothLeAdvertiser();
        bluetoothGattServer = bluetoothManager.openGattServer(this, gattServerCallback);
    }

    private void addService(String serviceUuidStr, String characteristicUuidStr) {
        if (bluetoothGattServer == null) {
            Log.e(TAG, "GATT Server not initialized.");
            return;
        }
        UUID serviceUuid = UUID.fromString(serviceUuidStr);
        UUID characteristicUuid = UUID.fromString(characteristicUuidStr);

        gattCharacteristic = new BluetoothGattCharacteristic(
            characteristicUuid,
            BluetoothGattCharacteristic.PROPERTY_READ | BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        );

        // Add the CCCD descriptor to the characteristic
        BluetoothGattDescriptor cccdDescriptor = new BluetoothGattDescriptor(
            CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_READ | BluetoothGattDescriptor.PERMISSION_WRITE
        );
        gattCharacteristic.addDescriptor(cccdDescriptor);

        gattService = new BluetoothGattService(serviceUuid, BluetoothGattService.SERVICE_TYPE_PRIMARY);
        gattService.addCharacteristic(gattCharacteristic);

        bluetoothGattServer.addService(gattService);
        Log.d(TAG, "Service added: " + serviceUuidStr);
    }

    private void startAdvertising(String deviceName) {
        if (bluetoothLeAdvertiser == null) {
            Log.e(TAG, "Advertiser not initialized.");
            sendEvent("advertisingStatus", new HashMap<String, Object>() {{
                put("isAdvertising", false);
                put("error", "Advertiser not initialized");
            }});
            return;
        }

        AdvertiseSettings settings = new AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setConnectable(true)
            .setTimeout(0)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build();

        AdvertiseData data = new AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            // The gattService is already a member variable, so we use it directly.
            .addServiceUuid(new ParcelUuid(gattService.getUuid())) 
            .build();
            
        // Use the deviceName passed from Flutter.
        bluetoothAdapter.setName(deviceName); 
        bluetoothLeAdvertiser.startAdvertising(settings, data, advertiseCallback);
    }

    private void stopAdvertising() {
        if (bluetoothLeAdvertiser != null) {
            bluetoothLeAdvertiser.stopAdvertising(advertiseCallback);
            Log.d(TAG, "Advertising stopped.");
            // **FIX**: Manually send the advertising status update to Flutter.
            sendEvent("advertisingStatus", new HashMap<String, Object>() {{
                put("isAdvertising", false);
            }});
        }
    }

    private void updateCharacteristic(byte[] value) {
        if (gattCharacteristic != null && !registeredDevices.isEmpty()) {
            gattCharacteristic.setValue(value);
            for (BluetoothDevice device : registeredDevices) {
                bluetoothGattServer.notifyCharacteristicChanged(device, gattCharacteristic, false);
            }
        }
    }

    private final AdvertiseCallback advertiseCallback = new AdvertiseCallback() {
        @Override
        public void onStartSuccess(AdvertiseSettings settingsInEffect) {
            Log.d(TAG, "Advertising started successfully.");
            sendEvent("advertisingStatus", new HashMap<String, Object>() {{
                put("isAdvertising", true);
            }});
        }

        @Override
        public void onStartFailure(int errorCode) {
            Log.e(TAG, "Advertising failed with error code: " + errorCode);
            sendEvent("advertisingStatus", new HashMap<String, Object>() {{
                put("isAdvertising", false);
                put("error", "Failed to start advertising: " + errorCode);
            }});
        }
    };

    private final BluetoothGattServerCallback gattServerCallback = new BluetoothGattServerCallback() {
        @Override
        public void onConnectionStateChange(BluetoothDevice device, int status, int newState) {
            super.onConnectionStateChange(device, status, newState);
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.d(TAG, "Device connected: " + device.getAddress());
                sendEvent("connectionState", new HashMap<String, Object>() {{
                    put("isConnected", true);
                }});
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.d(TAG, "Device disconnected: " + device.getAddress());
                registeredDevices.remove(device);
                sendEvent("connectionState", new HashMap<String, Object>() {{
                    put("isConnected", false);
                }});
                // Also send subscription state false on disconnect
                sendEvent("subscriptionState", new HashMap<String, Object>() {{
                    put("isSubscribed", false);
                }});
            }
        }

        @Override
        public void onDescriptorWriteRequest(BluetoothDevice device, int requestId, BluetoothGattDescriptor descriptor, boolean preparedWrite, boolean responseNeeded, int offset, byte[] value) {
            super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value);
            if (CCCD_UUID.equals(descriptor.getUuid())) {
                if (Arrays.equals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE, value)) {
                    Log.d(TAG, "Subscribed to notifications: " + device.getAddress());
                    registeredDevices.add(device);
                    sendEvent("subscriptionState", new HashMap<String, Object>() {{
                        put("isSubscribed", true);
                    }});
                } else if (Arrays.equals(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE, value)) {
                    Log.d(TAG, "Unsubscribed from notifications: " + device.getAddress());
                    registeredDevices.remove(device);
                    sendEvent("subscriptionState", new HashMap<String, Object>() {{
                        put("isSubscribed", false);
                    }});
                }
                if (responseNeeded) {
                    bluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null);
                }
            }
        }
    };

    private void sendEvent(String eventType, HashMap<String, Object> data) {
        if (eventSink != null) {
            data.put("event", eventType);
            runOnUiThread(() -> eventSink.success(data));
        }
    }
}


