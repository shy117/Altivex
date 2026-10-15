import 'altimeter_controller.dart';
export 'altimeter_reading.dart';

/// Retained for tests and visual comparison with the archived UI baseline.
class DemoAltimeter extends AltimeterController {
  DemoAltimeter() : super(demo: true);
}
