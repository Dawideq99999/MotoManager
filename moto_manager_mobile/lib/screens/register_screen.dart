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

  bool _isLoading = false;

  // Toggle hasła
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;
    final confirm = _confirmCtl.text;

    if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wypełnij wszystkie pola.')),
      );
      return;
    }

    if (pass.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasło musi mieć minimum 6 znaków.')),
      );
      return;
    }

    if (pass != confirm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasła nie są identyczne.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zarejestrowano pomyślnie!')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String msg = 'Błąd: ${e.message ?? "Coś poszło nie tak"}';
      if (e.code == 'email-already-in-use') msg = 'Ten email jest już zajęty.';
      if (e.code == 'invalid-email') msg = 'Niepoprawny format emaila.';
      if (e.code == 'weak-password') msg = 'Hasło jest za słabe (daj dłuższe).';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePass() => setState(() => _obscurePass = !_obscurePass);
  void _toggleConfirm() => setState(() => _obscureConfirm = !_obscureConfirm);

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
                    const Icon(Icons.car_repair, color: Color(0xFF0B3D91), size: 56),
                    const SizedBox(height: 10),
                    const Text(
                      'Rejestracja',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B3D91),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Email
                    TextField(
                      controller: _emailCtl,
                      decoration: _inputDecoration('Email', Icons.email),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Hasło + 👁️
                    TextField(
                      controller: _passCtl,
                      decoration: _inputDecoration('Hasło', Icons.lock).copyWith(
                        suffixIcon: IconButton(
                          tooltip: _obscurePass ? 'Pokaż hasło' : 'Ukryj hasło',
                          onPressed: _togglePass,
                          icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      obscureText: _obscurePass,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Powtórz hasło + 👁️
                    TextField(
                      controller: _confirmCtl,
                      decoration: _inputDecoration('Powtórz hasło', Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirm ? 'Pokaż hasło' : 'Ukryj hasło',
                          onPressed: _toggleConfirm,
                          icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _isLoading ? null : _register(),
                    ),
                    const SizedBox(height: 24),

                    // Przycisk rejestracji
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.app_registration, color: Colors.white),
                        label: Text(
                          _isLoading ? "Rejestruję..." : 'Zarejestruj się',
                          style: const TextStyle(fontSize: 16),
                        ),
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

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        filled: true,
        fillColor: const Color(0xFFF3F6FA),
      );
}
