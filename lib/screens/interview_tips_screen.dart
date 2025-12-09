import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:student_suite/widgets/glass_section.dart';

// Data models for tips
class _Tip {
  final String title;
  final String content;
  const _Tip(this.title, this.content);
}

class _TipCategory {
  final String title;
  final IconData icon;
  final List<_Tip> tips;
  const _TipCategory(this.title, this.icon, this.tips);
}

// The actual content
const List<_TipCategory> _tipCategories = [
  _TipCategory(
    'Before the Interview',
    Icons.event_seat_outlined,
    [
      _Tip('Research the Company',
          'Understand their mission, values, products, and recent news. Know your interviewer if possible. This shows genuine interest.'),
      _Tip('Analyze the Job Description',
          'Break down the requirements and responsibilities. Match your skills and experiences to each point.'),
      _Tip('Prepare Your Stories (STAR Method)',
          'For behavioral questions ("Tell me about a time when..."), prepare stories using the STAR method: Situation, Task, Action, Result.'),
      _Tip('Prepare Questions for Them',
          'Have at least 3-5 thoughtful questions ready. Ask about team culture, challenges, or what success looks like in the role. This shows you are engaged.'),
      _Tip('Plan Your Outfit',
          'Choose a professional and comfortable outfit. It\'s always better to be slightly overdressed than underdressed.'),
      _Tip('Logistics Check',
          'For in-person interviews, know the route and parking. For virtual interviews, test your camera, microphone, and internet connection. Ensure a clean, quiet background.'),
    ],
  ),
  _TipCategory(
    'During the Interview',
    Icons.record_voice_over_outlined,
    [
      _Tip('First Impressions Matter',
          'Be on time (5-10 minutes early). Offer a firm handshake (if in person). Be polite and friendly to everyone you meet, including the receptionist.'),
      _Tip('Confident Body Language',
          'Maintain good eye contact, sit up straight, and avoid fidgeting. Use hand gestures to emphasize points naturally.'),
      _Tip('Listen Carefully',
          'Pay close attention to the question being asked. It\'s okay to take a brief pause to structure your thoughts before answering.'),
      _Tip('Be Concise but Thorough',
          'Answer the question directly without rambling. Provide enough detail to demonstrate your expertise, using your STAR stories where appropriate.'),
      _Tip('Show Enthusiasm',
          'Express genuine interest in the role and the company. Smile and let your personality show.'),
      _Tip('Ask Your Questions',
          'When given the opportunity, ask the questions you prepared. This turns the interview into a two-way conversation.'),
    ],
  ),
  _TipCategory(
    'After the Interview',
    Icons.mark_email_read_outlined,
    [
      _Tip('Send a Thank-You Note',
          'Within 24 hours, send a personalized thank-you email to each person you interviewed with. Reiterate your interest and briefly mention something specific you discussed.'),
      _Tip('Reflect and Take Notes',
          'Jot down the questions you were asked and how you answered. Note any areas you could improve for future interviews.'),
      _Tip('Be Patient',
          'The hiring process can take time. Avoid pestering the recruiter. If you haven\'t heard back by the timeline they gave you, a polite follow-up email is appropriate.'),
    ],
  ),
];

class InterviewTipsScreen extends StatelessWidget {
  const InterviewTipsScreen({super.key});

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
          title: const Text('Interview Tips'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _tipCategories.length,
          itemBuilder: (context, index) {
            final category = _tipCategories[index];
            return GlassSection(
              title: category.title,
              icon: category.icon,
              initiallyExpanded: index == 0,
              child: Column(
                children: category.tips.map((tip) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 4.0),
                    title: Text(tip.title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface)),
                    subtitle: Text(tip.content,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha((0.8 * 255).round()))),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
