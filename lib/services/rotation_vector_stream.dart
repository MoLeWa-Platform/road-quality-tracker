import 'dart:async';
import 'package:flutter/services.dart';

class RotationVectorStream {
  static const EventChannel _eventChannel =
      EventChannel('rotation_vector_channel');

  static Stream<List<double>>? _rotationVectorStream;

  static Stream<List<double>> get stream {
    _rotationVectorStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => (event as List<dynamic>).cast<double>());
    return _rotationVectorStream!;
  }
}