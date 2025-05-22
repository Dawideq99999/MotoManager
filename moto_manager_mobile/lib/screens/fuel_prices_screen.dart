import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'car_catalog_screen.dart';
import 'car_dashboard_screen.dart';
import 'car_service_screen.dart'; // import do ekranu serwisów

// EKRAN TANKOWAŃ I CEN PALIW
class FuelPricesScreen extends StatefulWidget {
  const FuelPricesScreen({Key? key}) : super(key: key);

  @override
  State<FuelPricesScreen> createState() => _FuelPricesScreenState();
}

class _FuelPricesScreenState extends State<FuelPricesScreen> {
  final _firestore = FirebaseFirestore.instance; // Połączenie z Firestore
  final _auth = FirebaseAuth.instance;           // Autoryzacja użytkownika

  int _selectedIndex = 1; // Do nawigacji Drawer/Rail

  // --- STAN FORMULARZA TANKOWANIA ---
  String? _selectedCarId;
  String? _selectedFuelType;
  final _litersCtl = TextEditingController(); // Kontroler litry
  final _priceCtl  = TextEditingController(); // Kontroler cena za litr
  final _totalCtl  = TextEditingController(); // Kontroler łączna kwota
  DateTime _selectedDate = DateTime.now();    // Data tankowania
  bool _manualTotal = true; // DOMYŚLNIE wpisujemy tylko łączną kwotę!

  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _carsCache; // Cache aut (żeby nie pobierać za każdym razem)

  // Pobieranie samochodów użytkownika z bazy
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getCars() async {
    final uid = _auth.currentUser!.uid;
    final snap = await _firestore.collection('Cars').where('uid', isEqualTo: uid).get();
    return snap.docs;
  }

  // Czyszczenie kontrolerów po zamknięciu ekranu
  @override
  void dispose() {
    _litersCtl.dispose();
    _priceCtl.dispose();
    _totalCtl.dispose();
    super.dispose();
  }

  // Picker do wyboru daty tankowania (wywołuje kalendarz)
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.deepPurple.shade600,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.deepPurple.shade900,
          ),
          dialogBackgroundColor: Colors.white,
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // Zapisanie tankowania do Firestore (obsługuje oba tryby)
  Future<void> _saveFill() async {
    double? liters;
    double? pricePerL;
    double? totalCost;

    if (_manualTotal) {
      // Jeśli wpisujemy tylko łączną kwotę (tryb uproszczony)
      totalCost = double.tryParse(_totalCtl.text.replaceAll(',', '.'));
      if (totalCost == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Podaj kwotę.')));
        return;
      }
      liters = 0;
      pricePerL = 0;
    } else {
      // Jeśli podajemy litry i cenę za litr (tryb klasyczny)
      liters = double.tryParse(_litersCtl.text.replaceAll(',', '.'));
      pricePerL = double.tryParse(_priceCtl.text.replaceAll(',', '.'));
      if (liters == null || pricePerL == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uzupełnij liczbę litrów i cenę za litr.')));
        return;
      }
      totalCost = liters * pricePerL;
    }

    if (_selectedCarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wybierz auto.')));
      return;
    }

    // Dodanie rekordu do kolekcji "Fule" (tankowania)
    await _firestore.collection('Fule').add({
      'uid': _auth.currentUser!.uid,
      'carId': _selectedCarId,
      'fuelType': _selectedFuelType,
      'date': Timestamp.fromDate(_selectedDate),
      'liters': liters,
      'pricePerL': pricePerL,
      'totalCost': totalCost,
    });

    // Czyścimy pola formularza
    _litersCtl.clear();
    _priceCtl.clear();
    _totalCtl.clear();
    setState(() {}); // Odśwież widok
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Tankowania & ceny paliw', style: TextStyle(color: Color(0xFF0B3D91), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF0B3D91)),
      ),
      body: Stack(
        children: [
          // Gradientowe tło
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF6F9FF),
                  Color(0xFFE0E8F7),
                  Color(0xFFD7ECFF),
                  Color(0xFFCCDCFF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Row(
            children: [
              if (MediaQuery.of(context).size.width >= 650) _buildRail(context), // Rail na szerokich ekranach
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                      future: _carsCache == null ? _getCars() : null,
                      initialData: _carsCache,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final cars = snap.data ?? [];
                        if (cars.isEmpty) {
                          return const Center(child: Text('Najpierw dodaj auto 😉'));
                        }
                        if (_selectedCarId == null) {
                          // Domyślnie wybieramy pierwsze auto i jego typ paliwa
                          _selectedCarId = cars.first.id;
                          _selectedFuelType = cars.first.data()['FuelType'];
                        }
                        _carsCache = cars;
                        return _buildMainContent(cars); // Główna zawartość ekranu
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Drawer boczny (menu nawigacji)
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
              Navigator.of(ctx).pushReplacement(MaterialPageRoute(builder: (_) => const CarDashboardScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_gas_station),
            title: const Text('Ceny paliw'),
            selected: _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.of(ctx).pushReplacement(MaterialPageRoute(builder: (_) => const FuelPricesScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Katalog aut'),
            selected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              Navigator.of(ctx).pushReplacement(MaterialPageRoute(builder: (_) => const CarCatalogScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text('Serwis auta'),
            selected: _selectedIndex == 3,
            onTap: () {
              setState(() => _selectedIndex = 3);
              Navigator.of(ctx).pushReplacement(MaterialPageRoute(builder: (_) => const CarServiceScreen()));
            },
          ),
        ],
      ),
    );
  }

  // Nawigacja boczna (Rail)
  Widget _buildRail(BuildContext ctx) {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (idx) {
        setState(() => _selectedIndex = idx);
        if (idx == 0) {
          Navigator.of(ctx).pushReplacement(MaterialPageRoute(builder: (_) => const CarDashboardScreen()));
        } else if (idx == 1) {
          Navigator.of(ctx).pushReplacement(MaterialPageRoute(builder: (_) => const FuelPricesScreen()));
        } else if (idx == 2) {
          Navigator.of(ctx).pushReplacement(MaterialPageRoute(builder: (_) => const CarCatalogScreen()));
        } else if (idx == 3) {
          Navigator.of(ctx).pushReplacement(MaterialPageRoute(builder: (_) => const CarServiceScreen()));
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

  // Główna zawartość ekranu: wybór auta, formularz, historia, wykres
  Widget _buildMainContent(List<QueryDocumentSnapshot<Map<String, dynamic>>> cars) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 40, left: 14, right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sekcja wyboru auta i rodzaju paliwa
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            elevation: 6,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car, color: Color(0xFF0B3D91)),
                      const SizedBox(width: 8),
                      const Text('Wybierz auto:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedCarId,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: const Color(0xFFF8FBFF),
                    ),
                    items: cars.map((doc) {
                      final c = doc.data();
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text('${c['Brand']} ${c['Model']} (${c['Year']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCarId = val;
                        _selectedFuelType = cars.firstWhere((d) => d.id == val).data()['FuelType'];
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.local_gas_station, size: 22, color: Color(0xFF0B3D91)),
                      const SizedBox(width: 7),
                      Text(_selectedFuelType ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Przycisk do strony z cenami paliw
          Center(
            child: ElevatedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://www.autocentrum.pl/paliwa/ceny-paliw/'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.link),
              label: const Text('Zobacz aktualne ceny paliw'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Formularz dodawania tankowania
          Card(
            elevation: 5,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Przełącznik trybu formularza (tylko łączna kwota <-> klasyczny)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wpisuję tylko łączną kwotę', style: TextStyle(fontSize: 15)),
                    value: _manualTotal,
                    onChanged: (val) {
                      setState(() {
                        _manualTotal = val;
                        _litersCtl.clear();
                        _priceCtl.clear();
                        _totalCtl.clear();
                      });
                    },
                  ),
                  if (!_manualTotal) ...[
                    // Klasyczny tryb — wpisujesz litry i cenę za litr
                    TextField(
                      controller: _litersCtl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Liczba litrów',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.local_gas_station),
                        filled: true,
                        fillColor: const Color(0xFFF8FBFF),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _priceCtl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cena za litr (zł)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.price_change),
                        filled: true,
                        fillColor: const Color(0xFFF8FBFF),
                      ),
                    ),
                  ] else ...[
                    // Tryb wpisywania tylko kwoty (domyślny)
                    TextField(
                      controller: _totalCtl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Łączny koszt (zł)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.payments),
                        filled: true,
                        fillColor: const Color(0xFFF8FBFF),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Wiersz z datą i przyciskami
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 19, color: Colors.deepPurple.shade600),
                      const SizedBox(width: 7),
                      Text(DateFormat('yyyy-MM-dd').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.date_range, size: 19),
                        label: const Text('Zmień datę', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          backgroundColor: Colors.deepPurple.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _saveFill,
                        icon: const Icon(Icons.save),
                        label: const Text('Zapisz'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Sekcja historii tankowań
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 7, top: 10),
            child: Text('Historia tankowań:', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0B3D91))),
          ),
          _buildFillsList(),
          const SizedBox(height: 24),
          _buildChart(), // Wykres miesięczny wydatków na paliwo
        ],
      ),
    );
  }

  // Lista tankowań dla wybranego auta (pobiera dane na bieżąco z Firestore)
  Widget _buildFillsList() {
    if (_selectedCarId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('Fule')
          .where('uid', isEqualTo: _auth.currentUser!.uid)
          .where('carId', isEqualTo: _selectedCarId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Text('Brak zapisów.');

        return Column(
          children: docs.map((d) {
            final f = d.data();
            final dt = (f['date'] as Timestamp).toDate();
            return Card(
              color: const Color(0xFFF8FBFF),
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              child: ListTile(
                leading: const Icon(Icons.local_gas_station, color: Colors.deepPurple),
                title: Text(
                  f['liters'] == 0
                      ? '${f['totalCost']} zł'
                      : '${f['liters']} l × ${f['pricePerL']} zł = ${(f['totalCost'] as num).toStringAsFixed(2)} zł',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(dt)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Wykres miesięcznych wydatków na paliwo (dla wybranego auta)
  Widget _buildChart() {
    if (_selectedCarId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('Fule')
          .where('uid', isEqualTo: _auth.currentUser!.uid)
          .where('carId', isEqualTo: _selectedCarId)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();

        final Map<String, double> perMonth = {};
        for (final d in snap.data!.docs) {
          final f = d.data();
          final dt = (f['date'] as Timestamp).toDate();
          final key = DateFormat('yyyy-MM').format(dt);
          perMonth[key] = (perMonth[key] ?? 0) + (f['totalCost'] as num).toDouble();
        }

        final sorted = perMonth.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        final maxY = sorted.isNotEmpty
            ? (sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.18)
            : 100.0;
        final interval = ((maxY ~/ 6) < 1 ? 10 : maxY ~/ 6).toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 5, bottom: 6),
              child: Text('Wydatki miesięczne (zł):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 210,
              child: Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.deepPurple.withOpacity(0.11),
                          strokeWidth: 1.2,
                          dashArray: [4, 3],
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.deepPurple.shade100, width: 1.2),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < sorted.length; i++)
                              FlSpot(i.toDouble(), sorted[i].value),
                          ],
                          isCurved: true,
                          color: Colors.deepPurple,
                          barWidth: 4,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                              radius: 6,
                              color: Colors.white,
                              strokeColor: Colors.deepPurple,
                              strokeWidth: 3,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.withOpacity(0.18),
                                Colors.deepPurple.withOpacity(0.02),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            interval: 1,
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= sorted.length) return const SizedBox();
                              final label = sorted[idx].key;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${label.substring(5)}/${label.substring(2, 4)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: interval,
                            reservedSize: 42,
                            getTitlesWidget: (val, meta) => Text(
                              val.toInt().toString(),
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      showingTooltipIndicators: List.generate(sorted.length, (i) => ShowingTooltipIndicators([
                        LineBarSpot(
                          LineChartBarData(
                            spots: [
                              for (var j = 0; j < sorted.length; j++)
                                FlSpot(j.toDouble(), sorted[j].value),
                            ],
                          ),
                          0,
                          FlSpot(i.toDouble(), sorted[i].value),
                        )
                      ])),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        getTouchedSpotIndicator: (barData, indicators) {
                          return indicators.map((index) {
                            return TouchedSpotIndicatorData(
                              FlLine(color: Colors.deepPurple, strokeWidth: 1.5),
                              FlDotData(show: true),
                            );
                          }).toList();
                        },
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Colors.deepPurple.shade50,
                          tooltipBorder: BorderSide(color: Colors.deepPurple.shade300),
                          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(2)} zł',
                              const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
