import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  static FirebaseOptions get currentPlatform {
    if (useEmulators) {
      return const FirebaseOptions(
        apiKey: 'demo-key',
        appId: '1:123456789:web:demo',
        messagingSenderId: '123456789',
        projectId: 'demo-bloco-notas',
        authDomain: 'demo-bloco-notas.firebaseapp.com',
      );
    }
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if ([apiKey, appId, senderId, projectId].any((value) => value.isEmpty)) {
      throw StateError(
        'Configure o arquivo firebase.local.json conforme o README.',
      );
    }
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    );
  }
}
