import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../models/flashcard_deck.dart';
import '../models/flashcard.dart';
import '../providers/theme_provider.dart' as app_theme;

enum ReviewMode { review, test }

class FlashcardReviewScreen extends StatefulWidget {
  final FlashcardDeck deck;

  const FlashcardReviewScreen({super.key, required this.deck});

  @override
  State<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends State<FlashcardReviewScreen> {
  late List<Flashcard> _shuffledCards;
  late PageController _pageController;
  late ConfettiController _confettiController;

  // State
  ReviewMode _mode = ReviewMode.review;
  int _currentIndex = 0;
  GlobalKey<FlipCardState> _cardKey = GlobalKey<FlipCardState>();

  // Test Mode State
  final _answerController = TextEditingController();
  bool _isCorrect = false;
  bool _hasAnswered = false;
  int _correctCount = 0;

  @override
  void initState() {
    super.initState();
    _shuffledCards = List.from(widget.deck.cards)..shuffle();
    _pageController = PageController();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _onModeChanged(Set<ReviewMode> newSelection) {
    setState(() {
      _mode = newSelection.first;
      _currentIndex = 0;
      _correctCount = 0;
      _resetCardState();
      _shuffledCards.shuffle();
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _checkAnswer() {
    if (_answerController.text.trim().isEmpty) return;

    setState(() {
      _hasAnswered = true;
      final userAnswer = _answerController.text.trim().toLowerCase();
      final correctAnswer =
          _shuffledCards[_currentIndex].answer.trim().toLowerCase();

      // Fuzzy match logic
      _isCorrect = userAnswer == correctAnswer ||
          correctAnswer.contains(userAnswer) && userAnswer.length > 3;

      if (_isCorrect) _correctCount++;
    });

    if (_isCorrect) _confettiController.play();
  }

  void _giveUp() {
    setState(() {
      _hasAnswered = true;
      _isCorrect = false;
    });
  }

  void _markAsCorrect() {
    if (!_isCorrect) {
      setState(() {
        _isCorrect = true;
        _correctCount++;
      });
      _confettiController.play();
    }
  }

  void _markAsIncorrect() {
    if (_isCorrect) {
      setState(() {
        _isCorrect = false;
        _correctCount--;
      });
    }
  }

  void _nextCard() {
    if (_currentIndex < _shuffledCards.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      setState(() {
        _currentIndex++;
        _resetCardState();
        _cardKey = GlobalKey<FlipCardState>();
      });
    } else {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _resetCardState() {
    _answerController.clear();
    _isCorrect = false;
    _hasAnswered = false;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<app_theme.ThemeProvider>(context);
    final currentTheme = themeProvider.currentTheme;

    BoxDecoration backgroundDecoration;
    if (currentTheme.imageAssetPath != null) {
      backgroundDecoration = BoxDecoration(
        image: DecorationImage(
          image: AssetImage(currentTheme.imageAssetPath!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withAlpha((0.7 * 255).round()),
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
          title: Text(widget.deck.name),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: SegmentedButton<ReviewMode>(
                segments: const [
                  ButtonSegment(
                    value: ReviewMode.review,
                    label: Text('Review'),
                    icon: Icon(Icons.visibility_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: ReviewMode.test,
                    label: Text('Test'),
                    icon: Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _onModeChanged,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return currentTheme.primaryAccent;
                    }
                    return Colors.white.withAlpha(20);
                  }),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          alignment: Alignment.topCenter,
          children: [
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _shuffledCards.length + 1,
              itemBuilder: (context, index) {
                if (index >= _shuffledCards.length) {
                  return _mode == ReviewMode.test
                      ? _buildTestCompletionScreen()
                      : _buildReviewCompletionScreen();
                }
                // Layout Builder ensures we use available height without overflow
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: _mode == ReviewMode.review
                              ? _buildReviewCard(index)
                              : _buildTestCard(index),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- GLASS CARD HELPER ---
  Widget _buildGlassContainer(
      {required Widget child, Color? color, Border? border}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color ??
                (isDark
                    ? Colors.white.withAlpha(15)
                    : Colors.black.withAlpha(10)),
            borderRadius: BorderRadius.circular(24),
            border: border ?? Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: child,
        ),
      ),
    );
  }

  // --- SLEEK BUTTON HELPER ---
  ButtonStyle _sleekButtonStyle({bool filled = true, Color? color}) {
    return ElevatedButton.styleFrom(
      backgroundColor: filled ? (color ?? Colors.white) : Colors.transparent,
      foregroundColor: filled ? Colors.black : (color ?? Colors.white),
      elevation: filled ? 2 : 0,
      side: filled
          ? null
          : BorderSide(color: (color ?? Colors.white).withAlpha(100)),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    );
  }

  // --- REVIEW MODE (Flip Card) ---
  Widget _buildReviewCard(int index) {
    final card = _shuffledCards[index];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("${index + 1} / ${_shuffledCards.length}",
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, letterSpacing: 1.0)),
          const SizedBox(height: 20),

          // Flexible height card
          Expanded(
            child: FlipCard(
              key: _cardKey,
              direction: FlipDirection.HORIZONTAL,
              speed: 500,
              front: _buildGlassContainer(
                child: _buildCardContent(card.question, "Question"),
              ),
              back: _buildGlassContainer(
                child: _buildCardContent(card.answer, "Answer"),
                color: Colors.black.withAlpha(120),
              ),
            ),
          ),
          const SizedBox(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut);
                      setState(() => _currentIndex--);
                    },
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text("Prev"),
                    style: _sleekButtonStyle(filled: false),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _nextCard,
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: const Text("Next Card"),
                style: _sleekButtonStyle(filled: true),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCardContent(String text, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withAlpha(100),
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 30),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
        if (label == "Question")
          Text("TAP TO FLIP",
              style: TextStyle(
                  color: Colors.white.withAlpha(80),
                  fontSize: 10,
                  letterSpacing: 1.5)),
      ],
    );
  }

  // --- TEST MODE (Input) ---
  Widget _buildTestCard(int index) {
    final card = _shuffledCards[index];
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text("${index + 1} / ${_shuffledCards.length}",
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, letterSpacing: 1.0)),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: _buildGlassContainer(
              child: _buildCardContent(card.question, "Question"),
            ),
          ),
          const SizedBox(height: 30),
          if (!_hasAnswered) _buildInputView() else _buildFeedbackView(card),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildInputView() {
    return Column(
      children: [
        _buildGlassContainer(
          color: Colors.black.withAlpha(60),
          child: TextField(
            controller: _answerController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              hintText: 'Type your answer...',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none,
            ),
            maxLines: 3,
            onSubmitted: (_) => _checkAnswer(),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _giveUp,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white30),
                  foregroundColor: Colors.white70,
                  shape: const StadiumBorder(),
                ),
                child: const Text("Give Up"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _checkAnswer,
                style: _sleekButtonStyle(filled: true),
                child: const Text('Check'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackView(Flashcard card) {
    final color = _isCorrect ? Colors.greenAccent : Colors.redAccent;

    return Column(
      children: [
        _buildGlassContainer(
          border: Border.all(color: color.withAlpha(100), width: 1),
          color: color.withAlpha(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isCorrect
                        ? Icons.check_circle_outline
                        : Icons.highlight_off,
                    color: color,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isCorrect ? 'Correct!' : 'Incorrect',
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (!_isCorrect) ...[
                const SizedBox(height: 20),
                Text("CORRECT ANSWER",
                    style: TextStyle(
                        color: Colors.white.withAlpha(150),
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(card.answer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _markAsCorrect,
                    icon:
                        const Icon(Icons.check, color: Colors.black, size: 18),
                    label: const Text("I Was Right (Override)",
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _markAsIncorrect,
                  child: const Text("Wait, I Was Wrong",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ]
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _nextCard,
            icon: const Icon(Icons.arrow_forward, size: 20),
            label: const Text('Next Card'),
            style: _sleekButtonStyle(filled: true),
          ),
        ),
      ],
    );
  }

  // --- COMPLETION SCREENS ---

  Widget _buildTestCompletionScreen() {
    final percentage = _shuffledCards.isEmpty
        ? 100
        : (_correctCount / _shuffledCards.length * 100).round();
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: _buildGlassContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_outlined,
                    size: 80, color: Colors.amberAccent),
                const SizedBox(height: 24),
                const Text(
                  'Test Complete!',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Score: $_correctCount / ${_shuffledCards.length}',
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w300,
                      color: Colors.white),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: _sleekButtonStyle(filled: true),
                  onPressed: () {
                    setState(() {
                      _shuffledCards.shuffle();
                      _currentIndex = 0;
                      _correctCount = 0;
                      _resetCardState();
                      _pageController.jumpToPage(0);
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  child: const Text('Back to Decks',
                      style: TextStyle(color: Colors.white70)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCompletionScreen() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: _buildGlassContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 80, color: Colors.white),
                const SizedBox(height: 32),
                const Text(
                  'All Cards Reviewed',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Shuffle & Restart'),
                  style: _sleekButtonStyle(filled: true),
                  onPressed: () {
                    setState(() {
                      _shuffledCards.shuffle();
                      _currentIndex = 0;
                      _correctCount = 0;
                      _resetCardState();
                      _pageController.jumpToPage(0);
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  child: const Text('Back to Decks',
                      style: TextStyle(color: Colors.white70)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
