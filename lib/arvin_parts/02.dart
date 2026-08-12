import 'package:timezone/timezone.dart' as tz;

final npl = FlutterLocalNotificationsPlugin();
String jd(DateTime d){final j=Gregorian.fromDateTime(d).toJalali();return '${j.year}/${j.month.toString().padLeft(2,'0')}/${j.day.toString().padLeft(2,'0')}';}
String tm(DateTime d)=>'${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
String id()=>DateTime.now().microsecondsSinceEpoch.toString();
Future<DateTime?> pickDT(BuildContext c,DateTime d,{bool past=true})async{final p=await showJalaliDatePicker(c,initialDate:Gregorian.fromDateTime(d).toJalali(),firstDate:Gregorian.fromDateTime(past?DateTime(2000):DateTime.now()).toJalali(),lastDate:Jalali(1450,12,29),textDirection:TextDirection.rtl);if(p==null)return null;final g=p.toGregorian();final t=await showTimePicker(context:c,initialTime:TimeOfDay.fromDateTime(d));if(t==null)return null;return DateTime(g.year,g.month,g.day,t.hour,t.minute);}
