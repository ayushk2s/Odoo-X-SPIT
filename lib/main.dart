import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  final savedName = prefs.getString('username');

  runApp(ChatBotApp(
    initialUserName: savedName,
  ));
}


class ChatBotApp extends StatelessWidget {
  final String? initialUserName;
  const ChatBotApp({super.key, this.initialUserName});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Friendly AI Chatbot 🤖',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigoAccent),
        useMaterial3: true,
      ),
      home: initialUserName != null
          ? ChatScreen(userName: initialUserName!)
          : const NameScreen(),
    );
  }
}


class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final TextEditingController _nameController = TextEditingController();


  void _continue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    // Save the username locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(userName: name)),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigoAccent.shade100,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Card(
            elevation: 8,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "👋 Welcome!",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Enter your name to start chatting",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: "Your name",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                    ),
                    child: const Text(
                      "Start Chat 💬",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String userName;
  const ChatScreen({super.key, required this.userName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String? urlT;
  bool _urlReady = false;

  @override
  void initState() {
    super.initState();
    fetchUrl();
  }

  Future<void> fetchUrl() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('imp_url')
          .doc('url_to_use')
          .get();

      if (snapshot.exists) {
        setState(() {
          urlT = snapshot['url'];
          _urlReady = true;
        });
      } else {
        print('Document does not exist');
      }
    } catch (e) {
      print('Error fetching URL: $e');
    }
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": message});
      _isLoading = true;
    });
    _controller.clear();

    // Save user message to Firestore
    await FirebaseFirestore.instance
        .collection(widget.userName)
        .add({"sender": "user", "text": message, "timestamp": DateTime.now()});

    final url = Uri.parse(
        '$urlT/chat');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['reply'] ?? 'Hmm... I couldn’t understand that 🧐';

        setState(() {
          _messages.add({"sender": "bot", "text": reply});
        });

        await FirebaseFirestore.instance
            .collection(widget.userName)
            .add({"sender": "bot", "text": reply, "timestamp": DateTime.now()});
      } else {
        setState(() {
          _messages.add({
            "sender": "bot",
            "text":
            "Oops! Server error (${response.statusCode}). Try again later."
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({"sender": "bot", "text": "Network error ⚠️: $e"});
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Chat with ${widget.userName} 🤖'),
        centerTitle: true,
        backgroundColor: Colors.indigoAccent.shade100,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["sender"] == "user";

                return Align(
                  alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.indigoAccent : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser
                            ? const Radius.circular(16)
                            : const Radius.circular(0),
                        bottomRight: isUser
                            ? const Radius.circular(0)
                            : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      msg["text"]!,
                      style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: sendMessage,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _urlReady ? () => sendMessage(_controller.text) : null,
                  icon: const Icon(Icons.send),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
