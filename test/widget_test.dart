import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecosytem/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ApiService initializes and supports mock login and kiosk session', () async {
    SharedPreferences.setMockInitialValues({});

    final api = ApiService();
    await api.init();

    expect(api.baseUrl, isNotEmpty);

    // Test authentication
    final user = await api.login(identifier: '0241234567', password: 'password123');
    expect(user.phone, '0241234567');
    expect(api.isAuthenticated, isTrue);

    // Test kiosk tap RFID
    final session = await api.startKioskSessionByRfid('A3 F1 82 4B');
    expect(session.userId, isNotNull);

    // Test bottle deposit
    final updatedSession = await api.recordKioskBottleDeposit(
      bottleClass: 'Clear PET',
      weight: 0.025,
    );
    expect(updatedSession.sessionBottles, 1);
    expect(updatedSession.sessionPoints, greaterThan(0));

    // Test finish session
    final finishedSession = await api.finishKioskSession();
    expect(finishedSession.sessionBottles, 1);
  });
}
