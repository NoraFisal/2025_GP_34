import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ReportChatbotPage extends StatefulWidget {
  final dynamic reportData;

  const ReportChatbotPage({
    super.key,
    required this.reportData,
  });

  @override
  State<ReportChatbotPage> createState() => _ReportChatbotPageState();
}

class _ReportChatbotPageState extends State<ReportChatbotPage> {
  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);

static const String _openRouterKey = 'YOUR_API_KEY';

  static const int _dailyMessageLimit = 15;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedLanguage = 'en';
  String? _selectedTopic;

  int _sentToday = 0;
  String _todayKey = '';
  bool _conversationClosed = false;

final List<String> _models = [
  'openrouter/free',
  'deepseek/deepseek-chat-v3-0324:free',
  'deepseek/deepseek-r1-0528:free',
  'meta-llama/llama-3.3-70b-instruct:free',
];
  final List<Map<String, dynamic>> _messages = [
    {'type': 'language_picker'},
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _dateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _cleanAiText(String value) {
    return value
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll(RegExp(r'#+\s*'), '')
        .trim();
  }

  Future<String> _askOpenRouter(String prompt) async {
  String lastError = '';

  for (final model in _models) {
    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openRouterKey',
          'HTTP-Referer': 'https://spark.local',
          'X-Title': 'SPARK',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are Spark Chatbot. Explain esports reports simply and clearly. Reply in the same language as the player.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.6,
          'max_tokens': 120,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        lastError =
            'Model: $model\nStatus: ${response.statusCode}\nError: ${data['error']?['message'] ?? response.body}';
        continue;
      }

      final reply =
          data['choices']?[0]?['message']?['content']?.toString().trim();

      if (reply != null && reply.isNotEmpty) {
        return _cleanAiText(reply);
      }

      lastError = 'Model: $model returned empty response.';
    } catch (e) {
      lastError = 'Model: $model\nError: $e';
    }
  }

  throw Exception(lastError.isEmpty ? 'All chatbot models failed.' : lastError);
}

  void _selectLanguage(String lang) {
    setState(() {
      _selectedLanguage = lang;

      _messages.add({
        'isBot': false,
        'text': lang == 'ar' ? 'العربية' : 'English',
      });

      _messages.add({
        'isBot': true,
        'text': lang == 'ar'
            ? 'ممتاز! اختر الموضوع الذي تريد التحدث عنه.'
            : 'Great! Choose what you want to talk about.',
      });

      _messages.add({'type': 'topic_picker'});
    });

    _scrollToBottom();
  }

  void _selectTopic(String topic) {
    _selectedTopic = topic;

    String userChoice = '';
    String response = '';

    switch (topic) {
      case 'weakness':
        userChoice = _selectedLanguage == 'ar' ? 'نقاط الضعف' : 'Weaknesses';
        response = _selectedLanguage == 'ar'
            ? 'حسنًا، لنتحدث عن نقاط ضعفك. اسألني عن معنى أي نقطة ضعف أو كيف يمكنك تحسينها.'
            : 'Okay, let’s talk about your weaknesses. Ask me what any weakness means or how to improve it.';
        break;
      case 'strength':
        userChoice = _selectedLanguage == 'ar' ? 'نقاط القوة' : 'Strengths';
        response = _selectedLanguage == 'ar'
            ? 'ممتاز، لنتحدث عن نقاط قوتك وكيف تستفيد منها أكثر داخل المباريات.'
            : 'Great, let’s talk about your strengths and how to use them better in matches.';
        break;
      case 'goal':
        userChoice = _selectedLanguage == 'ar' ? 'الهدف الحالي' : 'Focus Goal';
        response = _selectedLanguage == 'ar'
            ? 'لنركز على هدفك الحالي وكيف يمكنك تحقيقه.'
            : 'Let’s focus on your current goal and how you can achieve it.';
        break;
      case 'trends':
        userChoice = _selectedLanguage == 'ar' ? 'التطور' : 'Trends';
        response = _selectedLanguage == 'ar'
            ? 'لنتحدث عن التغيرات الأخيرة في أدائك.'
            : 'Let’s talk about your recent performance trends.';
        break;
      case 'score':
        userChoice = _selectedLanguage == 'ar' ? 'التقييم' : 'Score';
        response = _selectedLanguage == 'ar'
            ? 'لنتحدث عن تقييمك العام وما الذي يؤثر عليه.'
            : 'Let’s talk about your overall score and what affects it.';
        break;
    }

    setState(() {
      _messages.add({'isBot': false, 'text': userChoice});
      _messages.add({'isBot': true, 'text': response});
    });

    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final today = _dateKey();

    if (_todayKey != today) {
      _todayKey = today;
      _sentToday = 0;
      _conversationClosed = false;
    }

    if (_conversationClosed || _sentToday >= _dailyMessageLimit) {
      setState(() {
        _conversationClosed = true;
        _messages.add({
          'isBot': true,
          'text': _selectedLanguage == 'ar'
              ? 'تم إغلاق محادثة المساعد لهذا اليوم. حاول مرة أخرى غدًا.'
              : 'The Spark Chatbot conversation for today is closed. Please try again tomorrow.',
        });
      });
      _scrollToBottom();
      return;
    }

    final lower = text.toLowerCase();
    String? quickReply;

    if (lower == 'hi' || lower == 'hello' || lower == 'hey') {
      quickReply = _selectedLanguage == 'ar'
          ? 'مرحبًا! كيف أقدر أساعدك في فهم تقريرك؟'
          : 'Hello! How can I help you understand your report?';
    } else if (text.contains('السلام عليكم') || text.contains('سلام عليكم')) {
      quickReply = 'وعليكم السلام! كيف أقدر أساعدك في فهم تقريرك؟';
    }

    if (quickReply != null) {
      setState(() {
        _messages.add({'isBot': false, 'text': text});
        _messages.add({'isBot': true, 'text': quickReply});
      });
      _controller.clear();
      _scrollToBottom();
      return;
    }

    _sentToday++;

    setState(() {
      _messages.add({'isBot': false, 'text': text});
      _messages.add({'isBot': true, 'text': 'Thinking...'});
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final reportPrompt = '''
You are Spark Chatbot, a helpful assistant inside the SPARK esports platform.

Explain the player's performance report in simple esports language.
Use only the available report data.
Do not invent missing statistics.
Reply in the same language the player uses, Arabic or English.
Do not use markdown tables or HTML.
Do not use ** symbols.
Keep the answer very short: maximum 2-3 sentences.
Do not write long explanations unless the player asks for details.

Selected language: $_selectedLanguage
Selected topic: ${_selectedTopic ?? 'General'}

Player report:
Game: ${widget.reportData.gameId}
Overall score: ${widget.reportData.overallScore}
Strengths: ${widget.reportData.strengths.map((e) => e.key).toList()}
Weaknesses: ${widget.reportData.weaknesses.map((e) => e.key).toList()}
Focus goals: ${widget.reportData.goals.map((e) => {
            'title': e.title,
            'description': e.description,
            'target': e.targetText,
          }).toList()}

Player question:
$text
''';

      final reply = await _askOpenRouter(reportPrompt);
      setState(() {
        _messages[_messages.length - 1] = {
          'isBot': true,
          'text': reply,
        };
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] = {
          'isBot': true,
          'text': _selectedLanguage == 'ar'
              ? 'عذرًا، لم أتمكن من الحصول على رد الآن.\n\n$e'
              : 'Sorry, I could not get a response right now.\n\n$e',
        };
      });

      _scrollToBottom();
    }
  }

  Widget _botAvatar() {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: const Icon(
        Icons.smart_toy_rounded,
        color: _accent,
        size: 20,
      ),
    );
  }

  Widget _buildLanguagePicker() {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _botAvatar(),
        Flexible(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.68,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.smart_toy_rounded, color: _accent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Spark Chatbot',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: _text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Hi, with you Spark Chatbot. Choose your language:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    color: _text,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                _menuButton('English', () => _selectLanguage('en')),
                _menuButton('العربية', () => _selectLanguage('ar')),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildTopicPicker() {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _botAvatar(),
        Flexible(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.68,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.smart_toy_rounded, color: _accent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Spark Chatbot',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: _text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedLanguage == 'ar'
                      ? 'اختر الموضوع الذي تريد التحدث عنه:'
                      : 'Choose what you want to talk about:',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 8),
                _menuButton(
                  _selectedLanguage == 'ar' ? 'نقاط الضعف' : 'Weaknesses',
                  () => _selectTopic('weakness'),
                ),
                _menuButton(
                  _selectedLanguage == 'ar' ? 'نقاط القوة' : 'Strengths',
                  () => _selectTopic('strength'),
                ),
                _menuButton(
                  _selectedLanguage == 'ar' ? 'الهدف الحالي' : 'Focus Goal',
                  () => _selectTopic('goal'),
                ),
                _menuButton(
                  _selectedLanguage == 'ar' ? 'التطور' : 'Trends',
                  () => _selectTopic('trends'),
                ),
                _menuButton(
                  _selectedLanguage == 'ar' ? 'التقييم' : 'Score',
                  () => _selectTopic('score'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _menuButton(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE6E6E6)),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _accent,
          ),
        ),
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> msg) {
    final isBot = msg['isBot'] == true;

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isBot) _botAvatar(),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: isBot ? Colors.white : _accent,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isBot ? 4 : 18),
                  bottomRight: Radius.circular(isBot ? 18 : 4),
                ),
                border: isBot ? Border.all(color: _line) : null,
              ),
              child: Text(
                msg['text'].toString(),
                textDirection:
                    _selectedLanguage == 'ar' ? TextDirection.rtl : null,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: isBot ? _text : Colors.white,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF363435),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Spark Chatbot',
          style: TextStyle(
            fontFamily: 'Inter',
            color: _accent,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (_, index) {
                final msg = _messages[index];

                if (msg['type'] == 'language_picker') {
                  return _buildLanguagePicker();
                }

                if (msg['type'] == 'topic_picker') {
                  return _buildTopicPicker();
                }

                return _messageBubble(msg);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(
                color: _bg,
                border: Border(
                  top: BorderSide(color: _line, width: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        maxHeight: 110,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F3F4),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _line),
                      ),
                      child: TextField(
                        controller: _controller,
                        enabled: !_conversationClosed,
                        minLines: 1,
                        maxLines: 4,
                        cursorColor: _accent,
                        textInputAction: TextInputAction.newline,
                        textDirection:
                            _selectedLanguage == 'ar' ? TextDirection.rtl : null,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                        decoration: InputDecoration(
                          hintText: _selectedLanguage == 'ar'
                              ? 'اسأل عن تقريرك...'
                              : 'Ask about your report...',
                          hintStyle: const TextStyle(
                            fontFamily: 'Inter',
                            color: _muted,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _conversationClosed ? null : _sendMessage,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _conversationClosed ? _muted : _accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}