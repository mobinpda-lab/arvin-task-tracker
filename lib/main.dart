import 'package:flutter/material.dart';

void main() {
  runApp(const ArvinApp());
}

class ArvinApp extends StatelessWidget {
  const ArvinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'آروین',
      theme: ThemeData(useMaterial3: true, fontFamily: 'Vazirmatn'),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> notes = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('آروین'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: const [
              DrawerHeader(
                child: Text(
                  'آروین',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(title: Text('همه')),
              ListTile(title: Text('امروز')),
              ListTile(title: Text('آینده')),
              ListTile(title: Text('عقب‌افتاده')),
              ListTile(title: Text('بایگانی')),
              ListTile(title: Text('سطل زباله')),
            ],
          ),
        ),
      ),
      body: notes.isEmpty
          ? const Center(child: Text('هنوز موردی ثبت نشده است'))
          : ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(notes[index]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final controller = TextEditingController();
          final value = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('یادداشت جدید'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'عنوان'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('لغو'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: const Text('ذخیره'),
                ),
              ],
            ),
          );
          if (value != null && value.isNotEmpty) {
            setState(() => notes.add(value));
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
