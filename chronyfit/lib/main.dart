import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Indispensable pour la sauvegarde Android
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

// Imports des shaders
import 'background_anim.dart'; // Le fond Pollen (Liste)
import 'run_background_anim.dart'; // Le fond Néon (Run)

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ChronoController())],
      child: const ChronyFitApp(),
    ),
  );
}

// --- THÈME ---
const Color kBackgroundColor =
    Colors.transparent; // Transparent pour les shaders
const Color kTextColor = Colors.white;
const Color kInputBackground = Color(0xFFD9D9D9);

class ChronyFitApp extends StatelessWidget {
  const ChronyFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChronyFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kBackgroundColor,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          surface: Color(0xFF1E1E1E),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: kTextColor,
          ),
          bodyLarge: TextStyle(fontSize: 18, color: Colors.black),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// --- MODÈLE ---
class ChronoItem {
  String id;
  String name;
  int durationSeconds;
  int colorIndex;

  ChronoItem({
    required this.id,
    this.name = '',
    this.durationSeconds = 60,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'durationSeconds': durationSeconds,
    'colorIndex': colorIndex,
  };

  factory ChronoItem.fromJson(Map<String, dynamic> json) {
    return ChronoItem(
      id: json['id'],
      name: json['name'],
      durationSeconds: json['durationSeconds'],
      colorIndex: json['colorIndex'],
    );
  }
}

// --- CONTROLEUR ---
class ChronoController extends ChangeNotifier {
  List<ChronoItem> _items = [];
  List<ChronoItem> get items => _items;

  bool _isRunning = false;
  bool _isPaused = false;
  bool _isFinished = false;
  int _currentIndex = 0;
  int _timeLeft = 0;
  Timer? _timer;

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  bool get isFinished => _isFinished;
  int get currentIndex => _currentIndex;
  int get timeLeft => _timeLeft;

  ChronoItem? get currentItem =>
      _items.isNotEmpty && _currentIndex < _items.length
      ? _items[_currentIndex]
      : null;

  double get progress {
    if (currentItem == null || currentItem!.durationSeconds == 0) return 0.0;
    return _timeLeft / currentItem!.durationSeconds;
  }

  ChronoController() {
    _initDemo();
  }

  void _initDemo() {
    _items = [
      ChronoItem(id: '1', name: "Push Up", durationSeconds: 60, colorIndex: 0),
      ChronoItem(id: '2', name: "Plank", durationSeconds: 90, colorIndex: 1),
      ChronoItem(id: '3', name: "Traction", durationSeconds: 30, colorIndex: 2),
      ChronoItem(id: '4', name: "Chill", durationSeconds: 120, colorIndex: 3),
      ChronoItem(id: '5', name: "Abdos", durationSeconds: 150, colorIndex: 4),
    ];
  }

  void addChrono() {
    int nextColorIndex = (_items.length) % 5;
    _items.add(
      ChronoItem(
        id: DateTime.now().toString(),
        name: "",
        durationSeconds: 60,
        colorIndex: nextColorIndex,
      ),
    );
    notifyListeners();
  }

  void removeChrono(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void updateChronoName(int index, String name) {
    _items[index].name = name;
  }

  void updateChronoTime(int index, int seconds) {
    _items[index].durationSeconds = seconds;
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    notifyListeners();
  }

  void startSequence() {
    if (_items.isEmpty) return;

    if (!_isRunning) {
      if (_isFinished) {
        _currentIndex = 0;
        _isFinished = false;
      }
      if (_timeLeft == 0 && _currentIndex == 0) {
        _timeLeft = _items[0].durationSeconds > 0
            ? _items[0].durationSeconds
            : 0;
      }
      _isRunning = true;
      _isPaused = false;
    } else if (_isPaused) {
      _isPaused = false;
    }

    notifyListeners();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        _timeLeft--;
      } else {
        if (_currentIndex < _items.length - 1) {
          _currentIndex++;
          _timeLeft = _items[_currentIndex].durationSeconds;
        } else {
          _isFinished = true;
          _timeLeft = 0;
          _timer?.cancel();
          _isRunning = false;
        }
      }
      notifyListeners();
    });
  }

  void togglePause() {
    if (_isPaused) {
      _isPaused = false;
      _startTimer();
    } else {
      _isPaused = true;
      _timer?.cancel();
    }
    notifyListeners();
  }

  void quitToMenu() {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;
    _isFinished = false;
    _currentIndex = 0;
    _timeLeft = _items.isNotEmpty ? _items[0].durationSeconds : 0;
    notifyListeners();
  }

  void hardReset() {
    quitToMenu();
    _timeLeft = 0;
    _items = List.generate(
      5,
      (index) => ChronoItem(
        id: DateTime.now().add(Duration(milliseconds: index)).toString(),
        name: "",
        durationSeconds: 0,
        colorIndex: index % 5,
      ),
    );
    notifyListeners();
  }

  // --- IMPORT / EXPORT (CORRIGÉ POUR ANDROID) ---
  Future<String> exportToFile() async {
    try {
      // 1. Création du JSON
      String jsonString = jsonEncode(_items.map((e) => e.toJson()).toList());

      // 2. Conversion en Bytes (Octets) obligatoire pour Android
      List<int> list = utf8.encode(jsonString);
      Uint8List bytes = Uint8List.fromList(list);

      // 3. Sauvegarde via le plugin
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer votre entrainement',
        fileName: 'mon_entrainement.json',
        type: FileType.any, // 'any' est plus stable
        bytes: bytes,
      );

      if (outputFile != null) {
        return "Sauvegardé !";
      } else {
        return "Annulé";
      }
    } catch (e) {
      return "Erreur : $e";
    }
  }

  Future<String> importFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choisir un fichier',
        type: FileType.any, // Accepte tout pour éviter les filtres stricts
        withData: true, // Important si on veut lire les bytes directement
      );

      if (result != null) {
        String jsonString;

        // Lecture : Soit via le chemin (PC), soit via les bytes (Web/Certains Android)
        if (result.files.single.path != null) {
          File file = File(result.files.single.path!);
          jsonString = await file.readAsString();
        } else if (result.files.single.bytes != null) {
          jsonString = utf8.decode(result.files.single.bytes!);
        } else {
          return "Impossible de lire le fichier";
        }

        List<dynamic> jsonList = jsonDecode(jsonString);
        _items = jsonList.map((e) => ChronoItem.fromJson(e)).toList();

        quitToMenu();
        return "Chargé !";
      } else {
        return "Annulé";
      }
    } catch (e) {
      return "Erreur lecture : $e";
    }
  }
}

// --- UI PRINCIPALE ---
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChronoController>();

    bool showRunView = controller.isRunning || controller.isFinished;

    Widget content = Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const HeaderWidget(),
              const SizedBox(height: 20),
              Expanded(child: showRunView ? const RunView() : const EditView()),
              if (showRunView || controller.currentIndex > 0)
                const SizedBox(height: 20),
              if (showRunView || controller.currentIndex > 0)
                const BottomSequenceIndicator(),
            ],
          ),
        ),
      ),
    );

    // SWITCH DE BACKGROUND
    if (showRunView) {
      return RunBackgroundAnim(child: content);
    } else {
      return BackgroundAnim(child: content);
    }
  }
}

// --- HEADER ---
class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChronoController>();

    String statusText = "START";
    if (controller.isRunning || controller.isPaused) statusText = "STOP";

    void showMsg(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(12),
            color: Colors.black38,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActionButton(
                text: "Save",
                onTap: () async => showMsg(await controller.exportToFile()),
              ),
              _ActionButton(
                text: "Import",
                onTap: () async => showMsg(await controller.importFromFile()),
              ),
              _ActionButton(
                text: "Reset",
                onTap: () {
                  controller.hardReset();
                  showMsg("Remise à zéro");
                },
              ),
            ],
          ),
        ),

        GestureDetector(
          onTap: () {
            if (controller.isRunning ||
                controller.isPaused ||
                controller.isFinished) {
              controller.quitToMenu();
            } else {
              controller.startSequence();
            }
          },
          child: Text(
            statusText,
            style: Theme.of(context).textTheme.displayLarge,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _ActionButton({required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// --- VUE ÉDITION (LISTE) ---
class EditView extends StatelessWidget {
  const EditView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChronoController>();

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            itemCount: controller.items.length,
            onReorder: controller.reorder,
            itemBuilder: (context, index) {
              final item = controller.items[index];
              return Container(
                key: ValueKey(item.id),
                margin: const EdgeInsets.only(bottom: 12.0),
                padding: const EdgeInsets.only(right: 10.0),
                child: Row(
                  children: [
                    CShapeIcon(colorIndex: item.colorIndex, size: 45),
                    const SizedBox(width: 10),

                    // --- CARTOUCHE DU TEMPS ---
                    GestureDetector(
                      onTap: () => _showTimePicker(
                        context,
                        controller,
                        index,
                        item.durationSeconds,
                      ),
                      child: Container(
                        width: 70,
                        height: 45,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          "${item.durationSeconds ~/ 60}:${(item.durationSeconds % 60).toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // --- CARTOUCHE DU NOM (Stack pour le bouton supprimer) ---
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // Le champ texte
                            TextField(
                              controller: TextEditingController(
                                text: item.name,
                              ),
                              onChanged: (val) =>
                                  controller.updateChronoName(index, val),
                              onSubmitted: (_) => controller.refresh(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              cursorColor: Colors.blueAccent,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "Activité...",
                                hintStyle: TextStyle(color: Colors.white38),
                                contentPadding: EdgeInsets.only(
                                  left: 45, // Place pour le bouton
                                  bottom: 8,
                                  right: 10,
                                ),
                              ),
                            ),

                            // Le bouton supprimer (à gauche)
                            Positioned(
                              left: 8,
                              child: GestureDetector(
                                onTap: () => controller.removeChrono(index),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF717171),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: IconButton(
            onPressed: controller.addChrono,
            icon: const Icon(Icons.add_circle, size: 60, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showTimePicker(
    BuildContext context,
    ChronoController controller,
    int index,
    int currentSeconds,
  ) {
    int minutes = currentSeconds ~/ 60;
    int seconds = currentSeconds % 60;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text(
            "Définir la durée",
            style: TextStyle(color: Colors.white),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: minutes,
                    dropdownColor: const Color(0xFF3C3C3C),
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    items: List.generate(
                      60,
                      (i) => DropdownMenuItem(value: i, child: Text("$i m")),
                    ),
                    onChanged: (val) => setState(() => minutes = val!),
                  ),
                  const SizedBox(width: 20),
                  DropdownButton<int>(
                    value: seconds,
                    dropdownColor: const Color(0xFF3C3C3C),
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    items: List.generate(
                      60,
                      (i) => DropdownMenuItem(value: i, child: Text("$i s")),
                    ),
                    onChanged: (val) => setState(() => seconds = val!),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                controller.updateChronoTime(index, minutes * 60 + seconds);
                Navigator.pop(ctx);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
}

// --- VUE TIMER (RUN) ---
class RunView extends StatelessWidget {
  const RunView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChronoController>();

    if (controller.isFinished) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "ENTRAINEMENT TERMINÉ !",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // --- BOUTON RETOUR MENU MODIFIÉ (Style Verre Fumé) ---
            GestureDetector(
              onTap: () => controller.quitToMenu(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: const Text(
                  "RETOUR MENU",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // -----------------------------------------------------
          ],
        ),
      );
    }

    final item = controller.currentItem;
    if (item == null) return const SizedBox();

    final colors = [
      const Color(0xFF8B80F9),
      const Color(0xFFFFC076),
      const Color(0xFF6CF097),
      const Color(0xFF6CDCF0),
      const Color(0xFFE976FF),
    ];
    final activeColor = colors[item.colorIndex % colors.length];

    // CRÉATION DE LA COULEUR "PLUS LUMINEUSE"
    final brightColor = Color.lerp(activeColor, Colors.white, 0.25)!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 250,
          height: 250,
          child: CustomPaint(
            painter: TimerPainter(
              color: activeColor,
              progress: controller.progress,
            ),
          ),
        ),
        const SizedBox(height: 30),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- CARTOUCHE NOM (Style Verre Fumé) ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF000000).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: Text(
                item.name.isEmpty ? "..." : item.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 15),
            IconButton(
              iconSize: 45,
              onPressed: controller.togglePause,
              icon: Icon(
                controller.isPaused
                    ? Icons.play_circle_fill
                    : Icons.pause_circle_filled,
                color: Colors.white,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),

        const SizedBox(height: 20),
        // --- COMPTE A REBOURS LUMINEUX ---
        Text(
          "${controller.timeLeft ~/ 60}:${(controller.timeLeft % 60).toString().padLeft(2, '0')}",
          style: TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.bold,
            color: brightColor, // Texte plus lumineux
            shadows: [
              Shadow(
                blurRadius: 20.0,
                color: activeColor.withValues(alpha: 0.6),
                offset: Offset.zero,
              ),
              Shadow(
                blurRadius: 8.0,
                color: activeColor.withValues(alpha: 0.8),
                offset: Offset.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- UTILITAIRES (TimerPainter avec ombres) ---
class TimerPainter extends CustomPainter {
  final Color color;
  final double progress;
  TimerPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = size.width / 2;

    // 1. Ombre globale
    Path circlePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawShadow(
      circlePath,
      Colors.black.withValues(alpha: 0.5),
      8.0,
      true,
    );

    // 2. Fond du cercle
    paint.color = color.withValues(alpha: 0.3);
    canvas.drawCircle(center, radius, paint);

    // 3. Ombre portée interne
    Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius).shift(const Offset(3, 3)),
      -3.14159 / 2,
      2 * 3.14159 * progress,
      true,
      shadowPaint,
    );

    // 4. Partie colorée
    paint.color = color;
    paint.maskFilter = null;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * progress,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(TimerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class BottomSequenceIndicator extends StatelessWidget {
  const BottomSequenceIndicator({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChronoController>();
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: controller.items.length,
        itemBuilder: (context, index) {
          final item = controller.items[index];
          bool isCurrent = index == controller.currentIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: Opacity(
              opacity: isCurrent ? 1.0 : 0.4,
              child: Transform.scale(
                scale: isCurrent ? 1.2 : 0.9,
                child: CShapeIcon(colorIndex: item.colorIndex, size: 40),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CShapeIcon extends StatelessWidget {
  final int colorIndex;
  final double size;
  const CShapeIcon({super.key, required this.colorIndex, required this.size});
  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF8B80F9),
      const Color(0xFFFFC076),
      const Color(0xFF6CF097),
      const Color(0xFF6CDCF0),
      const Color(0xFFE976FF),
    ];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors[colorIndex % 5],
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.4,
          height: size * 0.4,
          decoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
