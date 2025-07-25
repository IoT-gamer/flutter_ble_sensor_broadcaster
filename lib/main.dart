import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'cubit/orientation_cubit.dart';
import 'cubit/ble_cubit.dart';
import 'repositories/ble_repository.dart';
import 'repositories/orientation_repository.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Important for plugin initialization
  await WakelockPlus.enable();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SensorBroadcasterApp());
}

class SensorBroadcasterApp extends StatelessWidget {
  const SensorBroadcasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use MultiBlocProvider to make the cubits available to the widget tree
    return MultiBlocProvider(
      providers: [
        BlocProvider<OrientationCubit>(
          create: (context) => OrientationCubit(OrientationService()),
        ),
        BlocProvider<BleCubit>(
          create: (context) =>
              BleCubit(BleRepository())..init(), // Initialize BLE on creation
        ),
      ],
      child: MaterialApp(
        title: 'Sensor BLE Broadcaster',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
