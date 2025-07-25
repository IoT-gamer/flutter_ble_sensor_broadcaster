import 'dart:async';
import 'dart:math';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/orientation_repository.dart';

part 'orientation_state.dart';

class OrientationCubit extends Cubit<OrientationState> {
  final OrientationService _orientationService;
  StreamSubscription? _sensorSubscription;

  OrientationCubit(this._orientationService)
    : super(OrientationState.initial()) {
    _initSensor();
  }

  void _initSensor() {
    _sensorSubscription = _orientationService.orientationStream.listen(
      (orientation) {
        emit(
          OrientationState(
            pitch: orientation.eulerAngles.pitch * 180 / pi,
            roll: orientation.eulerAngles.roll * 180 / pi,
            yaw: orientation.eulerAngles.yaw * 180 / pi,
          ),
        );
      },
      onError: (e) {
        print('Error reading sensor data: $e');
      },
    );
  }

  @override
  Future<void> close() {
    _sensorSubscription?.cancel();
    return super.close();
  }
}
