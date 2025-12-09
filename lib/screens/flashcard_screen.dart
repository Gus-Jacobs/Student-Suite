import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/models/flashcard.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/mixins/tutorial_support_mixin.dart';
import 'package:student_suite/models/subject.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import '../models/flashcard_deck.dart';
import 'package:uuid/uuid.dart';
import 'flashcard_editor_screen.dart';
import '../models/tutorial_step.dart';
import 'flashcard_review_screen.dart';
import '../providers/theme_provider.dart';
import '../services/ai_service.dart';
import '../widgets/upgrade_dialog.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with TutorialSupport<FlashcardScreen> {
  final AiService _aiService = AiService();
  final TextEditingController _deckNameController = TextEditingController();
  bool _isAiLoading = false;

  @override
  String get tutorialKey => 'flashcards';

  @override
  List<TutorialStep> get tutorialSteps => const [
        TutorialStep(
            icon: Icons.add_circle_outline,
            title: 'Create a Deck',
            description:
                "Tap the '+' button to create a new deck for a subject."),
        TutorialStep(
            icon: Icons.auto_awesome_outlined,
            title: 'Generate with AI (Pro)',
            description:
                "Use the magic wand to automatically create a full deck of flashcards on any topic."),
        TutorialStep(
            icon: Icons.menu_book_outlined,
            title: 'Study Your Decks',
            description:
                'Tap on a deck to start a review session. You can also edit the cards inside.'),
      ];

  @override
  void dispose() {
    _deckNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _addDeck(String name) async {
    if (name.isEmpty) return;
    final box = context.read<AuthProvider>().flashcardDecksBox;
    // Check for duplicate names
    if (box.values.any((deck) => deck.name == name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('A deck with the name "$name" already exists.')),
        );
      }
      return;
    }
    final newDeck = FlashcardDeck(
      id: const Uuid().v4(),
      name: name,
      cards: [],
    );
    await box.put(newDeck.id, newDeck);
  }

  void _showAddDeckDialog() {
    _deckNameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Deck'),
        content: TextField(
          controller: _deckNameController,
          decoration: const InputDecoration(labelText: 'Deck Name'),
          autofocus: true,
          onSubmitted: (_) {
            _addDeck(_deckNameController.text.trim());
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _addDeck(_deckNameController.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAiGenerateDialog() {
    final subscription =
        Provider.of<SubscriptionProvider>(context, listen: false);
    if (!subscription.isPro) {
      showUpgradeDialog(context);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _AiGenerateDialog(
        onGenerate: (topic, count, subjectContext) {
          _runAiGeneration(topic, count, subjectContext);
        },
      ),
    );
  }

  // Future<void> _runAiGeneration(
  //     String topic, int count, String? subjectContext) async {
  //   setState(() => _isAiLoading = true);

  //   // Capture values that need BuildContext before any awaits.
  //   final authProvider = context.read<AuthProvider>();
  //   final messenger = ScaffoldMessenger.of(context);

  //   try {
  //     final cardsData = await _aiService.generateFlashcards(
  //         topic: topic, count: count, subjectContext: subjectContext);
  //     final newCards = cardsData
  //         .map((c) => Flashcard(question: c['question']!, answer: c['answer']!))
  //         .toList();

  //     // Use the captured provider/box to create and update the deck.
  //     await _addDeck(topic); // Creates a new deck with the topic name
  //     final deck = authProvider.flashcardDecksBox.values
  //         .firstWhere((d) => d.name == topic);
  //     deck.cards.addAll(newCards);
  //     await deck.save();
  //   } catch (e) {
  //     if (mounted) {
  //       // Use captured messenger to show errors safely.
  //       messenger.showSnackBar(
  //         SnackBar(content: Text('Failed to generate flashcards: $e')),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isAiLoading = false);
  //     }
  //   }
  // }

  // PASTE THIS INTO YOUR flashcard_screen.dart

  // PASTE THIS INTO YOUR flashcard_screen.dart

  Future<void> _runAiGeneration(
      String topic, int count, String? subjectContext) async {
    setState(() => _isAiLoading = true);

    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final deckBox = authProvider.flashcardDecksBox;

    // 1. Get the Flashcards box
    final flashcardBox = authProvider.flashcardsBox;

    try {
      // 2. This part is correct and was working
      final cardsData = await _aiService.generateFlashcards(
          topic: topic, count: count, subjectContext: subjectContext);

      final newCards = cardsData
          .map((c) => Flashcard(question: c['question']!, answer: c['answer']!))
          .toList();

      if (newCards.isEmpty) {
        throw Exception("AI returned 0 cards. Please try a different topic.");
      }

      // --- THIS IS THE HIVE FIX ---

      // 3. Save the new Flashcard objects to THEIR OWN box first.
      //    (This is required now that Flashcard extends HiveObject)
      await flashcardBox.addAll(newCards);

      // 4. Now, find or create the deck
      final existingDeck = deckBox.values.where((d) => d.name == topic);

      if (existingDeck.isNotEmpty) {
        // Deck already exists. Find it and add the new cards.
        final deck = existingDeck.first;
        deck.cards.addAll(newCards);
        await deck.save(); // Now this .save() will work

        messenger.showSnackBar(
          SnackBar(
              content:
                  Text('Added ${newCards.length} cards to "$topic" deck!')),
        );
      } else {
        // Deck is new. Create it WITH the "managed" cards.
        final newDeck = FlashcardDeck(
          id: const Uuid().v4(),
          name: topic,
          cards: newCards,
        );
        // Save the new, complete deck to the deckBox.
        await deckBox.put(newDeck.id, newDeck);

        messenger.showSnackBar(
          SnackBar(
              content: Text(
                  'Successfully created "$topic" deck with ${newCards.length} cards!')),
        );
      }
      // --- END OF FIX ---
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('Failed to generate flashcards: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAiLoading = false);
      }
    }
  }

  void _showDeleteConfirmDialog(FlashcardDeck deck) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Deck?'),
        content: Text(
            'Are you sure you want to delete the "${deck.name}" deck and all its cards? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              deck.delete();
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
          colorFilter: const ColorFilter.mode(
            Color.fromRGBO(0, 0, 0, 0.5),
            BlendMode.darken,
          ),
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
          title: const Text('Flashcard Decks'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (_isAiLoading)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white))),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Help',
                onPressed: showTutorialDialog,
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome_outlined),
                onPressed: _showAiGenerateDialog,
                tooltip: 'Generate Deck with AI (Pro)',
              ),
            ]
          ],
        ),
        body: ValueListenableBuilder<Box<FlashcardDeck>>(
          valueListenable:
              context.read<AuthProvider>().flashcardDecksBox.listenable(),
          builder: (context, box, _) {
            final decks = box.values.toList();
            if (decks.isEmpty) {
              return const Center(child: Text('No decks yet.'));
            }
            return ListView.builder(
              itemCount: decks.length,
              itemBuilder: (context, i) {
                final deck = decks[i];
                return _DeckCard(
                  deck: deck,
                  onDelete: () => _showDeleteConfirmDialog(deck),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddDeckDialog,
          tooltip: 'Create Deck',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

/// A stateful dialog for the AI generation form, which now includes a dropdown.
class _AiGenerateDialog extends StatefulWidget {
  final Function(String topic, int count, String? subjectContext) onGenerate;

  const _AiGenerateDialog({required this.onGenerate});

  @override
  State<_AiGenerateDialog> createState() => _AiGenerateDialogState();
}

class _AiGenerateDialogState extends State<_AiGenerateDialog> {
  final _topicController = TextEditingController();
  final _countController = TextEditingController(text: '10');
  final _formKey = GlobalKey<FormState>();

  List<Subject> _subjects = [];
  Subject? _selectedSubject;

  @override
  void initState() {
    super.initState();
    final box = context.read<AuthProvider>().subjectsBox;
    _subjects = box.values.toList();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _handleGenerate() {
    if (_formKey.currentState?.validate() ?? false) {
      final topic = _topicController.text.trim();
      final count = int.tryParse(_countController.text) ?? 10;
      Navigator.of(context).pop(); // Close dialog first
      widget.onGenerate(topic, count, _selectedSubject?.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Deck with AI'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_subjects.isNotEmpty) ...[
              DropdownButtonFormField<Subject?>(
                value: _selectedSubject,
                items: [
                  const DropdownMenuItem<Subject?>(
                    value: null,
                    child: Text('None (General Topic)'),
                  ),
                  ..._subjects.map((subject) {
                    return DropdownMenuItem<Subject>(
                      value: subject,
                      child: Text(subject.name),
                    );
                  }),
                ],
                onChanged: (Subject? newValue) {
                  setState(() {
                    _selectedSubject = newValue;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Select Course (Optional)',
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _topicController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Topic*',
                hintText: 'e.g., "World War II"',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Topic is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of Cards',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                final number = int.tryParse(value);
                if (number == null || number <= 0) {
                  return 'Please enter a positive number.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _handleGenerate,
          child: const Text('Generate'),
        ),
      ],
    );
  }
}

class _DeckCard extends StatelessWidget {
  final FlashcardDeck deck;
  final VoidCallback onDelete;

  const _DeckCard({required this.deck, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cardCount = deck.cards.length;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading:
                Icon(Icons.layers_outlined, color: theme.colorScheme.primary),
            title: Text(deck.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$cardCount card${cardCount == 1 ? '' : 's'}'),
            mouseCursor: SystemMouseCursors.click,
            onTap: () {
              if (deck.cards.isEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlashcardEditorScreen(deckId: deck.id),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlashcardReviewScreen(deck: deck),
                  ),
                );
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FlashcardEditorScreen(deckId: deck.id),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: onDelete,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Study'),
                  onPressed: cardCount > 0
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FlashcardReviewScreen(deck: deck),
                            ),
                          )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
