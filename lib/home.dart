import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget 
{
  const HomePage({super.key});


  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home Page"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'tante',
            style:GoogleFonts.comfortaa(
                fontSize: 100,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
          ),

          const Text(
            "Find - Rent - Manage",
            style: TextStyle(
              fontSize: 16,
            ),
          ),

          const SizedBox(height:20),

          FilledButton(
            onPressed: (){}, 
            child: Text("Get Started")
          )
          
        ]
      ),
    );
  }
}
