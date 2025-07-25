import 'dart:async';
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart';

class OrientationService {
  Stream<OrientationEvent> get orientationStream =>
      RotationSensor.orientationStream;
}
