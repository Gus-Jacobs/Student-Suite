import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/models/flashcard.dart';
import 'package:student_suite/models/flashcard_deck.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import 'package:student_suite/services/ai_service.dart';
import 'package:student_suite/widgets/error_dialog.dart';
import 'package:student_suite/widgets/upgrade_dialog.dart';
import '../providers/theme_provider.dart';

class FlashcardEditorScreen extends StatefulWidget {
  final String deckId;

  const FlashcardEditorScreen({super.key, required this.deckId});

  @override
  State<FlashcardEditorScreen> createState() => _FlashcardEditorScreenState();
}

class _FlashcardEditorScreenState extends State<FlashcardEditorScreen> {
  late FlashcardDeck _deck;
  bool _isLoading = true; // For both initial load and AI generation
  final AiService _aiService = AiService();

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  void _loadDeck() {
    final box = context.read<AuthProvider>().flashcardDecksBox;
    final deck = box.get(widget.deckId);
    if (deck != null) {
      setState(() {
        _deck = deck;
        _isLoading = false;
      });
    } else {
      // Handle case where deck is not found
      Navigator.of(context).pop();
    }
  }

  Future<void> _addCard(Flashcard card) async {
    if (_deck.cards.any((c) =>
        c.question.trim().toLowerCase() ==
        card.question.trim().toLowerCase())) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('A card with this question already exists.'),
          ),
        );
      }
      return;
    }
    setState(() {
      _deck.cards.add(card);
    });
    await _deck.save(); // Use save() for HiveObjects
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Card added!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _deleteCard(int index) async {
    setState(() {
      _deck.cards.removeAt(index);
    });
    await _deck.save(); // Use save() for HiveObjects
  }

  void _showAddCardDialog() {
    final questionController = TextEditingController();
    final answerController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Card'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                decoration: const InputDecoration(labelText: 'Question'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: answerController,
                decoration: const InputDecoration(labelText: 'Answer'),
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (questionController.text.isNotEmpty &&
                  answerController.text.isNotEmpty) {
                _addCard(Flashcard(
                  question: questionController.text.trim(),
                  answer: answerController.text.trim(),
                ));
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add'),
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

    final topicController = TextEditingController();
    final countController = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Generate with AI'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: topicController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Topic',
                    hintText: 'e.g., "Cellular Respiration"'),
              ),
              TextField(
                controller: countController,
                decoration: const InputDecoration(labelText: 'Number of cards'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final topic = topicController.text;
              final count = int.tryParse(countController.text) ?? 0;
              if (topic.isNotEmpty && count > 0) {
                Navigator.of(ctx).pop(); // Close dialog
                _runAiGeneration(topic, count);
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Future<void> _runAiGeneration(String topic, int count) async {
    setState(() => _isLoading = true);
    try {
      final newCards =
          await _aiService.generateFlashcards(topic: topic, count: count);
      int addedCount = 0;
      for (final cardData in newCards) {
        // Silently skip duplicates
        final newQuestion = cardData['question'] ?? '';
        if (!_deck.cards.any((c) =>
            c.question.trim().toLowerCase() ==
            newQuestion.trim().toLowerCase())) {
          _deck.cards.add(Flashcard(
              question: newQuestion, answer: cardData['answer'] ?? ''));
          addedCount++;
        }
      }
      await _deck.save(); // Use save() for HiveObjects
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Added $addedCount new cards!')),
      );
    } catch (e) {
      showErrorDialog(context, 'Failed to generate cards: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
            Colors.black.withAlpha((0.5 * 255).round()),
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
          title: Text('Edit: ${_isLoading ? "" : _deck.name}'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: _showAiGenerateDialog,
              tooltip: 'Generate with AI (Pro)',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI is thinking...'),
                ],
              ))
            : _deck.cards.isEmpty
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_card_outlined,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Empty Deck',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Tap '+' to add a card manually, or use the magic wand to generate cards with AI.",
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _deck.cards.length,
                    itemBuilder: (context, index) {
                      final card = _deck.cards[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: ListTile(
                          title: Text(card.question),
                          subtitle: Text(card.answer),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () => _deleteCard(index),
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddCardDialog,
          tooltip: 'Add Card Manually',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
