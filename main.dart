import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const ZakirlyApp());

class ZakirlyApp extends StatelessWidget {
  const ZakirlyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ذاكرلي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo, fontFamily: 'Cairo'),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ذاكرلي - الشاشة الرئيسية')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StageScreen(stage: 'اعدادي'))), child: const Text('اعدادي')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StageScreen(stage: 'ثانوي عام'))), child: const Text('ثانوي عام')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PathsScreen())), child: const Text('ثانوي بكالوريا')),
          ],
        ),
      ),
    );
  }
}

class PathsScreen extends StatelessWidget {
  const PathsScreen({super.key});
  final paths = const ['طب', 'هندسة', 'اعمال', 'اداب'];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختر المسار')),
      body: ListView.builder(
        itemCount: paths.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(paths[i]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectScreen(path: paths[i]))),
        ),
      ),
    );
  }
}

class StageScreen extends StatelessWidget {
  const StageScreen({super.key, required this.stage});
  final String stage;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(stage)),
      body: ListView(
        children: ['عربي', 'رياضيات', 'علوم']
            .map((s) => ListTile(
                  title: Text(s),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectScreen(path: s))),
                ))
            .toList(),
      ),
    );
  }
}

class SubjectScreen extends StatelessWidget {
  const SubjectScreen({super.key, required this.path});
  final String path;
  @override
  Widget build(BuildContext context) {
    final tools = [
      {'title': 'تايمر', 'icon': Icons.timer},
      {'title': 'ملاحظات', 'icon': Icons.note},
      {'title': 'فلاش كارد', 'icon': Icons.style},
      {'title': 'امتحان', 'icon': Icons.quiz},
      {'title': 'احصائيات', 'icon': Icons.bar_chart},
      {'title': 'AI PRO', 'icon': Icons.smart_toy},
    ];
    return Scaffold(
      appBar: AppBar(title: Text(path)),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        childAspectRatio: 1.1,
        children: tools
            .map((t) => Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: () {
                      final title = t['title'] as String;
                      if (title == 'تايمر') Navigator.push(context, MaterialPageRoute(builder: (_) => const TimerScreen()));
                      if (title == 'ملاحظات') Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesScreen()));
                      if (title == 'فلاش كارد') Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashcardScreen()));
                      // إمكان إضافة بقية الأدوات لاحقًا
                    },
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(t['icon'] as IconData, size: 36, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 8),
                        Text(t['title'] as String),
                      ]),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/* ------------------ TimerScreen (محسّن، مع حفظ حالة واستئناف) ------------------ */

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});
  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  static const int defaultSeconds = 1500; // 25 دقيقة
  int seconds = defaultSeconds;
  bool isRunning = false;
  Timer? _ticker;

  // Keys in SharedPreferences
  static const _keySeconds = 'timer_seconds';
  static const _keyRunning = 'timer_running';
  static const _keyLastStarted = 'timer_last_started'; // millisecondsSinceEpoch

  @override
  void initState() {
    super.initState();
    _loadTimerState();
  }

  Future<void> _loadTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSeconds = prefs.getInt(_keySeconds);
    final running = prefs.getBool(_keyRunning) ?? false;
    final lastStarted = prefs.getInt(_keyLastStarted);

    int restoredSeconds = savedSeconds ?? defaultSeconds;

    if (running && lastStarted != null) {
      final elapsedMillis = DateTime.now().millisecondsSinceEpoch - lastStarted;
      final elapsedSeconds = (elapsedMillis / 1000).floor();
      restoredSeconds = (restoredSeconds - elapsedSeconds).clamp(0, 999999);
      if (restoredSeconds <= 0) {
        // timer finished while app wasn't running
        restoredSeconds = 0;
        await _saveTimerState(seconds: restoredSeconds, running: false);
        setState(() {
          seconds = restoredSeconds;
          isRunning = false;
        });
        return;
      }
      // resume the ticker
      setState(() {
        seconds = restoredSeconds;
        isRunning = true;
      });
      _startTicker();
    } else {
      setState(() {
        seconds = restoredSeconds;
        isRunning = false;
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds > 0) {
        setState(() {
          seconds--;
        });
        _saveTimerState(seconds: seconds, running: true);
      } else {
        _ticker?.cancel();
        setState(() {
          isRunning = false;
        });
        _saveTimerState(seconds: 0, running: false);
      }
    });
  }

  Future<void> _saveTimerState({required int seconds, required bool running}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySeconds, seconds);
    await prefs.setBool(_keyRunning, running);
    if (running) {
      await prefs.setInt(_keyLastStarted, DateTime.now().millisecondsSinceEpoch);
    } else {
      await prefs.remove(_keyLastStarted);
    }
  }

  void toggle() {
    if (isRunning) {
      _ticker?.cancel();
      setState(() => isRunning = false);
      _saveTimerState(seconds: seconds, running: false);
    } else {
      // if seconds == 0, reset to default when starting
      if (seconds <= 0) seconds = defaultSeconds;
      setState(() => isRunning = true);
      _saveTimerState(seconds: seconds, running: true);
      _startTicker();
    }
  }

  void reset() {
    _ticker?.cancel();
    setState(() {
      seconds = defaultSeconds;
      isRunning = false;
    });
    _saveTimerState(seconds: seconds, running: false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تايمر بومودورو')),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_format(seconds), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton.icon(
              onPressed: toggle,
              icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
              label: Text(isRunning ? 'إيقاف' : 'ابدأ'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(onPressed: reset, icon: const Icon(Icons.restart_alt), label: const Text('إعادة')),
          ]),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('تبقى: ${seconds ~/ 60} دقيقة و ${seconds % 60} ثانية', textAlign: TextAlign.center),
          ),
        ]),
      ),
    );
  }
}

/* ------------------ NotesScreen (محسّن: حفظ تلقائي + debounce) ------------------ */

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final controller = TextEditingController();
  Timer? _debounce;
  static const _keyNotes = 'notes';

  @override
  void initState() {
    super.initState();
    _load();
    controller.addListener(_onTextChanged);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    controller.text = prefs.getString(_keyNotes) ?? '';
  }

  void _onTextChanged() {
    // debounce save: 800ms after user stops typing
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _save();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNotes, controller.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Save immediately on dispose
    _save();
    controller.removeListener(_onTextChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملاحظات'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'اكتب ملاحظاتك هنا...', border: OutlineInputBorder()),
          textAlignVertical: TextAlignVertical.top,
        ),
      ),
    );
  }
}

/* ------------------ FlashcardScreen (محسّن: CRUD + حفظ) ------------------ */

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});
  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  int index = 0;
  bool showAnswer = false;
  List<Map<String, String>> cards = [];
  static const _keyCards = 'flashcards';

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCards);
    if (raw != null) {
      try {
        final List parsed = jsonDecode(raw);
        cards = parsed.map((e) => {'q': e['q'] as String, 'a': e['a'] as String}).toList();
      } catch (_) {
        cards = [];
      }
    } else {
      // default cards
      cards = [
        {'q': 'ما هو 2+2', 'a': '4'},
        {'q': 'عاصمة مصر', 'a': 'القاهرة'},
      ];
    }
    setState(() {});
  }

  Future<void> _saveCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCards, jsonEncode(cards));
  }

  Future<void> _addOrEditCard({int? editIndex}) async {
    final qController = TextEditingController(text: editIndex == null ? '' : cards[editIndex]['q']);
    final aController = TextEditingController(text: editIndex == null ? '' : cards[editIndex]['a']);
    final isEdit = editIndex != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'تعديل الفلاش كارد' : 'إضافة فلاش كارد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: qController, decoration: const InputDecoration(labelText: 'السؤال')),
          TextField(controller: aController, decoration: const InputDecoration(labelText: 'الإجابة')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () {
                final q = qController.text.trim();
                final a = aController.text.trim();
                if (q.isEmpty || a.isEmpty) {
                  // بسيطة: لا نغلق الـ dialog إن كانت الحقول فارغة
                  return;
                }
                if (isEdit) {
                  cards[editIndex!] = {'q': q, 'a': a};
                } else {
                  cards.add({'q': q, 'a': a});
                  index = cards.length - 1;
                }
                _saveCards();
                Navigator.of(ctx).pop(true);
              },
              child: const Text('حفظ')),
        ],
      ),
    );

    if (result == true) setState(() {});
  }

  void _removeCard(int i) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف'),
        content: const Text('هل متأكد أنك تريد حذف هذا الكارت؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () {
                cards.removeAt(i);
                if (cards.isEmpty) index = 0;
                else index = index.clamp(0, cards.length - 1);
                _saveCards();
                Navigator.of(ctx).pop();
                setState(() {});
              },
              child: const Text('حذف')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCards = cards.isNotEmpty;
    final current = hasCards ? cards[index] : null;

    return Scaffold(
      appBar: AppBar(title: const Text('فلاش كارد')),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(heroTag: 'add', onPressed: () => _addOrEditCard(), child: const Icon(Icons.add), tooltip: 'إضافة'),
        const SizedBox(height: 8),
        FloatingActionButton.small(
            heroTag: 'manage',
            onPressed: () {
              // Show management sheet
              showModalBottomSheet(
                context: context,
                builder: (ctx) => SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (c, i) => ListTile(
                      title: Text(cards[i]['q']!),
                      subtitle: Text(cards[i]['a']!),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(onPressed: () => _addOrEditCard(editIndex: i), icon: const Icon(Icons.edit)),
                        IconButton(onPressed: () => _removeCard(i), icon: const Icon(Icons.delete)),
                      ]),
                      onTap: () {
                        setState(() {
                          index = i;
                          showAnswer = false;
                        });
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                ),
              );
            },
            child: const Icon(Icons.list),
            tooltip: 'إدارة'),
      ]),
      body: Center(
        child: hasCards
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(showAnswer ? current!['a']! : current!['q']!, style: const TextStyle(fontSize: 22), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            ElevatedButton(onPressed: () => setState(() => showAnswer = !showAnswer), child: Text(showAnswer ? 'السؤال' : 'اظهر الاجابة')),
                            const SizedBox(width: 8),
                            OutlinedButton(onPressed: () => setState(() {
                                  index = (index - 1) % cards.length;
                                  if (index < 0) index += cards.length;
                                  showAnswer = false;
                                }), child: const Icon(Icons.chevron_left)),
                            const SizedBox(width: 8),
                            OutlinedButton(onPressed: () => setState(() {
                                  index = (index + 1) % cards.length;
                                  showAnswer = false;
                                }), child: const Icon(Icons.chevron_right)),
                          ]),
                          const SizedBox(height: 8),
                          Text('بطاقة ${index + 1} / ${cards.length}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ])
            : Center(child: Text('لا يوجد فلاش كاردات بعد. اضغط + لإضافة واحدة.', style: Theme.of(context).textTheme.bodyLarge)),
      ),
    );
  }
}
