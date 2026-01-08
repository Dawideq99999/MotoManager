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

  // Toggle hasła
  bool _obscurePass = true;

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
    )..forward();

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj email i hasło')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } on FirebaseAuthException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Błąd: nieprawidłowe dane')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePassword() {
    setState(() => _obscurePass = !_obscurePass);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      children: const [
                        Icon(
                          Icons.directions_car_filled_rounded,
                          color: Color(0xFF0B3D91),
                          size: 54,
                        ),
                        SizedBox(height: 6),
                        Text(
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
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 18),

                  // Pole hasło z 👁️
                  TextField(
                    controller: _passCtl,
                    decoration: _inputDecoration('Hasło', Icons.lock).copyWith(
                      suffixIcon: IconButton(
                        tooltip: _obscurePass ? 'Pokaż hasło' : 'Ukryj hasło',
                        onPressed: _togglePassword,
                        icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    obscureText: _obscurePass,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _isLoading ? null : _login(),
                  ),
                  const SizedBox(height: 30),

                  // Przycisk logowania
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      onPressed: _isLoading ? null : _login,
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

                  // Link do rejestracji
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
        fillColor: const Color.fromARGB(255, 240, 240, 241),
      );
}
