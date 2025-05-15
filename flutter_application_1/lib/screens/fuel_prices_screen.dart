import 'package:flutter/material.dart';

class FuelPricesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> demoData = [
    {'type': 'Benzyna 95', 'price': 6.49},
    {'type': 'Benzyna 98', 'price': 6.89},
    {'type': 'Diesel', 'price': 6.39},
    {'type': 'LPG', 'price': 2.89},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ceny paliw')),
      body: ListView.builder(
        itemCount: demoData.length,
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.local_gas_station),
          title: Text(demoData[i]['type']),
          trailing: Text('${demoData[i]['price'].toStringAsFixed(2)} zł/l', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}