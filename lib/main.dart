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
  String folderName;
  String lyrics;
  bool isDeleted;

  Song({
    required this.id,
    required this.title,
    required this.singlishTitle,
    required this.folderName,
    required this.lyrics,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'singlishTitle': singlishTitle,
        'folderName': folderName,
        'lyrics': lyrics,
        'isDeleted': isDeleted,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] ?? DateTime.now().toIso8601String(),
        title: json['title'] ?? '',
        singlishTitle: json['singlishTitle'] ?? '',
        folderName: json['folderName'] ?? 'සාමාන්‍ය',
        lyrics: json['lyrics'] ?? '',
        isDeleted: json['isDeleted'] ?? false,
      );
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
  String _selectedFolder = 'All';

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
            folderName: "ප්‍රශංසා ගීතිකා",
            lyrics: "[C]ස්තුතිය පූජා [G]වේවා\n[Am]දෙවියන් වහන්සේට [F]වේවා",
          )
        ];
        _filterSongs();
      });
      _saveSongsToPrefs();
    }
  }

  Future<void> _saveSongsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'saved_songs', jsonEncode(_songs.map((e) => e.toJson()).toList()));
  }

  List<String> get _availableFolders {
    Set<String> folders = _songs
        .where((song) => !song.isDeleted)
        .map((song) => song.folderName)
        .toSet();
    return folders.toList();
  }

  void _filterSongs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSongs = _songs.where((song) {
        if (song.isDeleted) return false;
        bool matchesSearch = song.title.toLowerCase().contains(query) ||
            song.singlishTitle.toLowerCase().contains(query) ||
            song.folderName.toLowerCase().contains(query);
        bool matchesFolder =
            _selectedFolder == 'All' || song.folderName == _selectedFolder;
        return matchesSearch && matchesFolder;
      }).toList();
    });
  }

  void _navigateToAddSong() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditSongScreen(existingFolders: _availableFolders),
      ),
    );
    if (result == true) {
      _loadSongs();
    }
  }

  void _moveToRecycleBin(Song song) {
    setState(() {
      song.isDeleted = true;
      _filterSongs();
    });
    _saveSongsToPrefs();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isSinhala ? 'ගීතිකාව ඉවත් කරන ලදී (Recycle Bin වෙත)' : 'Song moved to Recycle Bin'),
        action: SnackBarAction(
          label: widget.isSinhala ? 'අස්ථානගත කිරීම අවලංගු කරන්න' : 'Undo',
          onPressed: () {
            setState(() {
              song.isDeleted = false;
              _filterSongs();
            });
            _saveSongsToPrefs();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool si = widget.isSinhala;
    List<String> folders = _availableFolders;

    return Scaffold(
      appBar: AppBar(
        title: Text(si ? 'Rhythm of Grace පුස්තකාලය' : 'Rhythm of Grace Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: si ? 'රිසයිකල් බින්' : 'Recycle Bin',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecycleBinScreen(
                    songs: _songs,
                    onRestore: (song) {
                      setState(() {
                        song.isDeleted = false;
                        _filterSongs();
                      });
                      _saveSongsToPrefs();
                    },
                    onDeletePermanent: (song) {
                      setState(() {
                        _songs.removeWhere((s) => s.id == song.id);
                        _filterSongs();
                      });
                      _saveSongsToPrefs();
                    },
                    isSinhala: si,
                  ),
                ),
              );
              _loadSongs();
            },
          ),
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
                hintText: si ? 'ගීතිකාව හෝ ෆයිල් නම සොයන්න...' : 'Search song or folder...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(si ? 'සියල්ල' : 'All'),
                    selected: _selectedFolder == 'All',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFolder = 'All';
                        _filterSongs();
                      });
                    },
                  ),
                ),
                ...folders.map((folder) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(folder),
                        selected: _selectedFolder == folder,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFolder = folder;
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
                          subtitle: Text('📁 ${song.folderName} • ${song.singlishTitle}',
                              style: TextStyle(color: Colors.grey[600])),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _moveToRecycleBin(song),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                          onTap: () async {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SongDetailScreen(
                                  song: song,
                                  fontSize: widget.fontSize,
                                  isSinhala: si,
                                  existingFolders: _availableFolders,
                                ),
                              ),
                            );
                            if (updated == true) {
                              _loadSongs();
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
  final List<String> existingFolders;

  const AddEditSongScreen({super.key, this.songToEdit, required this.existingFolders});

  @override
  State<AddEditSongScreen> createState() => _AddEditSongScreenState();
}

class _AddEditSongScreenState extends State<AddEditSongScreen> {
  final _titleController = TextEditingController();
  final _singlishController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _folderController = TextEditingController();
  String _selectedFolder = '';

  @override
  void initState() {
    super.initState();
    if (widget.songToEdit != null) {
      _titleController.text = widget.songToEdit!.title;
      _singlishController.text = widget.songToEdit!.singlishTitle;
      _lyricsController.text = widget.songToEdit!.lyrics;
      _selectedFolder = widget.songToEdit!.folderName;
      _folderController.text = _selectedFolder;
    } else {
      _selectedFolder = widget.existingFolders.isNotEmpty ? widget.existingFolders[0] : 'ප්‍රශංසා';
      _folderController.text = _selectedFolder;
    }
  }

  Future<void> _saveSong() async {
    if (_titleController.text.isEmpty || _lyricsController.text.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final String? songsString = prefs.getString('saved_songs');
    List<Song> songs = [];

    if (songsString != null) {
      List decoded = jsonDecode(songsString);
      songs = decoded.map((item) => Song.fromJson(item)).toList();
    }

    String folder = _folderController.text.trim().isEmpty
        ? 'සාමාන්‍ය'
        : _folderController.text.trim();

    if (widget.songToEdit != null) {
      final index = songs.indexWhere((s) => s.id == widget.songToEdit!.id);
      if (index != -1) {
        songs[index].title = _titleController.text;
        songs[index].singlishTitle = _singlishController.text;
        songs[index].folderName = folder;
        songs[index].lyrics = _lyricsController.text;
      }
    } else {
      songs.add(Song(
        id: DateTime.now().toIso8601String(),
        title: _titleController.text,
        singlishTitle: _singlishController.text,
        folderName: folder,
        lyrics: _lyricsController.text,
      ));
    }

    await prefs.setString(
        'saved_songs', jsonEncode(songs.map((e) => e.toJson()).toList()));

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.songToEdit != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'ගීතිකාව වෙනස් කරන්න (Edit Song)' : 'නව ගීතිකාවක් එක් කරන්න')),
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
            const SizedBox(height: 10),
            TextField(
              controller: _folderController,
              decoration: const InputDecoration(
                labelText: 'ෆයිල් නම / කාණ්ඩය (Folder / File Name)',
                helperText: 'ඔබට අවශ්‍ය නව ෆයිල් නමක් ටයිප් කරන්න පුළුවන්',
              ),
            ),
            const SizedBox(height: 10),
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
              onPressed: _saveSong,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
              child: Text(isEditing ? 'යාවත්කාලීන කරන්න (Update)' : 'සුරකින්න (Save)', style: const TextStyle(fontSize: 16)),
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
  final List<String> existingFolders;

  const SongDetailScreen({
    super.key,
    required this.song,
    required this.fontSize,
    required this.isSinhala,
    required this.existingFolders,
  });

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  int _transposeStep = 0;
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _isAutoScrolling = false;
  double _scrollSpeed = 1.0;
  late Song _currentSong;

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

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditSongScreen(
          songToEdit: _currentSong,
          existingFolders: widget.existingFolders,
        ),
      ),
    );
    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      final String? songsString = prefs.getString('saved_songs');
      if (songsString != null) {
        List decoded = jsonDecode(songsString);
        List<Song> allSongs = decoded.map((item) => Song.fromJson(item)).toList();
        setState(() {
          _currentSong = allSongs.firstWhere((s) => s.id == _currentSong.id, orElse: () => _currentSong);
        });
      }
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

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentSong.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: si ? 'ගීතිකාව වෙනස් කරන්න' : 'Edit Song',
              onPressed: _navigateToEdit,
            ),
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () => setState(() => _transposeStep--),
              tooltip: 'Transpose Down',
            ),
            Center(child: Text('$_transposeStep', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => _transposeStep++),
              tooltip: 'Transpose Up',
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.blue.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleAutoScroll,
                    icon: Icon(_isAutoScrolling ? Icons.pause : Icons.play_arrow),
                    label: Text(_isAutoScrolling ? (si ? 'නවතන්න' : 'Stop') : 'Auto Scroll'),
                  ),
                  Row(
                    children: [
                      Text(si ? 'වේගය: ' : 'Speed: '),
                      Slider(
                        value: _scrollSpeed,
                        min: 0.5,
                        max: 3.0,
                        divisions: 5,
                        label: _scrollSpeed.toString(),
                        onChanged: (val) => setState(() => _scrollSpeed = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  processedLyrics,
                  style: TextStyle(fontSize: widget.fontSize, height: 1.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecycleBinScreen extends StatefulWidget {
  final List<Song> songs;
  final Function(Song) onRestore;
  final Function(Song) onDeletePermanent;
  final bool isSinhala;

  const RecycleBinScreen({
    super.key,
    required this.songs,
    required this.onRestore,
    required this.onDeletePermanent,
    required this.isSinhala,
  });

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  @override
  Widget build(BuildContext context) {
    bool si = widget.isSinhala;
    List<Song> deletedSongs = widget.songs.where((s) => s.isDeleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(si ? 'රිසයිකල් බින් (Recycle Bin)' : 'Recycle Bin'),
      ),
      body: deletedSongs.isEmpty
          ? Center(
              child: Text(si ? 'රිසයිකල් බින් එක හිස්ය' : 'Recycle Bin is empty'),
            )
          : ListView.builder(
              itemCount: deletedSongs.length,
              itemBuilder: (context, index) {
                final song = deletedSongs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(song.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(song.singlishTitle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.restore, color: Colors.green), // මෙහි තිබූ වැරදි code: null ඉවත් කරන ලදී
                          tooltip: si ? 'යථා තත්ත්වයට පත් කරන්න' : 'Restore',
                          onPressed: () {
                            widget.onRestore(song);
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          tooltip: si ? 'සම්පූර්ණයෙන්ම ඉවත් කරන්න' : 'Delete Forever',
                          onPressed: () {
                            widget.onDeletePermanent(song);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
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
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    bool si = widget.isSinhala;
    return Scaffold(
      appBar: AppBar(title: Text(si ? 'සැකසුම්' : 'Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: Text(si ? 'සිංහල භාෂාව (Sinhala)' : 'Sinhala Language'),
            subtitle: Text(si ? 'ඇප් එකේ භාෂාව සිංහල/ඉංග්‍රීසි මාරු කරන්න' : 'Toggle app language between Sinhala and English'),
            value: widget.isSinhala,
            onChanged: widget.toggleLanguage,
          ),
          const Divider(),
          ListTile(
            title: Text(si ? 'අකුරු ප්‍රමාණය (Font Size)' : 'Font Size'),
            subtitle: Slider(
              value: widget.fontSize,
              min: 14.0,
              max: 36.0,
              divisions: 11,
              label: widget.fontSize.round().toString(),
              onChanged: widget.onFontSizeChanged,
            ),
          ),
        ],
      ),
    );
  }
}
