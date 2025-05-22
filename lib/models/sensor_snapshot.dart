
class SensorSnapshot<T> {
  final T? value;
  final DateTime? timestamp;

  SensorSnapshot({this.value, this.timestamp});

  bool isFresh(Duration maxAge, DateTime referenceTime) {
    if (value == null || timestamp == null) return false;
    return referenceTime.difference(timestamp!).abs() <= maxAge;
  }

  SensorSnapshot<T> clear() => SensorSnapshot<T>(value: null, timestamp: null);

  SensorSnapshot<T> update(T newValue) => SensorSnapshot<T>(
        value: newValue,
        timestamp: DateTime.now(),
      );
}