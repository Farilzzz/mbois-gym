import 'package:flutter/material.dart';
import 'detail.dart';

void main() =>
    runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Home()));

class Product {
  final String name;
  final String price;
  final String desc;
  final IconData icon;
  bool isFav;

  Product(this.name, this.price, this.desc, this.icon, {this.isFav = false});
}

final List<Product> products = [
  Product(
    'Laptop',
    'RP 15.000.000',
    'Laptop Gaming Terbaru Dengan Performa Paling Cepat Saat Ini',
    Icons.laptop,
  ),
  Product(
    'Smartphone',
    'RP 5.000.000',
    'Iphone 18 Pro Max Dengan Chipset A18 Paling Terbaru Keluaran Apple',
    Icons.smartphone,
  ),
  Product(
    'Kamera',
    'RP 50.000.000',
    'Kamera Keluaran Sony Terbaru, Collab Dengan Leica',
    Icons.camera_alt,
  ),
  Product(
    'Headphone',
    'RP 2.000.000',
    'LG Tone FN 7 WIth Meridians, Powerful Than The Others',
    Icons.headphones,
  ),
  Product(
    'Tablet',
    'RP 8.000.000',
    'Tablet Seper Tipis Include Stylist Nyamana Buat Nggambar',
    Icons.tablet_mac,
  ),
  Product(
    'Smartwatch',
    'RP 500.000',
    'Huawei Band 10, Makin Banyak Fitur Buat Olahraga',
    Icons.watch,
  ),
];

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold (
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const Text('Mini Catalog'),
        backgroundColor: Colors.indigo, 
        foregroundColor: Colors.white,
      ),
    body: ListView.builder(
      itemCount: products.length, 
      itemBuilder:(context,index){
        final p = products[index];
        return Card(
          elevation: 2, 
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            ),
            child:ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading:CircleAvatar(
                backgroundColor: Colors.indigo[100], 
                child: Icon(p.icon, color: Colors.indigo),
                ),
              title: Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              subtitle: Text(
                p.price, 
                style: const TextStyle(color: Colors.indigo),
                ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16), 
              onTap: () => Navigator.push(
                context,MaterialPageRoute(builder: (_) => Detail(product: p)),
                ),
    ),
        );
    },
    ),
    );
  }
}
