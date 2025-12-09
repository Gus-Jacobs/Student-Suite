import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:student_suite/models/flashcard.dart';
import 'package:student_suite/models/flashcard_deck.dart';
import 'package:student_suite/screens/flashcard_screen.dart';

// A helper to wrap the widget in MaterialApp for testing
Widget createFlashcardScreen() => const MaterialApp(home: FlashcardScreen());

void main() {
  // Setup Hive for testing
  setUpAll(() async {
    // Use a temporary directory for Hive tests to avoid conflicts
    Hive.init('test_path');
    // Register adapters, since they are needed for Hive to work.
    // This check prevents errors if tests are run multiple times.
    if (!Hive.isAdapterRegistered(FlashcardAdapter().typeId)) {
      Hive.registerAdapter(FlashcardAdapter());
    }
    if (!Hive.isAdapterRegistered(FlashcardDeckAdapter().typeId)) {
      Hive.registerAdapter(FlashcardDeckAdapter());
    }
  });

  // Clean up the Hive box from disk after each test
  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('FlashcardScreen shows empty state when no decks exist',
      (WidgetTester tester) async {
    await Hive.openBox<FlashcardDeck>('flashcardDecks');

    await tester.pumpWidget(createFlashcardScreen());
    await tester.pumpAndSettle(); // Wait for ValueListenableBuilder

    expect(find.text('No decks yet'), findsOneWidget);
    expect(find.byType(Card), findsNothing); // No deck cards should be present
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('FlashcardScreen displays a list of decks',
      (WidgetTester tester) async {
    final box = await Hive.openBox<FlashcardDeck>('flashcardDecks');
    final deck1 = FlashcardDeck(id: '1', name: 'Deck One', cards: []);
    final deck2 = FlashcardDeck(
        id: '2',
        name: 'Deck Two',
        cards: [Flashcard(question: 'q', answer: 'a')]);
    await box.put(deck1.id, deck1);
    await box.put(deck2.id, deck2);

    await tester.pumpWidget(createFlashcardScreen());
    await tester.pumpAndSettle();

    expect(find.text('No decks yet'), findsNothing);
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('Deck One'), findsOneWidget);
    expect(find.text('0 cards'), findsOneWidget);
    expect(find.text('Deck Two'), findsOneWidget);
    expect(find.text('1 card'), findsOneWidget);
  });

  testWidgets('Can add a new deck via dialog', (WidgetTester tester) async {
    await Hive.openBox<FlashcardDeck>('flashcardDecks');
    await tester.pumpWidget(createFlashcardScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Create New Deck'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'My New Deck');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Create New Deck'), findsNothing);
    expect(find.text('My New Deck'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });
}
