import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';
import 'model.dart';
import 'vault.dart';
import 'document_reader.dart';
import 'languages.dart';
import 'local_ai.dart';
import 'photo_table.dart';
import 'product_ai.dart';

void main(){WidgetsFlutterBinding.ensureInitialized();runApp(const VaultApp());}
class VaultApp extends StatelessWidget{
  const VaultApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(title:'Warranty Vault',debugShowCheckedModeBanner:false,theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff3158bd)),inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder()),cardTheme:const CardThemeData(elevation:0,margin:EdgeInsets.zero)),home:const Dashboard());
}
Future<bool> saveBytes(String name,Uint8List bytes) async {
  final saved = await FilePicker.saveFile(fileName: name, bytes: bytes);
  return saved != null;
}
String remainingLabel(int days)=>days<0?'Expired ${-days} day${days==-1?'':'s'} ago':days==0?'Expires today':'$days day${days==1?'':'s'} left';
Color statusColor(int d)=>d<0?Colors.grey:d<=7?Colors.red.shade700:d<=30?Colors.orange.shade800:Colors.green.shade700;
String displayDate(String value){final d=parseDate(value);return d==null?value:'${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';}

class Dashboard extends StatefulWidget{const Dashboard({super.key});@override State<Dashboard> createState()=>_DashboardState();}
class _DashboardState extends State<Dashboard> with WidgetsBindingObserver{
  Vault? vault;List<Warranty> records=[];String? error;String filter='Active',query='';bool busy=false;Timer? timer;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();timer=Timer.periodic(const Duration(minutes:1),(_){if(mounted)setState((){});});}
  @override void dispose(){timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed&&mounted)setState((){});}
  Future<void> load() async{try{final v=vault??await Vault.open();final data=await v.load();if(mounted)setState((){vault=v;records=data;error=null;});}catch(e){if(mounted)setState(()=>error='$e');}}
  void message(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  Future<void> guarded(Future<void> Function() fn) async{if(busy)return;setState(()=>busy=true);try{await fn();}catch(e){message('Could not complete: $e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> edit([Warranty? w]) async{if(vault==null)return;final saved=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>Editor(vault:vault!,existing:w)));if(saved==true||w==null)await load();}
  Future<void> details(Warranty w) async{final changed=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>Details(vault:vault!,w:w)));if(changed==true)await load();}
  Future<void> exportBackup()=>guarded(()async{final bytes=await vault!.backup(records);if(await saveBytes('warranty-vault-${iso(DateTime.now())}.wvb',bytes))message('Backup exported. Keep it somewhere safe.');});
  Future<void> importBackup()=>guarded(()async{final f=await FilePicker.pickFile(type:FileType.custom,allowedExtensions:['wvb']);if(f==null)return;final length=await f.length();if(length==null||length>maxBackup)throw StateError('Backup size unknown or exceeds 100 MB');final bytes=await f.readAsBytes();if(bytes.length>maxBackup)throw StateError('Backup exceeds 100 MB');if(!mounted)return;final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Import backup?'),content:const Text('Records will be added as new copies. Existing warranties will not be replaced. Importing twice creates duplicates.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Import'))]));if(yes!=true)return;final n=await vault!.restore(bytes);await load();message('Imported $n warranties.');});
  @override Widget build(BuildContext context){
    final active=records.where((w)=>w.remaining()>=0).length,soon=records.where((w)=>w.remaining()>=0&&w.remaining()<=30).length,expired=records.length-active;
    final visible=records.where((w){final d=w.remaining();final matches=filter=='All'||(filter=='Active'&&d>=0)||(filter=='Soon'&&d>=0&&d<=30)||(filter=='Expired'&&d<0);return matches&&[w.product,w.store,w.model,w.serial,w.reference,w.receipt].join(' ').toLowerCase().contains(query.toLowerCase());}).toList()..sort((a,b)=>a.remaining().compareTo(b.remaining()));
    return Scaffold(appBar:AppBar(title:const Row(children:[Icon(Icons.shield_outlined),SizedBox(width:10),Text('Warranty Vault')]),actions:[PopupMenuButton<String>(enabled:vault!=null&&!busy,onSelected:(s){if(s=='export')exportBackup();if(s=='import')importBackup();if(s=='storage')showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('Local storage'),content:SelectableText(vault!.root.path),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]));},itemBuilder:(_)=>const [PopupMenuItem(value:'export',child:Text('Export backup')),PopupMenuItem(value:'import',child:Text('Import backup')),PopupMenuItem(value:'storage',child:Text('Storage location'))])]),floatingActionButton:vault==null?null:FloatingActionButton.extended(onPressed:busy?null:()=>edit(),icon:const Icon(Icons.add),label:const Text('Add warranty')),body:error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Text('Unable to open your library. No data was erased.\n$error'),TextButton(onPressed:load,child:const Text('Retry'))]))):vault==null?const Center(child:CircularProgressIndicator()):Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),child:Padding(padding:const EdgeInsets.fromLTRB(16,12,16,0),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Your warranties',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:4),const Text('Private by design. Everything stays on this device.'),const SizedBox(height:20),
      Row(children:[Expanded(child:metric('Active',active,Icons.verified_user_outlined,'Active')),const SizedBox(width:8),Expanded(child:metric('Soon',soon,Icons.schedule,'Soon')),const SizedBox(width:8),Expanded(child:metric('Expired',expired,Icons.archive_outlined,'Expired'))]),const SizedBox(height:16),
      TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search products, stores or numbers'),onChanged:(s)=>setState(()=>query=s)),const SizedBox(height:12),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:['All','Active','Soon','Expired'].map((s)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(s=='Soon'?'Expiring soon':s),selected:filter==s,onSelected:(_)=>setState(()=>filter=s)))).toList())),
      if(busy)const LinearProgressIndicator(),const SizedBox(height:12),
      Expanded(child:visible.isEmpty?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.inventory_2_outlined,size:56),const SizedBox(height:12),Text(records.isEmpty?'Your vault is empty':'No matching warranties',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),Text(records.isEmpty?'Add a receipt, warranty PDF or manual record.':'Try another search or filter.',textAlign:TextAlign.center),if(records.isEmpty)TextButton(onPressed:()=>edit(),child:const Text('Add your first warranty'))])):LayoutBuilder(builder:(ctx,c){return GridView.builder(padding:const EdgeInsets.only(bottom:100),gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:c.maxWidth>=720?2:1,mainAxisExtent:180,crossAxisSpacing:12,mainAxisSpacing:12),itemCount:visible.length,itemBuilder:(_,i)=>warrantyCard(visible[i]));}))
    ])))));
  }
  Widget metric(String label,int count,IconData icon,String value)=>InkWell(borderRadius:BorderRadius.circular(16),onTap:()=>setState(()=>filter=value),child:Card(color:Theme.of(context).colorScheme.surfaceContainer,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:22),const SizedBox(height:8),Text('$count',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),Text(label)]))));
  Widget warrantyCard(Warranty w){final d=w.remaining();final start=parseDate(w.start);final total=start==null?0:daysBetween(start,parseDate(w.expiry)!);final progress=total<=0?0.0:(d/total).clamp(0.0,1.0).toDouble();return Card(color:Theme.of(context).colorScheme.surfaceContainerLow,child:InkWell(borderRadius:BorderRadius.circular(12),onTap:()=>details(w),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(w.product,maxLines:1,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold))),IconButton(tooltip:'Edit',onPressed:()=>edit(w),icon:const Icon(Icons.edit_outlined,size:20))]),Text(w.store.isEmpty?'Seller not entered':w.store,maxLines:1,overflow:TextOverflow.ellipsis),const Spacer(),Text(remainingLabel(d),style:TextStyle(fontWeight:FontWeight.bold,color:statusColor(d))),const SizedBox(height:8),if(start!=null)LinearProgressIndicator(value:progress,color:statusColor(d)) else const Text('Start date unknown',style:TextStyle(fontSize:12)),const SizedBox(height:8),Text('Expires ${displayDate(w.expiry)}  ·  ${w.docs.length} document(s)',style:Theme.of(context).textTheme.bodySmall)]))));}
}

class Editor extends StatefulWidget{final Vault vault;final Warranty? existing;const Editor({super.key,required this.vault,this.existing});@override State<Editor> createState()=>_EditorState();}
class _EditorState extends State<Editor>{
  final form=GlobalKey<FormState>();final fields=<String,TextEditingController>{};final pending=<PendingDoc>[];bool busy=false;String? scanNote;String raw='';String ocrLanguage='auto';String ocrPageMode='6';bool useAi=Platform.isWindows||Platform.isMacOS||Platform.isLinux;
  final tableQueue=<Map<String,String>>[]; int tableTotal=0, tableCurrent=0;
  void fillTable(Map<String,String> row){for(final e in fields.entries){e.value.text=row[e.key]??'';}}
  static const labels={'product':'Product name *','store':'Store / seller','customer':'Customer name','model':'Model','serial':'Serial number','reference':'Warranty reference','receipt':'Receipt / invoice / order number','start':'Warranty start date (optional, YYYY-MM-DD)','months':'Duration (months, optional)','expiry':'Expiration date * (YYYY-MM-DD)','notes':'Notes'};
  @override void initState(){super.initState();final old=widget.existing?.toJson()??{};for(final k in labels.keys){fields[k]=TextEditingController(text:old[k]?.toString()??'');}if(fields['months']!.text=='0')fields['months']!.clear();}
  @override void dispose(){for(final c in fields.values){c.dispose();}super.dispose();}
  void message(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  Future<void> addFiles() async{if(busy)return;setState(()=>busy=true);try{final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:['pdf','jpg','jpeg','png']);for(final f in files){final length=await f.length();if(length==null||length>maxFile){message('${f.name}: size unknown or exceeds 25 MB');continue;}await addDoc(f.name,await f.readAsBytes());if(tableTotal>0){if(files.length>1)message('Review the table first. Import other files separately.');break;}}}catch(e){message('Import failed: $e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> camera() async{if(busy)return;setState(()=>busy=true);try{final x=await ImagePicker().pickImage(source:ImageSource.camera,imageQuality:100);if(x==null)return;await addDoc(x.name,await x.readAsBytes());}catch(e){message('Camera unavailable: $e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> addDoc(String name,Uint8List bytes) async{final ext=p.extension(name).replaceFirst('.','').toLowerCase();if(!['pdf','jpg','jpeg','png'].contains(ext)||bytes.length>maxFile||bytes.isEmpty){message('Unsupported or oversized document. Use PDF, JPG or PNG (max 25 MB).');return;}final doc=PendingDoc(Attachment(const Uuid().v4(),p.basename(name),ext),bytes);if(!mounted)return;setState((){pending.add(doc);scanNote='Reading $name…';});try{final text=await readDocument(doc,language:ocrLanguage,pageMode:ocrPageMode);if(!mounted)return;
      final table=extractPhotoTable(text);
      if(table.isNotEmpty && widget.existing==null && pending.length==1 && fields['product']!.text.trim().isEmpty){
        var reviewed = table;
        var enhancement = 'Standard recognition.';
        if (useAi) {
          setState(() => scanNote = 'Checking all ${table.length} product descriptions with local AI…');
          try {
            reviewed = await improveProductRows(table);
            final changed = List.generate(table.length, (i) => i)
                .where((i) => reviewed[i]['product'] != table[i]['product']).length;
            final held = reviewed.where((r) => (r['notes'] ?? '').contains('AI product suggestion (not applied')).length;
            enhancement = 'Local AI checked ${table.length} descriptions; $changed correction(s), $held suggestion(s) need manual review. See Notes for original text and proposed changes.';
          } catch (e) {
            enhancement = 'Local AI could not complete the check ($e). Original OCR descriptions kept.';
          }
        }
        if (!mounted) return;
        setState((){tableQueue.clear();tableQueue.addAll(reviewed.skip(1));tableTotal=reviewed.length;tableCurrent=1;fillTable(reviewed.first);raw+='\n--- $name ---\n${ext=="pdf"?"PDF text":"OCR language: $ocrLanguage; layout mode: $ocrPageMode"}\n$text';scanNote='Found ${reviewed.length} product row(s). $enhancement Review each product and check serial numbers against the original.';});return;
      }
      Map<String,String> data;String method;
      if(useAi){
        setState(()=>scanNote='Understanding $name with local AI…');
        try{data=await readWithLocalAi(text);method='Local AI';}
        catch(_){data=extractFields(text);method='Standard recognition (local AI unavailable or unable to read)';}
      }else{data=extractFields(text);method='Standard recognition';}
      if(!mounted)return;
      for(final e in data.entries){final field=fields[e.key];if(field!=null&&field.text.trim().isEmpty)field.text=e.value;}setState((){raw+='\n--- $name ---\n${ext=="pdf"?"PDF text":"OCR language: $ocrLanguage; layout mode: $ocrPageMode"}\n$text';scanNote=data.isEmpty?(text.trim().isEmpty?'No text was recognized. Retake the photo or select the document language. Your file is still attached.':'Text was recognized (${text.trim().length} characters), but no supported fields were found. Open View extracted text to check the OCR output. Language hint: ${documentLanguage(text)}.'): '$method: detected ${data.keys.where((k)=>k!="notes").length} fields. Verify all values against the original document.';});}catch(e){if(mounted)setState(()=>scanNote='File attached, but automatic reading was unavailable. Enter details manually. ($e)');}}
  void calculate(){final start=parseDate(fields['start']!.text);final m=int.tryParse(fields['months']!.text);if(start==null||m==null||m<1||m>600){message('Enter a valid start date and 1–600 months.');return;}final end=addMonths(start,m);if(end.year>2200){message('Expiration must be in 2200 or earlier.');return;}fields['expiry']!.text=iso(end);setState((){});}
  Future<void> date(String key) async{final d=await showDatePicker(context:context,firstDate:DateTime(1900),lastDate:DateTime(2200,12,31),initialDate:parseDate(fields[key]!.text)??DateTime.now());if(d!=null)fields[key]!.text=iso(d);}
  Future<void> save() async{if(busy||!form.currentState!.validate())return;final start=parseDate(fields['start']!.text),end=parseDate(fields['expiry']!.text)!;if(start!=null&&end.isBefore(start)){message('Expiration cannot be before the start date.');return;}setState(()=>busy=true);try{String s(String k)=>fields[k]!.text.trim();final w=Warranty(id:widget.existing?.id??const Uuid().v4(),product:s('product'),store:s('store'),customer:s('customer'),model:s('model'),serial:s('serial'),reference:s('reference'),receipt:s('receipt'),start:start==null?'':iso(start),expiry:iso(end),months:int.tryParse(s('months'))??0,notes:s('notes'),docs:[...?widget.existing?.docs,...pending.map((d)=>d.doc)]);await widget.vault.save(w,pending);if(!mounted)return;
    if(tableQueue.isNotEmpty){
      final next=tableQueue.removeAt(0);
      final copies=pending.map((d)=>PendingDoc(Attachment(const Uuid().v4(),d.doc.name,d.doc.ext),d.bytes)).toList();
      setState((){pending.clear();pending.addAll(copies);tableCurrent++;fillTable(next);scanNote='Product $tableCurrent of $tableTotal. Previous product saved. Check the original serial number and dates before saving.';});
      message('Product saved. Review the next one.');
    }else{Navigator.pop(context,true);}}catch(e){message('Save failed: $e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> deleteExisting() async {
    final w=widget.existing;
    if(w==null||busy)return;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Delete warranty?'),
      content:Text('Permanently delete ${w.product} and its stored documents? Unsaved changes will be discarded.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));
    if(yes!=true||!mounted)return;
    setState(()=>busy=true);
    try{await widget.vault.remove(w);if(mounted)Navigator.pop(context,true);}
    catch(e){message('Delete failed: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.existing==null?'Add warranty':'Edit warranty'),actions:[if(widget.existing!=null)IconButton(tooltip:'Delete warranty',onPressed:busy?null:deleteExisting,icon:const Icon(Icons.delete_outline))]),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:720),child:Form(key:form,child:ListView(padding:const EdgeInsets.all(20),children:[Text('Original documents',style:Theme.of(context).textTheme.titleLarge),const Text('Attach the receipt and warranty card. Your files are copied into private local storage on save.'),const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:busy||tableTotal>0?null:addFiles,icon:const Icon(Icons.upload_file),label:const Text('Upload files')),if(Platform.isAndroid||Platform.isIOS)OutlinedButton.icon(onPressed:busy||tableTotal>0?null:camera,icon:const Icon(Icons.camera_alt_outlined),label:const Text('Take photo'))]),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:ocrLanguage,isExpanded:true,decoration:const InputDecoration(labelText:'Photo OCR language'),items:[const DropdownMenuItem(value:'auto',child:Text('Auto (English / Bulgarian / German / Dutch)')),const DropdownMenuItem(value:'bul_only',child:Text('Bulgarian only (test)')),for(final lang in documentLanguages.entries)DropdownMenuItem(value:lang.key,child:Text(lang.value))],onChanged:busy?null:(v)=>setState(()=>ocrLanguage=v??'auto')),const SizedBox(height:8),const Text('PDF text uses automatic multilingual labels. Choose a photo language before scanning; for other languages, use the selector.'),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:ocrPageMode,decoration:const InputDecoration(labelText:'Photo OCR layout'),items:const [DropdownMenuItem(value:'6',child:Text('Single block / table (default)')),DropdownMenuItem(value:'3',child:Text('Automatic page layout')),DropdownMenuItem(value:'11',child:Text('Sparse text / separate blocks'))],onChanged:busy?null:(v)=>setState(()=>ocrPageMode=v??'6')),const SizedBox(height:8),const Text('If OCR looks wrong, try another layout and re-import the same photo in a fresh form. The original photo is not changed.'),if(Platform.isWindows||Platform.isMacOS||Platform.isLinux)SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Use local AI'),subtitle:const Text('Qwen3 4B via Ollama. Checks product spelling for single and multi-product documents; preserves recognized dates and identifiers. Turn off for faster standard recognition.'),value:useAi,onChanged:busy?null:(v)=>setState(()=>useAi=v)),for(final d in widget.existing?.docs??<Attachment>[])ListTile(leading:const Icon(Icons.description_outlined),title:Text(d.name),subtitle:const Text('Saved document')),for(final d in pending)ListTile(leading:const Icon(Icons.description_outlined),title:Text(d.doc.name),trailing:IconButton(onPressed:busy||tableTotal>0?null:()=>setState(()=>pending.remove(d)),icon:const Icon(Icons.close))),if(busy)const LinearProgressIndicator(),if(scanNote!=null)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(scanNote!)),if(raw.trim().isNotEmpty)OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>OcrResults(text:raw))),icon:const Icon(Icons.text_snippet_outlined),label:const Text('View / copy extracted text')),if(tableTotal>0)Card(child:Padding(padding:const EdgeInsets.all(12),child:Text('Product $tableCurrent of $tableTotal. Verify this item, then save. ${tableQueue.isNotEmpty?'The next item will open automatically.':'This is the final item.'} Each saved product gets its own copy of the original.'))),const SizedBox(height:16),Text('Warranty details',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),const Text('Verify the dates and identifiers. The app does not validate coverage with the seller.'),const SizedBox(height:16),for(final e in labels.entries)...[TextFormField(controller:fields[e.key],enabled:!busy,decoration:InputDecoration(labelText:e.value,suffixIcon:(e.key=='start'||e.key=='expiry')?IconButton(onPressed:()=>date(e.key),icon:const Icon(Icons.calendar_today_outlined)):null),keyboardType:e.key=='months'?TextInputType.number:TextInputType.text,maxLines:e.key=='notes'?3:1,validator:(s){final v=s?.trim()??'';if(e.key=='product'&&v.isEmpty)return 'Required';if((e.key=='expiry'||(e.key=='start'&&v.isNotEmpty))&&parseDate(v)==null)return 'Enter a valid date, e.g. 2026-11-12';if(e.key=='months'&&v.isNotEmpty){final n=int.tryParse(v);if(n==null||n<1||n>600)return 'Enter 1–600 months';}return null;}),const SizedBox(height:12),if(e.key=='months')... [Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:busy?null:calculate,icon:const Icon(Icons.calculate_outlined),label:const Text('Calculate expiration from start + duration'))),const SizedBox(height:8)]],FilledButton.icon(onPressed:busy?null:save,icon:const Icon(Icons.save_outlined),label:Text(tableQueue.isNotEmpty?'Save and review next product':'Save warranty')),if(widget.existing!=null)...[const SizedBox(height:12),OutlinedButton.icon(onPressed:busy?null:deleteExisting,style:OutlinedButton.styleFrom(foregroundColor:Theme.of(context).colorScheme.error),icon:const Icon(Icons.delete_outline),label:const Text('Delete warranty'))],const SizedBox(height:20)])))));
}

class Details extends StatefulWidget{final Vault vault;final Warranty w;const Details({super.key,required this.vault,required this.w});@override State<Details> createState()=>_DetailsState();}
class _DetailsState extends State<Details>{bool busy=false;int lead=30;
  void message(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  Future<void> guarded(Future<void> Function() fn)async{if(busy)return;setState(()=>busy=true);try{await fn();}catch(e){message('Could not complete: $e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> delete()async{final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Delete warranty?'),content:const Text('This permanently deletes the record and its local documents. Export a backup first if you may need them.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));if(yes==true)await guarded(()async{await widget.vault.remove(widget.w);if(mounted)Navigator.pop(context,true);});}
  @override Widget build(BuildContext context){final w=widget.w;final fields={'Seller':w.store,'Customer':w.customer,'Model':w.model,'Serial number':w.serial,'Warranty reference':w.reference,'Receipt / invoice':w.receipt,'Start':w.start,'Expiration':w.expiry,'Notes':w.notes};return Scaffold(appBar:AppBar(title:const Text('Warranty details'),actions:[IconButton(tooltip:'Edit warranty',onPressed:busy?null:()async{final changed=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>Editor(vault:widget.vault,existing:w)));if(changed==true&&context.mounted)Navigator.pop(context,true);},icon:const Icon(Icons.edit_outlined)),IconButton(tooltip:'Delete warranty',onPressed:busy?null:delete,icon:const Icon(Icons.delete_outline))]),body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760),child:ListView(padding:const EdgeInsets.all(20),children:[Text(w.product,style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:12),Text(remainingLabel(w.remaining()),style:TextStyle(color:statusColor(w.remaining()),fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:16),if(busy)const LinearProgressIndicator(),for(final e in fields.entries)if(e.value.isNotEmpty)ListTile(contentPadding:EdgeInsets.zero,title:Text(e.key),subtitle:SelectableText(e.value),trailing:IconButton(tooltip:'Copy ${e.key}',onPressed:()=>Clipboard.setData(ClipboardData(text:e.value)),icon:const Icon(Icons.copy,size:18))),const Divider(),Text('Original documents',style:Theme.of(context).textTheme.titleLarge),if(w.docs.isEmpty)const Text('No documents attached.'),for(final a in w.docs)ListTile(contentPadding:EdgeInsets.zero,leading:Icon(a.ext=='pdf'?Icons.picture_as_pdf_outlined:Icons.image_outlined),title:Text(a.name),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>DocumentView(file:widget.vault.file(a),attachment:a))),trailing:IconButton(tooltip:'Export original',onPressed:busy?null:()=>guarded(()async{if(await saveBytes(a.name,await widget.vault.file(a).readAsBytes()))message('Document exported');}),icon:const Icon(Icons.download_outlined))),const Divider(),Text('Calendar reminder',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),const Text('Export an all-day calendar event for the selected reminder date. Open the .ics file in your calendar and save the event. Enable calendar alerts if desired.'),const SizedBox(height:12),DropdownButtonFormField<int>(initialValue:lead,decoration:const InputDecoration(labelText:'Reminder date'),items:[30,7,1,0].map((d)=>DropdownMenuItem(value:d,child:Text(d==0?'Expiration day':'$d day(s) before expiration'))).toList(),onChanged:(d)=>setState(()=>lead=d??30)),const SizedBox(height:12),OutlinedButton.icon(onPressed:busy?null:()=>guarded(()async{if(await saveBytes('warranty-reminder.ics',Uint8List.fromList(utf8.encode(calendarFile(w,lead)))))message('Calendar file exported. Import it into your calendar.');}),icon:const Icon(Icons.event_outlined),label:const Text('Export calendar event')),const SizedBox(height:16),OutlinedButton.icon(onPressed:()=>Clipboard.setData(ClipboardData(text:'${w.product}\n${fields.entries.map((e)=>'${e.key}: ${e.value}').join('\n')}')),icon:const Icon(Icons.copy),label:const Text('Copy warranty details'))]))));}
}
class DocumentView extends StatelessWidget{final File file;final Attachment attachment;const DocumentView({super.key,required this.file,required this.attachment});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(attachment.name)),body:!file.existsSync()?const Center(child:Text('Document is missing. Restore a backup if available.')):attachment.ext=='pdf'?PdfViewer.file(file.path):InteractiveViewer(maxScale:6,child:Center(child:Image.file(file,errorBuilder:(_,__,___)=>const Text('Unable to display this image.')))));}


class OcrResults extends StatelessWidget {
  final String text;
  const OcrResults({super.key, required this.text});
  Future<void> copy(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied extracted text. Paste it into a note or chat.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clipboard failed: $e. Try Export text instead.')));
    }
  }
  Future<void> export(BuildContext context) async {
    try {
      final saved = await saveBytes('warranty-ocr.txt', Uint8List.fromList(utf8.encode(text)));
      if (saved && context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR text exported.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')));
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Extracted text'), actions: [
      IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
    ]),
    body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: () => copy(context), icon: const Icon(Icons.copy), label: const Text('Copy text')),
        OutlinedButton.icon(onPressed: () => export(context), icon: const Icon(Icons.download_outlined), label: const Text('Export text')),
      ])),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Raw OCR output. Check for recognizable words. This text may contain private purchase information.')),
      const Divider(),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(text))),
    ])),
  );
}
