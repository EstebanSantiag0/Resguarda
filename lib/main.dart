import 'package:flutter/material.dart';

import 'screens/inicio.dart';
import 'theme.dart';

void main() => runApp(const Resguarda());

class Resguarda extends StatelessWidget {
  const Resguarda({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resguarda',
      debugShowCheckedModeBanner: false,
      theme: temaResguarda(),
      home: const Inicio(),
    );
  }
}
