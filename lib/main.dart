// @dart=2.9

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

String auth_token = "";
List<bool> semester = [false,false,false,false,false,false,false,false,false];


class MyHttpOverrides extends HttpOverrides{
  @override
  HttpClient createHttpClient(SecurityContext context){
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port)=> true;
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void scheduleAlarm(
    DateTime scheduledNotificationDateTime, String title) async {
  var androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'alarm_notif',
    'alarm_notif',
    'Channel for Alarm notification',
    icon: 'epitech_logo',
    sound: RawResourceAndroidNotificationSound('a_long_cold_sting'),
    largeIcon: DrawableResourceAndroidBitmap('epitech_logo'),
  );

  var iOSPlatformChannelSpecifics = IOSNotificationDetails(
      sound: 'a_long_cold_sting.wav',
      presentAlert: true,
      presentBadge: true,
      presentSound: true);
  var platformChannelSpecifics = NotificationDetails();

  Future<void> scheduleNotification(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
      String id,
      String body,
      DateTime scheduledNotificationDateTime) async {
    var platformChannelSpecifics = NotificationDetails();
    await flutterLocalNotificationsPlugin.schedule(0, 'Reminder', body,
        scheduledNotificationDateTime, platformChannelSpecifics);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (await Permission.notification.isGranted)
    debugPrint("Permission already granted!");
  else
    Permission.notification.request();

  var initializationSettingsAndroid =
  AndroidInitializationSettings('epitech_logo');
  var initializationSettingsIOS = IOSInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification:
          (int id, String title, String body, String payload) async {});
  var initializationSettings = InitializationSettings();


  HttpOverrides.global = new MyHttpOverrides(); // Todo: remove this when epitech has renewed its certificate!

  DateTime time = DateTime.now();
  time.add(Duration(seconds: 4));
  scheduleAlarm(time, "Hello World!");

  runApp(MaterialApp(
    theme: ThemeData(
      canvasColor: Colors.white,
      scaffoldBackgroundColor: Colors.blueGrey,


    ),
    home: ActivityList(), // Home()
  ));
}

class HttpService {
  static DateTime now = DateTime.now();
  static DateTime end = now.add(Duration(days: 14));
  static DateFormat formatter = DateFormat('yyyy-MM-dd');
  static final String formatted_now = formatter.format(now);
  static final String formatted_end = formatter.format(end);

  Future<List<Activity>>getActivities(Function decider) async {
    String url = "https://intra.epitech.eu/auth-" + auth_token + "/planning/load?format=json&start=$formatted_now&end=$formatted_end";
    print(url);
    Response res = await get(url);

    if (res.statusCode == 200) {
      print(json);
      List<dynamic> body = jsonDecode(res.body);
      List<Activity> activities = body.map((dynamic item) => Activity.fromJson(item)).toList();
      activities.sort((a, b) => a.time_start.compareTo(b.time_start));
      activities.removeWhere(decider);
      return activities;
    } else {
      List<Activity> errorList;
      return errorList;
    }
  }
}

class Activity {
  String id;
  String type;
  String name;
  String title_module;
  DateTime time_start;
  DateTime time_end;
  int semester = 0;
  bool registered;
  bool allow_register;
  bool module_registered = true;
  String event_url;
  Map<String, dynamic> json_debug;

  Activity({@required this.id, @required this.type, @required this.name, @required this.title_module, @required this.allow_register, @required this.module_registered, @required this.semester});

  factory Activity.fromJson(Map<String, dynamic> json) {
    Activity res = Activity(
      id: json['codeacti'] as String,
      type: json['type_title'] as String,
      name: json['acti_title'] as String,
      title_module: json['titlemodule'] as String,
      allow_register: json['allow_register'] as bool,
      module_registered: json['module_registered'] as bool,
      semester: json['semester'] as int,
    );
    res.json_debug = json;
    res.time_start = DateTime.tryParse(json['start'] as String);
    res.time_end = DateTime.tryParse(json['end'] as String);
    res.registered = json['event_registered'] == "registered";
    res.event_url = "https://intra.epitech.eu/" + "auth-" + auth_token + "/" + "module/" + json['scolaryear'] + "/" + json['codemodule'] + "/" + json['codeinstance'] + "/" + json['codeacti'] + "/" + json['codeevent'] + "/";
    return res;
  }
}

class ActivityList extends StatefulWidget {
  @override
  _ActivityListState createState() => _ActivityListState();
}

class RegistrationInterface extends StatefulWidget {
  Activity activity;

  RegistrationInterface({@required this.activity});

  @override
  _RegistrationInterfaceState createState() => _RegistrationInterfaceState();
}

class _RegistrationInterfaceState extends State<RegistrationInterface> {
  int state = 0;

  Widget build(BuildContext context) {
    if (widget.activity.type == "Review" || widget.activity.type == "Follow-up") {
      return FlatButton(
        child: Icon(Icons.arrow_right_alt_sharp, color: Colors.grey, size: 30),
        onPressed: () {
          _launchURL() async {
            String url = widget.activity.event_url.substring(0, widget.activity.event_url.length - 13);
            print(url);
            if (await canLaunch(url)) {
              await launch(url);
            } else {
              throw 'Could not launch $url';
            }
          }
          _launchURL();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      );
    } else if (!widget.activity.allow_register || !widget.activity.module_registered) {
      return FlatButton(
        child: Icon(Icons.add_circle_outline, color: Colors.grey, size: 30),
        onPressed: () {},
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      );
    } else if (!widget.activity.registered) {
      return FlatButton(
        child: Icon(Icons.add_circle_outline, color: Colors.green, size: 30),
        onPressed: () {
          Future<List<Activity>>reg(Activity activity) async {
            String url = activity.event_url + "register?format=json";
            Response res = await post(url);
            if (res.statusCode == 200)
              widget.activity.registered = !widget.activity.registered;
            else
              widget.activity.allow_register = false;
            setState(() {});
          }
          reg(widget.activity);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      );
    } else {
      return FlatButton(
        child: Icon(Icons.remove_circle_outline, color: Colors.red, size: 30),
        onPressed: () {
          Future<List<Activity>>unreg(Activity activity) async {
            String url = activity.event_url + "unregister?format=json";
            Response res = await post(url);
            if (res.statusCode == 200)
              widget.activity.registered = !widget.activity.registered;
            setState(() {state *= -1;});
          }
          unreg(widget.activity);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      );
    }
  }
}

class _ActivityListState extends State<ActivityList> {
  String username = "unknown";
  String usermail = "unknown@unknown.eu";
  Response userdata;
  String img_url = "";
  var _controller = TextEditingController(text: auth_token);

  @override
  void initState() {
    super.initState();
    loadPrefs();
  }

  loadPrefs() async {
    SharedPreferences.getInstance().then((prefs) {
      auth_token = prefs.getString("auth_token") ?? "";
      username = prefs.getString("username") ?? "unknown";
      usermail = prefs.getString("usermail") ?? "unknown@unknown.eu";
      img_url = "https://intra.epitech.eu/auth-" + auth_token + "/file/userprofil/commentview/" + usermail.substring(0, usermail.length - 11) + ".jpg";
      print(img_url);
      semester[0] = prefs.getBool("sem0") ?? false;
      semester[1] = prefs.getBool("sem1") ?? false;
      semester[2] = prefs.getBool("sem2") ?? false;
      semester[3] = prefs.getBool("sem3") ?? false;
      semester[4] = prefs.getBool("sem4") ?? false;
      semester[5] = prefs.getBool("sem5") ?? false;
      semester[6] = prefs.getBool("sem6") ?? false;
      _controller = TextEditingController(text: auth_token);
      print("semester: $semester");
      print("auth_token: $auth_token");
      setState(() {});
    });
  }

  safePrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print("saving...");
    prefs.setString("auth_token", auth_token);
    prefs.setBool("sem0", semester[0]);
    prefs.setBool("sem1", semester[1]);
    prefs.setBool("sem2", semester[2]);
    prefs.setBool("sem3", semester[3]);
    prefs.setBool("sem4", semester[4]);
    prefs.setBool("sem5", semester[5]);
    prefs.setBool("sem6", semester[6]);

    setState(() {});
    userdata = await get("https://intra.epitech.eu/auth-" + auth_token + "/user/?format=json");
    print("https://intra.epitech.eu/auth-" + auth_token + "/user/?format=json");
    if (userdata.statusCode == 200) {
      Map body = jsonDecode(userdata.body);
      username = body['title'];
      usermail = body['login']; // TODO: fix this
    } else {
      username = 'unknown';
      usermail = 'unknown@unknown.eu';
    }
    prefs.setString("username", username);
    prefs.setString("usermail", usermail);
    img_url = "https://intra.epitech.eu/auth-" + auth_token + "/file/userprofil/commentview/" + usermail.substring(0, usermail.length - 11) + ".jpg";
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    StatefulBuilder settingsBuilder = StatefulBuilder(builder: (context, setState) { return Dialog(
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(trailing: Icon(Icons.settings, size: 30,), title: Text("Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),)),
            ListTile(
                trailing: IconButton(icon: Icon(Icons.help_outline, size: 25), onPressed: () {
                  _launchURL() async {
                    const url = 'https://intra.epitech.eu/admin/autolog';
                    if (await canLaunch(url)) {
                      await launch(url);
                    } else {
                      throw 'Could not launch $url';
                    }
                  }
                  _launchURL();
                },),
                title: TextFormField(
                  controller: _controller,
                  autocorrect: false,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    labelText: 'Autologin Token',
                    suffixIcon: IconButton(icon: Icon(Icons.delete_forever_outlined), onPressed: () {setState(() {
                      auth_token = "";
                      username = "unknown";
                      usermail = "unknown@unknown.eu";
                      FocusScope.of(context).requestFocus(new FocusNode());
                      _controller.clear();
                      safePrefs();
                    });},),
                  ),
                  onChanged: (val) {
                    print("change detected");
                    RegExp alphanumeric = RegExp(r'[a-zA-Z0-9]{40}');
                    if (alphanumeric.hasMatch(val)) {
                      val = alphanumeric.firstMatch(val).group(0);
                      auth_token = val;
                      print("new auth_token: $auth_token");
                      safePrefs();
                    }
                  },
                )),
            SwitchListTile(secondary: Icon(Icons.notification_important_outlined), value: semester[0], onChanged: (bool val) {setState(() {semester[0] = val; safePrefs();});}, title: Text("Semester - 0"),),
            SwitchListTile(secondary: Icon(Icons.notification_important_outlined), value: semester[1], onChanged: (bool val) {setState(() {semester[1] = val; safePrefs();});}, title: Text("Semester - 1"),),
            SwitchListTile(secondary: Icon(Icons.notification_important_outlined), value: semester[2], onChanged: (bool val) {setState(() {semester[2] = val; safePrefs();});}, title: Text("Semester - 2"),),
            SwitchListTile(secondary: Icon(Icons.notification_important_outlined), value: semester[3], onChanged: (bool val) {setState(() {semester[3] = val; safePrefs();});}, title: Text("Semester - 3"),),
            SwitchListTile(secondary: Icon(Icons.notification_important_outlined), value: semester[4], onChanged: (bool val) {setState(() {semester[4] = val; safePrefs();});}, title: Text("Semester - 4"),),
            SwitchListTile(secondary: Icon(Icons.notification_important_outlined), value: semester[5], onChanged: (bool val) {setState(() {semester[5] = val; safePrefs();});}, title: Text("Semester - 5"),),
            SwitchListTile(secondary: Icon(Icons.notification_important_outlined), value: semester[6], onChanged: (bool val) {setState(() {semester[6] = val; safePrefs();});}, title: Text("Semester - 6"),),
            Align(
              alignment: FractionalOffset.bottomRight,
              child: TextButton(onPressed: () {Navigator.pop(context);}, child: Text("done", style: TextStyle(fontSize: 17),)),
            )
          ],
        ))); });
    DateTime old = DateTime(0);
    Widget account_drawer = (auth_token != "") ? (UserAccountsDrawerHeader(
      accountName: Text(username),
      accountEmail: Text(usermail),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.blueGrey[800],
        backgroundImage: NetworkImage(img_url),
      ),
      decoration: BoxDecoration(
        color: Colors.blueGrey,
      ),))
    : (UserAccountsDrawerHeader(
      accountName: Text(""),
      accountEmail: Text(""),
      decoration: BoxDecoration(
        color: Colors.blueGrey,
      ),));
    FutureBuilder eventListBuilder_all = FutureBuilder(
      future: HttpService().getActivities((element) => !semester[element.semester]),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (auth_token == "")
          return Center(
              child: Column(children: [
                Icon(Icons.search_off_outlined, size: 40, color: Colors.grey),
                Text("please login", style: TextStyle(color: Colors.grey),),
                TextButton(onPressed: () {
                  showDialog(context: context, builder: (_) { return settingsBuilder;});
                }, child: Text("settings"))
              ]));
        if (snapshot.hasData) {
          List<Activity> activities = snapshot.data;
          if (activities.isEmpty || auth_token == "") {
            return Center(
                child: Column(children: [
                  Icon(Icons.search_off_outlined, size: 40, color: Colors.grey),
                  Text("no results", style: TextStyle(color: Colors.grey),),
                  TextButton(onPressed: () {
                    showDialog(context: context, builder: (_) { return settingsBuilder;});
                  }, child: Text("settings"))
                ]));
          }
          return Expanded(child: ListView(
            padding: EdgeInsets.only(top: 7),
            children: activities.map((val) {
              Widget date = Container();
              if (val.time_start.day != old.day) {
                old = val.time_start;
                date = Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(margin: const EdgeInsets.only(left: 10.0, right: 15.0), child: Divider(color: Colors.white, thickness: 0.5,)),
                      ),
                      Text(DateFormat('E. dd.MM.yyyy').format(val.time_start), style: TextStyle(fontSize: 20, color: Colors.white)),
                      Expanded(
                        child: Container(margin: const EdgeInsets.only(left: 15.0, right: 10.0), child: Divider(color: Colors.white, thickness: 0.5,)),
                      ),
                    ]
                );
              }
              return Column(children: [
                date,
                Container(
                  child: Row(
                      children: <Widget> [
                        Expanded(child: Column(
                            children: <Widget>[
                              Row(children: [
                                Align(alignment: Alignment.centerLeft, child: Text(val.type,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 19.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ))),
                                Expanded(child: Align(alignment: Alignment.centerRight, child: Text(DateFormat('hh:mm').format(val.time_start),
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 19.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    )))),

                              ]),
                              Align(alignment: Alignment.centerLeft, child: Text(val.title_module,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 17.0,
                                    color: Colors.black87,
                                    fontStyle: FontStyle.italic,
                                  ))),
                              Divider(),
                              Align(alignment: Alignment.centerLeft, child: Text(val.name,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 17.0,
                                    color: Colors.black87,
                                    fontStyle: FontStyle.italic,
                                  ))),
                            ]
                        )),
                        RegistrationInterface(activity: val),
                      ]
                  ),
                  padding: EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          spreadRadius: 0.01,
                          color: Colors.black,
                          offset: Offset(6, 6),
                        ),
                      ],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.0),
                        topRight: Radius.circular(20.0),
                        bottomLeft: Radius.circular(20.0),
                        bottomRight: Radius.circular(20.0),
                      )
                  ),
                  margin: EdgeInsets.all(10.0),
                  alignment: Alignment.center,
                )]);
            }).toList(),
          ));
        }
        return Center(child: RefreshProgressIndicator());
      },
    );
    FutureBuilder eventListBuilder_possible_reg = FutureBuilder(
      future: HttpService().getActivities((element) => !semester[element.semester] || !element.allow_register || element.registered || !element.module_registered),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (auth_token == "")
          return Center(
              child: Column(children: [
                Icon(Icons.search_off_outlined, size: 40, color: Colors.grey),
                Text("please login", style: TextStyle(color: Colors.grey),),
                TextButton(onPressed: () {
                  showDialog(context: context, builder: (_) { return settingsBuilder;});
                }, child: Text("settings"))
              ]));
        if (snapshot.hasData) {
          List<Activity> activities = snapshot.data;
          if (activities.isEmpty || auth_token == "") {
            return Center(
                child: Column(children: [
                  Icon(Icons.search_off_outlined, size: 40, color: Colors.grey),
                  Text("no results", style: TextStyle(color: Colors.grey),),
                  TextButton(onPressed: () {
                    showDialog(context: context, builder: (_) { return settingsBuilder;});
                  }, child: Text("settings"))
                ]));
          }
          return Expanded(child: ListView(
            padding: EdgeInsets.only(top: 7),
            children: activities.map((val) {
              Widget date = Container();
              if (val.time_start.day != old.day) {
                old = val.time_start;
                date = Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(margin: const EdgeInsets.only(left: 10.0, right: 15.0), child: Divider(color: Colors.white, thickness: 0.5,)),
                      ),
                      Text(DateFormat('E. dd.MM.yyyy').format(val.time_start), style: TextStyle(fontSize: 20, color: Colors.white)),
                      Expanded(
                        child: Container(margin: const EdgeInsets.only(left: 15.0, right: 10.0), child: Divider(color: Colors.white, thickness: 0.5,)),
                      ),
                    ]
                );
              }
              return Column(children: [
                date,
                Container(
                  child: Row(
                      children: <Widget> [
                        Expanded(child: Column(
                            children: <Widget>[
                              Row(children: [
                                Align(alignment: Alignment.centerLeft, child: Text(val.type,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 19.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ))),
                                Expanded(child: Align(alignment: Alignment.centerRight, child: Text(DateFormat('hh:mm').format(val.time_start),
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 19.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    )))),

                              ]),
                              Align(alignment: Alignment.centerLeft, child: Text(val.title_module,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 17.0,
                                    color: Colors.black87,
                                    fontStyle: FontStyle.italic,
                                  ))),
                              Divider(),
                              Align(alignment: Alignment.centerLeft, child: Text(val.name,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 17.0,
                                    color: Colors.black87,
                                    fontStyle: FontStyle.italic,
                                  ))),
                            ]
                        )),
                        RegistrationInterface(activity: val),
                      ]
                  ),
                  padding: EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.0),
                        topRight: Radius.circular(20.0),
                        bottomLeft: Radius.circular(20.0),
                        bottomRight: Radius.circular(20.0),
                      )
                  ),
                  margin: EdgeInsets.all(10.0),
                  alignment: Alignment.center,
                )]);
            }).toList(),
          ));
        }
        return Center(child: RefreshProgressIndicator());
      },
    );
    FutureBuilder eventListBuilder_all_reg = FutureBuilder(
      future: HttpService().getActivities((element) => !semester[element.semester] || !element.registered),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (auth_token == "")
          return Center(
              child: Column(children: [
                Icon(Icons.search_off_outlined, size: 40, color: Colors.grey),
                Text("please login", style: TextStyle(color: Colors.grey),),
                TextButton(onPressed: () {
                  showDialog(context: context, builder: (_) { return settingsBuilder;});
                }, child: Text("settings"))
              ]));
        if (snapshot.hasData) {
          List<Activity> activities = snapshot.data;
          if (activities.isEmpty || auth_token == "") {
            return Center(
                child: Column(children: [
                  Icon(Icons.search_off_outlined, size: 40, color: Colors.grey),
                  Text("no results", style: TextStyle(color: Colors.grey),),
                  TextButton(onPressed: () {
                    showDialog(context: context, builder: (_) { return settingsBuilder;});
                  }, child: Text("settings"))
                ]));
          }
          return Expanded(child: ListView(
            padding: EdgeInsets.only(top: 7),
            children: activities.map((val) {
              Widget date = Container();
              if (val.time_start.day != old.day) {
                old = val.time_start;
                date = Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(margin: const EdgeInsets.only(left: 10.0, right: 15.0), child: Divider(color: Colors.white, thickness: 0.5,)),
                      ),
                      Text(DateFormat('E. dd.MM.yyyy').format(val.time_start), style: TextStyle(fontSize: 20, color: Colors.white)),
                      Expanded(
                        child: Container(margin: const EdgeInsets.only(left: 15.0, right: 10.0), child: Divider(color: Colors.white, thickness: 0.5,)),
                      ),
                    ]
                );
              }
              return Column(children: [
                date,
                Container(
                  child: Row(
                      children: <Widget> [
                        Expanded(child: Column(
                            children: <Widget>[
                              Row(children: [
                                Align(alignment: Alignment.centerLeft, child: Text(val.type,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 19.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ))),
                                Expanded(child: Align(alignment: Alignment.centerRight, child: Text(DateFormat('HH:mm').format(val.time_start) + ' - ' + DateFormat('HH:mm').format(val.time_end),
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 19.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    )))),

                              ]),
                              Align(alignment: Alignment.centerLeft, child: Text(val.title_module,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 17.0,
                                    color: Colors.black87,
                                    fontStyle: FontStyle.italic,
                                  ))),
                              Divider(),
                              Align(alignment: Alignment.centerLeft, child: Text(val.name,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 17.0,
                                    color: Colors.black87,
                                    fontStyle: FontStyle.italic,
                                  ))),
                            ]
                        )),
                        RegistrationInterface(activity: val),
                      ]
                  ),
                  padding: EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.0),
                        topRight: Radius.circular(20.0),
                        bottomLeft: Radius.circular(20.0),
                        bottomRight: Radius.circular(20.0),
                      )
                  ),
                  margin: EdgeInsets.all(10.0),
                  alignment: Alignment.center,
                )]);
            }).toList(),
          ));
        }
        return Center(child: RefreshProgressIndicator());
      },
    );

    final pageController = PageController(
      initialPage: 1,
    );
    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            Padding(padding: EdgeInsets.only(top: 30)),
            account_drawer,
            ListTile(leading: Icon(Icons.bug_report, size: 25,), title: Text("report a bug", style: TextStyle(fontSize: 20),),onTap: () {
              _launchURL() async {
                const url = 'mailto:hanau.emile@gmail.com';
                if (await canLaunch(url)) {
                  await launch(url);
                } else {
                  throw 'Could not launch $url';
                }
              }
              _launchURL();
            },),
            ListTile(leading: Icon(Icons.developer_mode, size: 25,), title: Text("contribute", style: TextStyle(fontSize: 20),),onTap: () {
              _launchURL() async {
                const url = 'https://github.com/EmileHanau';
                if (await canLaunch(url)) {
                  await launch(url);
                } else {
                  throw 'Could not launch $url';
                }
              }
              _launchURL();
            },),
            Divider(),
            ListTile(leading: Icon(Icons.help_outline, size: 25,), title: Text("About", style: TextStyle(fontSize: 20),),onTap: () { showAboutDialog(context: context, applicationVersion: 'Version 0.0.2', applicationLegalese: 'created by Emile Hanau');},),
            Expanded(child: Align(
              alignment: FractionalOffset.bottomCenter,
              child: ListTile(leading: Icon(Icons.settings, size: 25,), title: Text("Settings", style: TextStyle(fontSize: 20),),onTap: () {
                showDialog(context: context, builder: (_) { return settingsBuilder;});
              },),
            )),
            /*FloatingActionButton(onPressed: () {
              auth_token = "0395fe8ae2a5b8c16b88f4febcdb2cb9a7a19e36";
              safePrefs();
            }),*/
          ],
        ),
      ),
      endDrawerEnableOpenDragGesture: false,
      backgroundColor: Colors.blueGrey,
      appBar: AppBar(
        title: Text('{Epitech student helper}'),
        backgroundColor: Colors.blueGrey,
      ),
      body: PageView(
          controller: pageController,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[eventListBuilder_possible_reg,]),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[eventListBuilder_all,]),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[eventListBuilder_all_reg,]),
          ],
        ),
    );
  }
}