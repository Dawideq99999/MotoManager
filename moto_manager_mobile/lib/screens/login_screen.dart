import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart'; 

/// Główny ekran logowania użytkownika
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // Kontrolery do przechowywania wpisanych danych
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();

  // Flaga ładowania (żeby np. zablokować przycisk na czas logowania)
  bool _isLoading = false;

  // Animacja wejścia loga aplikacji
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    // Inicjalizacja animacji (lekko sprężysta)
    _animController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward(); // Uruchamiamy animację od razu

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut, // Efekt "odbicia" przy pojawianiu się
    );
  }

  @override
  void dispose() {
    // Czyszczenie kontrolerów i animacji po zamknięciu ekranu
    _animController.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  /// Funkcja logowania — wywoływana po kliknięciu przycisku "Zaloguj się"
  Future<void> _login() async {
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;

    // Walidacja czy pola nie są puste
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Podaj email i hasło')));
      return;
    }

    setState(() => _isLoading = true); // Pokazujemy spinner na przycisku

    try {
      // Próba logowania z użyciem Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // Po zalogowaniu przekierowanie na dashboard (bez możliwości cofnięcia)
      Navigator.pushReplacementNamed(context, '/dashboard');
    } on FirebaseAuthException {
      // Jeśli logowanie nie powiedzie się — pokazujemy błąd
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Błąd: nieprawidłowe dane')));
    } finally {
      setState(() => _isLoading = false); // Wyłączamy spinner
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradientowe tło aplikacji (niebieski w dwóch odcieniach)
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B3D91), Color(0xFF6EC6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.97),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 32,
                    offset: Offset(0, 12),
                  ),
                ],
              ),

              // Właściwa zawartość ekranu logowania
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo aplikacji z animacją skalowania
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      children: [
                        Icon(
                          Icons.directions_car_filled_rounded,
                          color: Color(0xFF0B3D91),
                          size: 54,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'MotoManager',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B3D91),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pole e-mail
                  TextField(
                    controller: _emailCtl,
                    decoration: _inputDecoration('Email', Icons.email),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 18),

                  // Pole hasło
                  TextField(
                    controller: _passCtl,
                    decoration: _inputDecoration('Hasło', Icons.lock),
                    obscureText: true,
                  ),
                  const SizedBox(height: 30),

                  // Przycisk logowania (z loaderem w trakcie działania)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      onPressed: _isLoading ? null : _login, // Blokujemy kliknięcie podczas logowania
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 231, 235, 243),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      label: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Zaloguj się',
                              style: TextStyle(fontSize: 17),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Link do rejestracji konta
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text(
                      'Nie masz konta? Zarejestruj się',
                      style: TextStyle(color: Color(0xFF0B3D91)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pomocnicza funkcja do stylizacji pól tekstowych
  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
        fillColor: const Color.fromARGB(255, 240, 240, 241), // Jasne tło pól tekstowych
      );
}
