import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:flutter_jalali_date_picker/flutter_jalali_date_picker.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final notifications = FlutterLocalNotificationsPlugin();
String makeId() => DateTime.now().microsecondsSinceEpoch.toString();
String jalali(DateTime d) { final j = Gregorian.fromDateTime(d).toJalali(); return '${j.year}/${j.month.toString().padLeft(2,'0')}/${j.day.toString().padLeft(2,'0')}'; }
String hm(DateTime d) => '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

Future<DateTime?> pickJalaliDateTime(BuildContext c, DateTime initial, {bool allowPast = true}) async {
  final min = allowPast ? Jalali(1380,1,1) : Gregorian.fromDateTime(DateTime.now()).toJalali();
  final max = Jalali(1450,12,29);
  final p = await showJalaliDatePicker(c,
    initialDate: Gregorian.fromDateTime(initial).toJalali(),
    firstDate: min,
    lastDate: max,
    textDirection: TextDirection.rtl,
  );
  if (p == null) return null;
  final g = p.toGregorian();
  final t = await showTimePicker(context: c, initialTime: TimeOfDay.fromDateTime(initial));
  if (t == null) return null;
  return DateTime(g.year,g.month,g.day,t.hour,t.minute);
}

class FollowUp {
  String id, text;
  DateTime at;
  DateTime? reminder;
  FollowUp({required this.id,required this.text,required this.at,this.reminder});
  Map<String,dynamic> toJson()=>{'id':id,'text':text,'at':at.toIso8601String(),'reminder':reminder?.toIso8601String()};
  factory FollowUp.fromJson(Map<String,dynamic> j)=>FollowUp(
    id: '${j['id'] ?? makeId()}', text: '${j['text'] ?? ''}',
    at: DateTime.tryParse('${j['at']}') ?? DateTime.now(),
    reminder: j['reminder']==null?null:DateTime.tryParse('${j['reminder']}'),
  );
}

class Item {
  String id,title,note,category;
  DateTime date;
  DateTime? reminder;
  bool task,archived,trashed,tracking;
  List<String> tags, checklist;
  List<bool> checked;
  List<FollowUp> followUps;
  Item({required this.id,required this.title,required this.note,required this.category,required this.date,required this.task,required this.tags,required this.checklist,required this.checked,required this.followUps,this.reminder,this.archived=false,this.trashed=false,this.tracking=false});
  Map<String,dynamic> toJson()=>{
    'id':id,'title':title,'note':note,'category':category,'date':date.toIso8601String(),'reminder':reminder?.toIso8601String(),
    'task':task,'archived':archived,'trashed':trashed,'tracking':tracking,'tags':tags,'checklist':checklist,'checked':checked,
    'followUps':followUps.map((e)=>e.toJson()).toList(),
  };
  factory Item.fromJson(Map<String,dynamic> j){
    final cl=List<String>.from(j['checklist']??[]); final ch=List<bool>.from(j['checked']??[]); while(ch.length<cl.length){ch.add(false);} 
    return Item(id:'${j['id'] ?? makeId()}',title:'${j['title']??''}',note:'${j['note']??j['description']??''}',category:'${j['category']??j['cat']??'عمومی'}',
      date:DateTime.tryParse('${j['date']}')??DateTime.now(), reminder:j['reminder']==null?null:DateTime.tryParse('${j['reminder']}'),
      task:j['task']??false,archived:j['archived']??j['arch']??false,trashed:j['trashed']??j['trash']??false,tracking:j['tracking']??false,
      tags:List<String>.from(j['tags']??[]),checklist:cl,checked:ch,
      followUps:(j['followUps']??j['fs']??[]).map((e)=>FollowUp.fromJson(Map<String,dynamic>.from(e))).toList());
  }
}

Future<void> initNotifications() async {
  tz.initializeTimeZones(); tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
  await notifications.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
}
Future<void> scheduleReminder(int id,String title,String body,DateTime when) async {
  if(!when.isAfter(DateTime.now())) return;
  const a=AndroidNotificationDetails('arvin','یادآوری‌های آروین',channelDescription:'یادآوری کارها و پیگیری‌ها',importance:Importance.max,priority:Priority.high);
  await notifications.zonedSchedule(id,title,body,tz.TZDateTime.from(when,tz.local),const NotificationDetails(android:a),androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle);
}

Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); await initNotifications(); runApp(const ArvinApp()); }
class ArvinApp extends StatefulWidget { const ArvinApp({super.key}); @override State<ArvinApp> createState()=>_ArvinAppState(); }
class _ArvinAppState extends State<ArvinApp>{String font='Vazirmatn'; bool dark=false; @override void initState(){super.initState();loadPrefs();} Future<void>loadPrefs()async{final p=await SharedPreferences.getInstance();setState((){font=p.getString('font')??'Vazirmatn';dark=p.getBool('dark')??false;});} Future<void> setFont(String f)async{final p=await SharedPreferences.getInstance();await p.setString('font',f);setState(()=>font=f);} Future<void> setDark(bool v)async{final p=await SharedPreferences.getInstance();await p.setBool('dark',v);setState(()=>dark=v);} @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'آروین',theme:ThemeData(useMaterial3:true,fontFamily:font),darkTheme:ThemeData(useMaterial3:true,fontFamily:font,brightness:Brightness.dark),themeMode:dark?ThemeMode.dark:ThemeMode.light,home:Directionality(textDirection:TextDirection.rtl,child:Home(font:font,dark:dark,onFont:setFont,onDark:setDark)));}

class Home extends StatefulWidget { final String font; final bool dark; final Future<void> Function(String) onFont; final Future<void> Function(bool) onDark; const Home({super.key,required this.font,required this.dark,required this.onFont,required this.onDark}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home>{
  List<Item> items=[]; List<String> categories=['عمومی']; List<String> tags=[];
  String categoryFilter='همه', statusFilter='همه', sort='آخرین وارده'; bool reverse=false, multi=false; final selected=<String>{};
  String leftSwipe='سطل زباله', rightSwipe='امروز'; bool loading=true;
  @override void initState(){super.initState();load();}
  Future<void> load() async { final p=await SharedPreferences.getInstance(); final raw=p.getString('items')??p.getString('arvin_items'); if(raw!=null){items=(jsonDecode(raw) as List).map((e)=>Item.fromJson(Map<String,dynamic>.from(e))).toList();} categories=p.getStringList('cats')??p.getStringList('arvin_categories')??['عمومی']; tags=p.getStringList('tags')??[]; categoryFilter=p.getString('catFilter')??'همه'; statusFilter=p.getString('statusFilter')??'همه'; leftSwipe=p.getString('leftSwipe')??'سطل زباله'; rightSwipe=p.getString('rightSwipe')??'امروز'; for(final x in items){if(x.reminder!=null) scheduleReminder(('i'+x.id).hashCode,'یادآوری آروین: ${x.title}',x.note,x.reminder!); for(final f in x.followUps){if(f.reminder!=null)scheduleReminder(('f'+f.id).hashCode,'یادآوری پیگیری: ${x.title}',f.text.isEmpty?'زمان پیگیری فرا رسید':f.text,f.reminder!);}} setState(()=>loading=false); }
  Future<void> save() async { final p=await SharedPreferences.getInstance(); await p.setString('items',jsonEncode(items.map((e)=>e.toJson()).toList())); await p.setStringList('cats',categories); await p.setStringList('tags',tags); await p.setString('catFilter',categoryFilter); await p.setString('statusFilter',statusFilter); await p.setString('leftSwipe',leftSwipe); await p.setString('rightSwipe',rightSwipe); }
  List<Item> get visible { final now=DateTime.now(); var r=items.where((x)=>!x.trashed).where((x){if(statusFilter=='بایگانی')return x.archived; if(x.archived)return false; switch(statusFilter){case'امروز':return sameDay(x.date,now);case'آینده':return x.date.isAfter(now);case'عقب‌افتاده':return x.date.isBefore(now)&&!sameDay(x.date,now);case'یادداشت‌ها':return !x.task;case'کارها':return x.task;default:return true;}}).where((x)=>categoryFilter=='همه'||x.category==categoryFilter).toList(); r.sort((a,b){int c; if(sort=='عنوان') c=a.title.compareTo(b.title); else if(sort=='تاریخ') c=a.date.compareTo(b.date); else {final aa=a.followUps.isEmpty?a.date:a.followUps.last.at; final bb=b.followUps.isEmpty?b.date:b.followUps.last.at; c=aa.compareTo(bb);} return reverse?c:-c;}); return r; }

  Future<void> editItem({Item? old,bool? task}) async { final x=await showModalBottomSheet<Item>(context:context,isScrollControlled:true,builder:(_)=>Editor(old:old,task:task??old?.task??false,categories:categories,tags:tags)); if(x==null)return; if(old==null)items.add(x); else {final i=items.indexWhere((e)=>e.id==old.id); if(i>=0)items[i]=x;} await save(); if(x.reminder!=null) await scheduleReminder(('i'+x.id).hashCode,'یادآوری آروین: ${x.title}',x.note,x.reminder!); setState((){}); }
  Future<void> addFollowUp(Item x,{FollowUp? old}) async { final f=await showDialog<FollowUp>(context:context,builder:(_)=>FollowEditor(old:old)); if(f==null)return; if(old==null)x.followUps.add(f); else {final i=x.followUps.indexOf(old); if(i>=0)x.followUps[i]=f;} await save(); if(f.reminder!=null)await scheduleReminder(('f'+f.id).hashCode,'یادآوری پیگیری: ${x.title}',f.text.isEmpty?'زمان پیگیری فرا رسید':f.text,f.reminder!); setState((){}); }
  Future<void> deleteFollowUp(Item x, FollowUp f) async { x.followUps.remove(f); await save(); setState((){}); }
  Future<void> exportPdf(Item x) async { final doc=pw.Document(); doc.addPage(pw.MultiPage(build:(_)=>[pw.Text(x.title),pw.Text('دسته: ${x.category}'),pw.Text('تاریخ: ${jalali(x.date)} ${hm(x.date)}'),pw.Text(x.note),...x.followUps.map((f)=>pw.Text('${jalali(f.at)} ${hm(f.at)}  ${f.text}'))])); await Printing.sharePdf(bytes:await doc.save(),filename:'arvin_${x.id}.pdf'); }
  Future<void> exportList() async { final doc=pw.Document(); doc.addPage(pw.MultiPage(build:(_)=>visible.map((x)=>pw.Text('${x.title} | ${x.category} | ${jalali(x.date)}')).toList())); await Printing.sharePdf(bytes:await doc.save(),filename:'arvin_list.pdf'); }
  Future<void> backup() async { final dir=await getApplicationDocumentsDirectory(); final f=File('${dir.path}/arvin_backup.json'); await f.writeAsString(jsonEncode({'items':items.map((e)=>e.toJson()).toList(),'cats':categories,'tags':tags})); await Share.shareXFiles([XFile(f.path)],text:'پشتیبان آروین'); }
  Future<void> restore() async { final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json'],withData:true); if(r==null||r.files.single.bytes==null)return; final m=jsonDecode(utf8.decode(r.files.single.bytes!)) as Map<String,dynamic>; items=(m['items'] as List).map((e)=>Item.fromJson(Map<String,dynamic>.from(e))).toList(); categories=List<String>.from(m['cats']??['عمومی']); tags=List<String>.from(m['tags']??[]); await save(); setState((){}); }
  Future<void> manageList(String title,List<String> src,Future<void> Function(List<String>) done) async { final v=await showDialog<List<String>>(context:context,builder:(_)=>ManageDialog(title,src)); if(v!=null){await done(v);setState((){});} }
  Future<void> swipe(Item x,String action) async { switch(action){case'امروز':x.date=DateTime.now();break;case'بایگانی':x.archived=true;break;case'سطل زباله':x.trashed=true;break;case'پیگیری':if(x.task)await addFollowUp(x);break;case'ویرایش':await editItem(old:x);break;case'اشتراک‌گذاری':await exportPdf(x);break;} await save(); setState((){}); }
  void openItem(Item x){ Navigator.push(context,MaterialPageRoute(builder:(_)=>Details(item:x,onEdit:()=>editItem(old:x),onFollow:()=>addFollowUp(x),onEditFollow:(f)=>addFollowUp(x,old:f),onDeleteFollow:(f)=>deleteFollowUp(x,f),onChanged:(){save();setState((){});}))); }

  Future<void> settings() async { await Navigator.push(context,MaterialPageRoute(builder:(_)=>SettingsPage(font:widget.font,dark:widget.dark,onFont:widget.onFont,onDark:widget.onDark,left:leftSwipe,right:rightSwipe,onSwipe:(_l,_r)async{leftSwipe=_l;rightSwipe=_r;await save();setState((){});}))); }
  Future<String?> chooseAction(BuildContext c) async => showDialog<String>(context:c,builder:(_)=>SimpleDialog(title:const Text('عملیات Swipe'),children:['هیچ‌کاری','امروز','بایگانی','سطل زباله','پیگیری','ویرایش','اشتراک‌گذاری'].map((e)=>SimpleDialogOption(onPressed:()=>Navigator.pop(c,e),child:Text(e))).toList()));

  @override Widget build(BuildContext c){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return Scaffold(
      endDrawer: Drawer(child:SafeArea(child:ListView(children:[const DrawerHeader(child:Text('آروین',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold))),
        ...['همه','امروز','آینده','عقب‌افتاده','یادداشت‌ها','کارها','بایگانی'].map((v)=>ListTile(title:Text(v),onTap:(){setState(()=>statusFilter=v);save();Navigator.pop(c);})),
        ListTile(title:const Text('دسته‌بندی‌ها'),onTap:(){Navigator.pop(c);manageList('دسته‌بندی‌ها',categories,(v)async{categories=v.contains('عمومی')?v:['عمومی',...v];await save();});}),
        ListTile(title:const Text('تگ‌ها'),onTap:(){Navigator.pop(c);manageList('تگ‌ها',tags,(v)async{tags=v;await save();});}),
        ListTile(title:const Text('سطل زباله'),onTap:(){Navigator.pop(c);showTrash();}),
        ListTile(title:const Text('پشتیبان‌گیری'),onTap:(){Navigator.pop(c);backup();}),ListTile(title:const Text('بازیابی'),onTap:(){Navigator.pop(c);restore();}),
        ListTile(title:const Text('خروجی PDF لیست'),onTap:(){Navigator.pop(c);exportList();}),ListTile(title:const Text('تنظیمات'),onTap:(){Navigator.pop(c);settings();})]))),
      appBar:AppBar(title:const Text('آروین'),actions:[IconButton(icon:const Icon(Icons.search),onPressed:search),Builder(builder:(b)=>IconButton(icon:const Icon(Icons.menu),onPressed:()=>Scaffold.of(b).openEndDrawer()))]),
      body:Column(children:[Padding(padding:const EdgeInsets.all(8),child:Row(children:[Expanded(child:DropdownButtonFormField<String>(initialValue:categoryFilter,decoration:const InputDecoration(labelText:'دسته‌بندی',filled:true),items:['همه',...categories].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null){categoryFilter=v;save();setState((){});}})),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(initialValue:statusFilter,decoration:const InputDecoration(labelText:'وضعیت',filled:true),items:const ['همه','امروز','آینده','عقب‌افتاده','یادداشت‌ها','کارها','بایگانی'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null){statusFilter=v;save();setState((){});}}))])),
        Expanded(child:visible.isEmpty?const Center(child:Text('موردی وجود ندارد')):ListView.builder(itemCount:visible.length,itemBuilder:(ctx,i){final x=visible[i];final last=x.followUps.isEmpty?null:x.followUps.last;return Dismissible(key:ValueKey(x.id),background:Container(alignment:Alignment.centerRight,padding:const EdgeInsets.all(20),child:Text(rightSwipe)),secondaryBackground:Container(alignment:Alignment.centerLeft,padding:const EdgeInsets.all(20),child:Text(leftSwipe)),confirmDismiss:(d)async{await swipe(x,d==DismissDirection.startToEnd?rightSwipe:leftSwipe);return x.trashed||x.archived;},child:Card(child:ListTile(onLongPress:(){setState(()=>multi=true);selected.add(x.id);},onTap:(){if(multi){setState((){if(selected.contains(x.id))selected.remove(x.id);else selected.add(x.id);if(selected.isEmpty)multi=false;});}else openItem(x);},leading:CircleAvatar(child:Icon(x.task?Icons.task_alt:Icons.note_outlined)),title:Text(x.title.isEmpty?'بدون عنوان':x.title),subtitle:Text('${x.category} • ${jalali(x.date)} ${hm(x.date)}\n${last==null?'بدون پیگیری':'آخرین پیگیری ${jalali(last.at)} ${hm(last.at)}'}'),trailing:x.task?IconButton(icon:const Icon(Icons.add_task),onPressed:()=>addFollowUp(x)):null))));}))),
      ]),
      floatingActionButton:multi?FloatingActionButton.extended(onPressed:()async{for(final id in selected){final x=items.firstWhere((e)=>e.id==id);x.archived=true;}selected.clear();multi=false;await save();setState((){});},label:const Text('بایگانی انتخاب‌شده‌ها'),icon:const Icon(Icons.archive)):FloatingActionButton(onPressed:()=>editItem(task:false),child:const Icon(Icons.add)),
    );
  }
  Future<void> search() async { final ctl=TextEditingController(); final q=await showDialog<String>(context:context,builder:(_)=>AlertDialog(title:const Text('جستجو'),content:TextField(controller:ctl),actions:[FilledButton(onPressed:()=>Navigator.pop(context,ctl.text),child:const Text('جستجو'))])); if(q==null||q.isEmpty)return; final s=q.toLowerCase(); final r=items.where((x)=>('${x.title} ${x.note} ${x.category} ${x.tags.join(' ')} ${x.followUps.map((f)=>f.text).join(' ')}').toLowerCase().contains(s)).toList(); if(!mounted)return; showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('نتایج جستجو'),content:SizedBox(width:340,height:350,child:ListView(children:r.map((x)=>ListTile(title:Text(x.title),onTap:(){Navigator.pop(context);openItem(x);})).toList())))); }
  Future<void> showTrash() async { final tr=items.where((x)=>x.trashed).toList(); await showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('سطل زباله'),content:tr.isEmpty?const Text('سطل زباله خالی است'):SizedBox(width:340,height:300,child:ListView(children:tr.map((x)=>ListTile(title:Text(x.title),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(icon:const Icon(Icons.restore),onPressed:(){x.trashed=false;save();Navigator.pop(context);setState((){});}),IconButton(icon:const Icon(Icons.delete_forever),onPressed:(){x.trashed=true;items.remove(x);save();Navigator.pop(context);setState((){});})])).toList())),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('بستن'))]); }
}

class Editor extends StatefulWidget{final Item? old;final bool task;final List<String> categories,tags;const Editor({super.key,this.old,required this.task,required this.categories,required this.tags});@override State<Editor>createState()=>_EditorState();}
class _EditorState extends State<Editor>{late TextEditingController title,note,tagsCtl,checkCtl;late String cat;late bool task;late DateTime date;DateTime? rem;bool manualTitle=false;@override void initState(){super.initState();final x=widget.old;title=TextEditingController(text:x?.title??'');note=TextEditingController(text:x?.note??'');tagsCtl=TextEditingController(text:x?.tags.join(', ')??'');checkCtl=TextEditingController(text:x?.checklist.join('\n')??'');cat=x?.category??widget.categories.first;task=widget.task;date=x?.date??DateTime.now();rem=x?.reminder;title.addListener(()=>manualTitle=true);}String autoTitle(){final s=note.text.split('\n').map((e)=>e.trim()).firstWhere((e)=>e.isNotEmpty,orElse:()=> '');return s.length>80?s.substring(0,80):s;}@override Widget build(BuildContext c)=>Padding(padding:EdgeInsets.only(bottom:MediaQuery.of(c).viewInsets.bottom),child:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان')),TextField(controller:note,maxLines:6,onChanged:(_){if(!manualTitle&&title.text.trim().isEmpty){final s=autoTitle();if(s.isNotEmpty)title.value=TextEditingValue(text:s,selection:TextSelection.collapsed(offset:s.length));}},decoration:const InputDecoration(labelText:'توضیحات / یادداشت')),SwitchListTile(title:const Text('فعال بودن پیگیری'),value:task,onChanged:(v)=>setState(()=>task=v)),DropdownButtonFormField<String>(initialValue:cat,items:widget.categories.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)setState(()=>cat=v);},decoration:const InputDecoration(labelText:'دسته‌بندی')),TextField(controller:tagsCtl,decoration:const InputDecoration(labelText:'تگ‌ها با ویرگول جدا شوند')),TextField(controller:checkCtl,maxLines:3,decoration:const InputDecoration(labelText:'چک‌لیست؛ هر مورد در یک سطر')),ListTile(title:Text('تاریخ و ساعت: ${jalali(date)} ${hm(date)}'),onTap:()async{final d=await pickJalaliDateTime(c,date,allowPast:true);if(d!=null)setState(()=>date=d);}),ListTile(title:Text(rem==null?'یادآوری ندارد':'یادآوری: ${jalali(rem!)} ${hm(rem!)}'),trailing:rem==null?null:IconButton(icon:const Icon(Icons.clear),onPressed:()=>setState(()=>rem=null)),onTap:()async{final d=await pickJalaliDateTime(c,rem??DateTime.now().add(const Duration(minutes:5)),allowPast:false);if(d!=null)setState(()=>rem=d);}),FilledButton(onPressed:(){final o=widget.old;final lines=checkCtl.text.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();Navigator.pop(c,Item(id:o?.id??makeId(),title:title.text.trim().isEmpty?autoTitle():title.text.trim(),note:note.text.trim(),category:cat,date:date,reminder:rem,task:task,tags:tagsCtl.text.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(),checklist:lines,checked:List<bool>.generate(lines.length,(i)=>i<(o?.checked.length??0)?o!.checked[i]:false),followUps:List<FollowUp>.from(o?.followUps??[]),archived:o?.archived??false,trashed:o?.trashed??false,tracking:o?.tracking??task));},child:const Text('ذخیره'))]));}
}

class FollowEditor extends StatefulWidget{final FollowUp? old;const FollowEditor({super.key,this.old});@override State<FollowEditor>createState()=>_FollowEditorState();}
class _FollowEditorState extends State<FollowEditor>{late TextEditingController ctl;late DateTime at;DateTime? rem;@override void initState(){super.initState();final x=widget.old;ctl=TextEditingController(text:x?.text??'');at=x?.at??DateTime.now();rem=x?.reminder;}@override Widget build(BuildContext c)=>AlertDialog(title:Text(widget.old==null?'ثبت پیگیری':'ویرایش پیگیری'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:ctl,maxLines:4,decoration:const InputDecoration(labelText:'شرح پیگیری (اختیاری)')),ListTile(title:Text('تاریخ پیگیری: ${jalali(at)} ${hm(at)}'),onTap:()async{final d=await pickJalaliDateTime(c,at,allowPast:true);if(d!=null)setState(()=>at=d);}),ListTile(title:Text(rem==null?'یادآوری ندارد':'یادآوری: ${jalali(rem!)} ${hm(rem!)}'),trailing:rem==null?null:IconButton(icon:const Icon(Icons.clear),onPressed:()=>setState(()=>rem=null)),onTap:()async{final d=await pickJalaliDateTime(c,rem??DateTime.now().add(const Duration(minutes:5)),allowPast:false);if(d!=null)setState(()=>rem=d);})]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,FollowUp(id:widget.old?.id??makeId(),text:ctl.text.trim(),at:at,reminder:rem)),child:const Text('ذخیره'))]);}
}

class Details extends StatefulWidget{final Item item;final Future<void>Function() onEdit,onFollow;final Future<void>Function(FollowUp)onEditFollow,onDeleteFollow;final VoidCallback onChanged;const Details({super.key,required this.item,required this.onEdit,required this.onFollow,required this.onEditFollow,required this.onDeleteFollow,required this.onChanged});@override State<Details>createState()=>_DetailsState();}
class _DetailsState extends State<Details>{@override Widget build(BuildContext c){final x=widget.item;return WillPopScope(onWillPop:()async{widget.onChanged();return true;},child:Scaffold(appBar:AppBar(title:Text(x.title),actions:[IconButton(icon:const Icon(Icons.edit),onPressed:()async{await widget.onEdit();setState((){});})]),body:ListView(padding:const EdgeInsets.all(16),children:[Text(x.note.isEmpty?'بدون توضیحات':x.note,style:const TextStyle(fontSize:18)),const SizedBox(height:12),Text('تاریخ: ${jalali(x.date)} ${hm(x.date)}'),Text('دسته: ${x.category}'),if(x.tags.isNotEmpty)Wrap(spacing:6,children:x.tags.map((e)=>Chip(label:Text(e))).toList()),if(x.checklist.isNotEmpty)...[const Divider(),const Text('چک‌لیست',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),...List.generate(x.checklist.length,(i)=>CheckboxListTile(value:x.checked[i],onChanged:(v){setState(()=>x.checked[i]=v??false);widget.onChanged();},title:Text(x.checklist[i])))],if(x.task)...[const Divider(),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('سوابق پیگیری',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),FilledButton.icon(onPressed:()async{await widget.onFollow();setState((){});},icon:const Icon(Icons.add),label:const Text('پیگیری جدید'))]),...x.followUps.reversed.map((f)=>Card(child:ListTile(title:Text(f.text.isEmpty?'(بدون شرح)':f.text),subtitle:Text('${jalali(f.at)} ${hm(f.at)}${f.reminder==null?'':'\nیادآوری: ${jalali(f.reminder!)} ${hm(f.reminder!)}'}'),trailing:PopupMenuButton<String>(onSelected:(v)async{if(v=='edit')await widget.onEditFollow(f);else await widget.onDeleteFollow(f);setState((){});},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('ویرایش')),PopupMenuItem(value:'delete',child:Text('حذف'))]))))]]));}}

class ManageDialog extends StatefulWidget{final String title;final List<String> source;const ManageDialog(this.title,this.source,{super.key});@override State<ManageDialog>createState()=>_ManageDialogState();}
class _ManageDialogState extends State<ManageDialog>{late List<String> list;final ctl=TextEditingController();@override void initState(){super.initState();list=[...widget.source];} @override Widget build(BuildContext c)=>AlertDialog(title:Text(widget.title),content:SizedBox(width:330,height:330,child:Column(children:[TextField(controller:ctl,decoration:InputDecoration(labelText:'مورد جدید',suffixIcon:IconButton(icon:const Icon(Icons.add),onPressed:(){final v=ctl.text.trim();if(v.isNotEmpty&&!list.contains(v)){setState(()=>list.add(v));ctl.clear();}}))),Expanded(child:ListView(children:list.map((v)=>ListTile(title:Text(v),trailing:widget.title=='دسته‌بندی‌ها'&&v=='عمومی'?null:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>setState(()=>list.remove(v)))).toList()))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(c,list),child:const Text('ذخیره'))]);}

class SettingsPage extends StatelessWidget{final String font;final bool dark;final Future<void>Function(String) onFont;final Future<void>Function(bool)onDark;final String left,right;final Future<void>Function(String,String)onSwipe;const SettingsPage({super.key,required this.font,required this.dark,required this.onFont,required this.onDark,required this.left,required this.right,required this.onSwipe});Future<String?> choose(BuildContext c)=>showDialog<String>(context:c,builder:(_)=>SimpleDialog(title:const Text('عملیات Swipe'),children:['هیچ‌کاری','امروز','بایگانی','سطل زباله','پیگیری','ویرایش','اشتراک‌گذاری'].map((a)=>SimpleDialogOption(onPressed:()=>Navigator.pop(c,a),child:Text(a))).toList()));@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('تنظیمات')),body:ListView(padding:const EdgeInsets.all(16),children:[SwitchListTile(title:const Text('حالت تاریک'),value:dark,onChanged:onDark),DropdownButtonFormField<String>(initialValue:font,items:const[DropdownMenuItem(value:'Vazirmatn',child:Text('Vazirmatn'))],onChanged:(v){if(v!=null)onFont(v);},decoration:const InputDecoration(labelText:'فونت')),ListTile(title:Text('کشیدن به راست: $right'),onTap:()async{final v=await choose(c);if(v!=null)onSwipe(left,v);}),ListTile(title:Text('کشیدن به چپ: $left'),onTap:()async{final v=await choose(c);if(v!=null)onSwipe(v,right);})]));}
