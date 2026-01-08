import 'dart:async';
import 'dart:convert';
import 'config/api_keys.dart';




import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;



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

  // Czy było już wykonane wyszukiwanie (żeby nie pokazywać "Brak wyników" od razu)
  bool hasSearched = false;

  // Komunikat o błędzie (jeśli coś nie działa)
  String? error;

  // Wybrany indeks w drawerze/railu
  int _selectedIndex = 2;

  // Debounce
  Timer? _debounce;

  // Wybrany rocznik (tylko rok)
  int? _pickedYear;

  // Prosty cache: make|model|year -> wyniki
  final Map<String, List<Map<String, dynamic>>> _cache = {};

  // Polskie opisy i kolejność (whitelist kluczy do pokazania)
  static const List<String> _detailKeys = [
    'make',
    'model',
    'year',
    'class',
    'fuel_type',
    'drive',
    'transmission',
    'cylinders',
    'displacement',
    'horsepower',
    'torque',
    'doors',
    'curb_weight',
  ];

  final Map<String, String> carLabels = const {
    'make': 'Marka',
    'model': 'Model',
    'year': 'Rok produkcji',
    'class': 'Typ nadwozia',
    'cylinders': 'Liczba cylindrów',
    'displacement': 'Pojemność silnika',
    'drive': 'Napęd',
    'fuel_type': 'Rodzaj paliwa',
    'transmission': 'Skrzynia biegów',
    'doors': 'Liczba drzwi',
    'horsepower': 'Moc silnika',
    'torque': 'Moment obrotowy',
    'curb_weight': 'Masa własna',
  };

  @override
  void initState() {
    super.initState();

    void onTyping() {
      // Debounce: 500 ms po ostatnim znaku
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        // żeby nie spamować: odpal dopiero jak coś ma sens (min 2 znaki albo rok)
        final make = brandCtl.text.trim();
        final model = modelCtl.text.trim();
        final year = yearCtl.text.trim();

        final hasMeaningful =
            (make.length >= 2) || (model.length >= 2) || year.isNotEmpty;
        if (!hasMeaningful) return;

        if (!_validateInputs(showSnack: false)) return;
        fetchCars(autoTriggered: true);
      });
    }

    brandCtl.addListener(onTyping);
    modelCtl.addListener(onTyping);
    yearCtl.addListener(onTyping);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    brandCtl.dispose();
    modelCtl.dispose();
    yearCtl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _validateInputs({required bool showSnack}) {
    final make = brandCtl.text.trim();
    final model = modelCtl.text.trim();
    final yearText = yearCtl.text.trim();

    // tylko podstawowe znaki: litery/cyfry/spacja/kropka/myślnik
    final re = RegExp(r"^[a-zA-Z0-9 .\-]{0,40}$");

    if (make.isNotEmpty && !re.hasMatch(make)) {
      if (showSnack) _showSnack('Marka ma niedozwolone znaki.');
      return false;
    }
    if (model.isNotEmpty && !re.hasMatch(model)) {
      if (showSnack) _showSnack('Model ma niedozwolone znaki.');
      return false;
    }

    if (yearText.isNotEmpty) {
      final y = int.tryParse(yearText);
      final now = DateTime.now().year;
      if (y == null) {
        if (showSnack) _showSnack('Rok musi być liczbą.');
        return false;
      }
      if (y < 1970 || y > now) {
        if (showSnack) _showSnack('Rok musi być w zakresie 1970–$now.');
        return false;
      }
    }

    return true;
  }

  String _cacheKey(String make, String model, String year) =>
      '${make.toLowerCase()}|${model.toLowerCase()}|$year';

  // Czyści wszystkie pola wyszukiwarki i wyniki
  void clearForm() {
    setState(() {
      brandCtl.clear();
      modelCtl.clear();
      yearCtl.clear();
      _pickedYear = null;
      cars = [];
      error = null;
      loading = false;
      hasSearched = false;
    });
  }

  Future<void> _pickYearDialog() async {
    final now = DateTime.now().year;
    final initYear = _pickedYear ?? now;

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Wybierz rocznik'),
          content: SizedBox(
            width: 320,
            height: 360,
            child: YearPicker(
              firstDate: DateTime(1970),
              lastDate: DateTime(now),
              selectedDate: DateTime(initYear),
              onChanged: (d) => Navigator.of(ctx).pop(d.year),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Anuluj'),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      setState(() {
        _pickedYear = picked;
        yearCtl.text = picked.toString();
      });
    }
  }

  // Pobiera dane o autach z API na podstawie tego co wpisał użytkownik
  Future<void> fetchCars({bool autoTriggered = false}) async {
    final brand = brandCtl.text.trim();
    final model = modelCtl.text.trim();
    final year = yearCtl.text.trim();

    if (brand.isEmpty && model.isEmpty && year.isEmpty) {
      if (!autoTriggered) _showSnack('Wpisz markę, model lub rok.');
      return;
    }

    if (!_validateInputs(showSnack: !autoTriggered)) return;

    final key = _cacheKey(brand, model, year);
    if (_cache.containsKey(key)) {
      setState(() {
        cars = _cache[key]!;
        error = null;
        loading = false;
        hasSearched = true;
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
      cars = [];
      hasSearched = true;
    });

    // adres URL do zapytania
    // UWAGA: NIE dodajemy limit/offset, bo free plan API Ninjas zwraca 400 "premium only"
    final url = Uri.https('api.api-ninjas.com', '/v1/cars', {
      if (brand.isNotEmpty) 'make': brand,
      if (model.isNotEmpty) 'model': model,
      if (year.isNotEmpty) 'year': year,
    });

   try {
  final res = await http
      .get(url, headers: {'X-Api-Key': apiNinjasKey, 'Accept': 'application/json'})
      .timeout(const Duration(seconds: 10));

  if (!mounted) return;

      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        final list = List<Map<String, dynamic>>.from(decoded);

        _cache[key] = list;

        setState(() {
          cars = list;
          loading = false;
        });
        return;
      }

      // spróbuj wyciągnąć "error" z body
      String msg = 'Błąd API (HTTP ${res.statusCode})';
      try {
        final body = json.decode(res.body);
        if (body is Map && body['error'] != null) {
          msg = 'Błąd API (HTTP ${res.statusCode}): ${body['error']}';
        } else {
          msg = 'Błąd API (HTTP ${res.statusCode}): ${res.body}';
        }
      } catch (_) {
        msg = 'Błąd API (HTTP ${res.statusCode}): ${res.body}';
      }

      // przyjaźniejsze komunikaty
      if (res.statusCode == 401 || res.statusCode == 403) {
        msg = 'Brak dostępu (HTTP ${res.statusCode}). Sprawdź klucz API.\n$msg';
      } else if (res.statusCode == 429) {
        msg = 'Limit zapytań (HTTP 429). Odczekaj chwilę i spróbuj ponownie.\n$msg';
      } else if (res.statusCode == 400) {
        // często wyskakuje przy premium parametrach typu limit
        msg = 'Błąd zapytania (HTTP 400). Sprawdź dane albo limity API.\n$msg';
      }

      setState(() {
        loading = false;
        error = msg;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Timeout. Sprawdź internet i spróbuj ponownie.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Błąd sieci lub API: $e';
      });
    }
  }

  String _formatValue(String key, dynamic value) {
    if (value == null) return '';
    if (key == 'displacement') {
      final d = (value is num) ? value.toDouble() : double.tryParse('$value');
      if (d == null) return '$value';
      return '${d.toStringAsFixed(2)} l';
    }
    if (key == 'horsepower') {
      final n = (value is num) ? value.toInt() : int.tryParse('$value');
      return n == null ? '$value' : '$n KM';
    }
    if (key == 'torque') {
      final n = (value is num) ? value.toInt() : int.tryParse('$value');
      return n == null ? '$value' : '$n Nm';
    }
    if (key == 'curb_weight') {
      final n = (value is num) ? value.toInt() : int.tryParse('$value');
      return n == null ? '$value' : '$n kg';
    }
    if (key == 'transmission') {
      final s = value.toString().toLowerCase();
      if (s.startsWith('a')) return 'Automat';
      if (s.startsWith('m')) return 'Manual';
      return value.toString();
    }
    return value.toString();
  }

  // Generuje listę szczegółów auta jako widgety (whitelist + formatowanie)
  List<Widget> _carDetails(Map<String, dynamic> car) {
    final List<Widget> details = [];

    for (final key in _detailKeys) {
      final value = car[key];
      if (value == null) continue;

      final s = value.toString().trim();
      if (s.isEmpty || s == 'N/A') continue;

      final label = carLabels[key] ?? key;
      final formatted = _formatValue(key, value);

      details.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: ',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              Expanded(
                child: Text(formatted, style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      );
    }

    if (details.isEmpty) {
      details.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Brak dodatkowych danych do wyświetlenia.'),
      ));
    }

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
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => fetchCars(),
                    decoration: InputDecoration(
                      labelText: 'Marka',
                      prefixIcon: const Icon(Icons.directions_car),
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      fillColor: const Color(0xFFF6F7FA),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: modelCtl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => fetchCars(),
                    decoration: InputDecoration(
                      labelText: 'Model',
                      prefixIcon: const Icon(Icons.search),
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      fillColor: const Color(0xFFF6F7FA),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: yearCtl,
                    readOnly: true,
                    onTap: _pickYearDialog,
                    decoration: InputDecoration(
                      labelText: 'Rok',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      fillColor: const Color(0xFFF6F7FA),
                      filled: true,
                      suffixIcon: yearCtl.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Wyczyść rok',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _pickedYear = null;
                                  yearCtl.clear();
                                });
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: loading ? null : () => fetchCars(),
                  icon: const Icon(Icons.search),
                  label: const Text('Szukaj'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: clearForm,
                  icon: const Icon(Icons.clear),
                  label: const Text('Wyczyść'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (loading) ...[
                  const SizedBox(width: 22),
                  const SizedBox(
                    width: 28,
                    height: 28,
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

  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 18, width: 260, color: Colors.black12),
          const SizedBox(height: 10),
          Container(height: 14, width: 180, color: Colors.black12),
          const SizedBox(height: 10),
          Container(height: 14, width: 220, color: Colors.black12),
        ],
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
        title: const Text('Katalog aut',
            style: TextStyle(
                color: Color(0xFF181947), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              color: Colors.deepPurple,
              onPressed: clearForm),
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
                  _searchPanel(context),

                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                error!,
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              onPressed: loading ? null : () => fetchCars(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Stan początkowy
                  if (!hasSearched && !loading && cars.isEmpty && error == null)
                    const Padding(
                      padding: EdgeInsets.all(26),
                      child: Text(
                        'Wpisz dane i kliknij "Szukaj".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 17),
                      ),
                    ),

                  if (loading) ...List.generate(6, (_) => _skeletonCard()),

                  if (!loading && cars.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                      child: Text(
                        'Znaleziono: ${cars.length} wyników',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                            fontSize: 17),
                      ),
                    ),

                  if (!loading && cars.isNotEmpty)
                    ...cars.asMap().entries.map((entry) {
                      final index = entry.key;
                      final car = entry.value;

                      return AnimatedContainer(
                        duration: Duration(milliseconds: 430 + index * 12),
                        curve: Curves.easeOutBack,
                        margin:
                            const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
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
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            color: Colors.white.withOpacity(0.99),
                            child: Padding(
                              padding: const EdgeInsets.all(19),
                              child: ExpansionTile(
                                backgroundColor: Colors.transparent,
                                collapsedIconColor: Colors.deepPurple.shade300,
                                iconColor: Colors.deepPurple,
                                title: Row(
                                  children: [
                                    Icon(Icons.directions_car,
                                        color: Colors.deepPurple.shade400,
                                        size: 28),
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
                                      color: Colors.deepPurple.shade50
                                          .withOpacity(0.85),
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

                  // Brak wyników dopiero po wyszukaniu
                  if (!loading && hasSearched && cars.isEmpty && error == null)
                    const Padding(
                      padding: EdgeInsets.all(26),
                      child: Text('Brak wyników.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 17)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Drawer (menu boczne)
  Widget _buildDrawer(BuildContext ctx) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B3D91), Color(0xFF63A4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Text(
              'MotoManager',
              style: TextStyle(
                  fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
            ),
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
            onTap: () => Navigator.of(ctx).pop(),
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

  // NavigationRail (panel boczny na desktopie)
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
        NavigationRailDestination(
            icon: Icon(Icons.directions_car), label: Text('Samochody')),
        NavigationRailDestination(
            icon: Icon(Icons.local_gas_station), label: Text('Ceny paliw')),
        NavigationRailDestination(icon: Icon(Icons.search), label: Text('Katalog aut')),
        NavigationRailDestination(icon: Icon(Icons.build), label: Text('Serwis auta')),
      ],
    );
  }
}
