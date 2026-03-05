import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
 
  String aglVersion = "Loading...";
  bool showImage = false;
  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    readVersion();
  }

  Future<void> readVersion() async {
    try {
      final file = File('/etc/os-release');
      final content = await file.readAsString();

      for (var line in content.split('\n')) {
        if (line.startsWith('VERSION=')) {
          aglVersion = line.split('=')[1];
        }
      }
    } catch (e) {
      aglVersion = "Unknown";
    }

    setState(() {});
  }

  void playSound() async {
    await player.play(AssetSource('sound.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("AGL Flutter Demo")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Text("AGL Version: $aglVersion"),
              const SizedBox(height: 10),
 
              const Text("Name: Abdulrahman Yasser - Quiz of AGL Flutter"),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showImage = true;
                  });
                },
                child: const Text("Show Image"),
              ),

              ElevatedButton(
                onPressed: playSound,
                child: const Text("Play Sound"),
              ),

              const SizedBox(height: 20),

              if (showImage)
                Image.asset('assets/picture.png', width: 200)

            ],
          ),
        ),
      ),
    );
  }
}
