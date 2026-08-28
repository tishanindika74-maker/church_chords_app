import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:convert';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RhythmOfGraceApp());
}

class RhythmOfGraceApp extends StatefulWidget {
  const RhythmOfGraceApp({super.key});

  @override
  State<RhythmOfGraceApp> createState() => _RhythmOfGraceAppState();
}

class _RhythmOfGraceAppState extends State<RhythmOfGraceApp> {
  bool _isDarkMode = false;
  bool _isSinhala = true;
  double _globalFontSize = 20.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      _isSinhala = prefs.getBool('is_sinhala') ?? true;
      _globalFontSize = prefs.getDouble('font_size') ?? 20.0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
    await prefs.setBool('is_sinhala', _isSinhala);
    await prefs.setDouble('font_size', _globalFontSize);
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    _saveSettings();
  }

  void _toggleLanguage(bool value) {
    setState(() {
      _isSinhala = value;
    });
    _saveSettings();
  }

  void _updateFontSize(double newSize) {
    setState(() {
      _globalFontSize = newSize;
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rhythm of Grace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(
        toggleTheme: _toggleTheme,
        isDarkMode: _isDarkMode,
        isSinhala: _isSinhala,
        toggleLanguage: _toggleLanguage,
        fontSize: _globalFontSize,
        onFontSizeChanged: _updateFontSize,
      ),
    );
  }
}

class Song {
  String id;
  String title;
  String singlishTitle;
  String fileName;
  String lyrics;

  Song({
    required this.id,
    required this.title,
    required this.singlishTitle,
    required this.fileName,
    required this.lyrics,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'singlishTitle': singlishTitle,
        'fileName': fileName,
        'lyrics': lyrics,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] ?? '',
        singlishTitle: json['singlishTitle'] ?? '',
        fileName: json['fileName'] ?? 'පොදු ෆයිල් එක',
        lyrics: json['lyrics'] ?? '',
      );
}

class SettingsScreen extends StatelessWidget {
  final double fontSize;
  final Function(double) onFontSizeChanged;
  final bool isSinhala;
  final Function(bool) toggleLanguage;

  const SettingsScreen({
    super.key,
    required this.fontSize,
    required this.onFontSizeChanged,
    required this.isSinhala,
    required this.toggleLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isSinhala ? 'සැකසුම්' : 'Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: Text(isSinhala ? 'සිංහල භාෂාව' : 'Sinhala Language'),
            value: isSinhala,
            onChanged: toggleLanguage,
          ),
          const Divider(),
          ListTile(
            title: Text(isSinhala ? 'අකුරු ප්‍රමාණය (Font Size)' : 'Font Size'),
            subtitle: Slider(
              min: 14.0,
              max: 32.0,
              divisions: 9,
              value: fontSize,
              label: fontSize.round().toString(),
              onChanged: onFontSizeChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  final bool isSinhala;
  final Function(bool) toggleLanguage;
  final double fontSize;
  final Function(double) onFontSizeChanged;

  const HomeScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.isSinhala,
    required this.toggleLanguage,
    required this.fontSize,
    required this.onFontSizeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedFile = 'All';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? songsString = prefs.getString('saved_songs');
    if (songsString != null) {
      final List decoded = jsonDecode(songsString);
      setState(() {
        _songs = decoded.map((item) => Song.fromJson(item)).toList();
        _filterSongs();
      });
    } else {
      setState(() {
        _songs = [
          Song(
            id: '1',
            title: "ස්තුතිය පූජා වේවා",
            singlishTitle: "sthuthi puja wewa",
            fileName: "ප්‍රශංසා ගීතිකා",
            lyrics: "[C]ස්තුතිය පූජා [G]වේවා\n[Am]දෙවියන් වහන්සේට [F]වේවා",
          )
        ];
        _filterSongs();
      });
    }
  }

  Future<void> _saveSongsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'saved_songs', jsonEncode(_songs.map((e) => e.toJson()).toList()));
  }

  void _filterSongs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSongs = _songs.where((song) {
        bool matchesSearch = song.title.toLowerCase().contains(query) ||
            song.singlishTitle.toLowerCase().contains(query);
        bool matchesFile =
            _selectedFile == 'All' || song.fileName == _selectedFile;
        return matchesSearch && matchesFile;
      }).toList();
    });
  }

  List<String> get _availableFiles {
    Set<String> files = _songs.map((s) => s.fileName).toSet();
    return files.toList();
  }

  void _navigateToAddSong() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AddEditSongScreen(existingFiles: _availableFiles)),
    );
    if (result != null && result is Song) {
      setState(() {
        _songs.add(result);
      });
      await _saveSongsToPrefs();
      _filterSongs();
    }
  }

  void _deleteSong(String id) async {
    setState(() {
      _songs.removeWhere((song) => song.id == id);
      _filterSongs();
    });
    await _saveSongsToPrefs();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.isSinhala ? 'ගීතිකාව ඉවත් කරන ලදී' : 'Song deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool si = widget.isSinhala;
    List<String> files = _availableFiles;

    return Scaffold(
      appBar: AppBar(
        title: Text(si ? 'Rhythm of Grace ගීතිකා පුස්තකාලය' : 'Rhythm of Grace Library'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    fontSize: widget.fontSize,
                    onFontSizeChanged: widget.onFontSizeChanged,
                    isSinhala: widget.isSinhala,
                    toggleLanguage: widget.toggleLanguage,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _filterSongs(),
              decoration: InputDecoration(
                hintText: si ? 'ගීතිකාව සොයන්න (සිංහල / Singlish)...' : 'Search song...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
              ),
            ),
          ),
          if (files.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(si ? 'සියලුම ගීතිකා' : 'All Files'),
                      selected: _selectedFile == 'All',
                      onSelected: (selected) {
                        setState(() {
                          _selectedFile = 'All';
                          _filterSongs();
                        });
                      },
                    ),
                  ),
                  ...files.map((file) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(file),
                          selected: _selectedFile == file,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFile = file;
                              _filterSongs();
                            });
                          },
                        ),
                      )),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _filteredSongs.isEmpty
                ? Center(child: Text(si ? 'ගීතිකා හමු නොවීය' : 'No songs found'))
                : ListView.builder(
                    itemCount: _filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = _filteredSongs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(song.title,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('📁 ${song.fileName} • ${song.singlishTitle}',
                              style: TextStyle(color: Colors.grey[600])),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _deleteSong(song.id),
                                tooltip: si ? 'මකන්න' : 'Delete',
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                          onTap: () async {
                            final updatedSong = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SongDetailScreen(
                                  song: song,
                                  fontSize: widget.fontSize,
                                  isSinhala: si,
                                  existingFiles: files,
                                ),
                              ),
                            );
                            if (updatedSong != null && updatedSong is Song) {
                              setState(() {
                                int idx = _songs.indexWhere((s) => s.id == updatedSong.id);
                                if (idx != -1) {
                                  _songs[idx] = updatedSong;
                                }
                              });
                              await _saveSongsToPrefs();
                              _filterSongs();
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddSong,
        icon: const Icon(Icons.add),
        label: Text(si ? 'ගීතිකාවක් එකතු කරන්න' : 'Add Song'),
      ),
    );
  }
}

class AddEditSongScreen extends StatefulWidget {
  final Song? songToEdit;
  final List<String> existingFiles;

  const AddEditSongScreen({super.key, this.songToEdit, required this.existingFiles});

  @override
  State<AddEditSongScreen> createState() => _AddEditSongScreenState();
}

class _AddEditSongScreenState extends State<AddEditSongScreen> {
  late TextEditingController _titleController;
  late TextEditingController _singlishController;
  late TextEditingController _lyricsController;
  late TextEditingController _fileController;
  bool _isNewFileSelected = false;
  String _selectedExistingFile = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.songToEdit?.title ?? '');
    _singlishController = TextEditingController(text: widget.songToEdit?.singlishTitle ?? '');
    _lyricsController = TextEditingController(text: widget.songToEdit?.lyrics ?? '');
    
    String initialFile = widget.songToEdit?.fileName ?? (widget.existingFiles.isNotEmpty ? widget.existingFiles[0] : 'පොදු ෆයිල් එක');
    _selectedExistingFile = initialFile;
    _fileController = TextEditingController(text: initialFile);
  }

  void _save() {
    if (_titleController.text.isEmpty || _lyricsController.text.isEmpty) return;

    String finalFile = _isNewFileSelected ? _fileController.text.trim() : _selectedExistingFile;
    if (finalFile.isEmpty) finalFile = 'පොදු ෆයිල් එක';

    Song song = Song(
      id: widget.songToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      singlishTitle: _singlishController.text.trim(),
      fileName: finalFile,
      lyrics: _lyricsController.text,
    );

    Navigator.pop(context, song);
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.songToEdit != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'ගීතිකාව වෙනස් කරන්න' : 'නව ගීතිකාවක් එක් කරන්න')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'ගීතිකාවේ නම (සිංහල / English)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _singlishController,
              decoration: const InputDecoration(labelText: 'Singlish නම (උදා: sthuthi puja wewa)'),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _isNewFileSelected
                      ? TextField(
                          controller: _fileController,
                          decoration: const InputDecoration(labelText: 'අලුත් ෆයිල් නම (New File Name)'),
                        )
                      : DropdownButtonFormField<String>(
                          value: widget.existingFiles.contains(_selectedExistingFile) ? _selectedExistingFile : null,
                          decoration: const InputDecoration(labelText: 'ෆයිල් එකක් තෝරන්න (Select File)'),
                          items: widget.existingFiles
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedExistingFile = val ?? ''),
                        ),
                ),
                IconButton(
                  icon: Icon(_isNewFileSelected ? Icons.list : Icons.create_new_folder, color: Colors.blue),
                  onPressed: () {
                    setState(() {
                      _isNewFileSelected = !_isNewFileSelected;
                    });
                  },
                  tooltip: 'අලුත් ෆයිල් එකක් සාදන්න / ලැයිස්තුවෙන් තෝරන්න',
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _lyricsController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Lyrics සහ Chords (උදා: [C]ස්තුතිය [G]වේවා)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
              child: Text(isEditing ? 'යාවත්කාලීන කරන්න' : 'සුරකින්න', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class SongDetailScreen extends StatefulWidget {
  final Song song;
  final double fontSize;
  final bool isSinhala;
  final List<String> existingFiles;

  const SongDetailScreen({
    super.key,
    required this.song,
    required this.fontSize,
    required this.isSinhala,
    required this.existingFiles,
  });

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  late Song _currentSong;
  int _transposeStep = 0;
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _isAutoScrolling = false;
  double _scrollSpeed = 1.0;

  final List<String> _notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  @override
  void initState() {
    super.initState();
    _currentSong = widget.song;
  }

  String _transposeChord(String chord, int step) {
    if (step == 0) return chord;
    RegExp regExp = RegExp(r'([A-G][#b]?)');
    return chord.replaceAllMapped(regExp, (match) {
      String note = match.group(0)!;
      int index = _notes.indexOf(note);
      if (index == -1) return note;
      int newIndex = (index + step) % _notes.length;
      if (newIndex < 0) newIndex += _notes.length;
      return _notes[newIndex];
    });
  }

  String _processLyrics(String lyrics, int step) {
    if (step == 0) return lyrics;
    return lyrics.replaceAllMapped(RegExp(r'\[(.*?)\]'), (match) {
      String chord = match.group(1)!;
      return '[${_transposeChord(chord, step)}]';
    });
  }

  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _autoScrollTimer?.cancel();
      setState(() => _isAutoScrolling = false);
    } else {
      setState(() => _isAutoScrolling = true);
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (_scrollController.hasClients) {
          double maxScroll = _scrollController.position.maxScrollExtent;
          double currentScroll = _scrollController.offset;
          if (currentScroll >= maxScroll) {
            _toggleAutoScroll();
          } else {
            _scrollController.jumpTo(currentScroll + _scrollSpeed);
          }
        }
      });
    }
  }

  void _editSong() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditSongScreen(
          songToEdit: _currentSong,
          existingFiles: widget.existingFiles,
        ),
      ),
    );
    if (result != null && result is Song) {
      setState(() {
        _currentSong = result;
      });
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String processedLyrics = _processLyrics(_currentSong.lyrics, _transposeStep);
    bool si = widget.isSinhala;
  }
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, _currentSong);
      },
      child: Scaffold(
        // ඉතුරු කෝඩ් එක මේ විදිහටම තියෙන්න දෙන්න...
        appBar: AppBar(
          title: Text(_currentSong.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editSong,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(si ? 'Transpose: ' : 'Transpose: '),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => setState(() => _transposeStep--),
                  ),
                  Text('$_transposeStep', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => _transposeStep++),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Text(
                    processedLyrics,
                    style: TextStyle(fontSize: widget.fontSize),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleAutoScroll,
          child: Icon(_isAutoScrolling ? Icons.pause : Icons.play_arrow),
        ),
      ),
    );
  }
}
