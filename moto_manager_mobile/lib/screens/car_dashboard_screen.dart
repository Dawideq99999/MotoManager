import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CarDashboardScreen extends StatefulWidget {
  const CarDashboardScreen({super.key});
  @override
  State<CarDashboardScreen> createState() => _CarDashboardScreenState();
}

class _CarDashboardScreenState extends State<CarDashboardScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _brandCtl = TextEditingController();
  final _insuranceCtl = TextEditingController();
  final _modelCtl = TextEditingController();
  final _serviceCtl = TextEditingController();
  final _yearCtl = TextEditingController();

  final _fuelTypes = ['Benzyna', 'Diesel', 'Elektryczny', 'Hybryda'];
  String? _selectedFuel;

  bool _isEditing = false;
  String? _editingDocId;
  int _selectedIndex = 0; // Ustawiamy na "Samochody"

  late AnimationController _screenController;
  late AnimationController _confettiController;

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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchCars() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    final snap = await _firestore.collection('Cars').where('uid', isEqualTo: uid).get();
    return snap.docs;
  }

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

  Future<void> _saveCar() async {
    final brand = _brandCtl.text.trim();
    final insurance = _insuranceCtl.text.trim();
    final model = _modelCtl.text.trim();
    final service = _serviceCtl.text.trim();
    final year = _yearCtl.text.trim();
    final fuel = _selectedFuel;

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
        await _firestore.collection('Cars').doc(_editingDocId).update(data);
      } else {
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

  Future<void> _deleteCar(String id) async {
    await _firestore.collection('Cars').doc(id).delete();
    setState(() {});
  }

  void _showCarDialog({Map<String, dynamic>? car, String? docId}) {
    if (car != null) {
      _brandCtl.text = car['Brand'] ?? '';
      _insuranceCtl.text = car['InsuranceDate'] ?? '';
      _modelCtl.text = car['Model'] ?? '';
      _serviceCtl.text = car['ServiceDate'] ?? '';
      _yearCtl.text = car['Year'] ?? '';
      _selectedFuel = car['FuelType'];
      _isEditing = true;
      _editingDocId = docId;
    } else {
      _clear();
    }

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

  void _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  int _daysLeft(String dateString) {
    try {
      final inputDate = DateTime.parse(dateString);
      final now = DateTime.now();
      return inputDate.difference(now).inDays;
    } catch (_) {
      return 99999;
    }
  }

  Widget _buildAlert(String msg, {bool isCritical = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical ? Colors.red.shade300 : Colors.orange.shade300,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCritical ? Icons.warning_amber_rounded : Icons.notifications_active,
              color: isCritical ? Colors.red : Colors.orange, size: 22),
          const SizedBox(width: 8),
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

  Widget _buildCarList() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
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

            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: cars.length,
              itemBuilder: (_, i) {
                final car = cars[i].data();
                final insuranceLeft = _daysLeft(car['InsuranceDate'] ?? '');
                final serviceLeft = _daysLeft(car['ServiceDate'] ?? '');

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

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  elevation: 7,
                  margin: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4.0, top: 4),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.indigo.shade100,
                        child: Icon(Icons.directions_car, size: 32, color: Color(0xFF0B3D91)),
                      ),
                      title: Text(
                        '${car['Brand']} ${car['Model']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFF0B3D91)),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...alerts,
                          const SizedBox(height: 2),
                          Text('Rok: ${car['Year']}'),
                          Text('Ubezpieczenie: ${car['InsuranceDate']}'),
                          Text('Serwis: ${car['ServiceDate']}'),
                          Text('Paliwo: ${car['FuelType']}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () => _showCarDialog(car: car, docId: cars[i].id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _deleteCar(cars[i].id),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Twoje auta', style: TextStyle(color: Color(0xFF0B3D91), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.logout), color: Color(0xFF0B3D91), onPressed: _logout),
          IconButton(icon: const Icon(Icons.add), color: Color(0xFF0B3D91), onPressed: () => _showCarDialog()),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          // Motoryzacyjny gradient
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
              Expanded(child: _buildCarList()),
            ],
          ),
        ],
      ),
    );
  }
}
