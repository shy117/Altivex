import 'dart:async';

import 'package:altivex/measurement_hardware.dart';

class FakeHardware implements MeasurementHardware {
  LocationAccess permission = LocationAccess.ready;
  bool? initialServiceEvent;
  int serviceSubscriptions = 0;
  final fixes = StreamController<GeoFix>.broadcast(sync: true);
  final pressures = StreamController<double>.broadcast(sync: true);
  final headings = StreamController<double?>.broadcast(sync: true);
  final services = StreamController<bool>.broadcast(sync: true);
  @override
  Future<LocationAccess> access({required bool request}) async => permission;
  @override
  Stream<GeoFix> positions() => fixes.stream;
  @override
  Stream<double> pressure() => pressures.stream;
  @override
  Stream<double?> heading() => headings.stream;
  @override
  Stream<bool> locationService() {
    serviceSubscriptions++;
    if (initialServiceEvent == null) return services.stream;
    return Stream<bool>.multi((sink) {
      // Bound the replay count so a regression fails instead of looping forever.
      if (serviceSubscriptions <= 4) sink.add(initialServiceEvent!);
      final subscription = services.stream.listen(
        sink.add,
        onError: sink.addError,
        onDone: sink.close,
      );
      sink.onCancel = subscription.cancel;
    });
  }
  Future<void> close() async {
    await Future.wait([
      fixes.close(),
      pressures.close(),
      headings.close(),
      services.close(),
    ]);
  }
}
