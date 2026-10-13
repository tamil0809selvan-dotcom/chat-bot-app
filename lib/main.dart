import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const PDFChatApp());
}

// Laptop IP address change aana, indha URL-ai update pannanum.
const String apiBaseUrl = 'https://my-rag-chatbot-api.onrender.com';
class PDFChatApp extends StatelessWidget {
  const PDFChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Chat',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF536DFE),
        ),
      ),
      home: const ChatHomePage(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  const ChatMessage({
    required this.text,
    required this.isUser,
  });
}

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];

  String? _pdfName;
  bool _isUploading = false;
  bool _isSending = false;

  bool get _isBusy => _isUploading || _isSending;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addMessage(String text, {required bool isUser}) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: isUser));
    });
  }

  String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
    } catch (_) {}
    return 'Server error (${response.statusCode}). Backend-ai check pannunga.';
  }

  Future<void> _selectPDF() async {
    if (_isBusy) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty || !mounted) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        _addMessage(
          'PDF file read panna mudiyala. Vera PDF select pannunga.',
          isUser: false,
        );
        return;
      }

      setState(() => _isUploading = true);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/upload-pdf'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 3),
      );

      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;

        setState(() {
          _pdfName = file.name;
          _messages.clear();
          _messages.add(
            ChatMessage(
              text:
                  'PDF upload successful! 🎉\n'
                  'File: ${file.name}\n'
                  'Chunks created: ${data['chunks_created'] ?? 'Done'}\n\n'
                  'Ippo indha PDF pathi questions kelunga bro!',
              isUser: false,
            ),
          );
        });
      } else {
        throw Exception(_errorMessage(response));
      }
    } catch (e) {
      _addMessage(
        'PDF upload fail aagiduchu.\n${e.toString().replaceFirst('Exception: ', '')}\n\n'
        'Backend run aagudha, Wi-Fi same network-la irukka-nu check pannunga.',
        isUser: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final question = _controller.text.trim();

    if (question.isEmpty || _isBusy) return;

    if (_pdfName == null) {
      _addMessage(
        'Bro, first PDF upload pannunga. Appuram questions-ku answer pannuren!',
        isUser: false,
      );
      return;
    }

    _controller.clear();
    _addMessage(question, isUser: true);

    setState(() => _isSending = true);

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/ask'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'question': question}),
          )
          .timeout(const Duration(minutes: 2));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        _addMessage(
          data['answer']?.toString() ?? 'Server answer return pannala.',
          isUser: false,
        );
      } else {
        throw Exception(_errorMessage(response));
      }
    } catch (e) {
      _addMessage(
        'Answer edukka mudiyala.\n'
        '${e.toString().replaceFirst('Exception: ', '')}\n\n'
        'Backend terminal-ai check pannunga bro.',
        isUser: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _startNewChat() {
    if (_isBusy) return;

    setState(() {
      _messages.clear();
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 16,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFFE8EBFF),
              child: Icon(
                Icons.auto_awesome,
                color: Color(0xFF536DFE),
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF Chat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                  ),
                ),
                Text(
                  'Your document assistant',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _startNewChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_pdfName != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pdfName!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Upload another PDF',
                      onPressed: _isBusy
                          ? null
                          : () {
                              setState(() => _pdfName = null);
                              _selectPDF();
                            },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 88,
                              width: 88,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8EBFF),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                size: 45,
                                color: Color(0xFF536DFE),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Vanakkam bro! 👋',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Welcome to PDF Chat',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Upload a PDF and ask questions about it.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 26),
                            OutlinedButton.icon(
                              onPressed: _isBusy ? null : _selectPDF,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Choose PDF'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            if (_isUploading) ...[
                              const SizedBox(height: 16),
                              const CircularProgressIndicator(),
                              const SizedBox(height: 8),
                              const Text('PDF upload & processing...'),
                            ],
                            const SizedBox(height: 22),
                            const Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _SuggestionChip(
                                  label: 'Summarize my PDF',
                                  icon: Icons.summarize_outlined,
                                ),
                                _SuggestionChip(
                                  label: 'Explain a topic',
                                  icon: Icons.lightbulb_outline,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isSending && index == _messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('PDF-la search pannuren...'),
                                ],
                              ),
                            ),
                          );
                        }

                        final message = _messages[index];

                        return Align(
                          alignment: message.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.82,
                            ),
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: message.isUser
                                  ? const Color(0xFF536DFE)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: SelectableText(
                              message.text,
                              style: TextStyle(
                                color: message.isUser
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE9EAF0)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isUploading)
                    const LinearProgressIndicator(minHeight: 3),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _isBusy ? null : _selectPDF,
                        tooltip: 'Upload PDF',
                        icon: const Icon(
                          Icons.attach_file,
                          color: Color(0xFF536DFE),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_isBusy,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Ask anything about your PDF...',
                            filled: true,
                            fillColor: const Color(0xFFF3F4F8),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isBusy ? null : _sendMessage,
                        tooltip: 'Send message',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF536DFE),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _isUploading
                        ? 'PDF upload aagudhu...'
                        : _pdfName == null
                            ? 'Upload a PDF to start chatting.'
                            : 'Connected to your PDF backend.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: () {},
      avatar: Icon(
        icon,
        size: 17,
        color: const Color(0xFF536DFE),
      ),
      label: Text(label),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE1E4F0)),
    );
  }
}
