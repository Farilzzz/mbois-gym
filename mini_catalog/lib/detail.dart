import 'package:flutter/material.dart';
import 'main.dart'; 

class Detail extends StatefulWidget {
  final Product product;
  const Detail({super.key, required this.product});

  @override
  State<Detail> createState() => _DetailState();
}

// 1. '-DetailState' diubah jadi '_DetailState', dan '<Detail>' diubah jadi 'State<Detail>'
class _DetailState extends State<Detail> {
  @override
  // 2. 'Build' diawali dengan huruf kecil menjadi 'build'
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        // 3. 'classtitle:' dihilangkan kata 'class'-nya, dan 'text' jadi 'Text'
        title: Text(widget.product.name),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        // 4. 'classchild:' dan 'classpadding:' dihilangkan kata 'class'-nya
        child: Padding(
          padding: const EdgeInsets.all(24),
          // 5. Struktur Card diperbaiki, properti elevation dan child dimasukkan ke dalam kurung Card(...)
          child: Card(
            // 6. 'RoundedRectangelBorder' typo, diperbaiki jadi 'RoundedRectangleBorder'
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            // 7. 'elecation' typo, diperbaiki jadi 'elevation'
            elevation: 4,
            child: Padding(
              // 8. 'EdgeInSets' huruf 'i' diubah menjadi kecil 'EdgeInsets'
              padding: const EdgeInsets.all(32),
              // 9. 'classmainAxisSize' diperbaiki, dan 'children[' ditambah titik dua jadi 'children: ['
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 10. 'Widget' jadi 'widget', 'Color' jadi 'color', dan 'COlors' jadi 'Colors'
                  Icon(
                    widget.product.icon,
                    size: 100,
                    color: Colors.indigo,
                  ),
                  // 11. 'SizedBoz' typo, diperbaiki jadi 'SizedBox'
                  const SizedBox(height: 8),
                  // 12. 'Colors:indigo' titik dua diganti jadi titik 'Colors.indigo'
                  Text(
                    widget.product.price,
                    style: const TextStyle(fontSize: 20, color: Colors.indigo),
                  ),
                  const SizedBox(height: 16),
                  // 13. 'text' harus huruf kapital 'Text'
                  Text(
                    widget.product.desc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  // 14. 'SizedBos' typo, diperbaiki jadi 'SizedBox'
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 15. 'iconButton' jadi 'IconButton', dan 'classicon' jadi 'icon'
                      IconButton(
                        icon: Icon(
                          widget.product.isFav
                              ? Icons.favorite
                              : Icons.favorite_border,
                          // 16. 'color.Colors.red' titik pertama diganti titik dua 'color: Colors.red'
                          color: Colors.red,
                          size: 40,
                        ),
                        onPressed: () {
                          setState(() {
                            widget.product.isFav = !widget.product.isFav;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.product.isFav ? 'Favorit' : 'Bukan Favorit',
                        // 17. 'fontWight' typo, diperbaiki jadi 'fontWeight'
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}