import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:system_tray/system_tray.dart';
import 'dart:io';
import 'package:process_run/process_run.dart';
import 'package:window_manager/window_manager.dart';

List<String> splitPath() {
  return Platform.environment['PATH']?.split(';').toList() ?? [];
}

class FlutterSDK {
  final String version;
  final String channel;
  late String path;

  FlutterSDK({required this.version, required this.channel});
}

Future<FlutterSDK> flutterVersion(String flutterPath) async {
  var shell = Shell(
      stdoutEncoding: Encoding.getByName('UTF-8') ?? systemEncoding,
      verbose: false);
  var result = await shell.run('$flutterPath --version');
  var temp = result.outLines.first.trim().split(' • ');
  return FlutterSDK(
    version: temp[0],
    channel: temp[1],
  );
}

List<String> searchApplication(String app) {
  if (Platform.isWindows) app += '.bat';
  var tempList = <String>[];
  for (var item in splitPath()) {
    var dir = Directory(item);
    var bin = join(dir.path, app);
    var file = File(bin);
    // print('${file.path},${file.existsSync()}');
    if (file.existsSync()) {
      tempList.add(file.path);
    }
  }
  return tempList;
}

class OpenFolderPage extends StatefulWidget {
  const OpenFolderPage({Key? key}) : super(key: key);

  @override
  State<OpenFolderPage> createState() => _OpenFolderPageState();
}

class _OpenFolderPageState extends State<OpenFolderPage> {
  int _currentIndex = 0;
  List<FlutterSDK> sdks = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // print(splitPath());
    var flutterPath = searchApplication('flutter');
    // flutterPath.forEach((element) {
    //
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 44,
          child: WindowCaption(),
        ),
        Expanded(
          child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  // Row(
                  //   children: [
                  //     const Spacer(),
                  //
                  //   ],
                  // ),
                  TextButton(
                    onPressed: () async {
                      String? selectedDirectory =
                          await FilePicker.platform.getDirectoryPath();

                      if (selectedDirectory != null) {
                        var binPath = join(selectedDirectory, 'bin',
                            'flutter${Platform.isWindows ? '.bat' : ''}');
                        if (!File(binPath).existsSync()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('The folder isn\'t a Flutter sdk root.'),
                            ),
                          );
                        } else {
                          flutterVersion(binPath).then((value) {
                            sdks.add(value..path = binPath);
                            setState(() {});
                          });
                        }
                      }
                    },
                    child: Text('Add New SDK'),
                  ),
                  DropdownButton(
                    items: sdks
                        .map(
                          (e) => DropdownMenuItem(
                            child: Text(e.version),
                            value: sdks.indexOf(e),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      _currentIndex = value ?? 0;
                      setState(() {});
                    },
                    value: _currentIndex,
                  ),
                  TextButton(
                    onPressed: () {
                      var path = searchApplication('flutter');

                      if (path.length == 1) {
                        var temp=path.first.substring(
                            0, path.first.indexOf("flutter.bat") - 1);
                        var originPath=(splitPath()
                          ..removeWhere((element) => element==temp)).reduce((value, element) => value+=';$element');
                        originPath+=';${sdks[_currentIndex].path}';
                        Shell().run('setx \"PATH\" \"$originPath\" /m');
                      } else {
                        print('add path');
                      }
                    },
                    child: Text('Set'),
                  ),
                  const Spacer(),
                  if (sdks.isNotEmpty)
                    Text('Current Version:${sdks.first.version.split(' ')[1]}'),
                ],
              )),
        ),
      ],
    );
  }
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: OpenFolderPage(),
      ),
    );
  }
}

Future<void> initSystemTray() async {
  String path =
      Platform.isWindows ? 'assets/favicon.ico' : 'assets/app_icon.png';

  final AppWindow appWindow = AppWindow();
  final SystemTray systemTray = SystemTray();

  // We first init the systray menu
  await systemTray.initSystemTray(
    title: "system tray",
    iconPath: path,
  );

  // create context menu
  final Menu menu = Menu();
  await menu.buildFrom([
    MenuItemLabel(label: 'Show', onClicked: (menuItem) => appWindow.show()),
    MenuItemLabel(label: 'Hide', onClicked: (menuItem) => appWindow.hide()),
    MenuItemLabel(label: 'Exit', onClicked: (menuItem) => appWindow.close()),
  ]);

  // set context menu
  await systemTray.setContextMenu(menu);

  // handle system tray event
  systemTray.registerSystemTrayEventHandler((eventName) {
    debugPrint("eventName: $eventName");
    if (eventName == kSystemTrayEventClick) {
      Platform.isWindows ? appWindow.show() : systemTray.popUpContextMenu();
    } else if (eventName == kSystemTrayEventRightClick) {
      Platform.isWindows ? systemTray.popUpContextMenu() : appWindow.show();
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSystemTray();

  // 必须加上这一行。
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(200, 200),
    minimumSize: Size(200, 200),
    // maximumSize: Size(200, 200),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,

    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const App());
}
