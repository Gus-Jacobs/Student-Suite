import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'ai_teacher_screen.dart';
import 'flashcard_review_screen.dart';
import 'subject_editor_screen.dart';

// Data model for a search result
class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final SearchResultType type;
  final IconData icon;
  final dynamic object; // The actual Hive object or route string

  SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.icon,
    required this.object,
  });
}

enum SearchResultType {
  note,
  flashcardDeck,
  aiTeacherSession,
  tool,
  subject,
  setting
}

// Static list of all searchable tools and settings
final List<SearchResult> _staticSearchableItems = [
  // Tools
  SearchResult(
      id: '/notes',
      title: 'Notes',
      subtitle: 'Tool',
      type: SearchResultType.tool,
      icon: Icons.note_alt_outlined,
      object: '/notes'),
  SearchResult(
      id: '/flashcards',
      title: 'Flashcards',
      subtitle: 'Tool',
      type: SearchResultType.tool,
      icon: Icons.style_outlined,
      object: '/flashcards'),
  SearchResult(
      id: '/pomodoro',
      title: 'Pomodoro Timer',
      subtitle: 'Tool',
      type: SearchResultType.tool,
      icon: Icons.timer_outlined,
      object: '/pomodoro'),
  SearchResult(
      id: '/ai_teacher',
      title: 'AI Teacher',
      subtitle: 'Pro Tool',
      type: SearchResultType.tool,
      icon: Icons.smart_toy_outlined,
      object: '/ai_teacher'),
  SearchResult(
      id: '/resume',
      title: 'Resume Builder',
      subtitle: 'Pro Tool',
      type: SearchResultType.tool,
      icon: Icons.description_outlined,
      object: '/resume'),
  SearchResult(
      id: '/cover_letter',
      title: 'Cover Letter Generator',
      subtitle: 'Pro Tool',
      type: SearchResultType.tool,
      icon: Icons.edit_note_outlined,
      object: '/cover_letter'),
  SearchResult(
      id: '/interview_tips',
      title: 'Interview Tips',
      subtitle: 'Tool',
      type: SearchResultType.tool,
      icon: Icons.lightbulb_outline,
      object: '/interview_tips'),
  SearchResult(
      id: '/ai_interviewer',
      title: 'AI Interviewer',
      subtitle: 'Pro Tool',
      type: SearchResultType.tool,
      icon: Icons.record_voice_over_outlined,
      object: '/ai_interviewer'),
  SearchResult(
      id: '/subjects',
      title: 'AI Context Subjects',
      subtitle: 'Tool',
      type: SearchResultType.tool,
      icon: Icons.library_books_outlined,
      object: '/subjects'),

  // Settings
  SearchResult(
      id: '/profile',
      title: 'Profile',
      subtitle: 'Settings',
      type: SearchResultType.setting,
      icon: Icons.person_outline,
      object: '/profile'),
  SearchResult(
      id: '/theme_settings',
      title: 'Theme & Colors',
      subtitle: 'Settings',
      type: SearchResultType.setting,
      icon: Icons.palette_outlined,
      object: '/theme_settings'),
  SearchResult(
      id: '/font_settings',
      title: 'Font Settings',
      subtitle: 'Settings',
      type: SearchResultType.setting,
      icon: Icons.font_download_outlined,
      object: '/font_settings'),
  SearchResult(
      id: '/account_settings',
      title: 'Account',
      subtitle: 'Settings',
      type: SearchResultType.setting,
      icon: Icons.verified_user_outlined,
      object: '/account_settings'),
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<SearchResult> _results = [];
  bool _isLoading = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.trim();
      // Debounce search slightly by checking length and if query changed
      if (query.length > 1 && query != _lastQuery) {
        _runSearch(query);
      } else if (query.isEmpty && _lastQuery.isNotEmpty) {
        setState(() {
          _results = [];
          _lastQuery = '';
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
      _lastQuery = query;
    });

    final lowerCaseQuery = query.toLowerCase();
    final List<SearchResult> foundResults = [];
    final authProvider = context.read<AuthProvider>();

    // 1. Search static items (tools and settings)
    foundResults.addAll(_staticSearchableItems.where((item) =>
        item.title.toLowerCase().contains(lowerCaseQuery) ||
        item.subtitle.toLowerCase().contains(lowerCaseQuery)));

    // 2. Search user-generated content from Hive
    // Search Notes
    final notesBox = authProvider.notesBox;
    for (final note in notesBox.values) {
      if (note.content.toLowerCase().contains(lowerCaseQuery)) {
        foundResults.add(SearchResult(
          id: note.id,
          title: 'Note: ${note.content.split('\n').first}',
          subtitle: note.content,
          type: SearchResultType.note,
          icon: Icons.note_alt_outlined,
          object: note,
        ));
      }
    }

    // Search Flashcard Decks
    final decksBox = authProvider.flashcardDecksBox;
    for (final deck in decksBox.values) {
      bool deckAdded = false;
      if (deck.name.toLowerCase().contains(lowerCaseQuery)) {
        foundResults.add(SearchResult(
          id: deck.id,
          title: deck.name,
          subtitle: '${deck.cards.length} cards',
          type: SearchResultType.flashcardDeck,
          icon: Icons.style_outlined,
          object: deck,
        ));
        deckAdded = true;
      }
      // Also search within cards of the deck
      for (final card in deck.cards) {
        if (deckAdded) break; // Don't add the same deck twice
        if (card.question.toLowerCase().contains(lowerCaseQuery) ||
            card.answer.toLowerCase().contains(lowerCaseQuery)) {
          foundResults.add(SearchResult(
            id: deck.id,
            title: deck.name,
            subtitle: 'Found in card: "${card.question}"',
            type: SearchResultType.flashcardDeck,
            icon: Icons.style_outlined,
            object: deck,
          ));
          break; // Move to next deck
        }
      }
    }

    // Search AI Teacher Sessions
    final sessionsBox = authProvider.aiTeacherSessionsBox;
    for (final session in sessionsBox.values) {
      if (session.topic.toLowerCase().contains(lowerCaseQuery)) {
        foundResults.add(SearchResult(
          id: session.id,
          title: session.topic,
          subtitle: 'AI Teacher Session',
          type: SearchResultType.aiTeacherSession,
          icon: Icons.smart_toy_outlined,
          object: session,
        ));
      }
    }

    // Search Subjects
    final subjectsBox = authProvider.subjectsBox;
    for (final subject in subjectsBox.values) {
      if (subject.name.toLowerCase().contains(lowerCaseQuery) ||
          subject.content.toLowerCase().contains(lowerCaseQuery)) {
        foundResults.add(SearchResult(
          id: subject.id,
          title: subject.name,
          subtitle: 'AI Context Subject',
          type: SearchResultType.subject,
          icon: Icons.library_books_outlined,
          object: subject,
        ));
      }
    }

    setState(() {
      _results = foundResults;
      _isLoading = false;
    });
  }

  void _navigateToResult(SearchResult result) {
    switch (result.type) {
      case SearchResultType.note:
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(result.title),
            content: SingleChildScrollView(child: Text(result.subtitle)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              )
            ],
          ),
        );
        break;
      case SearchResultType.flashcardDeck:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FlashcardReviewScreen(deck: result.object),
          ),
        );
        break;
      case SearchResultType.aiTeacherSession:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AITeacherScreen(sessionToResume: result.object),
          ),
        );
        break;
      case SearchResultType.subject:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubjectEditorScreen(subjectId: result.object.id),
          ),
        );
        break;
      case SearchResultType.tool:
      case SearchResultType.setting:
        Navigator.pushNamed(context, result.object as String);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = themeProvider.currentTheme;

    BoxDecoration backgroundDecoration;
    if (currentTheme.imageAssetPath != null) {
      backgroundDecoration = BoxDecoration(
        image: DecorationImage(
          image: AssetImage(currentTheme.imageAssetPath!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
              Colors.black.withAlpha((0.5 * 255).round()), BlendMode.darken),
        ),
      );
    } else {
      backgroundDecoration = BoxDecoration(gradient: currentTheme.gradient);
    }

    return Container(
      decoration: backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                      color: Colors.white.withAlpha((0.2 * 255).round())),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search anything...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _results.isEmpty && _searchController.text.isNotEmpty
                ? Center(
                    child: Text(
                        'No results found for "${_searchController.text}"',
                        style: const TextStyle(color: Colors.white70)),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return Card(
                        color: Colors.white.withAlpha((0.1 * 255).round()),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Icon(result.icon, color: Colors.white70),
                          title: Text(
                            result.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            result.subtitle,
                            style: const TextStyle(color: Colors.white70),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _navigateToResult(result),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
