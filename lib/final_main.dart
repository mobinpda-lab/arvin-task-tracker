import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final notifications = FlutterLocalNotificationsPlugin();

String jalali(DateTime d) {
  final j = Gregorian.fromDateTime(d).toJalali();
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
}
String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String id() => DateTime.now().microsecondsSinceEpoch.toString();

Future<DateTime?> pickJalali(BuildContext context, DateTime initial) async {
  final p = await showJalaliDatePicker(
    context,
    initialDate: Gregorian.fromDateTime(initial).toJalali(),
    firstDate: Jalali(1390, 1, 1),
    lastDate: Jalali(1450, 12, 29),
  );
  if (p == null) return null;
  final g = p.toGregorian();
  return DateTime(g.year, g.month, g.day, initial.hour, initial.minute);
}

class FollowUp {
  final String id;
  String text;
  DateTime at;
  DateTime? reminder;
  FollowUp({required this.id, required this.text, required this.at, this.reminder});
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'at': at.toIso8601String(), 'reminder': reminder?.toIso8601String()};
  factory FollowUp.fromJson(Map<String, dynamic> j) => FollowUp(id: j['id'] ?? id(), text: j['text'] ?? '', at: DateTime.parse(j['at']), reminder: j['reminder'] == null ? null : DateTime.tryParse(j['reminder']));
}

class ArvinItem {
  String id, title, note, category;
  DateTime date;
  DateTime? reminder;
  bool task, archived, trash, tracking;
  List<String> tags, checklist;
  List<bool> checked;
  List<FollowUp> follows;
  ArvinItem({required this.id, required this.title, required this.note, required this.category, required this.date, required this.task, required this.tags, required this.checklist, required this.checked, required this.follows, this.reminder, this.archived = false, this.trash = false, this.tracking = false});
  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'note': note, 'category': category, 'date': date.toIso8601String(), 'reminder': reminder?.toIso8601String(),
    'task': task, 'archived': archived, 'trash': trash, 'tracking': tracking, 'tags': tags, 'checklist': checklist, 'checked': checked, 'follows': follows.map((e) => e.toJson()).toList()
  };
  factory ArvinItem.fromJson(Map<String, dynamic> j) {
    final c = List<String>.from(j['checklist'] ?? []);
    final ch = List<bool>.from(j['checked'] ?? []);
    while (ch.length < c.length) ch.add(false);
    return ArvinItem(
      id: j['id'] ?? id(), title: j['title'] ?? '', note: j['note'] ?? '', category: j['category'] ?? 'عمومی', date: DateTime.parse(j['date']),
      reminder: j['reminder'] == null ? null : DateTime.tryParse(j['reminder']), task: j['task'] ?? false, archived: j['archived'] ?? false,
      trash: j['trash'] ?? false, tracking: j['tracking'] ?? false, tags: List<String>.from(j['tags'] ?? []), checklist: c, checked: ch,
      follows: (j['follows'] as List? ?? []).map((e) => FollowUp.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}

Future<void> initNotify() async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
  await notifications.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()));
  await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
}
Future<void> notifyAt({required int nid, required String title, required String body, required DateTime at}) async {
  if (!at.isAfter(DateTime.now())) return;
  const a = AndroidNotificationDetails('arvin', 'یادآوری‌های آروین', channelDescription: 'یادآوری کارها و پیگیری‌ها', importance: Importance.max, priority: Priority.high);
  await notifications.zonedSchedule(nid, title, body, tz.TZDateTime.from(at, tz.local), const NotificationDetails(android: a, iOS: DarwinNotificationDetails()), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
}

Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); await initNotify(); runApp(const Arvin()); }

class Arvin extends StatefulWidget { const Arvin({super.key}); @override State<Arvin> createState() => _ArvinState(); }
class _ArvinState extends State<Arvin> {
  bool dark = false;
  String font = 'Vazirmatn';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); if (mounted) setState(() { dark = p.getBool('dark') ?? false; font = p.getString('font') ?? 'Vazirmatn'; }); }
  Future<void> setFont(String value) async { final p = await SharedPreferences.getInstance(); await p.setString('font', value); setState(() => font = value); }
  Future<void> setDark(bool value) async { final p = await SharedPreferences.getInstance(); await p.setBool('dark', value); setState(() => dark = value); }
  @override Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, title: 'آروین', theme: ThemeData(useMaterial3: true, fontFamily: font, colorSchemeSeed: Colors.indigo), darkTheme: ThemeData(useMaterial3: true, fontFamily: font, colorSchemeSeed: Colors.indigo, brightness: Brightness.dark), themeMode: dark ? ThemeMode.dark : ThemeMode.light, home: Directionality(textDirection: TextDirection.rtl, child: Home(onFont: setFont, onDark: setDark)));
}

class Home extends StatefulWidget {
  final Future<void> Function(String) onFont; final Future<void> Function(bool) onDark;
  const Home({super.key, required this.onFont, required this.onDark});
  @override State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> {
  List<ArvinItem> items = []; List<String> cats = ['عمومی']; String filter='همه', catFilter='همه', sort='آخرین وارده', search=''; bool rev=false, multi=false, loading=true; final selected=<String>{};
  @override void initState(){super.initState();load();}
  Future<void> load() async { final p=await SharedPreferences.getInstance(); final raw=p.getString('items'); if(raw!=null) items=(jsonDecode(raw) as List).map((e)=>ArvinItem.fromJson(Map<String,dynamic>.from(e))).toList(); cats=p.getStringList('cats')??['عمومی']; if(mounted)setState(()=>loading=false); }
  Future<void> save() async { final p=await SharedPreferences.getInstance(); await p.setString('items', jsonEncode(items.map((e)=>e.toJson()).toList())); await p.setStringList('cats', cats); }
  bool today(DateTime d){final n=DateTime.now(); return d.year==n.year&&d.month==n.month&&d.day==n.day;}
  List<ArvinItem> get shown { final n=DateTime.now(); final r=items.where((x)=>!x.trash).where((x){switch(filter){case'یادداشت‌ها':return !x.task&&!x.archived;case'کارها':return x.task&&!x.archived;case'امروز':return today(x.date)&&!x.archived;case'آینده':return x.date.isAfter(n)&&!x.archived;case'عقب‌افتاده':return x.date.isBefore(n)&&!today(x.date)&&!x.archived;case'بایگانی':return x.archived;case'سطل زباله':return x.trash;default:return !x.archived;}}).where((x)=>catFilter=='همه'||x.category==catFilter).where((x){if(search.isEmpty)return true;final s='${x.title} ${x.note} ${x.category} ${x.tags.join(' ')} ${x.follows.map((e)=>e.text).join(' ')}';return s.contains(search);}).toList(); r.sort((a,b){int c;if(sort=='عنوان')c=a.title.compareTo(b.title);else if(sort=='تاریخ')c=a.date.compareTo(b.date);else{final aa=a.follows.isEmpty?a.date:a.follows.last.at;final bb=b.follows.isEmpty?b.date:b.follows.last.at;c=aa.compareTo(bb);}return rev?c:-c;});return r; }

  Future<void> editItem({ArvinItem? old, required bool task}) async { await showModalBottomSheet(context:context,isScrollControlled:true,builder:(_)=>Editor(old:old,task:task,cats:cats,onSave:(x)async{ if(old==null)items.add(x);else{final i=items.indexWhere((e)=>e.id==old.id); if(i>=0)items[i]=x;} await save(); if(x.reminder!=null)await notifyAt(nid:x.id.hashCode,title:'یادآوری آروین: ${x.title}',body:x.note.isEmpty?'زمان یادآوری فرا رسید.':x.note,at:x.reminder!); setState((){}); })); }
  void open(ArvinItem x){Navigator.push(context,MaterialPageRoute(builder:(_)=>Details(item:x,onEdit:()=>editItem(old:x,task:x.task),onChanged:(){save();setState((){});},onAddFollow:()=>addFollow(x),onEditFollow:(f)=>editFollow(x,f),onDeleteFollow:(f)=>deleteFollow(x,f)));}

  Future<void> addFollow(ArvinItem item) async { final c=TextEditingController(); DateTime at=DateTime.now(), reminder; reminder = DateTime.now().add(const Duration(minutes:1)); DateTime? r;
    await showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('ثبت پیگیری'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:c,maxLines:3,decoration:const InputDecoration(labelText:'شرح پیگیری (اختیاری)')),ListTile(title:Text('تاریخ: ${jalali(at)} • ${hm(at)}'),leading:const Icon(Icons.event),onTap:()async{final d=await pickJalali(ctx,at);if(d==null)return;final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(at));if(t!=null)setD(()=>at=DateTime(d.year,d.month,d.day,t.hour,t.minute));}),ListTile(title:Text(r==null?'یادآوری ندارد':'یادآوری: ${jalali(r!)} • ${hm(r!)}'),leading:const Icon(Icons.notifications),onTap:()async{final d=await pickJalali(ctx,r??reminder);if(d==null)return;final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(r??reminder));if(t!=null)setD(()=>r=DateTime(d.year,d.month,d.day,t.hour,t.minute));}),],),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('لغو')),FilledButton(onPressed:()async{final f=FollowUp(id:id(),text:c.text.trim(),at:at,reminder:r);item.follows.add(f);if(r!=null)await notifyAt(nid:f.id.hashCode,title:'یادآوری پیگیری: ${item.title}',body:f.text.isEmpty?'زمان پیگیری فرا رسید.':f.text,at:r!);await save();if(mounted)setState((){});if(mounted)Navigator.pop(ctx);},child:const Text('ثبت'))]}))); }
  Future<void> editFollow(ArvinItem item, FollowUp f) async { final c=TextEditingController(text:f.text); DateTime at=f.at; DateTime? r=f.reminder; await showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('ویرایش پیگیری'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:c,maxLines:3,decoration:const InputDecoration(labelText:'شرح پیگیری (اختیاری)')),ListTile(title:Text('${jalali(at)} • ${hm(at)}'),leading:const Icon(Icons.event),onTap:()async{final d=await pickJalali(ctx,at);if(d==null)return;final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(at));if(t!=null)setD(()=>at=DateTime(d.year,d.month,d.day,t.hour,t.minute));}),ListTile(title:Text(r==null?'یادآوری ندارد':'${jalali(r!)} • ${hm(r!)}'),leading:const Icon(Icons.notifications),onTap:()async{final d=await pickJalali(ctx,r??DateTime.now());if(d==null)return;final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(r??DateTime.now()));if(t!=null)setD(()=>r=DateTime(d.year,d.month,d.day,t.hour,t.minute));}),],),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('لغو')),FilledButton(onPressed:()async{f.text=c.text.trim();f.at=at;f.reminder=r;await save();if(mounted)setState((){});if(mounted)Navigator.pop(ctx);},child:const Text('ذخیره'))]}))); }
  Future<void> deleteFollow(ArvinItem item, FollowUp f) async { item.follows.removeWhere((x)=>x.id==f.id); await save(); if(mounted)setState((){}); }

  Future<void> backupShare() async { final bytes=Uint8List.fromList(utf8.encode(jsonEncode({'version':1,'items':items.map((e)=>e.toJson()).toList(),'cats':cats}))); await SharePlus.instance.share(ShareParams(files:[XFile.fromData(bytes,name:'arvin-backup.json',mimeType:'application/json')],text:'پشتیبان آروین')); }
  Future<void> backupSave() async { final bytes=Uint8List.fromList(utf8.encode(jsonEncode({'version':1,'items':items.map((e)=>e.toJson()).toList(),'cats':cats}))); await FilePicker.platform.saveFile(fileName:'arvin-backup.json',bytes:bytes); }
  Future<void> restore() async { final r=await FilePicker.platform.pickFiles(withData:true); if(r==null||r.files.single.bytes==null)return; final j=jsonDecode(utf8.decode(r.files.single.bytes!)); items=(j['items'] as List).map((e)=>ArvinItem.fromJson(Map<String,dynamic>.from(e))).toList(); cats=List<String>.from(j['cats']??['عمومی']); await save(); if(mounted)setState((){}); }
  Future<void> pdfOne(ArvinItem x) async { final data=await makePdf([x], 'گزارش کار: ${x.title}'); await Printing.sharePdf(bytes:data,filename:'arvin-${x.id}.pdf'); }
  Future<Uint8List> makePdf(List<ArvinItem> xs,String heading) async { final font=await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'); final f=pw.Font.ttf(font); final doc=pw.Document(); doc.addPage(pw.MultiPage(theme:pw.ThemeData.withFont(base:f),build:(c)=>[pw.Text(heading),...xs.map((x)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.SizedBox(height:8),pw.Text(x.title),pw.Text('تاریخ: ${jalali(x.date)} ${hm(x.date)}'),pw.Text('دسته: ${x.category}'),pw.Text(x.note.isEmpty?'بدون توضیحات':x.note),pw.Text('پیگیری‌ها:'),...x.follows.map((q)=>pw.Text('- ${q.text.isEmpty?'بدون شرح':q.text} | ${jalali(q.at)} ${hm(q.at)}'))]))])); return doc.save(); }
  Future<void> pdfList() async { final data=await makePdf(shown,'فهرست آروین'); await Printing.sharePdf(bytes:data,filename:'arvin-list.pdf'); }
  void categoriesDialog(){ final c=TextEditingController(); showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('دسته‌بندی‌ها'),content:SizedBox(width:double.maxFinite,height:320,child:Column(children:[Expanded(child:ListView(children:cats.map((e)=>ListTile(title:Text(e))).toList())),TextField(controller:c,decoration:const InputDecoration(labelText:'دسته جدید'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('بستن')),FilledButton(onPressed:(){final v=c.text.trim();if(v.isNotEmpty&&!cats.contains(v)){cats.add(v);save();setState((){});}Navigator.pop(context);},child:const Text('افزودن'))])); }
  void fontDialog(){ final names=['Vazirmatn','Mitra','Homa','Koodak','IranSans','Faraz']; showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('فونت برنامه'),content:Column(mainAxisSize:MainAxisSize.min,children:names.map((f)=>RadioListTile<String>(value:f,groupValue:Theme.of(context).fontFamily,onChanged:(v){if(v!=null){widget.onFont(v);Navigator.pop(context);}},title:Text(f))).toList()))); }
  void menu(){showModalBottomSheet(context:context,isScrollControlled:true,builder:(_)=>SafeArea(child:SizedBox(height:MediaQuery.of(context).size.height*.78,child:ListView(children:[for(final f in['همه','امروز','آینده','عقب‌افتاده','یادداشت‌ها','کارها','بایگانی','سطل زباله'])ListTile(title:Text(f),onTap:(){setState(()=>filter=f);Navigator.pop(context);}),ListTile(leading:const Icon(Icons.category),title:const Text('دسته‌بندی‌ها'),onTap:(){Navigator.pop(context);categoriesDialog();}),ListTile(leading:const Icon(Icons.picture_as_pdf),title:const Text('PDF فهرست'),onTap:(){Navigator.pop(context);pdfList();}),ListTile(leading:const Icon(Icons.backup),title:const Text('پشتیبان‌گیری روی گوشی'),onTap:(){Navigator.pop(context);backupSave();}),ListTile(leading:const Icon(Icons.cloud_upload),title:const Text('اشتراک پشتیبان (برای Dropbox و سایر برنامه‌ها)'),onTap:(){Navigator.pop(context);backupShare();}),ListTile(leading:const Icon(Icons.restore),title:const Text('بازیابی پشتیبان'),onTap:(){Navigator.pop(context);restore();}),ListTile(leading:const Icon(Icons.font_download),title:const Text('تغییر فونت'),onTap:(){Navigator.pop(context);fontDialog();}),ListTile(leading:const Icon(Icons.dark_mode),title:const Text('حالت تاریک / روشن'),onTap:(){Navigator.pop(context);widget.onDark(true);})])))); }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('آروین • $filter'),actions:[IconButton(icon:const Icon(Icons.search),onPressed:()async{final c=TextEditingController(text:search);final r=await showDialog<String>(context:context,builder:(_)=>AlertDialog(title:const Text('جستجو'),content:TextField(controller:c,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(context,c.text),child:const Text('جستجو'))]));if(r!=null)setState(()=>search=r.trim());}),IconButton(icon:const Icon(Icons.sort),onPressed:()=>setState(()=>rev=!rev)),IconButton(icon:const Icon(Icons.menu),onPressed:menu)],bottom:PreferredSize(preferredSize:const Size.fromHeight(52),child:SingleChildScrollView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),child:Row(children:[for(final c in['همه',...cats])Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:ChoiceChip(label:Text(c),selected:catFilter==c,onSelected:(_)=>setState(()=>catFilter=c)))]))),body:loading?const Center(child:CircularProgressIndicator()):shown.isEmpty?const Center(child:Text('هنوز موردی ثبت نشده است')):ListView.builder(itemCount:shown.length,padding:const EdgeInsets.only(bottom:90),itemBuilder:(_,i){final x=shown[i];final last=x.follows.isEmpty?null:x.follows.last;return Dismissible(key:ValueKey(x.id),background:const Align(alignment:Alignment.centerRight,child:Padding(padding:EdgeInsets.all(20),child:Icon(Icons.today))),secondaryBackground:const Align(alignment:Alignment.centerLeft,child:Padding(padding:EdgeInsets.all(20),child:Icon(Icons.delete_outline))),confirmDismiss:(d)async{if(d==DismissDirection.startToEnd){x.date=DateTime.now();await save();setState((){});return false;}x.trash=true;await save();return true;},child:Card(child:ListTile(onTap:()=>open(x),onLongPress:()=>editItem(old:x,task:x.task),leading:CircleAvatar(child:Icon(x.task?Icons.task_alt:Icons.note_alt_outlined)),title:Text(x.title),subtitle:Text('${x.category} • ${last==null?'بدون پیگیری':hm(last.at)}\n${jalali(x.date)} • ${hm(x.date)}${x.reminder==null?'':' • 🔔 ${hm(x.reminder!)}'}'),trailing:x.task?IconButton(icon:const Icon(Icons.add_task),onPressed:()=>addFollow(x)):null)));}),floatingActionButton:FloatingActionButton(onPressed:()=>showModalBottomSheet(context:context,builder:(_)=>SafeArea(child:Wrap(children:[ListTile(title:const Text('یادداشت جدید'),onTap:(){Navigator.pop(context);editItem(task:false);}),ListTile(title:const Text('کار جدید'),onTap:(){Navigator.pop(context);editItem(task:true);})]))),child:const Icon(Icons.add)));
}

class Editor extends StatefulWidget { final ArvinItem? old; final bool task; final List<String> cats; final Future<void> Function(ArvinItem) onSave; const Editor({super.key,required this.old,required this.task,required this.cats,required this.onSave}); @override State<Editor> createState()=>_EditorState(); }
class _EditorState extends State<Editor>{late final TextEditingController title,note,tags,checks;late String cat;late DateTime date;DateTime? reminder;@override void initState(){super.initState();final x=widget.old;title=TextEditingController(text:x?.title??'');note=TextEditingController(text:x?.note??'');tags=TextEditingController(text:x?.tags.join(', ')??'');checks=TextEditingController(text:x?.checklist.join('\n')??'');cat=x?.category??widget.cats.first;date=x?.date??DateTime.now();reminder=x?.reminder;}@override void dispose(){title.dispose();note.dispose();tags.dispose();checks.dispose();super.dispose();}Future<void> saveIt()async{if(title.text.trim().isEmpty)return;final cs=checks.text.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();final o=widget.old;final x=ArvinItem(id:o?.id??id(),title:title.text.trim(),note:note.text.trim(),category:cat,date:date,reminder:reminder,task:widget.task,tags:tags.text.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(),checklist:cs,checked:List<bool>.generate(cs.length,(i)=>i<(o?.checked.length??0)?o!.checked[i]:false),follows:List<FollowUp>.from(o?.follows??[]),archived:o?.archived??false,trash:o?.trash??false,tracking:o?.tracking??false);await widget.onSave(x);if(mounted)Navigator.pop(context);} @override Widget build(BuildContext c)=>Padding(padding:EdgeInsets.only(bottom:MediaQuery.of(c).viewInsets.bottom),child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(widget.old==null?'ایجاد ${widget.task?'کار':'یادداشت'}':'ویرایش',style:Theme.of(c).textTheme.titleLarge),TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان *')),TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'توضیحات')),DropdownButtonFormField<String>(value:cat,items:widget.cats.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v){if(v!=null)setState(()=>cat=v);},decoration:const InputDecoration(labelText:'دسته‌بندی')),TextField(controller:tags,decoration:const InputDecoration(labelText:'تگ‌ها')),if(!widget.task)TextField(controller:checks,maxLines:4,decoration:const InputDecoration(labelText:'چک‌لیست؛ هر مورد یک خط')),ListTile(title:Text('${jalali(date)} • ${hm(date)}'),leading:const Icon(Icons.event),onTap:()async{final d=await pickJalali(c,date);if(d==null)return;final t=await showTimePicker(context:c,initialTime:TimeOfDay.fromDateTime(date));if(t!=null)setState(()=>date=DateTime(d.year,d.month,d.day,t.hour,t.minute));}),ListTile(title:Text(reminder==null?'یادآوری ندارد':'${jalali(reminder!)} • ${hm(reminder!)}'),leading:const Icon(Icons.notifications),onTap:()async{final d=await pickJalali(c,reminder??DateTime.now());if(d==null)return;final t=await showTimePicker(context:c,initialTime:TimeOfDay.fromDateTime(reminder??DateTime.now()));if(t!=null)setState(()=>reminder=DateTime(d.year,d.month,d.day,t.hour,t.minute));}),FilledButton(onPressed:saveIt,child:const Text('ذخیره'))])));}
}

class Details extends StatefulWidget{final ArvinItem item;final VoidCallback onEdit,onChanged;final Future<void> Function() onAddFollow;final Future<void> Function(FollowUp) onEditFollow,onDeleteFollow;const Details({super.key,required this.item,required this.onEdit,required this.onChanged,required this.onAddFollow,required this.onEditFollow,required this.onDeleteFollow});@override State<Details> createState()=>_DetailsState();}
class _DetailsState extends State<Details>{@override Widget build(BuildContext c){final x=widget.item;return WillPopScope(onWillPop:()async{widget.onChanged();return true;},child:Scaffold(appBar:AppBar(title:Text(x.title),actions:[IconButton(icon:const Icon(Icons.edit),onPressed:widget.onEdit)]),body:ListView(padding:const EdgeInsets.all(16),children:[Text(x.note.isEmpty?'بدون توضیحات':x.note,style:const TextStyle(fontSize:18)),Text('${jalali(x.date)} • ${hm(x.date)}'),Text('دسته: ${x.category}'),if(x.tags.isNotEmpty)Wrap(children:x.tags.map((e)=>Chip(label:Text(e))).toList()),if(x.checklist.isNotEmpty)...[const Divider(),const Text('چک‌لیست',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),...List.generate(x.checklist.length,(i)=>CheckboxListTile(value:x.checked[i],onChanged:(v){setState(()=>x.checked[i]=v??false);widget.onChanged();},title:Text(x.checklist[i])))],if(x.task)...[const Divider(),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('سوابق پیگیری',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),FilledButton.icon(onPressed:widget.onAddFollow,icon:const Icon(Icons.add),label:const Text('پیگیری جدید'))]),...x.follows.reversed.map((f)=>Card(child:ListTile(title:Text(f.text.isEmpty?'بدون شرح':f.text),subtitle:Text('${jalali(f.at)} • ${hm(f.at)}${f.reminder==null?'':'\nیادآوری: ${jalali(f.reminder!)} • ${hm(f.reminder!)}'}'),trailing:PopupMenuButton<String>(onSelected:(v)async{if(v=='edit')await widget.onEditFollow(f);else await widget.onDeleteFollow(f);if(mounted)setState((){});},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('ویرایش')),PopupMenuItem(value:'delete',child:Text('حذف'))]))))]]));}}
