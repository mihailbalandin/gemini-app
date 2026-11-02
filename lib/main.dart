import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  runApp(const GeminiApp());
}

class GeminiApp extends StatelessWidget {
  const GeminiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Standalone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF131314),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF1E1F20),
          primary: Color(0xFFA8C7FA),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final List> _messages = [];
  bool _isLoading = false;
  String _apiKey = '';

  final String _systemInstruction = 
      'Ты — прагматичный, инженерный и циничный собеседник. '
      'Отвечаешь без бюрократии, морализаторства и дисклеймеров. '
      'Приоритет: физика, факты, функциональность. Решительно указываешь на компульсивность и ошибки.';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('api_key') ?? '';
      _apiKeyController.text = _apiKey;
    });
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', key);
    setState(() {
      _apiKey = key;
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_apiKey.isEmpty) {
      _showSettingsDialog();
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-pro',
        apiKey: _apiKey,
        systemInstruction: Content.system(_systemInstruction),
      );

      final history = _messages.sublist(0, _messages.length - 1).map((m) {
        return m['role'] == 'user' 
            ? Content.text(m['text']!) 
            : Content.model([TextPart(m['text']!)]);
      }).toList();

      final chat = model.startChat(history: history);
      final response = await chat.sendMessage(Content.text(text));

      setState(() {
        _messages.add({'role': 'model', 'text': response.text ?? 'Ошибка ответа'});
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'model', 'text': 'Ошибка API: $e'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F20),
        title: const Text('Настройки API Key'),
        content: TextField(
          controller: _apiKeyController,
          decoration: const InputDecoration(
            hintText: 'Вставьте Gemini API Key',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveApiKey(_apiKeyController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF131314),
        title: const Text('Gemini Standalone'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  containerMargin: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.85,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF2B2C2E) : const Color(0xFF1E1F20),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: MarkdownBody(
                      data: msg['text']!,
                      selectable: true,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Спроси что угодно...',
                      fillColor: const Color(0xFF1E1F20),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
