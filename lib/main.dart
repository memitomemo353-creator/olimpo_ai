import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: OlimpoAIApp(),
    ),
  );
}

// ============================================================================
// MODELS & STATE MANAGEMENT
// ============================================================================

class Titan {
  final int id;
  final String name;
  final String emoji;
  final String description;
  final String modelType; // GGUF, ONNX, BIN
  final String capability;
  final String ramRequired;
  String? localPath;
  bool get isAssigned => localPath != null && localPath!.isNotEmpty;

  Titan({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.modelType,
    required this.capability,
    required this.ramRequired,
    this.localPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'description': description,
      'modelType': modelType,
      'capability': capability,
      'ramRequired': ramRequired,
      'localPath': localPath,
    };
  }

  factory Titan.fromJson(Map<String, dynamic> json) {
    return Titan(
      id: json['id'],
      name: json['name'],
      emoji: json['emoji'],
      description: json['description'],
      modelType: json['modelType'],
      capability: json['capability'],
      ramRequired: json['ramRequired'],
      localPath: json['localPath'],
    );
  }
}

class Message {
  final String id;
  final String role; // "user" or "titan"
  final String content;
  final DateTime timestamp;
  final String? titanName;
  final double? tokensPerSecond;
  final double? latencyMs;

  Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.titanName,
    this.tokensPerSecond,
    this.latencyMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'titanName': titanName,
      'tokensPerSecond': tokensPerSecond,
      'latencyMs': latencyMs,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      titanName: json['titanName'],
      tokensPerSecond: json['tokensPerSecond'],
      latencyMs: json['latencyMs'],
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Message> messages;
  final String? activeTitanId;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.activeTitanId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'activeTitanId': activeTitanId,
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m))
          .toList(),
      activeTitanId: json['activeTitanId'],
    );
  }
}

// ============================================================================
// RIVERPOD PROVIDERS
// ============================================================================

final titansProvider = StateNotifierProvider<TitansNotifier, List<Titan>>((ref) {
  return TitansNotifier();
});

class TitansNotifier extends StateNotifier<List<Titan>> {
  TitansNotifier() : super([]) {
    _initializeTitans();
  }

  void _initializeTitans() async {
    final titans = [
      Titan(
        id: 1,
        name: 'El Genio',
        emoji: '🧠',
        description: 'DeepSeek R1 - Lógica / Razonamiento profundo',
        modelType: 'GGUF',
        capability: 'Razonamiento avanzado y análisis lógico',
        ramRequired: '4GB',
      ),
      Titan(
        id: 2,
        name: 'El Programador',
        emoji: '💻',
        description: 'Qwen Coder 3B - Código / Dart / Flutter',
        modelType: 'GGUF',
        capability: 'Generación de código y debugging',
        ramRequired: '2GB',
      ),
      Titan(
        id: 3,
        name: 'El Veloz',
        emoji: '⚡',
        description: 'Qwen 3B - Chat fluido en español',
        modelType: 'GGUF',
        capability: 'Conversación natural y rápida',
        ramRequired: '2GB',
      ),
      Titan(
        id: 4,
        name: 'El Organizador',
        emoji: '📋',
        description: 'Phi-3.5 - Estructuras / JSON',
        modelType: 'GGUF',
        capability: 'Generación de JSON y estructuración de datos',
        ramRequired: '2.5GB',
      ),
      Titan(
        id: 5,
        name: 'El Oído',
        emoji: '🎧',
        description: 'Whisper Base - Voz a texto',
        modelType: 'BIN',
        capability: 'Transcripción de audio a texto',
        ramRequired: '1.5GB',
      ),
      Titan(
        id: 6,
        name: 'El Artista',
        emoji: '🖼️',
        description: 'SD Turbo - Generación de imágenes',
        modelType: 'GGUF',
        capability: 'Generación de imágenes a partir de prompts',
        ramRequired: '3GB',
      ),
      Titan(
        id: 7,
        name: 'El Sin Censura',
        emoji: '🦁',
        description: 'Hermes 3 - Rol / Creatividad libre',
        modelType: 'GGUF',
        capability: 'Rol playing y creatividad sin restricciones',
        ramRequired: '2.5GB',
      ),
      Titan(
        id: 8,
        name: 'El Vidente',
        emoji: '👁️',
        description: 'Qwen2-VL - Visión por cámara / OCR',
        modelType: 'GGUF',
        capability: 'Análisis de imágenes y OCR',
        ramRequired: '3.5GB',
      ),
      Titan(
        id: 9,
        name: 'El Orador',
        emoji: '🗣️',
        description: 'Kokoro 82M - Texto a voz humana',
        modelType: 'ONNX',
        capability: 'Síntesis de voz natural',
        ramRequired: '1GB',
      ),
      Titan(
        id: 10,
        name: 'La Memoria',
        emoji: '📚',
        description: 'Nomic Embed - Lector de PDFs / RAG',
        modelType: 'GGUF',
        capability: 'Lectura de documentos y búsqueda semántica',
        ramRequired: '2GB',
      ),
    ];

    // Cargar rutas guardadas
    final prefs = await SharedPreferences.getInstance();
    for (var titan in titans) {
      final savedPath = prefs.getString('titan_path_${titan.id}');
      if (savedPath != null && savedPath.isNotEmpty) {
        titan.localPath = savedPath;
      }
    }

    state = titans;
  }

  Future<void> assignModelPath(int titanId, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('titan_path_$titanId', path);

    state = [
      for (final titan in state)
        if (titan.id == titanId)
          Titan(
            id: titan.id,
            name: titan.name,
            emoji: titan.emoji,
            description: titan.description,
            modelType: titan.modelType,
            capability: titan.capability,
            ramRequired: titan.ramRequired,
            localPath: path,
          )
        else
          titan,
    ];
  }

  Future<void> removeModelPath(int titanId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('titan_path_$titanId');

    state = [
      for (final titan in state)
        if (titan.id == titanId)
          Titan(
            id: titan.id,
            name: titan.name,
            emoji: titan.emoji,
            description: titan.description,
            modelType: titan.modelType,
            capability: titan.capability,
            ramRequired: titan.ramRequired,
            localPath: null,
          )
        else
          titan,
    ];
  }
}

final chatSessionsProvider =
    StateNotifierProvider<ChatSessionsNotifier, List<ChatSession>>((ref) {
  return ChatSessionsNotifier();
});

class ChatSessionsNotifier extends StateNotifier<List<ChatSession>> {
  ChatSessionsNotifier() : super([]) {
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final dir = await getApplicationDocumentsDirectory();
    final sessionsDir = Directory('${dir.path}/chat_sessions');
    if (!await sessionsDir.exists()) {
      await sessionsDir.create(recursive: true);
      state = [];
      return;
    }

    final files = sessionsDir.listSync();
    final sessions = <ChatSession>[];

    for (var file in files) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content);
          sessions.add(ChatSession.fromJson(json));
        } catch (e) {
          print('Error loading session: $e');
        }
      }
    }

    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = sessions;
  }

  Future<ChatSession> createSession(String title) async {
    const uuid = Uuid();
    final session = ChatSession(
      id: uuid.v4(),
      title: title.isEmpty ? 'Nueva Sesión' : title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [],
    );

    await _saveSession(session);
    state = [session, ...state];
    return session;
  }

  Future<void> addMessage(
    String sessionId,
    String role,
    String content, {
    String? titanName,
    double? tokensPerSecond,
    double? latencyMs,
  }) async {
    const uuid = Uuid();
    final message = Message(
      id: uuid.v4(),
      role: role,
      content: content,
      timestamp: DateTime.now(),
      titanName: titanName,
      tokensPerSecond: tokensPerSecond,
      latencyMs: latencyMs,
    );

    final sessionIndex = state.indexWhere((s) => s.id == sessionId);
    if (sessionIndex == -1) return;

    final oldSession = state[sessionIndex];
    final newSession = ChatSession(
      id: oldSession.id,
      title: oldSession.title,
      createdAt: oldSession.createdAt,
      updatedAt: DateTime.now(),
      messages: [...oldSession.messages, message],
      activeTitanId: oldSession.activeTitanId,
    );

    await _saveSession(newSession);

    state = [
      newSession,
      ...state.sublist(0, sessionIndex),
      ...state.sublist(sessionIndex + 1),
    ];
  }

  Future<void> deleteSession(String sessionId) async {
    final dir = await getApplicationDocumentsDirectory();
    final sessionFile =
        File('${dir.path}/chat_sessions/$sessionId.json');

    if (await sessionFile.exists()) {
      await sessionFile.delete();
    }

    state = state.where((s) => s.id != sessionId).toList();
  }

  Future<void> updateSessionTitle(String sessionId, String newTitle) async {
    final sessionIndex = state.indexWhere((s) => s.id == sessionId);
    if (sessionIndex == -1) return;

    final oldSession = state[sessionIndex];
    final newSession = ChatSession(
      id: oldSession.id,
      title: newTitle,
      createdAt: oldSession.createdAt,
      updatedAt: DateTime.now(),
      messages: oldSession.messages,
      activeTitanId: oldSession.activeTitanId,
    );

    await _saveSession(newSession);
    state = [
      newSession,
      ...state.sublist(0, sessionIndex),
      ...state.sublist(sessionIndex + 1),
    ];
  }

  Future<void> _saveSession(ChatSession session) async {
    final dir = await getApplicationDocumentsDirectory();
    final sessionsDir = Directory('${dir.path}/chat_sessions');
    if (!await sessionsDir.exists()) {
      await sessionsDir.create(recursive: true);
    }

    final file = File('${sessionsDir.path}/${session.id}.json');
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  ChatSession? getSession(String sessionId) {
    try {
      return state.firstWhere((s) => s.id == sessionId);
    } catch (e) {
      return null;
    }
  }
}

final currentSessionProvider =
    StateProvider<String?>((ref) => null);

final currentTitanProvider =
    StateProvider<int?>((ref) => null);

// ============================================================================
// APP WIDGET
// ============================================================================

class OlimpoAIApp extends ConsumerWidget {
  const OlimpoAIApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'OlimpoAI',
      theme: ThemeData.dark().copyWith(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1F3A),
          elevation: 0,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1A1F3A),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A1F3A),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============================================================================
// HOME SCREEN
// ============================================================================

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSessionId = ref.watch(currentSessionProvider);
    final sessions = ref.watch(chatSessionsProvider);

    if (currentSessionId == null) {
      return const CatalogScreen();
    }

    final session = ref
        .watch(chatSessionsProvider)
        .firstWhere((s) => s.id == currentSessionId, orElse: () {
      ref.read(currentSessionProvider.notifier).state = null;
      return ChatSession(
        id: '',
        title: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      );
    });

    if (session.id.isEmpty) {
      return const CatalogScreen();
    }

    return ChatScreen(session: session);
  }
}

// ============================================================================
// CATALOG SCREEN (10 TITANS)
// ============================================================================

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titans = ref.watch(titansProvider);
    final sessions = ref.watch(chatSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OlimpoAI - Los 10 Titanes'),
        centerTitle: true,
        elevation: 0,
      ),
      drawer: SidebarMenu(sessions: sessions),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Catálogo de Modelos Locales',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: titans.length,
              itemBuilder: (context, index) {
                return TitanCard(titan: titans[index]);
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateChatDialog(context, ref),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add_comment),
      ),
    );
  }

  void _showCreateChatDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        title: const Text('Nueva Sesión de Chat'),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            hintText: 'Nombre de la sesión',
            filled: true,
            fillColor: const Color(0xFF2A2F4A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final session = await ref
                  .read(chatSessionsProvider.notifier)
                  .createSession(titleController.text);
              ref.read(currentSessionProvider.notifier).state = session.id;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TITAN CARD
// ============================================================================

class TitanCard extends ConsumerWidget {
  final Titan titan;

  const TitanCard({
    Key? key,
    required this.titan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showTitanDetails(context, ref),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2A2F4A),
              const Color(0xFF1A1F3A),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: titan.isAssigned
                ? const Color(0xFF6366F1)
                : const Color(0xFF4A4F6A),
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              titan.emoji,
              style: const TextStyle(fontSize: 40),
            ),
            Text(
              titan.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              titan.modelType,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: titan.isAssigned
                    ? const Color(0xFF6366F1)
                    : Colors.red.shade900,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                titan.isAssigned ? '✓ Asignado' : '✗ No asignado',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTitanDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F3A),
      builder: (context) => TitanDetailsBottomSheet(titan: titan),
    );
  }
}

// ============================================================================
// TITAN DETAILS BOTTOM SHEET
// ============================================================================

class TitanDetailsBottomSheet extends ConsumerWidget {
  final Titan titan;

  const TitanDetailsBottomSheet({
    Key? key,
    required this.titan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                titan.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titan.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    titan.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipo de Modelo',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  Text(
                    titan.modelType,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RAM Requerida',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  Text(
                    titan.ramRequired,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Capacidad',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          Text(titan.capability),
          const SizedBox(height: 16),
          if (titan.isAssigned) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📁 Ruta Asignada:'),
                  const SizedBox(height: 4),
                  Text(
                    titan.localPath!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickModelFile(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                    ),
                    child: const Text('Cambiar Ruta'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(titansProvider.notifier)
                        .removeModelPath(titan.id);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                  ),
                  child: const Text('Desasignar'),
                ),
              ],
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => _pickModelFile(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: const Text('Seleccionar Archivo del Modelo'),
            ),
          ],
        ],
      ),
    );
  }

  void _pickModelFile(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gguf', 'bin', 'onnx'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      await ref
          .read(titansProvider.notifier)
          .assignModelPath(titan.id, filePath);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}

// ============================================================================
// SIDEBAR MENU
// ============================================================================

class SidebarMenu extends ConsumerWidget {
  final List<ChatSession> sessions;

  const SidebarMenu({
    Key? key,
    required this.sessions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);

    final filteredSessions = sessions
        .where(
          (s) => s.title.toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF6366F1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'OlimpoAI',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${sessions.length} sesiones',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
              decoration: InputDecoration(
                hintText: 'Buscar chat...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: const Color(0xFF2A2F4A),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredSessions.length,
              itemBuilder: (context, index) {
                final session = filteredSessions[index];
                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(session.title),
                  subtitle: Text(
                    DateFormat('dd/MM/yy HH:mm').format(session.updatedAt),
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                  onTap: () {
                    ref.read(currentSessionProvider.notifier).state = session.id;
                    Navigator.pop(context);
                  },
                  onLongPress: () => _showDeleteDialog(context, ref, session),
                  selected: false,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: const Text('Catálogo'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    ChatSession session,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        title: const Text('Eliminar Sesión'),
        content: Text('¿Eliminar "${session.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(chatSessionsProvider.notifier)
                  .deleteSession(session.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

final searchQueryProvider = StateProvider<String>((ref) => '');

// ============================================================================
// CHAT SCREEN
// ============================================================================

class ChatScreen extends ConsumerStatefulWidget {
  final ChatSession session;

  const ChatScreen({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late TextEditingController _messageController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSession =
        ref.watch(chatSessionsProvider).firstWhere((s) => s.id == widget.session.id);
    final currentTitan = ref.watch(currentTitanProvider);
    final titans = ref.watch(titansProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentSession.title),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: currentTitan != null
                  ? Text(
                      titans
                          .firstWhere((t) => t.id == currentTitan)
                          .emoji,
                      style: const TextStyle(fontSize: 24),
                    )
                  : const Text('Seleccionar Titán'),
            ),
          ),
        ],
      ),
      drawer: SidebarMenu(
        sessions: ref.watch(chatSessionsProvider),
      ),
      body: Column(
        children: [
          Expanded(
            child: currentSession.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Sin mensajes',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Selecciona un Titán y comienza a chatear',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: currentSession.messages.length,
                    itemBuilder: (context, index) {
                      final message = currentSession.messages[index];
                      return MessageBubble(message: message);
                    },
                  ),
          ),
          if (currentTitan != null)
            PerformanceMetrics(
              titanName: titans
                  .firstWhere((t) => t.id == currentTitan)
                  .name,
            ),
          MessageInputBar(
            messageController: _messageController,
            onSend: (message) =>
                _sendMessage(message, currentTitan, ref),
            selectedTitanId: currentTitan,
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(
    String message,
    int? titanId,
    WidgetRef ref,
  ) async {
    if (message.isEmpty || titanId == null) return;

    HapticFeedback.mediumImpact();

    await ref
        .read(chatSessionsProvider.notifier)
        .addMessage(
          widget.session.id,
          'user',
          message,
        );

    _messageController.clear();

    // Simular respuesta del Titán
    await Future.delayed(const Duration(milliseconds: 500));

    final titans = ref.read(titansProvider);
    final titan = titans.firstWhere((t) => t.id == titanId);

    final tokensPerSecond = 45.3 + (titanId % 10);
    final latencyMs = 120.5 + (titanId % 50);

    HapticFeedback.lightImpact();

    await ref
        .read(chatSessionsProvider.notifier)
        .addMessage(
          widget.session.id,
          'titan',
          'Respuesta de ${titan.name} procesada localmente...\n\n'
              '```dart\n'
              '// Código generado por ${titan.name}\n'
              'void main() {\n'
              '  print("OlimpoAI: 100% Offline");\n'
              '}\n'
              '```',
          titanName: titan.name,
          tokensPerSecond: tokensPerSecond,
          latencyMs: latencyMs,
        );

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}

// ============================================================================
// MESSAGE BUBBLE
// ============================================================================

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6366F1) : const Color(0xFF2A2F4A),
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.titanName != null)
              Text(
                message.titanName!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[300],
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 4),
            MarkdownBody(
              data: message.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: isUser ? Colors.white : Colors.grey[200]),
                code: TextStyle(
                  backgroundColor: const Color(0xFF1A1F3A),
                  color: const Color(0xFF6366F1),
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: const Color(0xFF1A1F3A),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (!isUser && message.tokensPerSecond != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '⚡ ${message.tokensPerSecond?.toStringAsFixed(1)} tok/s | ⏱️ ${message.latencyMs?.toStringAsFixed(0)}ms',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[300],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                Share.share(message.content);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Copiar',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PERFORMANCE METRICS
// ============================================================================

class PerformanceMetrics extends StatelessWidget {
  final String titanName;

  const PerformanceMetrics({
    Key? key,
    required this.titanName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2F4A),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF6366F1).withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 14, color: Color(0xFF6366F1)),
              const SizedBox(width: 4),
              Text(
                '100% Local | $titanName',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Sin conexión requerida',
              style: TextStyle(fontSize: 9, color: Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MESSAGE INPUT BAR
// ============================================================================

class MessageInputBar extends ConsumerWidget {
  final TextEditingController messageController;
  final Function(String) onSend;
  final int? selectedTitanId;

  const MessageInputBar({
    Key? key,
    required this.messageController,
    required this.onSend,
    required this.selectedTitanId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titans = ref.watch(titansProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF6366F1).withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedTitanId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2F4A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    titans
                        .firstWhere((t) => t.id == selectedTitanId)
                        .emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chateando con ${titans.firstWhere((t) => t.id == selectedTitanId).name}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownButton<int>(
                    value: selectedTitanId,
                    dropdownColor: const Color(0xFF2A2F4A),
                    underline: const SizedBox(),
                    items: titans
                        .where((t) => t.isAssigned)
                        .map(
                          (titan) => DropdownMenuItem(
                            value: titan.id,
                            child: Text('${titan.emoji} ${titan.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(currentTitanProvider.notifier).state = value;
                      }
                    },
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, size: 16, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selecciona un Titán del catálogo',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    hintText: selectedTitanId != null
                        ? 'Escribe un mensaje...'
                        : 'Selecciona un Titán primero...',
                    filled: true,
                    fillColor: const Color(0xFF2A2F4A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  enabled: selectedTitanId != null,
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                mini: true,
                onPressed: selectedTitanId != null
                    ? () => onSend(messageController.text)
                    : null,
                backgroundColor: selectedTitanId != null
                    ? const Color(0xFF6366F1)
                    : Colors.grey[700],
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
