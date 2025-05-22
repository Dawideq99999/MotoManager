import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Plik z konfiguracją Firebase (wygenerowany automatycznie przez FlutterFire CLI)
import 'firebase_options.dart';

// Importy ekranów aplikacji
import 'screens/login_screen.dart';
import 'screens/car_dashboard_screen.dart';
import 'screens/fuel_prices_screen.dart';
import 'screens/car_catalog_screen.dart';
import 'screens/car_service_screen.dart';

/// Funkcja główna aplikacji - uruchamiana przy starcie.
/// Inicjalizujemy Fluttera i Firebase, a następnie uruchamiamy naszą aplikację.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Upewniamy się, że Flutter jest w pełni zainicjowany
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Inicjalizacja Firebase z wygenerowanymi opcjami (dla Androida/iOS/Web)
  );
  runApp(const MyApp()); // Uruchamiamy główny widget aplikacji
}

/// Główny widget aplikacji.
/// Tu konfigurujemy motyw, trasy i decydujemy co pokazać jako pierwszy ekran.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MotoManager', // Tytuł aplikacji
      debugShowCheckedModeBanner: false, // Usuwamy czerwony pasek "debug" z rogu ekranu
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, // Główna paleta kolorów (np. dla AppBar)
        useMaterial3: true, // Włączamy Material 3 (nowszy styl interfejsu Google)
      ),
      // Mapujemy trasy do konkretnych ekranów
      routes: {
        '/login': (_) => const LoginScreen(), // Ekran logowania
        '/dashboard': (_) => const CarDashboardScreen(), // Ekran główny po zalogowaniu
        '/fuel': (_) => const FuelPricesScreen(), // Ekran z cenami paliw
        '/catalog': (_) => const CarCatalogScreen(), // Katalog samochodów
        '/service': (_) => const CarServiceScreen(), // Historia serwisowa itp.
      },
      // Zamiast `initialRoute`, używamy `home`, który sprawdza zalogowanie użytkownika
      home: const AuthGate(),
    );
  }
}

/// Widget startowy, który decyduje, czy użytkownik jest zalogowany.
/// Jeśli tak — przechodzimy do dashboardu. Jeśli nie — pokaż ekran logowania.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Nasłuchujemy zmian w stanie uwierzytelnienia użytkownika
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Pokazujemy loader, dopóki nie wiemy, czy ktoś jest zalogowany
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()), // Prosty spinner ładowania
          );
        }

        // Jeśli użytkownik jest zalogowany — przejdź do dashboardu
        if (snapshot.hasData && snapshot.data != null) {
          return const CarDashboardScreen();
        }

        // W przeciwnym razie — pokaż ekran logowania
        return const LoginScreen();
      },
    );
  }
}
