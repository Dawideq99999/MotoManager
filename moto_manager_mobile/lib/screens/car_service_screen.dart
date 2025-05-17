import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class CarServiceScreen extends StatefulWidget {
  const CarServiceScreen({Key? key}) : super(key: key);

  @override
  State<CarServiceScreen> createState() => _CarServiceScreenState();
}

class _CarServiceScreenState extends State<CarServiceScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _costCtl = TextEditingController();
  final _descCtl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'Wymiana rozrządu';
  String? _selectedCarId; // wybrane auto (albo null = wszystkie)
  int _selectedIndex = 3; // rail/drawer

  List<Map<String, dynamic>> _cars = []; // lista aut użytkownika
  Map<String, String> _carNames = {}; // carId -> 'Marka Model (Rok)'

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

  @override
  void initState() {
    super.initState();
    _fetchCars();
  }

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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveService() async {
    final cost = double.tryParse(_costCtl.text.replaceAll(',', '.'));
    if (cost == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Podaj prawidłową kwotę')));
      return;
    }
    if (_selectedCarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wybierz samochód!')));
      return;
    }
    await _firestore.collection('CarService').add({
      'uid': _auth.currentUser!.uid,
      'type': _selectedType,
      'cost': cost,
      'date': Timestamp.fromDate(_selectedDate),
      'description': _descCtl.text,
      'carId': _selectedCarId,
    });
    _costCtl.clear();
    _descCtl.clear();
    setState(() {});
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
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
            if (MediaQuery.of(context).size.width >= 650) _buildRail(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
                children: [
                  _buildCarDropdown(),
                  _buildFormCard(),
                  const SizedBox(height: 22),
                  _buildSummary(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text('Historia serwisów:', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0B3D91))),
                  ),
                  _buildServiceList(),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Text('Wydatki miesięczne:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 260, child: _buildMonthlyChart()),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Text('Najdroższe typy usług:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 260, child: _buildTypeChart()),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                TextField(
                  controller: _descCtl,
                  decoration: const InputDecoration(
                    labelText: 'Opis (opcjonalnie)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 12),
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

  Query<Map<String, dynamic>> _baseQuery() {
    var q = _firestore
        .collection('CarService')
        .where('uid', isEqualTo: _auth.currentUser!.uid);
    if (_selectedCarId != null) {
      q = q.where('carId', isEqualTo: _selectedCarId);
    }
    return q;
  }

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
                subtitle: Text('${DateFormat('yyyy-MM-dd').format(dt)}\n${f['description'] ?? ''}\n$carName'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

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

        final pieSections = [
          for (int i = 0; i < top.length; i++)
            PieChartSectionData(
              color: Colors.primaries[i * 3 % Colors.primaries.length].shade300,
              value: top[i].value,
              title: '${top[i].key}\n${top[i].value.toStringAsFixed(0)} zł',
              radius: 60,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              titlePositionPercentageOffset: 0.62,
            ),
          if (restSum > 0)
            PieChartSectionData(
              color: Colors.grey.shade400,
              value: restSum,
              title: 'Inne\n${restSum.toStringAsFixed(0)} zł',
              radius: 48,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54),
              titlePositionPercentageOffset: 0.62,
            ),
        ];

        return Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, top: 12, bottom: 8),
          child: PieChart(
            PieChartData(
              sections: pieSections,
              sectionsSpace: 2,
              centerSpaceRadius: 32,
            ),
          ),
        );
      },
    );
  }

  // ---- Drawer/Rail

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
