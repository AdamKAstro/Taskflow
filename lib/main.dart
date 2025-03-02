import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() => runApp(TaskFlowApp());

class TaskFlowApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      home: TaskFlowHome(),
    );
  }
}

class TaskFlowHome extends StatefulWidget {
  @override
  _TaskFlowHomeState createState() => _TaskFlowHomeState();
}

class _TaskFlowHomeState extends State<TaskFlowHome> {
  // State
  List<Map<String, dynamic>> tasks = [];
  int streak = 0;
  String? lastEnergy;
  bool energyCheckShownToday = false;
  bool energyChecksOn = true;
  String energyFrequency = 'Once Daily';
  TimeOfDay energyCheckTime = TimeOfDay(hour: 12, minute: 0);
  bool isFirstRun = true;
  bool darkModeUnlocked = false;
  DateTime? lastReset;
  bool challengeActive = false;
  int challengeProgress = 0;
  int points = 0;
  int streakFreezes = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
    Timer.periodic(Duration(seconds: 30), (timer) => _checkEnergyAndReset());
  }

  // Load data
  _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      streak = prefs.getInt('streak') ?? 0;
      lastEnergy = prefs.getString('lastEnergy');
      isFirstRun = prefs.getBool('isFirstRun') ?? true;
      darkModeUnlocked = prefs.getBool('darkModeUnlocked') ?? false;
      energyChecksOn = prefs.getBool('energyChecksOn') ?? true;
      energyFrequency = prefs.getString('energyFrequency') ?? 'Once Daily';
      lastReset = DateTime.tryParse(prefs.getString('lastReset') ?? '') ?? DateTime.now();
      points = prefs.getInt('points') ?? 0;
      streakFreezes = prefs.getInt('streakFreezes') ?? 1;
      tasks = (prefs.getStringList('tasks') ?? []).map((t) {
        List<String> parts = t.split('|');
        return {
          'title': parts[0],
          'time': TimeOfDay(hour: int.parse(parts[1]), minute: int.parse(parts[2])),
          'complexity': parts[3],
          'done': parts[4] == 'true',
        };
      }).toList();
    });
    if (isFirstRun) _loadGuidedDay();
    if (!challengeActive && streak > 0) _startChallenge();
  }

  // Save data
  _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('streak', streak);
    prefs.setString('lastEnergy', lastEnergy ?? '');
    prefs.setBool('isFirstRun', isFirstRun);
    prefs.setBool('darkModeUnlocked', darkModeUnlocked);
    prefs.setBool('energyChecksOn', energyChecksOn);
    prefs.setString('energyFrequency', energyFrequency);
    prefs.setString('lastReset', lastReset!.toIso8601String());
    prefs.setInt('points', points);
    prefs.setInt('streakFreezes', streakFreezes);
    prefs.setStringList(
      'tasks',
      tasks.map((t) => '${t['title']}|${t['time'].hour}|${t['time'].minute}|${t['complexity']}|${t['done']}').toList(),
    );
  }

  // Guided Day
  _loadGuidedDay() {
    setState(() {
      tasks = [
        {'title': 'Say Hi', 'time': TimeOfDay(hour: 9, minute: 0), 'complexity': 'Easy', 'done': false},
        {'title': 'Stretch', 'time': TimeOfDay(hour: 12, minute: 0), 'complexity': 'Medium', 'done': false},
        {'title': 'Plan Tomorrow', 'time': TimeOfDay(hour: 18, minute: 0), 'complexity': 'Hard', 'done': false},
      ];
    });
    _showGuidedIntro();
  }

  _showGuidedIntro() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Welcome to TaskFlow!"),
        content: Text("3 tasks to start—finish them for your streak. Tap ‘Next Up’!"),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => isFirstRun = false);
              _saveData();
              Navigator.pop(context);
            },
            child: Text("Begin"),
          ),
        ],
      ),
    );
  }

  // Energy and streak check
  _checkEnergyAndReset() {
    DateTime now = DateTime.now();
    if (now.hour == 0 && now.minute == 0 && lastReset!.day != now.day) {
      setState(() {
        if (tasks.any((t) => !t['done']) && streakFreezes == 0) streak = 0;
        else if (tasks.any((t) => !t['done'])) streakFreezes--;
        tasks.clear();
        energyCheckShownToday = false;
        challengeActive = false;
        challengeProgress = 0;
        lastReset = now;
      });
      _saveData();
    }
    if (energyChecksOn && !energyCheckShownToday) {
      if ((energyFrequency == 'Once Daily' && now.hour == energyCheckTime.hour && now.minute == energyCheckTime.minute) ||
          (energyFrequency == 'Twice Daily' && ((now.hour == 9 && now.minute == 0) || (now.hour == 18 && now.minute == 0)))) {
        _showEnergyCheck();
      }
    }
  }

  // Add task
  _addTask(String title, String complexity) {
    TimeOfDay suggestedTime = _suggestTime(complexity, lastEnergy);
    setState(() {
      tasks.add({'title': title, 'time': suggestedTime, 'complexity': complexity, 'done': false});
    });
    _saveData();
  }

  // AI scheduling
  TimeOfDay _suggestTime(String complexity, String? energy) {
    int hour = energy == 'High'
        ? (complexity == 'Hard' ? 10 : complexity == 'Medium' ? 14 : 16)
        : energy == 'Low'
            ? (complexity == 'Easy' ? 15 : 17)
            : (complexity == 'Hard' ? 11 : complexity == 'Medium' ? 13 : 15);
    return TimeOfDay(hour: hour, minute: 0);
  }

  // Complete task
  _completeTask(int index) {
    setState(() {
      tasks[index]['done'] = true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Task Done! 🎉")));
      if (challengeActive) {
        challengeProgress++;
        if (challengeProgress >= 2) {
          points += 10;
          _showRewardDialog("Challenge Done!", "2 tasks—10 points!");
          challengeActive = false;
        }
      }
      if (tasks.every((t) => t['done']) && DateTime.now().hour >= 18) {
        streak++;
        energyCheckShownToday = false;
        if (streak == 7 && !darkModeUnlocked) {
          darkModeUnlocked = true;
          _showRewardDialog("Dark Mode Unlocked!", "7-day streak!");
        }
        _startChallenge();
      }
    });
    _saveData();
  }

  // Start challenge
  _startChallenge() {
    setState(() {
      challengeActive = true;
      challengeProgress = 0;
    });
    _showRewardDialog("New Challenge!", "Finish 2 tasks today for 10 points!");
  }

  _showRewardDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Great!"))],
      ),
    );
  }

  // Energy check
  _showEnergyCheck() {
    double _energy = 2.0;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Energy Check"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("How’s your energy?"),
              Slider(
                value: _energy,
                min: 1.0,
                max: 3.0,
                divisions: 2,
                label: _energy == 1.0 ? "Low" : _energy == 2.0 ? "Medium" : "High",
                onChanged: (value) => setDialogState(() => _energy = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Skip")),
            TextButton(
              onPressed: () {
                setState(() {
                  lastEnergy = _energy == 1.0 ? "Low" : _energy == 2.0 ? "Medium" : "High";
                  energyCheckShownToday = true;
                });
                _saveData();
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  // Add task dialog
  _showAddTaskDialog() {
    String title = '';
    String complexity = 'Medium';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Add Task"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) => title = value,
                decoration: InputDecoration(labelText: "Task Title"),
              ),
              DropdownButton<String>(
                value: complexity,
                items: ['Easy', 'Medium', 'Hard'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (value) => setDialogState(() => complexity = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (title.isNotEmpty) _addTask(title, complexity);
                Navigator.pop(context);
              },
              child: Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  // Settings & Shop
  _showSettingsDialog() {
    String tempFreq = energyFrequency;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Settings & Shop"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text("Energy Checks"),
                  value: energyChecksOn,
                  onChanged: (value) => setState(() => energyChecksOn = value),
                ),
                if (energyChecksOn)
                  DropdownButton<String>(
                    value: tempFreq,
                    items: ['Once Daily', 'Twice Daily'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (value) => setDialogState(() => tempFreq = value!),
                  ),
                Divider(),
                Text("Shop (Points: $points)", style: TextStyle(fontWeight: FontWeight.bold)),
                ListTile(
                  title: Text("Streak Freeze (20 points)"),
                  subtitle: Text("Freezes: $streakFreezes"),
                  trailing: ElevatedButton(
                    onPressed: points >= 20
                        ? () {
                            setState(() {
                              points -= 20;
                              streakFreezes++;
                            });
                            _saveData();
                            setDialogState(() {});
                          }
                        : null,
                    child: Text("Buy"),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => energyFrequency = tempFreq);
                _saveData();
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: darkModeUnlocked && streak >= 7 ? ThemeData.dark() : ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(
          title: Text("TaskFlow"),
          actions: [
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: _showSettingsDialog,
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Next Up", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
              tasks.isNotEmpty
                  ? Card(
                      elevation: 4,
                      child: ListTile(
                        title: Text(tasks.firstWhere((t) => !t['done'], orElse: () => tasks[0])['title']),
                        subtitle: Text("Time: ${tasks[0]['time'].format(context)} (Why? ${tasks[0]['complexity']})"),
                        trailing: tasks[0]['done']
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : ElevatedButton(
                                onPressed: () => _completeTask(0),
                                child: Text("Done"),
                              ),
                      ),
                    )
                  : Text("No tasks—add one!"),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Streak: $streak days", style: TextStyle(fontSize: 16)),
                  Text("Points: $points", style: TextStyle(fontSize: 16)),
                ],
              ),
              LinearProgressIndicator(value: streak / 7.clamp(0, 1), minHeight: 8, color: Colors.blue),
              if (challengeActive)
                Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text("Challenge: $challengeProgress/2 tasks", style: TextStyle(color: Colors.orange)),
                ),
              SizedBox(height: 20),
              Text("All Tasks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) => Card(
                    child: ListTile(
                      title: Text(tasks[index]['title']),
                      subtitle: Text("${tasks[index]['time'].format(context)} - ${tasks[index]['complexity']}"),
                      trailing: tasks[index]['done']
                          ? Icon(Icons.check_circle, color: Colors.green)
                          : IconButton(
                              icon: Icon(Icons.check),
                              onPressed: () => _completeTask(index),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: _showAddTaskDialog,
              child: Icon(Icons.add),
              tooltip: "Add Task",
            ),
            SizedBox(height: 10),
            FloatingActionButton(
              onPressed: _showEnergyCheck,
              child: Icon(Icons.battery_charging_full),
              tooltip: "Log Energy",
            ),
          ],
        ),
      ),
    );
  }
}
