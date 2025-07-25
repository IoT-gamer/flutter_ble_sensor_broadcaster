import UIKit
import Flutter
import CoreBluetooth

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    // --- Channel and BLE Properties ---
    private var methodChannel: FlutterMethodChannel!
    private var eventChannel: FlutterEventChannel!
    private var eventSink: FlutterEventSink?

    private var peripheralManager: CBPeripheralManager!
    private var service: CBMutableService?
    private var characteristic: CBMutableCharacteristic?
    
    // The service and characteristic UUIDs must match the Flutter and Android code.
    private var serviceUuid: CBUUID?
    private var characteristicUuid: CBUUID?
    
    // --- App Lifecycle ---
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller = window?.rootViewController as! FlutterViewController
        let messenger = controller.binaryMessenger
        
        // --- Channel Definitions ---
        let methodChannelName = "com.example.flutter_sensor_ble/method"
        let eventChannelName = "com.example.flutter_sensor_ble/event"

        methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
        eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)

        // --- Method Channel Handler ---
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            switch call.method {
            case "initialize":
                self.initializeBle()
                result(nil)
            case "addService":
                if let args = call.arguments as? [String: Any],
                   let serviceUuidStr = args["serviceUuid"] as? String,
                   let charUuidStr = args["characteristicUuid"] as? String {
                    self.addService(serviceUuidStr: serviceUuidStr, charUuidStr: charUuidStr)
                }
                result(nil)
            case "startAdvertising":
                // Get deviceName from the arguments passed by Flutter
                if let args = call.arguments as? [String: Any],
                   let deviceName = args["deviceName"] as? String {
                    self.startAdvertising(deviceName: deviceName)
                }
                result(nil)
            case "stopAdvertising":
                self.stopAdvertising()
                result(nil)
            case "updateCharacteristic":
                if let args = call.arguments as? [String: Any],
                   let value = args["value"] as? FlutterStandardTypedData {
                    self.updateCharacteristic(value: value.data)
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        // --- Event Channel Handler ---
        eventChannel.setStreamHandler(self)
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // --- BLE Methods ---
    private func initializeBle() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    private func addService(serviceUuidStr: String, charUuidStr: String) {
        guard peripheralManager?.state == .poweredOn else { return }
        
        self.serviceUuid = CBUUID(string: serviceUuidStr)
        self.characteristicUuid = CBUUID(string: charUuidStr)
        
        characteristic = CBMutableCharacteristic(
            type: self.characteristicUuid!,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )
        
        service = CBMutableService(type: self.serviceUuid!, primary: true)
        service!.characteristics = [characteristic!]
        
        peripheralManager.add(service!)
    }

    private func startAdvertising(deviceName: String) {
        guard peripheralManager?.state == .poweredOn, let serviceUuid = self.serviceUuid else {
             sendEvent(type: "advertisingStatus", body: ["isAdvertising": false, "error": "Bluetooth not powered on or service not added."])
            return
        }
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUuid],
            // Use the device name received from Flutter
            CBAdvertisementDataLocalNameKey: deviceName
        ]
        
        peripheralManager.startAdvertising(advertisementData)
    }

    private func stopAdvertising() {
        peripheralManager.stopAdvertising()
        sendEvent(type: "advertisingStatus", body: ["isAdvertising": false])
        print("Advertising stopped.")
    }

    private func updateCharacteristic(value: Data) {
        guard let characteristic = self.characteristic else { return }
        peripheralManager.updateValue(value, for: characteristic, onSubscribedCentrals: nil)
    }

    // --- Helper to Send Events to Flutter ---
    private func sendEvent(type: String, body: [String: Any]) {
        guard let eventSink = self.eventSink else { return }
        var eventBody = body
        eventBody["event"] = type
        eventSink(eventBody)
    }
}

// MARK: - CBPeripheralManagerDelegate
extension AppDelegate: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state != .poweredOn {
            print("Peripheral manager is not powered on.")
            sendEvent(type: "advertisingStatus", body: ["isAdvertising": false, "error": "Bluetooth not powered on."])
        } else {
            print("Peripheral manager is powered on.")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Failed to start advertising: \(error.localizedDescription)")
            sendEvent(type: "advertisingStatus", body: ["isAdvertising": false, "error": error.localizedDescription])
            return
        }
        print("Advertising started successfully.")
        sendEvent(type: "advertisingStatus", body: ["isAdvertising": true])
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic: \(characteristic.uuid)")
        sendEvent(type: "connectionState", body: ["isConnected": true])
        sendEvent(type: "subscriptionState", body: ["isSubscribed": true])
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic: \(characteristic.uuid)")
        sendEvent(type: "connectionState", body: ["isConnected": false])
        sendEvent(type: "subscriptionState", body: ["isSubscribed": false])
    }
}

// MARK: - FlutterStreamHandler
extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
