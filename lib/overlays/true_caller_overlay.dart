import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:caker/boxes.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:google_generative_ai/google_generative_ai.dart';

class TrueCallerOverlay extends StatefulWidget {
  const TrueCallerOverlay({super.key});

  @override
  State<TrueCallerOverlay> createState() => _TrueCallerOverlayState();
}

class _TrueCallerOverlayState extends State<TrueCallerOverlay> {
  bool isGold = true;

  String pageContent = 'Loading...';
  String geminiResponseOne = '';
  String geminiResponseTwo = '';
  final String apiKey = 'AIzaSyCQSVf0lpHgZ7t_nUDdZdU-Fv3xcmAznwQ';

  static const String _kPortNameOverlay = 'OVERLAY';
  static const String _kPortNameHome = 'UI';
  final _receivePort = ReceivePort();
  SendPort? homePort;
  String? messageFromOverlay;

  final _goldColors = const [
    Color.fromARGB(200, 162, 120, 13),
    Color.fromARGB(200, 235, 209, 151),
    Color.fromARGB(200, 162, 120, 13),
  ];

  final _silverColors = const [
    Color(0xFFAEB2B8),
    Color(0xFFC7C9CB),
    Color(0xFFD7D7D8),
    Color(0xFFAEB2B8),
  ];

  Future<void> processWithGeminiPromptOne(String content) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: apiKey,
      );
      
      String promptOne = """
      Can you clean up the following data collection from a privacy policy and present it as is in a legible manner?
      """;
      
      promptOne = '$promptOne\n$content';
      final response = await model.generateContent([Content.text(promptOne)]);
      setState(() {
        geminiResponseOne = response.text ?? 'No response received';
      });
    } catch (e) {
      setState(() {
        geminiResponseOne = 'Error processing first prompt: $e';
      });
    }
  }

  Future<void> processWithGeminiPromptTwo(String content) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: apiKey,
      );
      
      String promptTwo = """
      Based on this data safety information:
      1. Compare this app's data collection with industry standards
      2. Suggest potential privacy improvements
      3. Rate the overall privacy risk (Low/Medium/High)
      Content to analyze:
      """;
      
      promptTwo = '$promptTwo\n$content';
      final response = await model.generateContent([Content.text(promptTwo)]);
      setState(() {
        geminiResponseTwo = response.text ?? 'No response received';
      });
    } catch (e) {
      setState(() {
        geminiResponseTwo = 'Error processing second prompt: $e';
      });
    }
  }

  Future<void> scrapeWebsite() async {
    try {
      log('$messageFromOverlay');
      final String polAdd = 'https://play.google.com/store/apps/datasafety?id=$messageFromOverlay&hl=en_US';
      log(polAdd);
      final url = Uri.parse(polAdd);
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var textContent = document.body?.text ?? 'No content found';
        
        setState(() {
          pageContent = textContent;
        });
        
        // Process both prompts sequentially
        await processWithGeminiPromptOne(textContent);
        await processWithGeminiPromptTwo(textContent);
      } else {
        setState(() {
          pageContent = 'Failed to load content. Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        pageContent = 'Error loading content: $e';
      });
    }
  }

  void handleMessage(dynamic message) {
    log("message from UI: $message");
    setState(() {
      messageFromOverlay = '$message';
    });
    if (message is String && message.isNotEmpty) {
      scrapeWebsite();
    }
  }

  @override
  void initState() {
    super.initState();
    if (homePort != null) return;
    final res = IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      _kPortNameOverlay,
    );
    log("$res : HOME");
    _receivePort.listen(handleMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isGold ? _goldColors : _silverColors,
            ),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: GestureDetector(
            onTap: () {
              setState(() {
                isGold = !isGold;
              });
              FlutterOverlayWindow.getOverlayPosition().then((value) {
                log("Overlay Position: $value");
              });
            },
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Container(
                        height: 80.0,
                        width: 80.0,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black54),
                          shape: BoxShape.circle,
                          image: const DecorationImage(
                            image: NetworkImage(
                                "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRx16VdHh2dDEZKu6KDUCXcTmMfqWuPygi-0w&s"),
                          ),
                        ),
                      ),
                      title: const Text(
                        "Privacy Policy",
                        style: TextStyle(
                            fontSize: 20.0, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(messageFromOverlay ?? ""),
                    ),
                    OrangeBoxWithText(text: geminiResponseOne),
                    ListTile(
                      leading: Container(
                        height: 80.0,
                        width: 80.0,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black54),
                          shape: BoxShape.circle,
                          image: const DecorationImage(
                            image: NetworkImage(
                                "https://play-lh.googleusercontent.com/fgd_JMPhg5MIXlGYDv1hnsqYaP98Yf8-MtLhr7ol_sQm8ZdRkXKE9LgqdLoU6Y_Lguc=w240-h480-rw"),
                          ),
                        ),
                      ),
                      title: const Text(
                        "Summary Policy",
                        style: TextStyle(
                            fontSize: 20.0, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text("from Gemini"),
                    ),
                    OrangeBoxWithText(text: geminiResponseTwo),
                    const TextRectangleGrid(texts: ["+ Tell me more", "+ Simpler", "+ What data?", "+ "]),
                    const Spacer(),
                    const Divider(color: Colors.black54),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Package Name: com.deez.nuts"),
                              Text("John Ligma"),
                            ],
                          ),
                          Text(
                            "Pact Privacy",
                            style: TextStyle(
                                fontSize: 15.0, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                Positioned(
                  top: 10,
                  right: 15,
                  child: IconButton(
                    onPressed: () async {
                      await FlutterOverlayWindow.closeOverlay();
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /*
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Detected App: ',
              style: const TextStyle(color: Colors.black, fontSize: 20),
            ),
            // ... other overlay content ...
          ],
        ),
      ),
    );
  }

  */
}
