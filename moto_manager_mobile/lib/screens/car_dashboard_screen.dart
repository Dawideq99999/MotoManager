import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Główny ekran zarządzania autami użytkownika
class CarDashboardScreen extends StatefulWidget {
  const CarDashboardScreen({super.key});
  @override
  State<CarDashboardScreen> createState() => _CarDashboardScreenState();
}

// Klasa ze stanem (logika i zmienne ekranu)
class _CarDashboardScreenState extends State<CarDashboardScreen> with TickerProviderStateMixin {
  // Referencje do baz danych Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Kontrolery do formularza dodawania/edycji auta
  final _brandCtl = TextEditingController();
  final _insuranceCtl = TextEditingController();
  final _modelCtl = TextEditingController();
  final _serviceCtl = TextEditingController();
  final _yearCtl = TextEditingController();

  // Lista dostępnych rodzajów paliwa
  final _fuelTypes = ['Benzyna', 'Diesel', 'Elektryczny', 'Hybryda'];
  String? _selectedFuel; // Aktualnie wybrany rodzaj paliwa

  bool _isEditing = false; // Czy tryb edycji auta?
  String? _editingDocId;   // ID edytowanego auta
  int _selectedIndex = 0;  // Aktualna zakładka menu

  // Kontrolery animacji (do efektu konfetti po dodaniu auta)
  late AnimationController _screenController;
  late AnimationController _confettiController;

  // Inicjalizacja kontrolerów animacji
  @override
  void initState() {
    super.initState();
    _screenController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
  }

  // Zwolnienie pamięci po zamknięciu widoku
  @override
  void dispose() {
    _screenController.dispose();
    _confettiController.dispose();
    _brandCtl.dispose();
    _insuranceCtl.dispose();
    _modelCtl.dispose();
    _serviceCtl.dispose();
    _yearCtl.dispose();
    super.dispose();
  }

  // Pobieranie aut użytkownika z bazy Firestore
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchCars() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    final snap = await _firestore.collection('Cars').where('uid', isEqualTo: uid).get();
    return snap.docs;
  }

  // Czyszczenie formularza i reset stanu dodawania/edycji
  void _clear() {
    _brandCtl.clear();
    _insuranceCtl.clear();
    _modelCtl.clear();
    _serviceCtl.clear();
    _yearCtl.clear();
    _selectedFuel = null;
    _isEditing = false;
    _editingDocId = null;
  }

  // Zapis auta do bazy (dodanie/edycja)
  Future<void> _saveCar() async {
    final brand = _brandCtl.text.trim();
    final insurance = _insuranceCtl.text.trim();
    final model = _modelCtl.text.trim();
    final service = _serviceCtl.text.trim();
    final year = _yearCtl.text.trim();
    final fuel = _selectedFuel;

    // Walidacja: wszystkie pola muszą być wypełnione
    if ([brand, insurance, model, service, year, fuel].contains(null) ||
        brand.isEmpty ||
        insurance.isEmpty ||
        model.isEmpty ||
        service.isEmpty ||
        year.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wypełnij wszystkie pola!')));
      return;
    }

    // Dane auta do bazy
    final data = {
      'Brand': brand,
      'InsuranceDate': insurance,
      'Model': model,
      'ServiceDate': service,
      'Year': year,
      'FuelType': fuel,
      'uid': _auth.currentUser!.uid,
    };

    try {
      if (_isEditing) {
        // Jeśli edytujesz auto, aktualizuj dokument
        await _firestore.collection('Cars').doc(_editingDocId).update(data);
      } else {
        // Dodanie nowego auta – po sukcesie animacja konfetti
        await _firestore.collection('Cars').add(data);
        if (!mounted) return;
        Navigator.of(context).pop();
        _clear();
        _showEpicAnimation();
        setState(() {});
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      _clear();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
    }
  }

  // Usuwanie auta z bazy po id dokumentu
  Future<void> _deleteCar(String id) async {
    await _firestore.collection('Cars').doc(id).delete();
    setState(() {});
  }

  // Wyświetlenie okna dialogowego do dodania/edycji auta
  void _showCarDialog({Map<String, dynamic>? car, String? docId}) {
    if (car != null) {
      // Tryb edycji: uzupełnij pola
      _brandCtl.text = car['Brand'] ?? '';
      _insuranceCtl.text = car['InsuranceDate'] ?? '';
      _modelCtl.text = car['Model'] ?? '';
      _serviceCtl.text = car['ServiceDate'] ?? '';
      _yearCtl.text = car['Year'] ?? '';
      _selectedFuel = car['FuelType'];
      _isEditing = true;
      _editingDocId = docId;
    } else {
      // Tryb dodawania: wyczyść pola
      _clear();
    }

    // Okno dialogowe formularza auta
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF8FBFF),
        title: Row(
          children: [
            Icon(_isEditing ? Icons.edit : Icons.add_circle, color: Color(0xFF0B3D91)),
            const SizedBox(width: 10),
            Text(_isEditing ? 'Edytuj auto' : 'Dodaj auto', style: TextStyle(color: Color(0xFF0B3D91))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _formTextField(_brandCtl, 'Marka', Icons.directions_car),
            _formTextField(_modelCtl, 'Model', Icons.directions_car_filled),
            _formTextField(_yearCtl, 'Rok', Icons.calendar_today),
            _formTextField(_insuranceCtl, 'Data ubezpieczenia (YYYY-MM-DD)', Icons.verified_user),
            _formTextField(_serviceCtl, 'Data serwisu (YYYY-MM-DD)', Icons.build),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedFuel,
              items: _fuelTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              decoration: const InputDecoration(
                labelText: 'Rodzaj paliwa',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_gas_station),
              ),
              onChanged: (v) => setState(() => _selectedFuel = v),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: _saveCar,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0B3D91),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_isEditing ? 'Zapisz' : 'Dodaj'),
          ),
        ],
      ),
    );
  }

  // Widget – pole tekstowe formularza (z ikoną)
  Widget _formTextField(TextEditingController ctl, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: ctl,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  // Wylogowanie użytkownika i powrót do ekranu logowania
  void _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Liczenie dni do wybranej daty (np. do serwisu/ubezpieczenia)
  int _daysLeft(String dateString) {
    try {
      final inputDate = DateTime.parse(dateString);
      final now = DateTime.now();
      return inputDate.difference(now).inDays;
    } catch (_) {
      return 99999;
    }
  }

  // Widget ostrzeżenia (np. o wygasającym ubezpieczeniu)
  Widget _buildAlert(String msg, {bool isCritical = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isCritical ? Colors.red.shade300 : Colors.orange.shade300,
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(isCritical ? Icons.warning_amber_rounded : Icons.notifications_active,
              color: isCritical ? Colors.red : Colors.orange, size: 22),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: isCritical ? Colors.red.shade700 : Colors.orange.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget wyświetlający ramkę z autem – ELEGANCKI, PROFESJONALNY
  Widget _buildCarCard(Map<String, dynamic> car, String docId, List<Widget> alerts) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      constraints: const BoxConstraints(maxWidth: 600),
      child: Material(
        elevation: 18,
        borderRadius: BorderRadius.circular(32),
        shadowColor: Colors.deepPurpleAccent.withOpacity(0.13),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: [Color(0xFFF7FAFF), Color(0xFFD3E0F7), Color(0xFFE2E7F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.deepPurple.withOpacity(0.14),
              width: 2.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.09),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Górny rząd: Ikona auta + nazwa + akcje
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ikona samochodu z gradientem
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF8EB1FF), Color(0xFFD3E2FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(0.23),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.transparent,
                        child: Icon(Icons.directions_car, size: 37, color: Color(0xFF224EA9)),
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Dane auta + ewentualne alerty
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${car['Brand']} ${car['Model']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 23,
                              color: Color(0xFF13306D),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          ...alerts,
                        ],
                      ),
                    ),
                    // Akcje: edytuj, usuń
                    Column(
                      children: [
                        Tooltip(
                          message: 'Edytuj',
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF3C6FE1)),
                            onPressed: () => _showCarDialog(car: car, docId: docId),
                          ),
                        ),
                        Tooltip(
                          message: 'Usuń',
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Color(0xFFE14242)),
                            onPressed: () => _deleteCar(docId),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 22, color: Color(0xFFCBD8EF)),
                // Dolny pasek – szczegóły auta
                Wrap(
                  spacing: 24,
                  runSpacing: 10,
                  children: [
                    _buildCarDetailIcon(Icons.calendar_today, 'Rok', car['Year']),
                    _buildCarDetailIcon(Icons.verified_user, 'Ubezp.', car['InsuranceDate']),
                    _buildCarDetailIcon(Icons.build, 'Serwis', car['ServiceDate']),
                    _buildCarDetailIcon(Icons.local_gas_station, 'Paliwo', car['FuelType']),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget pojedynczego szczegółu auta z ikoną (np. rok, paliwo, itp.)
  Widget _buildCarDetailIcon(IconData icon, String label, String? value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: Colors.indigo.shade300),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5466AA)),
        ),
        Text(
          value ?? '-',
          style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF33477A)),
        ),
      ],
    );
  }
  //FutureBuilder
  // Główna lista aut użytkownika (ładne ramki, alerty, wszystko z mapowania)
  Widget _buildCarList() {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _fetchCars(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Błąd: ${snap.error}'));
        }
        final cars = snap.data ?? [];
        if (cars.isEmpty) {
          return const Center(child: Text('Brak samochodów'));
        }

        // Mapowanie po autach – każda ramka z alertami
        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 32),
                ...cars.map((doc) {
                  final car = doc.data();
                  final insuranceLeft = _daysLeft(car['InsuranceDate'] ?? '');
                  final serviceLeft = _daysLeft(car['ServiceDate'] ?? '');

                  // Tworzenie listy alertów (o kończących się terminach)
                  List<Widget> alerts = [];
                  if (insuranceLeft <= 14 && insuranceLeft >= 0) {
                    alerts.add(_buildAlert(
                      insuranceLeft == 0
                          ? 'Uwaga! To ostatni dzień ważności ubezpieczenia!'
                          : 'Uwaga! Tylko $insuranceLeft dni do końca ubezpieczenia!',
                      isCritical: insuranceLeft <= 3,
                    ));
                  } else if (insuranceLeft < 0 && insuranceLeft > -365) {
                    alerts.add(_buildAlert(
                      'Uwaga! Ubezpieczenie już wygasło!',
                      isCritical: true,
                    ));
                  }
                  if (serviceLeft <= 14 && serviceLeft >= 0) {
                    alerts.add(_buildAlert(
                      serviceLeft == 0
                          ? 'Uwaga! To ostatni dzień na wykonanie serwisu!'
                          : 'Uwaga! Tylko $serviceLeft dni do najbliższego serwisu!',
                      isCritical: serviceLeft <= 3,
                    ));
                  } else if (serviceLeft < 0 && serviceLeft > -365) {
                    alerts.add(_buildAlert(
                      'Uwaga! Termin serwisu już minął!',
                      isCritical: true,
                    ));
                  }

                  // Budowanie ramki dla jednego auta
                  return _buildCarCard(car, doc.id, alerts);
                }),
                SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // Drawer (menu boczne)
  Widget _buildDrawer(BuildContext ctx) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B3D91), Color(0xFF63A4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Text('MotoManager', style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.directions_car),
            title: const Text('Samochody'),
            selected: _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.of(ctx).pushReplacementNamed('/dashboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_gas_station),
            title: const Text('Ceny paliw'),
            selected: _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.of(ctx).pushReplacementNamed('/fuel');
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Katalog aut'),
            selected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              Navigator.of(ctx).pushReplacementNamed('/catalog');
            },
          ),
          ListTile(
            leading: const Icon(Icons.build_circle_outlined),
            title: const Text('Serwis'),
            selected: _selectedIndex == 3,
            onTap: () {
              setState(() => _selectedIndex = 3);
              Navigator.of(ctx).pushReplacementNamed('/service');
            },
          ),
        ],
      ),
    );
  }

  // NavigationRail – menu boczne 
  NavigationRail _buildRail(BuildContext ctx) => NavigationRail(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) {
            Navigator.of(ctx).pushReplacementNamed('/dashboard');
          } else if (index == 1) {
            Navigator.of(ctx).pushReplacementNamed('/fuel');
          } else if (index == 2) {
            Navigator.of(ctx).pushReplacementNamed('/catalog');
          } else if (index == 3) {
            Navigator.of(ctx).pushReplacementNamed('/service');
          }
        },
        labelType: NavigationRailLabelType.selected,
        destinations: const [
          NavigationRailDestination(icon: Icon(Icons.directions_car), label: Text('Samochody')),
          NavigationRailDestination(icon: Icon(Icons.local_gas_station), label: Text('Ceny paliw')),
          NavigationRailDestination(icon: Icon(Icons.search), label: Text('Katalog aut')),
          NavigationRailDestination(icon: Icon(Icons.build_circle_outlined), label: Text('Serwis')),
        ],
      );

  // ANIMACJA konfetti po dodaniu auta 
  void _showEpicAnimation() async {
    _screenController.reset();
    _confettiController.reset();
    _screenController.forward();
    _confettiController.forward();
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 800),
      pageBuilder: (ctx, a1, a2) => const SizedBox(),
      transitionBuilder: (ctx, anim, sec, child) {
        return AnimatedBuilder(
          animation: Listenable.merge([_screenController, _confettiController]),
          builder: (ctx, _) {
            double bounce = sin(_screenController.value * pi * 2) * (1 - _screenController.value) * 18;
            double rot = sin(_screenController.value * pi) * 0.07;

            return Transform.translate(
              offset: Offset(bounce, 0),
              child: Transform.rotate(
                angle: rot,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(48),
                          boxShadow: [BoxShadow(color: Colors.greenAccent.shade100, blurRadius: 50)],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.celebration, size: 100, color: Colors.green),
                            SizedBox(height: 10),
                            Text(
                              'Dodano auto!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 26,
                                color: Colors.green,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ..._buildConfetti(_confettiController.value),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop();
  }

  // Tworzenie kolorowych "konfetti" (animacja po dodaniu auta)
  List<Widget> _buildConfetti(double progress) {
    final List<Widget> confetti = [];
    final rnd = Random();
    for (int i = 0; i < 26; i++) {
      final angle = i * 2 * pi / 26;
      final radius = 40.0 + progress * 130 * (0.8 + rnd.nextDouble() * 0.5);
      final x = cos(angle) * radius;
      final y = sin(angle) * radius * (0.7 + rnd.nextDouble() * 0.5);
      final color = Colors.primaries[i % Colors.primaries.length].withOpacity(0.78);
      confetti.add(Positioned(
        left:  MediaQuery.of(context).size.width / 2 + x - 8,
        top:   MediaQuery.of(context).size.height / 2 + y - 8,
        child: Transform.rotate(
          angle: progress * 3 * pi * (i.isEven ? 1 : -1),
          child: Container(
            width: (16 + rnd.nextInt(7)).toDouble(),
            height: (8 + rnd.nextInt(4)).toDouble(),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      ));
    }
    return confetti;
  }

  // Główna budowa widoku ekranu
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Gradient również za AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 0, top: 18, bottom: 12),
          child: Center(
            child: Text(
              'Twoje auta',
              style: const TextStyle(
                color: Color(0xFF0B3D91),
                fontWeight: FontWeight.bold,
                fontSize: 28,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), color: Color(0xFF0B3D91), onPressed: _logout),
          IconButton(icon: const Icon(Icons.add), color: Color(0xFF0B3D91), onPressed: () => _showCarDialog()),
        ],
        toolbarHeight: 74,
      ),
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          // Gradientowe tło dla motoryzacyjnego klimatu
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFE3F2FD),
                  Color(0xFFC5CAE9),
                  Color(0xFFBBDEFB),
                  Color(0xFFE3EAFD),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Row(
            children: [
              if (MediaQuery.of(context).size.width >= 600) _buildRail(context),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: _buildCarList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
