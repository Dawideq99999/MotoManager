import 'package:flutter/material.dart';

class FuelPricesScreen extends StatelessWidget {
  final Map<String, double> fuelPrices = {
    'Benzyna': 6.59,
    'Diesel': 6.29,
    'LPG': 3.19,
    'Elektryczny (kWh)': 0.85,
    'Hybryda (średnia)': 5.50,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Aktualne ceny paliw'),
      ),
      body: ListView.builder(
        itemCount: fuelPrices.length,
        itemBuilder: (context, index) {
          final fuel = fuelPrices.keys.elementAt(index);
          final price = fuelPrices[fuel]!;

          return ListTile(
            leading: Icon(Icons.local_gas_station),
            title: Text(fuel),
            trailing: Text('${price.toStringAsFixed(2)} PLN'),
          );
        },
      ),
    );
  }
}
