import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/orientation_cubit.dart';
import '../cubit/ble_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Sensor Broadcaster'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // Use a MultiBlocListener to react to state changes from both cubits
      body: MultiBlocListener(
        listeners: [
          // This listener handles the continuous streaming of sensor data
          BlocListener<OrientationCubit, OrientationState>(
            listener: (context, orientationState) {
              context.read<BleCubit>().updateCharacteristic(
                orientationState.toCharacteristicString(),
              );
            },
          ),
          // **FIX**: This listener sends an immediate update upon subscription.
          BlocListener<BleCubit, BleState>(
            listenWhen: (previous, current) {
              // Trigger only when the client subscribes for the first time
              return !previous.isSubscribed && current.isSubscribed;
            },
            listener: (context, bleState) {
              // Immediately send the current orientation value to the new subscriber
              final orientationState = context.read<OrientationCubit>().state;
              context.read<BleCubit>().updateCharacteristic(
                orientationState.toCharacteristicString(),
              );
            },
          ),
        ],
        child: BlocBuilder<BleCubit, BleState>(
          builder: (context, bleState) {
            if (bleState.permissionsGranted) {
              return _buildMainContent(context, bleState);
            } else {
              return _buildPermissionRequest(context, bleState);
            }
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, BleState bleState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Live Sensor Data:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            BlocBuilder<OrientationCubit, OrientationState>(
              builder: (context, state) {
                return Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pitch: ${state.pitch.toStringAsFixed(3)}',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Roll:  ${state.roll.toStringAsFixed(3)}',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Yaw:   ${state.yaw.toStringAsFixed(3)}',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            const Text(
              'BLE Control:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              bleState.statusMessage,
              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Text(
              bleState.isSubscribed
                  ? 'Subscription: Active'
                  : 'Subscription: Inactive',
              style: TextStyle(
                fontSize: 16,
                color: bleState.isSubscribed ? Colors.blue : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bleState.isConnected
                  ? 'Status: Connected'
                  : 'Status: Not Connected',
              style: TextStyle(
                fontSize: 16,
                color: bleState.isConnected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: bleState.isAdvertising
                    ? Colors.redAccent
                    : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
              icon: Icon(
                bleState.isAdvertising
                    ? Icons.stop_circle_outlined
                    : Icons.wifi_tethering,
              ),
              label: Text(
                bleState.isAdvertising
                    ? 'Stop Broadcasting'
                    : 'Start Broadcasting',
              ),
              onPressed: !bleState.isBleReady
                  ? null
                  : () {
                      final bleCubit = context.read<BleCubit>();
                      if (bleState.isAdvertising) {
                        bleCubit.stopAdvertising();
                      } else {
                        bleCubit.startAdvertising();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRequest(BuildContext context, BleState bleState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Bluetooth Permissions Required',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              bleState.statusMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<BleCubit>().grantPermissions(),
              child: const Text('Grant Permissions'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.read<BleCubit>().openSettings(),
              child: const Text('Open App Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
