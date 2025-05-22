// Plik wygenerowany automatycznie przez FlutterFire CLI
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Domyślne opcje Firebase dla Twojej aplikacji.
/// 
/// Jak używać:
/// 
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
///

class DefaultFirebaseOptions {
  /// Wybiera odpowiednią konfigurację Firebase w zależności od platformy.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Jeżeli uruchamiamy na webie, zwróć konfigurację webową
      return web;
    }
    // Sprawdza na jakiej platformie uruchamiamy apkę (Android, iOS itd.)
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        // Wyrzuca błąd, jeżeli nie skonfigurowałeś linuxa
        throw UnsupportedError(
          'DefaultFirebaseOptions nie zostały skonfigurowane dla linuxa - '
          'możesz to zmienić, uruchamiając ponownie FlutterFire CLI.',
        );
      default:
        // Jakby pojawiła się jakaś dziwna platforma – błąd
        throw UnsupportedError(
          'DefaultFirebaseOptions nie są wspierane na tej platformie.',
        );
    }
  }

  /// Dane konfiguracyjne dla weba (przeglądarka)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB_t7cFyiSXC-V6P4RO8LO-_UUAtLZaH5A',
    appId: '1:703615843516:web:4729313f16656260ace4b9',
    messagingSenderId: '703615843516',
    projectId: 'lab5-27e91',
    authDomain: 'lab5-27e91.firebaseapp.com',
    databaseURL: 'https://lab5-27e91-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'lab5-27e91.firebasestorage.app',
    measurementId: 'G-6WHTPZ8YYB',
  );

  /// Konfiguracja na iOS 
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAJwxpTPeTyWM3yotW4IfnU2lTg6HOKe9M',
    appId: '1:703615843516:ios:79f83c894e67d312ace4b9',
    messagingSenderId: '703615843516',
    projectId: 'lab5-27e91',
    databaseURL: 'https://lab5-27e91-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'lab5-27e91.firebasestorage.app',
    iosBundleId: 'com.example.motoManagerMobile',
  );

  /// Konfiguracja na macOS
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAJwxpTPeTyWM3yotW4IfnU2lTg6HOKe9M',
    appId: '1:703615843516:ios:79f83c894e67d312ace4b9',
    messagingSenderId: '703615843516',
    projectId: 'lab5-27e91',
    databaseURL: 'https://lab5-27e91-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'lab5-27e91.firebasestorage.app',
    iosBundleId: 'com.example.motoManagerMobile',
  );

  /// Konfiguracja na Windowsa 
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB_t7cFyiSXC-V6P4RO8LO-_UUAtLZaH5A',
    appId: '1:703615843516:web:dd93fae34e4ccf78ace4b9',
    messagingSenderId: '703615843516',
    projectId: 'lab5-27e91',
    authDomain: 'lab5-27e91.firebaseapp.com',
    databaseURL: 'https://lab5-27e91-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'lab5-27e91.firebasestorage.app',
    measurementId: 'G-E5WYDMREWP',
  );

  /// Konfiguracja na Androida
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD1_RCCGVYaTHhevwcFDWsb5IsV4Kl5Hjg',
    appId: '1:703615843516:android:03fab6c6021f02e8ace4b9',
    messagingSenderId: '703615843516',
    projectId: 'lab5-27e91',
    databaseURL: 'https://lab5-27e91-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'lab5-27e91.firebasestorage.app',
  );

}
