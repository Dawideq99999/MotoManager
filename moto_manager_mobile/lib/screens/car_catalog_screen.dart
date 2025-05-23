import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Klucz do API ninjas (do pobierania danych o samochodach)
const apiKey = 'gtQlZ/YXtb1hDOxFvn594g==ty1WUiXdcDd3jX1M';

class CarCatalogScreen extends StatefulWidget {
  const CarCatalogScreen({Key? key}) : super(key: key);

  @override
  State<CarCatalogScreen> createState() => _CarCatalogScreenState();
}

class _CarCatalogScreenState extends State<CarCatalogScreen> {
  // Kontrolery do pól wyszukiwania
  final TextEditingController brandCtl = TextEditingController();
  final TextEditingController modelCtl = TextEditingController();
  final TextEditingController yearCtl = TextEditingController();

  // Lista pobranych samochodów
  List<Map<String, dynamic>> cars = [];
  // Czy trwa pobieranie?
  bool loading = false;
  // Komunikat o błędzie (jeśli coś nie działa)
  String? error;
  // Wybrany indeks w drawerze/railu
  int _selectedIndex = 2;

  // Wybrany rocznik (jako data) - do pickerka
  DateTime? _pickedYear;

  // Polskie opisy do kluczy samochodu
  final Map<String, String> carLabels = const {
    'make': 'Marka',
    'model': 'Model',
    'year': 'Rok produkcji',
    'class': 'Typ nadwozia',
    'cylinders': 'Liczba cylindrów',
    'displacement': 'Pojemność silnika (l)',
    'drive': 'Napęd',
    'fuel_type': 'Rodzaj paliwa',
    'transmission': 'Skrzynia biegów',
    'doors': 'Liczba drzwi',
    'horsepower': 'Moc silnika (KM)',
    'torque': 'Moment obrotowy (Nm)',
    'city_mpg': 'Spalanie miasto (mpg)',
    'highway_mpg': 'Spalanie trasa (mpg)',
    'combination_mpg': 'Spalanie średnie (mpg)',
    'fuel_tank_capacity': 'Pojemność zbiornika paliwa (l)',
    'length': 'Długość (mm)',
    'width': 'Szerokość (mm)',
    'height': 'Wysokość (mm)',
    'curb_weight': 'Masa własna (kg)',
    'max_speed': 'Prędkość maksymalna (km/h)',
    'zero_to_sixty_mph': '0-100 km/h (s)',
  };

  // Czyści wszystkie pola wyszukiwarki i wyniki
  void clearForm() {
    setState(() {
      brandCtl.clear();
      modelCtl.clear();
      yearCtl.clear();
      _pickedYear = null;
      cars = [];
      error = null;
    });
  }
  //setState
  // Pobiera dane o autach z API na podstawie tego co wpisał użytkownik
  Future<void> fetchCars() async {
    setState(() {
      loading = true;
      error = null;
      cars = [];
    });

    final brand = brandCtl.text.trim();
    final model = modelCtl.text.trim();
    final year = yearCtl.text.trim();

    //  adres URL do zapytania
    var url = Uri.https('api.api-ninjas.com', '/v1/cars', {
      if (brand.isNotEmpty) 'make': brand,
      if (model.isNotEmpty) 'model': model,
      if (year.isNotEmpty) 'year': year,
    });

    try {
      // Robimy zapytanie GET do API (z kluczem w nagłówkach)
      final res = await http.get(url, headers: {'X-Api-Key': apiKey});
      if (res.statusCode == 200) {
        // Sukces, parsujemy JSON i pokazujemy wyniki
        final decoded = json.decode(res.body);
        setState(() {
          cars = List<Map<String, dynamic>>.from(decoded);
          loading = false;
        });
      } else {
        // Jakiś błąd odpowiedzi API
        setState(() {
          loading = false;
          error = 'Błąd API (kod ${res.statusCode})';
        });
      }
    } catch (e) {
      // Złapany błąd sieciowy lub inny problem
      setState(() {
        loading = false;
        error = 'Błąd sieci lub API: $e';
      });
    }
  }

  // Generuje listę szczegółów auta jako widgety (wyklucza puste/N/A itp.)
  List<Widget> _carDetails(Map<String, dynamic> car) {
    final List<Widget> details = [];
    car.forEach((key, value) {
      if (value == null ||
          value.toString().isEmpty ||
          value.toString().contains('for premium') ||
          value.toString().contains('N/A')) return;
      final label = carLabels[key] ?? key;
      details.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
              Expanded(
                child: Text('$value', style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      );
    });
    return details;
  }

  // Wygląd panelu wyszukiwania (pola + przyciski)
  Widget _searchPanel(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.only(top: 24, bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.93),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.09),
              blurRadius: 28,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Wyszukaj auto wg marki, modelu lub rocznika.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: brandCtl,
                    decoration: InputDecoration(
                      labelText: 'Marka',
                      prefixIcon: const Icon(Icons.directions_car),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      fillColor: const Color(0xFFF6F7FA),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: modelCtl,
                    decoration: InputDecoration(
                      labelText: 'Model',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      fillColor: const Color(0xFFF6F7FA),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Pole wyboru rocznika przez date picker
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: yearCtl,
                    readOnly: true,
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _pickedYear ?? DateTime(now.year, 1, 1),
                        firstDate: DateTime(1970),
                        lastDate: DateTime(now.year, 12, 31),
                        helpText: 'Wybierz rocznik',
                        fieldLabelText: 'Rok',
                        initialEntryMode: DatePickerEntryMode.calendarOnly,
                      );
                      if (picked != null) {
                        setState(() {
                          _pickedYear = picked;
                          yearCtl.text = picked.year.toString();
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Rok',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      fillColor: const Color(0xFFF6F7FA),
                      filled: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                // Przycisk do szukania
                ElevatedButton.icon(
                  onPressed: loading ? null : fetchCars,
                  icon: const Icon(Icons.search),
                  label: const Text('Szukaj'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                // Przycisk do czyszczenia
                OutlinedButton.icon(
                  onPressed: clearForm,
                  icon: const Icon(Icons.clear),
                  label: const Text('Wyczyść'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (loading) ...[
                  const SizedBox(width: 22),
                  const SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.92),
        elevation: 1,
        title: const Text('Katalog aut', style: TextStyle(color: Color(0xFF181947), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), color: Colors.deepPurple, onPressed: clearForm),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE6EDF5), Color(0xFFC6E0F7), Color(0xFFD9E7F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            if (MediaQuery.of(context).size.width >= 600) _buildRail(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                children: [
                  // Panel wyszukiwania
                  _searchPanel(context),
                  // Błąd API/sieci jeśli wystąpił
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  // Ilość znalezionych wyników
                  if (cars.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                      child: Text(
                        'Znaleziono: ${cars.length > 50 ? "50+" : cars.length} wyników',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 17),
                      ),
                    ),
                  // Lista wyników jako karty z animacjami
                  if (cars.isNotEmpty)
                    ...cars.take(50).toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final car = entry.value;
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 430 + index * 12),
                        curve: Curves.easeOutBack,
                        margin: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
                        child: TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 420 + index * 15),
                          tween: Tween(begin: 0, end: 1),
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 28),
                              child: child,
                            ),
                          ),
                          child: Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            color: Colors.white.withOpacity(0.99),
                            child: Padding(
                              padding: const EdgeInsets.all(19),
                              child: ExpansionTile(
                                backgroundColor: Colors.transparent,
                                collapsedIconColor: Colors.deepPurple.shade300,
                                iconColor: Colors.deepPurple,
                                title: Row(
                                  children: [
                                    Icon(Icons.directions_car, color: Colors.deepPurple.shade400, size: 28),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${car['make']?.toString().toUpperCase() ?? ''} '
                                        '${car['model']?.toString().toUpperCase() ?? ''} '
                                        '(${car['year'] ?? ''})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Color(0xFF1A237E),
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade50.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: _carDetails(car),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  // Komunikat, gdy brak wyników i brak błędów
                  if (!loading && cars.isEmpty && error == null)
                    const Padding(
                      padding: EdgeInsets.all(26),
                      child: Text('Brak wyników.', style: TextStyle(color: Colors.black54, fontSize: 17)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Drawer (menu boczne) z nową zakładką "Serwis auta"
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
              Navigator.of(ctx).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text('Serwis auta'),
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

  // NavigationRail (panel boczny na desktopie) z zakładką "Serwis auta"
  Widget _buildRail(BuildContext ctx) {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (idx) {
        setState(() => _selectedIndex = idx);
        if (idx == 0) {
          Navigator.of(ctx).pushReplacementNamed('/dashboard');
        } else if (idx == 1) {
          Navigator.of(ctx).pushReplacementNamed('/fuel');
        } else if (idx == 2) {
          Navigator.of(ctx).pushReplacementNamed('/catalog');
        } else if (idx == 3) {
          Navigator.of(ctx).pushReplacementNamed('/service');
        }
      },
      labelType: NavigationRailLabelType.selected,
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.directions_car), label: Text('Samochody')),
        NavigationRailDestination(icon: Icon(Icons.local_gas_station), label: Text('Ceny paliw')),
        NavigationRailDestination(icon: Icon(Icons.search), label: Text('Katalog aut')),
        NavigationRailDestination(icon: Icon(Icons.build), label: Text('Serwis auta')), 
      ],
    );
  }
}
