import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

String jalaliDate(DateTime value) {
  final j = Gregorian.fromDateTime(value).toJalali();
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
}

String clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class FollowUp {
  final String id;
  String text;
  DateTime at;
  DateTime? reminderAt;

  FollowUp({required this.id, required this.text, required this.at, this.reminderAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'at': at.toIso8601String(),
        'reminderAt': reminderAt?.toIso8601String(),
      };

  factory FollowUp.fromJson(Map<String, dynamic> json) {
    return FollowUp(
      id: json['id'] ?? newId(),
      text: json['text'] ?? '',
      at: DateTime.parse(json['at']),
      reminderAt: json['reminderAt'] == null
          ? null
          : DateTime.tryParse(json['reminderAt']),
    );
  }
}

class ArvinItem {
  String id;
  String title;
  String description;
  String category;
  DateTime date;
  DateTime? reminderAt;
  bool task;
  bool archived;
  bool trashed;
  bool tracking;
  List<String> tags;
  List<String> checklist;
  List<bool> checked;
  List<FollowUp> followUps;

  ArvinItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    required this.task,
    required this.tags,
    required this.checklist,
    required this.checked,
    required this.followUps,
    this.reminderAt,
    this.archived = false,
    this.trashed = false,
    this.tracking = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'date': date.toIso8601String(),
        'reminderAt': reminderAt?.toIso8601String(),
        'task': task,
        'archived': archived,
        'trashed': trashed,
        'tracking': tracking,
        'tags': tags,
        'checklist': checklist,
        'checked': checked,
        'followUps': followUps.map((e) => e.toJson()).toList(),
      };

  factory ArvinItem.fromJson(Map<String, dynamic> json) {
    final checks = List<String>.from(json['checklist'] ?? []);
    final checked = List<bool>.from(json['checked'] ?? []);
    while (checked.length < checks.length) {
      checked.add(false);
    }

    return ArvinItem(
      id: json['id'] ?? newId(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'عمومی',
      date: DateTime.parse(json['date']),
      reminderAt: json['reminderAt'] == null
          ? null
          : DateTime.tryParse(json['reminderAt']),
      task: json['task'] ?? false,
      archived: json['archived'] ?? false,
      trashed: json['trashed'] ?? false,
      tracking: json['tracking'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
      checklist: checks,
      checked: checked,
      followUps: (json['followUps'] as List? ?? [])
          .map((e) => FollowUp.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

Future<void> initNotifications() async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tehran'));

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const settings = InitializationSettings(android: android, iOS: ios);
  await notifications.initialize(settings);

  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

Future<void> scheduleReminder({
  required int id,
  required String title,
  required String body,
  required DateTime when,
}) async {
  if (!when.isAfter(DateTime.now())) return;

  const android = AndroidNotificationDetails(
    'arvin_reminders',
    'یادآوری‌های آروین',
    channelDescription: 'یادآوری کارها و پیگیری‌های آروین',
    importance: Importance.max,
    priority: Priority.high,
  );

  await notifications.zonedSchedule(
    id,
    title,
    body,
    tz.TZDateTime.from(when, tz.local),
    const NotificationDetails(android: android, iOS: DarwinNotificationDetails()),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  runApp(const ArvinApp());
}

class ArvinApp extends StatefulWidget {
  const ArvinApp({super.key});

  @override
  State<ArvinApp> createState() => _ArvinAppState();
}

class _ArvinAppState extends State<ArvinApp> {
  bool dark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'آروین',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Vazirmatn',
        colorSchemeSeed: Colors.indigo,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Vazirmatn',
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Home(
          onToggleTheme: () => setState(() => dark = !dark),
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const Home({super.key, required this.onToggleTheme});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<ArvinItem> items = [];
  List<String> categories = ['عمومی'];
  String filter = 'همه';
  String sort = 'آخرین وارده';
  String query = '';
  bool reverse = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('arvin_items');
    if (raw != null) {
      items = (jsonDecode(raw) as List)
          .map((e) => ArvinItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    categories = prefs.getStringList('arvin_categories') ?? ['عمومی'];
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'arvin_items',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    await prefs.setStringList('arvin_categories', categories);
  }

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<ArvinItem> get shown {
    var result = items.where((x) => !x.trashed).where((x) {
      switch (filter) {
        case 'یادداشت‌ها':
          return !x.task && !x.archived;
        case 'کارها':
          return x.task && !x.archived;
        case 'امروز':
          return sameDay(x.date, DateTime.now()) && !x.archived;
        case 'آینده':
          return x.date.isAfter(DateTime.now()) && !x.archived;
        case 'عقب‌افتاده':
          return x.date.isBefore(DateTime.now()) &&
              !sameDay(x.date, DateTime.now()) &&
              !x.archived;
        case 'بایگانی':
          return x.archived;
        default:
          return !x.archived;
      }
    }).where((x) {
      if (query.isEmpty) return true;
      final text = '${x.title} ${x.description} ${x.category} ${x.tags.join(' ')}';
      return text.contains(query);
    }).toList();

    result.sort((a, b) {
      int compare;
      if (sort == 'عنوان') {
        compare = a.title.compareTo(b.title);
      } else if (sort == 'تاریخ') {
        compare = a.date.compareTo(b.date);
      } else {
        final aLast = a.followUps.isEmpty ? a.date : a.followUps.last.at;
        final bLast = b.followUps.isEmpty ? b.date : b.followUps.last.at;
        compare = aLast.compareTo(bLast);
      }
      return reverse ? compare : -compare;
    });
    return result;
  }

  Future<void> addOrEdit({ArvinItem? existing, required bool task}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EntryEditor(
        task: task,
        categories: categories,
        existing: existing,
        onSave: (data) async {
          setState(() {
            if (existing == null) {
              items.add(data);
            } else {
              existing
                ..title = data.title
                ..description = data.description
                ..category = data.category
                ..date = data.date
                ..reminderAt = data.reminderAt
                ..tags = data.tags
                ..checklist = data.checklist
                ..checked = data.checked;
            }
          });

          if (data.reminderAt != null) {
            await scheduleReminder(
              id: ('item-${data.id}').hashCode,
              title: 'یادآوری آروین: ${data.title}',
              body: data.description.isEmpty
                  ? 'زمان یادآوری فرا رسیده است.'
                  : data.description,
              when: data.reminderAt!,
            );
          }
          await save();
        },
      ),
    );
  }

  void openItem(ArvinItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailsPage(
          item: item,
          onEdit: () => addOrEdit(existing: item, task: item.task),
          onChange: () {
            setState(() {});
            save();
          },
          onFollow: () => addFollowUp(item),
        ),
      ),
    );
  }

  Future<void> addFollowUp(ArvinItem item) async {
    final textController = TextEditingController();
    DateTime? reminder;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ثبت پیگیری'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'شرح پیگیری'),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(
                  reminder == null
                      ? 'افزودن یادآوری پیگیری'
                      : 'یادآوری: ${jalaliDate(reminder!)} • ${clock(reminder!)}',
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    initialDate: reminder ?? DateTime.now(),
                  );
                  if (d == null) return;
                  final t = await showTimePicker(
                    context: context,
                    initialTime:
                        TimeOfDay.fromDateTime(reminder ?? DateTime.now()),
                  );
                  if (t == null) return;
                  setDialogState(() {
                    reminder = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لغو'),
            ),
            FilledButton(
              onPressed: () async {
                final text = textController.text.trim();
                if (text.isEmpty) return;
                final follow = FollowUp(
                  id: newId(),
                  text: text,
                  at: DateTime.now(),
                  reminderAt: reminder,
                );
                setState(() => item.followUps.add(follow));
                if (reminder != null) {
                  await scheduleReminder(
                    id: ('follow-${follow.id}').hashCode,
                    title: 'یادآوری پیگیری: ${item.title}',
                    body: text,
                    when: reminder!,
                  );
                }
                await save();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('ثبت'),
            ),
          ],
        ),
      ),
    );
  }

  void menu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in [
              'همه',
              'امروز',
              'آینده',
              'عقب‌افتاده',
              'یادداشت‌ها',
              'کارها',
              'بایگانی'
            ])
              ListTile(
                title: Text(f),
                onTap: () {
                  setState(() => filter = f);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('دسته‌بندی‌ها'),
              onTap: () {
                Navigator.pop(context);
                categoryDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('حالت تاریک / روشن'),
              onTap: () {
                Navigator.pop(context);
                widget.onToggleTheme();
              },
            ),
          ],
        ),
      ),
    );
  }

  void categoryDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('دسته‌بندی‌ها'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...categories.map((e) => ListTile(title: Text(e))),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'دسته جدید'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty && !categories.contains(value)) {
                setState(() => categories.add(value));
                save();
              }
              Navigator.pop(context);
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
  }

  void sortDialog() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in ['آخرین وارده', 'تاریخ', 'عنوان'])
            ListTile(
              title: Text(value),
              trailing: Icon(reverse ? Icons.arrow_upward : Icons.arrow_downward),
              onTap: () {
                setState(() {
                  if (sort == value) {
                    reverse = !reverse;
                  } else {
                    sort = value;
                    reverse = false;
                  }
                });
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Future<void> search() async {
    final result = await showSearch<ArvinItem?>(
      context: context,
      delegate: ArvinSearchDelegate(items),
    );
    if (result != null && mounted) openItem(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('آروین • $filter'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: search),
          IconButton(icon: const Icon(Icons.sort), onPressed: sortDialog),
          IconButton(icon: const Icon(Icons.menu), onPressed: menu),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : shown.isEmpty
              ? const Center(child: Text('هنوز موردی ثبت نشده است'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: shown.length,
                  itemBuilder: (_, index) {
                    final item = shown[index];
                    final last = item.followUps.isEmpty
                        ? null
                        : item.followUps.last;
                    return Dismissible(
                      key: ValueKey(item.id),
                      background: const Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Icon(Icons.today),
                        ),
                      ),
                      secondaryBackground: const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Icon(Icons.delete_outline),
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          setState(() => item.date = DateTime.now());
                          await save();
                          return false;
                        }
                        setState(() => item.trashed = true);
                        await save();
                        return true;
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: ListTile(
                          onTap: () => openItem(item),
                          onLongPress: () =>
                              addOrEdit(existing: item, task: item.task),
                          leading: CircleAvatar(
                            child: Icon(item.task
                                ? Icons.task_alt
                                : Icons.note_alt_outlined),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${item.category} • ${last == null ? 'بدون پیگیری' : 'آخرین پیگیری ${clock(last.at)}'}\n'
                            '${jalaliDate(item.date)} • ${clock(item.date)}'
                            '${item.reminderAt == null ? '' : ' • 🔔 ${clock(item.reminderAt!)}'}',
                          ),
                          isThreeLine: true,
                          trailing: item.task
                              ? IconButton(
                                  icon: const Icon(Icons.add_task),
                                  onPressed: () => addFollowUp(item),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.note_add_outlined),
                  title: const Text('یادداشت جدید'),
                  onTap: () {
                    Navigator.pop(context);
                    addOrEdit(task: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_task),
                  title: const Text('کار جدید'),
                  onTap: () {
                    Navigator.pop(context);
                    addOrEdit(task: true);
                  },
                ),
              ],
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class EntryEditor extends StatefulWidget {
  final bool task;
  final List<String> categories;
  final ArvinItem? existing;
  final Future<void> Function(ArvinItem data) onSave;

  const EntryEditor({
    super.key,
    required this.task,
    required this.categories,
    required this.existing,
    required this.onSave,
  });

  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController tagsController;
  late final TextEditingController checklistController;
  late String category;
  late DateTime date;
  DateTime? reminderAt;

  @override
  void initState() {
    super.initState();
    final x = widget.existing;
    titleController = TextEditingController(text: x?.title ?? '');
    descriptionController = TextEditingController(text: x?.description ?? '');
    tagsController = TextEditingController(text: x?.tags.join(', ') ?? '');
    checklistController = TextEditingController(text: x?.checklist.join('\n') ?? '');
    category = x?.category ?? widget.categories.first;
    date = x?.date ?? DateTime.now();
    reminderAt = x?.reminderAt;
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    tagsController.dispose();
    checklistController.dispose();
    super.dispose();
  }

  Future<void> pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: date,
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date),
    );
    if (t == null) return;
    setState(() => date = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> pickReminder() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: reminderAt ?? DateTime.now(),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(reminderAt ?? DateTime.now()),
    );
    if (t == null) return;
    setState(() => reminderAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> submit() async {
    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final checks = checklistController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final previous = widget.existing;
    final data = ArvinItem(
      id: previous?.id ?? newId(),
      title: title,
      description: descriptionController.text.trim(),
      category: category,
      date: date,
      reminderAt: reminderAt,
      task: widget.task,
      tags: tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      checklist: checks,
      checked: List<bool>.generate(
        checks.length,
        (i) => i < (previous?.checked.length ?? 0) ? previous!.checked[i] : false,
      ),
      followUps: List<FollowUp>.from(previous?.followUps ?? []),
      archived: previous?.archived ?? false,
      trashed: previous?.trashed ?? false,
      tracking: previous?.tracking ?? false,
    );

    await widget.onSave(data);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null
                  ? 'ایجاد ${widget.task ? 'کار' : 'یادداشت'}'
                  : 'ویرایش',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'عنوان *'),
            ),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'توضیحات'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: category,
              items: widget.categories
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => category = value);
              },
              decoration: const InputDecoration(labelText: 'دسته‌بندی'),
            ),
            TextField(
              controller: tagsController,
              decoration: const InputDecoration(
                labelText: 'تگ‌ها با ویرگول جدا شوند',
              ),
            ),
            if (!widget.task)
              TextField(
                controller: checklistController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'چک‌لیست؛ هر مورد در یک خط',
                ),
              ),
            ListTile(
              leading: const Icon(Icons.event),
              title: Text('تاریخ و ساعت: ${jalaliDate(date)} • ${clock(date)}'),
              onTap: pickDateTime,
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(
                reminderAt == null
                    ? 'یادآوری تنظیم نشده'
                    : 'یادآوری: ${jalaliDate(reminderAt!)} • ${clock(reminderAt!)}',
              ),
              trailing: reminderAt == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => reminderAt = null),
                    ),
              onTap: pickReminder,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: submit,
              icon: const Icon(Icons.save_outlined),
              label: const Text('ذخیره'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class DetailsPage extends StatefulWidget {
  final ArvinItem item;
  final VoidCallback onEdit;
  final VoidCallback onChange;
  final Future<void> Function() onFollow;

  const DetailsPage({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onChange,
    required this.onFollow,
  });

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: widget.onEdit),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            item.description.isEmpty ? 'بدون توضیحات' : item.description,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 12),
          Text('تاریخ: ${jalaliDate(item.date)} • ${clock(item.date)}'),
          Text('دسته: ${item.category}'),
          if (item.tags.isNotEmpty)
            Wrap(
              spacing: 6,
              children: item.tags.map((e) => Chip(label: Text(e))).toList(),
            ),
          if (item.reminderAt != null)
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('یادآوری'),
              subtitle: Text(
                '${jalaliDate(item.reminderAt!)} • ${clock(item.reminderAt!)}',
              ),
            ),
          if (item.checklist.isNotEmpty) ...[
            const Divider(),
            const Text(
              'چک‌لیست',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ...List.generate(
              item.checklist.length,
              (i) => CheckboxListTile(
                value: item.checked[i],
                onChanged: (value) {
                  setState(() => item.checked[i] = value ?? false);
                  widget.onChange();
                },
                title: Text(item.checklist[i]),
              ),
            ),
          ],
          if (item.task) ...[
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'سوابق پیگیری',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                FilledButton.icon(
                  onPressed: widget.onFollow,
                  icon: const Icon(Icons.add),
                  label: const Text('پیگیری جدید'),
                ),
              ],
            ),
            ...item.followUps.reversed.map(
              (follow) => Card(
                child: ListTile(
                  title: Text(follow.text),
                  subtitle: Text(
                    '${jalaliDate(follow.at)} • ${clock(follow.at)}'
                    '${follow.reminderAt == null ? '' : '\nیادآوری: ${jalaliDate(follow.reminderAt!)} • ${clock(follow.reminderAt!)}'}',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ArvinSearchDelegate extends SearchDelegate<ArvinItem?> {
  final List<ArvinItem> items;

  ArvinSearchDelegate(this.items);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) {
    final result = items.where((item) {
      final text = '${item.title} ${item.description} ${item.category} ${item.tags.join(' ')}';
      return text.contains(query);
    }).toList();

    return ListView.builder(
      itemCount: result.length,
      itemBuilder: (_, index) {
        final item = result[index];
        return ListTile(
          title: Text(item.title),
          subtitle: Text(item.description),
          onTap: () => close(context, item),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}
