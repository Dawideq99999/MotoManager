import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Przykładowy placeholder dla FuelPricesScreen
class FuelPricesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Ceny paliw', style: TextStyle(fontSize: 24)));
  }
}

class CarDashboardScreen extends StatefulWidget {
  @override
  _CarDashboardScreenState createState() => _CarDashboardScreenState();
}

class _CarDashboardScreenState extends State<CarDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Kontrolery i pola do zarządzania autami - jak w Twoim kodzie
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _instrunceDateController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _serviceDateController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  String? _selectedFuelType;
  final List<String> _fuelTypes = ['Benzyna', 'Diesel', 'Elektryczny', 'Hybryda'];

  bool _isEditing = false;
  String? _editingDocId;

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchCarsFuture() {
    return _firestore.collection('Cars').get();
  }

  void _clearControllers() {
    _brandController.clear();
    _instrunceDateController.clear();
    _modelController.clear();
    _serviceDateController.clear();
    _yearController.clear();
    _selectedFuelType = null;
    _isEditing = false;
    _editingDocId = null;
  }

  Future<void> _addOrUpdateCar() async {
    final brand = _brandController.text.trim();
    final instrunceDate = _instrunceDateController.text.trim();
    final model = _modelController.text.trim();
    final serviceDate = _serviceDateController.text.trim();
    final year = _yearController.text.trim();
    final fuelType = _selectedFuelType;

    if (brand.isEmpty || instrunceDate.isEmpty || model.isEmpty || serviceDate.isEmpty || year.isEmpty || fuelType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wypełnij wszystkie pola!')),
      );
      return;
    }

    final carData = {
      'Brand': brand,
      'InstrunceDate': instrunceDate,
      'Model': model,
      'ServiceDate': serviceDate,
      'Year': year,
      'FuelType': fuelType,
    };

    try {
      if (_isEditing && _editingDocId != null) {
        await _firestore.collection('Cars').doc(_editingDocId).update(carData);
      } else {
        await _firestore.collection('Cars').add(carData);
      }
      Navigator.of(context).pop();
      _clearControllers();
      setState(() {}); // odśwież widok po zmianach
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd zapisu: $e')),
      );
    }
  }

  Future<void> _deleteCar(String docId) async {
    try {
      await _firestore.collection('Cars').doc(docId).delete();
      setState(() {}); // odśwież widok po usunięciu
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd usuwania: $e')),
      );
    }
  }

  void _showAddOrEditCarDialog({Map<String, dynamic>? car, String? docId}) {
    if (car != null) {
      _brandController.text = car['Brand'] ?? '';
      _instrunceDateController.text = car['InstrunceDate'] ?? '';
      _modelController.text = car['Model'] ?? '';
      _serviceDateController.text = car['ServiceDate'] ?? '';
      _yearController.text = car['Year'] ?? '';
      _selectedFuelType = car['FuelType'];
      _isEditing = true;
      _editingDocId = docId;
    } else {
      _clearControllers();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isEditing ? 'Edytuj auto' : 'Dodaj auto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _brandController, decoration: InputDecoration(labelText: 'Marka')),
              TextField(controller: _instrunceDateController, decoration: InputDecoration(labelText: 'Data ubezpieczenia (YYYY-MM-DD)')),
              TextField(controller: _modelController, decoration: InputDecoration(labelText: 'Model')),
              TextField(controller: _serviceDateController, decoration: InputDecoration(labelText: 'Data serwisu (YYYY-MM-DD)')),
              TextField(controller: _yearController, decoration: InputDecoration(labelText: 'Rok')),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedFuelType,
                decoration: InputDecoration(labelText: 'Rodzaj paliwa'),
                items: _fuelTypes.map((fuel) {
                  return DropdownMenuItem(
                    value: fuel,
                    child: Text(fuel),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedFuelType = val;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () {
            Navigator.of(context).pop();
            _clearControllers();
          }, child: Text('Anuluj')),
          ElevatedButton(onPressed: _addOrUpdateCar, child: Text(_isEditing ? 'Zapisz' : 'Dodaj')),
        ],
      ),
    );
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  // Zarządzanie aktualnie wyświetlaną kartą
  int _selectedIndex = 0;

  // Lista widoków do przełączania
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.add(_buildCarListView());
    _pages.add(FuelPricesScreen());
  }

  // Twój widget z listą aut (wydzieliłem, żeby łatwiej przełączać)
  Widget _buildCarListView() {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _fetchCarsFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Błąd ładowania danych: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Brak samochodów'));
        }

        final carsDocs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: carsDocs.length,
          itemBuilder: (context, index) {
            final doc = carsDocs[index];
            final car = doc.data();

            return ListTile(
              leading: Icon(Icons.directions_car),
              title: Text('${car['Brand'] ?? 'Nieznana marka'} ${car['Model'] ?? ''}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rok: ${car['Year'] ?? 'Brak danych'}'),
                  Text('Ubezpieczenie: ${car['InstrunceDate'] ?? 'Brak danych'}'),
                  Text('Serwis: ${car['ServiceDate'] ?? 'Brak danych'}'),
                  Text('Paliwo: ${car['FuelType'] ?? 'Brak danych'}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showAddOrEditCarDialog(car: car, docId: doc.id),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Usuń auto'),
                        content: Text('Na pewno chcesz usunąć to auto?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Anuluj')),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _deleteCar(doc.id);
                            },
                            child: Text('Usuń'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Twoje Auta i Paliwa'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Wyloguj',
            onPressed: _logout,
          ),
          if (_selectedIndex == 0)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () => _showAddOrEditCarDialog(),
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Text('Menu', style: TextStyle(fontSize: 24, color: Colors.white)),
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            ),
            ListTile(
              leading: Icon(Icons.directions_car),
              title: Text('Samochody'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() {
                  _selectedIndex = 0;
                });
                Navigator.of(context).pop(); // zamknij drawer
              },
            ),
            ListTile(
              leading: Icon(Icons.local_gas_station),
              title: Text('Ceny paliw'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() {
                  _selectedIndex = 1;
                });
                Navigator.of(context).pop(); // zamknij drawer
              },
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          // Lewa nawigacja z menu kart na większych ekranach
          if (MediaQuery.of(context).size.width >= 600)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.selected,
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.directions_car),
                  label: Text('Samochody'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.local_gas_station),
                  label: Text('Ceny paliw'),
                ),
              ],
            ),

          // Główna zawartość zajmująca resztę miejsca
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
