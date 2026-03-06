import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Process? player;
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
    player?.kill();

    try {
      final byteData = await rootBundle.load('assets/sound.mp3');
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/sound.mp3');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());

      player = await Process.start('gst-launch-1.0', [
        'playbin',
        'uri=file://${tempFile.path}',
      ]);
    } catch (e) {
      print("Error playing sound via GStreamer: $e");
    }
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
