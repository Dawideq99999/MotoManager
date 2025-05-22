import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// GŁÓWNY EKRAN SERWISÓW I NAPRAW
class CarServiceScreen extends StatefulWidget {
  const CarServiceScreen({Key? key}) : super(key: key);

  @override
  State<CarServiceScreen> createState() => _CarServiceScreenState();
}

class _CarServiceScreenState extends State<CarServiceScreen> {
  // Inicjalizacja instancji Firebase
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Kontroler do pola kwoty serwisu
  final _costCtl = TextEditingController();

  // Stan wybranej daty, typu, samochodu i indeksu menu
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'Wymiana rozrządu';
  String? _selectedCarId;
  int _selectedIndex = 3;

  // Czy sekcja historii jest rozwinięta
  bool _historyExpanded = true;

  // Listy aut i mapowanie ID -> nazwa
  List<Map<String, dynamic>> _cars = [];
  Map<String, String> _carNames = {};

  // Lista typów serwisowych (do dropdowna)
  final List<String> _serviceTypes = [
    'Wymiana rozrządu',
    'Wymiana oleju silnikowego',
    'Wymiana filtrów',
    'Wymiana płynów',
    'Wymiana hamulców',
    'Przegląd techniczny',
    'Wymiana sprzęgła',
    'Wymiana opon',
    'Wymiana akumulatora',
    'Inne',
  ];

  // Ładowanie aut użytkownika po uruchomieniu ekranu
  @override
  void initState() {
    super.initState();
    _fetchCars();
  }

  // Pobieranie aut aktualnego usera z Firestore
  Future<void> _fetchCars() async {
    final uid = _auth.currentUser!.uid;
    final snap = await _firestore.collection('Cars').where('uid', isEqualTo: uid).get();
    setState(() {
      _cars = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _carNames = {
        for (final car in _cars)
          car['id']: '${car['Brand']} ${car['Model']} (${car['Year']})'
      };
    });
  }

  // Picker do wyboru daty serwisu (kalendarz)
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // Zapis nowego wpisu serwisowego do bazy Firestore
  Future<void> _saveService() async {
    final cost = double.tryParse(_costCtl.text.replaceAll(',', '.'));
    if (cost == null) {
      // Walidacja - sprawdź kwotę
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Podaj prawidłową kwotę')));
      return;
    }
    if (_selectedCarId == null) {
      // Walidacja - wybierz samochód
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wybierz samochód!')));
      return;
    }
    // Dodaj wpis do kolekcji CarService w Firestore
    await _firestore.collection('CarService').add({
      'uid': _auth.currentUser!.uid,
      'type': _selectedType,
      'cost': cost,
      'date': Timestamp.fromDate(_selectedDate),
      'carId': _selectedCarId,
    });
    _costCtl.clear();
    setState(() {}); // Odśwież widok
  }

  // GŁÓWNY WIDOK EKRANU
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context), // Menu boczne
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.92),
        elevation: 1,
        title: const Text('Serwis & naprawy', style: TextStyle(color: Color(0xFF181947), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF181947)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE6EDF5), Color(0xFFC6E0F7), Color(0xFFD9E7F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            if (MediaQuery.of(context).size.width >= 650) _buildRail(context), // Nawigacja boczna tylko na desktopie
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
                children: [
                  _buildCarDropdown(),   // Dropdown wyboru auta
                  _buildFormCard(),      // Formularz dodawania wpisu serwisowego
                  const SizedBox(height: 22),
                  _buildSummary(),       // Szybkie podsumowanie wydatków
                  const SizedBox(height: 16),
                  _buildServiceHistory(),// Historia serwisów z rozwijaniem
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Text('Wydatki miesięczne:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 260, child: _buildMonthlyChart()), // Wykres słupkowy
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Text('Najdroższe typy usług:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 260, child: _buildTypeChart()),    // Wykres kołowy + legenda
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dropdown do wyboru auta (lub wszystkich aut)
  Widget _buildCarDropdown() {
    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 19, right: 19, bottom: 10),
      child: DropdownButtonFormField<String>(
        value: _selectedCarId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Wybierz samochód',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: true,
          fillColor: Colors.white,
        ),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text('Wszystkie samochody', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
          ),
          ..._cars.map((car) => DropdownMenuItem(
                value: car['id'],
                child: Text('${car['Brand']} ${car['Model']} (${car['Year']})'),
              ))
        ],
        onChanged: (val) => setState(() => _selectedCarId = val),
      ),
    );
  }

  // Formularz dodawania nowego wpisu serwisowego
  Widget _buildFormCard() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          color: Colors.white.withOpacity(0.98),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dropdown z typami czynności serwisowych
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Rodzaj czynności',
                    border: OutlineInputBorder(),
                  ),
                  items: _serviceTypes.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      )).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                // Pole do wpisania kosztu
                TextField(
                  controller: _costCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Koszt (zł)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments),
                  ),
                ),
                const SizedBox(height: 12),
                // Wiersz z datą, przyciskiem do wyboru daty i przyciskiem Dodaj
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 19, color: Colors.deepPurple),
                    const SizedBox(width: 7),
                    Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.date_range, size: 19),
                      label: const Text('Zmień datę'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _saveService,
                      icon: const Icon(Icons.save),
                      label: const Text('Dodaj'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Zapytanie do serwisów (filtrowane po użytkowniku i ewentualnie aucie)
  Query<Map<String, dynamic>> _baseQuery() {
    var q = _firestore
        .collection('CarService')
        .where('uid', isEqualTo: _auth.currentUser!.uid);
    if (_selectedCarId != null) {
      q = q.where('carId', isEqualTo: _selectedCarId);
    }
    return q;
  }

  // Sekcja HISTORIA SERWISÓW z możliwością rozwinięcia/zwiniecia
  Widget _buildServiceHistory() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        color: Colors.white.withOpacity(0.97),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        child: ExpansionTile(
          initiallyExpanded: _historyExpanded,
          title: Text(
            'Historia serwisów',
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0B3D91)),
          ),
          trailing: Icon(
            _historyExpanded ? Icons.expand_less : Icons.expand_more,
            color: const Color(0xFF0B3D91),
          ),
          children: [
            _buildServiceList(), // Lista wpisów serwisowych
          ],
          onExpansionChanged: (expanded) {
            setState(() => _historyExpanded = expanded);
          },
        ),
      ),
    );
  }

  // Lista wpisów serwisowych (każdy wpis w osobnej karcie)
  Widget _buildServiceList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _baseQuery().orderBy('date', descending: true).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Brak wpisów.', style: TextStyle(color: Colors.black54)),
        );
        return Column(
          children: docs.map((d) {
            final f = d.data();
            final dt = (f['date'] as Timestamp).toDate();
            final carName = _carNames[f['carId']] ?? '';
            return Card(
              color: Colors.grey[50],
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
              child: ListTile(
                leading: const Icon(Icons.build, color: Colors.deepPurple),
                title: Text('${f['type']} — ${f['cost']} zł', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${DateFormat('yyyy-MM-dd').format(dt)}\n$carName'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Szybkie podsumowanie wydatków (suma i wydatki z tego miesiąca)
  Widget _buildSummary() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _baseQuery().snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text('Brak danych do podsumowania.', style: TextStyle(color: Colors.black54)),
          );
        }
        final docs = snap.data!.docs;
        double total = 0;
        double thisMonth = 0;
        final now = DateTime.now();

        for (final d in docs) {
          final f = d.data();
          total += (f['cost'] as num).toDouble();
          final dt = (f['date'] as Timestamp).toDate();
          if (dt.year == now.year && dt.month == now.month) {
            thisMonth += (f['cost'] as num).toDouble();
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.deepPurple.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text('Suma wydatków (wybór):', style: TextStyle(fontSize: 15, color: Color(0xFF0B3D91))),
                        const SizedBox(height: 3),
                        Text('${total.toStringAsFixed(2)} zł', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Card(
                  color: Colors.green.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text('Ten miesiąc:', style: TextStyle(fontSize: 15, color: Colors.green.shade800)),
                        const SizedBox(height: 3),
                        Text('${thisMonth.toStringAsFixed(2)} zł', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Wykres słupkowy - wydatki miesięczne
  Widget _buildMonthlyChart() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _baseQuery().snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
        final docs = snap.data!.docs;
        final Map<String, double> perMonth = {};
        for (final d in docs) {
          final f = d.data();
          final dt = (f['date'] as Timestamp).toDate();
          final key = DateFormat('yyyy-MM').format(dt);
          perMonth[key] = (perMonth[key] ?? 0) + (f['cost'] as num).toDouble();
        }
        final sorted = perMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
        final maxY = sorted.isNotEmpty
            ? (sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.18)
            : 100.0;

        return Padding(
          padding: const EdgeInsets.only(left: 12, right: 16, top: 10, bottom: 8),
          child: BarChart(
            BarChartData(
              maxY: maxY,
              gridData: FlGridData(show: true, horizontalInterval: maxY / 6),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (int i = 0; i < sorted.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: sorted[i].value,
                        width: 21,
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple, Colors.blue.shade200],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
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
                    reservedSize: 40,
                    getTitlesWidget: (val, meta) => Text('${val.toInt()} zł', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: Colors.white,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final idx = group.x.toInt();
                    return BarTooltipItem(
                      'Miesiąc: ${sorted[idx].key}\n'
                          'Wydatki: ${rod.toY.toStringAsFixed(2)} zł',
                      const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Wykres kołowy - najdroższe typy usług + legenda (obok na szeroko)
  Widget _buildTypeChart() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _baseQuery().snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
        final docs = snap.data!.docs;
        final Map<String, double> typeTotals = {};

        for (final d in docs) {
          final f = d.data();
          final type = f['type'] as String;
          final cost = (f['cost'] as num).toDouble();
          typeTotals[type] = (typeTotals[type] ?? 0) + cost;
        }

        final sorted = typeTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = sorted.take(5).toList();
        final restSum = sorted.length > 5
            ? sorted.skip(5).map((e) => e.value).fold(0.0, (a, b) => a + b)
            : 0.0;

        // Lista kolorów do wykresu i legendy
        final List<Color> sectionColors = [
          ...List.generate(top.length, (i) => Colors.primaries[i * 3 % Colors.primaries.length].shade400),
          if (restSum > 0) Colors.grey.shade400,
        ];

        // PieChart (tylko kolory, bez tekstów w środku)
        final pieSections = [
          for (int i = 0; i < top.length; i++)
            PieChartSectionData(
              color: sectionColors[i],
              value: top[i].value,
              title: '',
              radius: 60,
            ),
          if (restSum > 0)
            PieChartSectionData(
              color: sectionColors.last,
              value: restSum,
              title: '',
              radius: 54,
            ),
        ];

        // Legenda: kolor + nazwa typu + suma w zł
        List<Widget> legendItems = [];
        for (int i = 0; i < top.length; i++) {
          legendItems.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: sectionColors[i],
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.black12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    top[i].key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF22224C),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${top[i].value.toStringAsFixed(0)} zł',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF273591),
                  ),
                ),
              ],
            ),
          ));
        }
        if (restSum > 0) {
          legendItems.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: sectionColors.last,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.black12),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Inne',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF6B6B7B)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${restSum.toStringAsFixed(0)} zł',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF727292),
                  ),
                ),
              ],
            ),
          ));
        }

        // Responsywność: legenda obok na szeroko, pod spodem na wąsko
        final isWide = MediaQuery.of(context).size.width > 580;

        return Padding(
          padding: const EdgeInsets.only(left: 28, right: 12, top: 12, bottom: 8),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PieChart (wykres kołowy)
                    SizedBox(
                      width: 160,
                      height: 170,
                      child: PieChart(
                        PieChartData(
                          sections: pieSections,
                          sectionsSpace: 2,
                          centerSpaceRadius: 42,
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Legenda
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: legendItems,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: PieChart(
                        PieChartData(
                          sections: pieSections,
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...legendItems,
                  ],
                ),
        );
      },
    );
  }

  // Drawer boczny (menu z lewej)
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
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  // Nawigacja boczna (Rail) - desktop/tablet
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
  }
}
