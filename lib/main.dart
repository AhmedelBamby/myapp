// Import necessary Flutter and package libraries
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // Gemini API
import 'package:flutter_tts/flutter_tts.dart'; // Text-to-Speech
import 'package:speech_to_text/speech_to_text.dart' as stt; // Speech-to-Text
import 'package:permission_handler/permission_handler.dart'; // Runtime permissions
import 'package:shared_preferences/shared_preferences.dart'; // Persistent storage for theme mode
import 'package:provider/provider.dart'; // For state management

// Entry point of the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request microphone permission at runtime
  await Permission.microphone.request();

  // Load saved theme mode preference
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(isDarkMode),
      child: const MyApp(),
    ),
  );
}

// ========== Theme Provider for State Management ========== //
class ThemeProvider extends ChangeNotifier {
  bool isDarkMode;

  ThemeProvider(this.isDarkMode);

  // Toggle between light and dark mode
  void toggleTheme() async {
    isDarkMode = !isDarkMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  ThemeMode get currentTheme => isDarkMode ? ThemeMode.dark : ThemeMode.light;
}

// ========== Main Application Widget ========== //
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Gemini TTS App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeProvider.currentTheme, // Use ThemeMode from provider
      home: const MyHomePage(title: 'Gemini TTS Application'),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ========== Home Page with Tabs and Theme Switch ========== //
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return DefaultTabController(
      length: 2, // Two tabs: Gemini Chat and TTS
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
              tooltip: "Toggle Theme",
              onPressed: () => themeProvider.toggleTheme(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat), text: "Gemini Chat"),
              Tab(icon: Icon(Icons.record_voice_over), text: "TTS"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            GeminiChatTab(), // First tab for chat
            TTSTab(), // Second tab for TTS
          ],
        ),
      ),
    );
  }
}

// ========== Gemini Chat Tab ========== //
class GeminiChatTab extends StatefulWidget {
  const GeminiChatTab({super.key});

  @override
  State<GeminiChatTab> createState() => _GeminiChatTabState();
}

class _GeminiChatTabState extends State<GeminiChatTab> {
  final _textController = TextEditingController();
  final List<Map<String, String>> _messages = [];

  // Replace with your Gemini API key
  final model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: 'AIzaSyB1V5Z3hSw3No64UYphJ-9EWVz8-khcY9M',
  );

  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  // Sends input to Gemini and reads the result
  Future<void> _sendMessage(String input) async {
    if (input.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': input});
    });

    final content = [Content.text(input)];
    try {
      final response = await model.generateContent(content);
      final reply = response.text ?? "No response from Gemini";

      setState(() {
        _messages.add({'role': 'bot', 'text': reply});
      });

      await flutterTts.speak(reply);
    } catch (e) {
      setState(() {
        _messages.add({'role': 'bot', 'text': 'Error: $e'});
      });
    }

    _textController.clear();
  }

  // Start or stop speech recognition
  Future<void> _toggleListening() async {
    final status = await Permission.microphone.status;

    if (!status.isGranted) {
      await Permission.microphone.request();
    }

    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          _textController.text = result.recognizedWords;
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg['role'] == 'user';

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(msg['text'] ?? ""),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                onPressed: _toggleListening,
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(hintText: 'Ask Gemini...'),
                  onSubmitted: _sendMessage,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _sendMessage(_textController.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ========== TTS Tab ========== //
class TTSTab extends StatefulWidget {
  const TTSTab({super.key});

  @override
  State<TTSTab> createState() => _TTSTabState();
}

class _TTSTabState extends State<TTSTab> {
  final _ttsController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();

  // Speak text input
  Future<void> _speak() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(_ttsController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _ttsController,
            decoration: const InputDecoration(
              labelText: 'Enter text to speak',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _speak,
            icon: const Icon(Icons.play_arrow),
            label: const Text("Speak"),
          ),
        ],
      ),
    );
  }
}
