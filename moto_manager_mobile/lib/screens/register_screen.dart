import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Ekran rejestracji nowego użytkownika
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// Stan dla ekranu rejestracji
class _RegisterScreenState extends State<RegisterScreen> {
  // Kontrolery do obsługi pól tekstowych (email, hasło, powtórz hasło)
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  bool _isLoading = false; // Flaga, czy trwa rejestracja (dla loadera)

  // Sprzątamy kontrolery przy zamykaniu ekranu
  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  // Funkcja rejestrująca użytkownika w Firebase
  Future<void> _register() async {
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;
    final confirm = _confirmCtl.text;

    // Walidacja pól — czy wszystkie wypełnione?
    if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wypełnij wszystkie pola.')));
      return;
    }
    // Czy hasła są identyczne?
    if (pass != confirm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Hasła nie są identyczne.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Rejestrujemy przez Firebase
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email, password: pass,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zarejestrowano pomyślnie!')));
      Navigator.pop(context); // Wróć na ekran logowania
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Błąd: ${e.message}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Budowanie widoku ekranu
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradientowe tło
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1557C1), Color(0xFFE9EEF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.97),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo lub ikona aplikacji
                    const Icon(Icons.car_repair, color: Color(0xFF0B3D91), size: 56),
                    const SizedBox(height: 10),
                    const Text('Rejestracja',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF0B3D91))),
                    const SizedBox(height: 22),
                    // Pole email
                    TextField(
                      controller: _emailCtl,
                      decoration: _inputDecoration('Email', Icons.email),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    // Pole hasło
                    TextField(
                      controller: _passCtl,
                      decoration: _inputDecoration('Hasło', Icons.lock),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    // Pole powtórz hasło
                    TextField(
                      controller: _confirmCtl,
                      decoration: _inputDecoration('Powtórz hasło', Icons.lock_outline),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    // Przycisk rejestracji
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.app_registration, color: Colors.white),
                        label: Text(_isLoading ? "Rejestruję..." : 'Zarejestruj się',
                            style: const TextStyle(fontSize: 16)),
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B3D91),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Link powrotu do logowania
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Masz już konto? Zaloguj się'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Dekoracja pól formularza (etykieta, ikona, itp.)
  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        filled: true,
        fillColor: const Color(0xFFF3F6FA),
      );
}
