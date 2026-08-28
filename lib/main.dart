import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:convert';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChurchChordsApp());
}

class ChurchChordsApp extends StatefulWidget {
  const ChurchChordsApp({super.key});

  @override
  State<ChurchChordsApp> createState() => _ChurchChordsAppState();
}

class _ChurchChordsAppState extends State<ChurchChordsApp> {
  bool _isDarkMode = false;
  bool _isSinhala = true;
  double _globalFontSize = 20.0;
  List<String> _categories = ['ප්‍රශංසා', 'නමස්කාර', 'පන්ති ගීතිකා', 'විශේෂ'];

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
      final savedCats = prefs.getStringList('saved_categories');
      if (savedCats != null && savedCats.isNotEmpty) {
        _categories = savedCats;
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
    await prefs.setBool('is_sinhala', _isSinhala);
    await prefs.setDouble('font_size', _globalFontSize);
    await prefs.setStringList('saved_categories', _categories);
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

  void _updateCategories(List<String> newCategories) {
    setState(() {
      _categories = newCategories;
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Church Chords',
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
        categories: _categories,
        onCategoriesChanged: _updateCategories,
      ),
    );
  }
}

class Song {
  String title;
  String singlishTitle;
  String category;
  String lyrics;

  Song({
    required this.title,
    required this.singlishTitle,
    required this.category,
    required this.lyrics,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'singlishTitle': singlishTitle,
        'category': category,
        'lyrics': lyrics,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        title: json['title'] ?? '',
        singlishTitle: json['singlishTitle'] ?? '',
        category: json['category'] ?? 'සාමාන්‍ය',
        lyrics: json['lyrics'] ?? '',
      );
}

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  final bool isSinhala;
  final Function(bool) toggleLanguage;
  final double fontSize;
  final Function(double) onFontSizeChanged;
  final List<String> categories;
  final Function(List<String>) onCategoriesChanged;

  const HomeScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.isSinhala,
    required this.toggleLanguage,
    required this.fontSize,
    required this.onFontSizeChanged,
    required this.categories,
    required this.onCategoriesChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _loadSongs();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories != oldWidget.categories) {
      if (_selectedCategory != 'All' && !widget.categories.contains(_selectedCategory)) {
        _selectedCategory = 'All';
      }
      _filterSongs();
    }
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
            title: "ස්තුතිය පූජා වේවා",
            singlishTitle: "sthuthi puja wewa",
            category: widget.categories.isNotEmpty ? widget.categories[0] : 'ප්‍රශංසා',
            lyrics: "[C]ස්තුතිය පූජා [G]වේවා\n[Am]දෙවියන් වහන්සේට [F]වේවා",
          )
        ];
        _filterSongs();
      });
    }
  }

  void _filterSongs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSongs = _songs.where((song) {
        bool matchesSearch = song.title.toLowerCase().contains(query) ||
            song.singlishTitle.toLowerCase().contains(query);
        bool matchesCategory =
            _selectedCategory == 'All' || song.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _navigateToAddSong() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddSongScreen(categories: widget.categories)),
    );
    if (result == true) {
      _loadSongs();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool si = widget.isSinhala;
    return Scaffold(
      appBar: AppBar(
        title: Text(si ? 'පල්ලියේ ගීතිකා පුස්තකාලය' : 'Church Chords Library'),
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
                    categories: widget.categories,
                    onCategoriesChanged: widget.onCategoriesChanged,
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
                hintText: si ? 'ගීතිකාව සොයන්න (සිංහල / Singlish)...' : 'Search song (Sinhala / Singlish)...',
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
                    selected: _selectedCategory == 'All',
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = 'All';
                        _filterSongs();
                      });
                    },
                  ),
                ),
                ...widget.categories.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = cat;
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
                          subtitle: Text('${song.category} • ${song.singlishTitle}',
                              style: TextStyle(color: Colors.grey[600])),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SongDetailScreen(
                                    song: song, fontSize: widget.fontSize, isSinhala: si),
                              ),
                            );
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

class AddSongScreen extends StatefulWidget {
  final List<String> categories;
  const AddSongScreen({super.key, required this.categories});

  @override
  State<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final _titleController = TextEditingController();
  final _singlishController = TextEditingController();
  final _lyricsController = TextEditingController();
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categories.isNotEmpty ? widget.categories[0] : 'ප්‍රශංසා';
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

    songs.add(Song(
      title: _titleController.text,
      singlishTitle: _singlishController.text,
      category: _selectedCategory,
      lyrics: _lyricsController.text,
    ));

    await prefs.setString(
        'saved_songs', jsonEncode(songs.map((e) => e.toJson()).toList()));

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('නව ගීතිකාවක් එක් කරන්න')),
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
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'ගීතිකා කාණ්ඩය (Category)'),
              items: widget.categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
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
              child: const Text('සුරකින්න (Save)', style: TextStyle(fontSize: 16)),
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
  const SongDetailScreen({super.key, required this.song, required this.fontSize, required this.isSinhala});

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  int _transposeStep = 0;
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _isAutoScrolling = false;
  double _scrollSpeed = 1.0;

  final List<String> _notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

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

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String processedLyrics = _processLyrics(widget.song.lyrics, _transposeStep);
    bool si = widget.isSinhala;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title),
        actions: [
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
                  label: Text(_isAutoScrolling ? (si ? 'නවතන්න' : 'Stop') : (si ? 'Auto Scroll' : 'Auto Scroll')),
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
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final double fontSize;
  final Function(double) onFontSizeChanged;
  final bool isSinhala;
  final Function(bool) toggleLanguage;
  final List<String> categories;
  final Function(List<String>) onCategoriesChanged;

  const SettingsScreen({
    super.key,
    required this.fontSize,
    required this.onFontSizeChanged,
    required this.isSinhala,
    required this.toggleLanguage,
    required this.categories,
    required this.onCategoriesChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<String> _editableCategories;

  @override
  void initState() {
    super.initState();
    _editableCategories = List.from(widget.categories);
  }

  void _addCategoryDialog() {
    TextEditingController catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isSinhala ? 'අලුත් කැටගරියක් එක් කරන්න' : 'Add New Category'),
        content: TextField(
          controller: catController,
          decoration: InputDecoration(hintText: widget.isSinhala ? 'කැටගරි නම (Category Name)' : 'Category Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isSinhala ? 'අවලංගු කරන්න'
