import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart'; // Utilisez share_plus au lieu de share

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cahier de Musculation',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}

class Exercise {
  String name;
  List<Serie> series;

  Exercise({required this.name, required this.series});

  Map<String, dynamic> toJson() => {
    'name': name,
    'series': series.map((s) => s.toJson()).toList(),
  };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'],
      series: (json['series'] as List)
          .map((s) => Serie.fromJson(s))
          .toList(),
    );
  }
}

class Serie {
  String weight;
  String reps;
  String time;
  double feeling;
  String note;

  Serie({
    this.weight = '',
    this.reps = '',
    this.time = '',
    this.feeling = 0,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'weight': weight,
    'reps': reps,
    'time': time,
    'feeling': feeling,
    'note': note,
  };

  factory Serie.fromJson(Map<String, dynamic> json) {
    return Serie(
      weight: json['weight'] ?? '',
      reps: json['reps'] ?? '',
      time: json['time'] ?? '',
      feeling: (json['feeling'] ?? 0).toDouble(),
      note: json['note'] ?? '',
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Exercise> exercises = [];
  final TextEditingController exerciseNameController = TextEditingController();
  final TextEditingController previousSessionController = TextEditingController();
  final List<String> timeOptions = [
    '30 sec',
    '45 sec',
    '1 min',
    '1 min 30',
    '2 min',
    '2 min 30',
    '3 min',
    '4 min',
    '5 min'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? exercisesJson = prefs.getString('exercises');
    if (exercisesJson != null) {
      final List<dynamic> decodedData = jsonDecode(exercisesJson);
      setState(() {
        exercises = decodedData
            .map((json) => Exercise.fromJson(json))
            .toList();
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String exercisesJson = jsonEncode(
      exercises.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('exercises', exercisesJson);
  }

  Future<void> _importPreviousSession() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final File file = File(result.files.single.path!);
        final String content = await file.readAsString();
        setState(() {
          previousSessionController.text = content;
        });
        _parseCsvContent(content);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'importation: $e')),
      );
    }
  }

  void _parseCsvContent(String content) {
    final List<List<dynamic>> rows = const CsvToListConverter().convert(content);
    final List<Exercise> importedExercises = [];

    for (var row in rows) {
      if (row[0] == 'Nom Exercice') continue; // Skip the header row
      final exerciseName = row[0];
      final weight = row[1];
      final reps = row[2];
      final time = row[3];
      final feeling = double.tryParse(row[4].toString()) ?? 0;
      final note = row[5];

      final exercise = importedExercises.firstWhere(
        (ex) => ex.name == exerciseName,
        orElse: () {
          final newExercise = Exercise(name: exerciseName, series: []);
          importedExercises.add(newExercise);
          return newExercise;
        },
      );

      exercise.series.add(Serie(
        weight: weight,
        reps: reps,
        time: time,
        feeling: feeling,
        note: note,
      ));
    }

    setState(() {
      exercises = importedExercises;
    });
    _saveData();
  }

  void _addExercise() {
    if (exerciseNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez entrer un nom d\'exercice')),
      );
      return;
    }

    setState(() {
      exercises.add(Exercise(
        name: exerciseNameController.text,
        series: [Serie()],
      ));
      exerciseNameController.clear();
    });
    _saveData();
  }

  void _addSerie(int exerciseIndex) {
    setState(() {
      exercises[exerciseIndex].series.add(Serie());
    });
    _saveData();
  }

  void _shareWorkout() {
    String csv = 'Nom Exercice,Poids,Répétitions,Temps,Ressenti,Note\n';

    for (var exercise in exercises) {
      for (var serie in exercise.series) {
        csv += '${exercise.name},${serie.weight},${serie.reps},${serie.time},${serie.feeling},${serie.note}\n';
      }
    }

    Share.share(csv, subject: 'Séance d\'entraînement');
  }

  void _newWorkout() {
    // Votre code pour créer un nouvel entraînement
    // Par exemple, vous pouvez vider la liste des exercices et enregistrer les données
    setState(() {
      exercises.clear();
    });
    _saveData();
  }

  Widget _buildStarRating(double rating, Function(double) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 20,
          ),
          onPressed: () => onChanged(index + 1.0),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 30, minHeight: 30),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cahier de Musculation'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_box),
            tooltip: 'Nouvel entraînement',
            onPressed: _newWorkout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone d'importation de la séance précédente
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: previousSessionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Données de la séance précédente',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.file_upload),
                  onPressed: _importPreviousSession,
                ),
              ],
            ),
          ),
          // Champ nom de l'exercice
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: exerciseNameController,
              decoration: InputDecoration(
                labelText: 'Nom de l\'exercice',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _addExercise,
                ),
              ),
              onSubmitted: (_) => _addExercise(),
            ),
          ),
          // Liste des exercices
          Expanded(
            child: ListView.builder(
              itemCount: exercises.length,
              itemBuilder: (context, exerciseIndex) {
                final exercise = exercises[exerciseIndex];
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: Colors.blue,
                        padding: EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                exercise.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add, color: Colors.white),
                              onPressed: () => _addSerie(exerciseIndex),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          columns: [
                            DataColumn(label: Text('Poids', style: TextStyle(fontSize: 14))),
                            DataColumn(label: Text('REP', style: TextStyle(fontSize: 14))),
                            DataColumn(label: Text('Temps', style: TextStyle(fontSize: 14))),
                            DataColumn(label: Text('Ressenti', style: TextStyle(fontSize: 14))),
                            DataColumn(label: Text('Note', style: TextStyle(fontSize: 14))),
                          ],
                          rows: exercise.series.map((serie) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 60,
                                    child: TextField(
                                      controller: TextEditingController(text: serie.weight),
                                      onChanged: (value) {
                                        serie.weight = value;
                                        _saveData();
                                      },
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: 'kg',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 50,
                                    child: TextField(
                                      controller: TextEditingController(text: serie.reps),
                                      onChanged: (value) {
                                        serie.reps = value;
                                        _saveData();
                                      },
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 100,
                                    child: DropdownButton<String>(
                                      value: serie.time.isEmpty ? timeOptions[0] : serie.time,
                                      items: timeOptions.map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                      onChanged: (String? value) {
                                        setState(() {
                                          serie.time = value ?? '';
                                          _saveData();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                DataCell(
                                  _buildStarRating(
                                    serie.feeling,
                                    (rating) {
                                      setState(() {
                                        serie.feeling = rating;
                                        _saveData();
                                      });
                                    },
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: TextEditingController(text: serie.note),
                                      onChanged: (value) {
                                        serie.note = value;
                                        _saveData();
                                      },
                                      decoration: InputDecoration(
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: _shareWorkout,
            child: Text('Partager la séance'),
          ),
        ),
      ),
    );
  }
}
