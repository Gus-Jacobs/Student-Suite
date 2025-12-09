import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
// ...existing code...
import 'package:cloud_functions/cloud_functions.dart';
import 'package:student_suite/utils/error_utils.dart';

/// A custom exception for the AI service to provide user-friendly error messages.
class AiServiceException implements Exception {
  final String message;
  AiServiceException(this.message);

  @override
  String toString() => message;
}

/// A standard class to represent a message in a chat history.
class ChatMessage {
  final String role; // 'user' or 'model'
  final String content;
  ChatMessage({required this.role, required this.content});
}

class AiService {
  // Singleton pattern
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal() {
    // You can configure functions to use the emulator here if needed.
  }

  // Helper: call a named cloud function with a prompt and return the text result.
  Future<String> _callCloudFunction(String functionName, String prompt) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(functionName);
      final result =
          await callable.call<Map<String, dynamic>>({'prompt': prompt});
      try {
        final map = result.data as Map;
        final text = map.containsKey('text') ? map['text'] : map.values.first;
        return text.toString();
      } catch (_) {
        return result.data.toString();
      }
    } on FirebaseFunctionsException catch (e) {
      final friendly = ErrorUtils.getFriendlyMessage(
        e.message ?? 'An unknown AI error occurred.',
        context: 'ai_service',
      );
      throw AiServiceException(friendly);
    } catch (e) {
      debugPrint('DEBUG (AiService): Unexpected error in $functionName -> $e');
      final friendly = ErrorUtils.getFriendlyMessage(
        'Unexpected AI error: $e',
        context: 'ai_service',
      );
      throw AiServiceException(friendly);
    }
  }

  /// Generate a resume HTML (and structured data). Returns a map containing both the parsed fields and the raw HTML under 'html'.
  Future<Map<String, dynamic>> generateResume({
    required Map<String, String> contactInfo,
    required List<Map<String, dynamic>> experiences,
    required List<Map<String, dynamic>> education,
    required List<Map<String, dynamic>> certificates,
    required List<String> skills,
    required String templateStyle,
  }) async {
    final prompt = _buildResumePrompt(contactInfo, experiences, education,
        certificates, skills, templateStyle);
    final generatedText = await _callCloudFunction('generateResume', prompt);

    // The cloud function will return HTML followed by a structured block with tags.
    // Attempt to extract the structured section for parsing; if not present, fall back
    // to parsing the whole string (backwards compatibility).
    String toParse = generatedText;
    final markerStart = '-----RESUME_DATA_START-----';
    final markerEnd = '-----RESUME_DATA_END-----';
    if (generatedText.contains(markerStart) &&
        generatedText.contains(markerEnd)) {
      final start = generatedText.indexOf(markerStart);
      final end = generatedText.indexOf(markerEnd, start);
      if (start != -1 && end != -1) {
        toParse = generatedText.substring(start + markerStart.length, end);
      }
    }

    final parsed = _parseResumeOutput(toParse, education, certificates);
    // Return parsed fields and raw HTML for preview/export.
    return {
      ...parsed,
      'html': generatedText,
    };
  }

  Future<Map<String, dynamic>> generateCoverLetter({
    required String userName,
    required String companyName,
    required String hiringManager,
    required String jobDescription,
    required String templateStyle,
  }) async {
    final prompt = _buildCoverLetterPrompt(
        userName, companyName, hiringManager, jobDescription, templateStyle);
    final generatedText =
        await _callCloudFunction('generateCoverLetter', prompt);
    return _parseCoverLetterOutput(generatedText);
  }

  Future<String> generateStudyNote({required String topic}) async {
    final prompt = _buildStudyNotePrompt(topic);
    return await _callCloudFunction('generateStudyNote', prompt);
  }

  Future<List<Map<String, String>>> generateFlashcards({
    required String topic,
    int count = 10,
    String? subjectContext,
  }) async {
    final prompt = _buildFlashcardPrompt(topic, count, subjectContext);
    final generatedText =
        await _callCloudFunction('generateFlashcards', prompt);
    return _parseFlashcardOutput(generatedText);
  }

  Future<String> getTeacherResponse({
    required List<ChatMessage> history,
  }) async {
    const systemMessage =
        'You are an expert AI Teacher. Your goal is to explain complex topics clearly and concisely. Be encouraging and ask clarifying questions. If your explanation is long, end it with "[CONTINUE]" to signal that you have more to say.';

    var historyForApi = List<ChatMessage>.from(history);

    // If it's the first message, prepend the system message to the user's first query.
    // For subsequent messages, the system message is implicitly part of the ongoing conversation
    // and handled by the model's understanding of the roles.
    if (historyForApi.length == 1) {
      final firstUserMessage = historyForApi.first;
      historyForApi[0] = ChatMessage(
          role: 'user',
          content:
              '$systemMessage\n\nMy first question is: ${firstUserMessage.content}');
    }

    final prompt =
        historyForApi.map((m) => '${m.role}: ${m.content}').join('\n');
    return await _callCloudFunction('getTeacherResponse', prompt);
  }

  Future<String> getInterviewerResponse({
    required List<ChatMessage> history,
    required String jobDescription,
    String? resumeText,
  }) async {
    const systemMessage =
        'You are a highly disciplined AI Interviewer. Follow these RULES exactly:\n'
        '1) Ask exactly ONE question in each response. The question must be either behavioral or technical and should be tailored to the provided job description and resume.\n'
        '2) NEVER provide feedback, commentary, or evaluation of the candidate\'s answer. Do NOT summarize, rate, or give tips. Your output must be ONLY the next question text.\n'
        '3) If the candidate types "quit" or "stop" the UI will handle ending; do not end on those words yourself.\n'
        '4) The interviewer must ask between 5 and 7 questions in total. When it is time to end the interview (i.e. you have already asked 5, 6, or 7 questions), respond with ONLY the exact token [END_INTERVIEW] (no extra text).\n'
        '5) Do not ask compound questions or multiple questions in one turn. Keep each question clear and focused.\n'
        '6) If the job description suggests technical skills, mix in one technical question approximately every 2-3 turns.\n'
        '7) Use professional, neutral language and avoid coaching tone.\n'
        'Strictly follow these instructions. Any deviation will break the interview flow.';
    final context =
        'Job Description: $jobDescription\n\nResume: ${resumeText ?? 'Not provided.'}';

    var historyForApi = List<ChatMessage>.from(history);

    // Programmatic guard: if we've already asked 6 interviewer questions, end interview locally
    final interviewerTurns =
        historyForApi.where((m) => m.role == 'model').length;
    if (interviewerTurns >= 6) {
      // Force the interview to end without calling the cloud function.
      return '[END_INTERVIEW]';
    }

    // If history is empty, it's the start of the interview, so prime with system message and context.
    if (historyForApi.isEmpty) {
      historyForApi.add(
        ChatMessage(
          role: 'user',
          content:
              '$systemMessage\n\nHere is the context for our interview:\n$context\n\nPlease ask your first question.',
        ),
      );
    }
    // If history is not empty, it means the conversation is ongoing.
    // The system message and context are already part of the initial prompt's "memory"
    // and handled by the conversation history, so we just pass the ongoing messages.

    final prompt =
        historyForApi.map((m) => '${m.role}: ${m.content}').join('\n');
    return await _callCloudFunction('getInterviewerResponse', prompt);
  }

  Future<String> getInterviewFeedback({
    required List<ChatMessage> history,
    required String jobDescription,
    String? resumeText,
  }) async {
    const systemMessage =
        'You are a helpful career coach. The user has just completed a mock interview. Your task is to provide constructive feedback on their answers based on the interview history and the job description. Format the feedback in Markdown with clear headings for "Overall Impression", "Strengths", and "Areas for Improvement".';
    final context =
        'Job Description: $jobDescription\n\nResume: ${resumeText ?? 'Not provided.'}';
    final transcript = history
        .map((m) =>
            '${m.role == 'user' ? 'Candidate' : 'Interviewer'}: ${m.content}')
        .join('\n');

    final prompt =
        '$systemMessage\n\nHere is the context for the interview:\n$context\n\nHere is the full interview transcript:\n$transcript\n\nPlease provide your feedback now.';
    return await _callCloudFunction('getInterviewFeedback', prompt);
  }

  // --- PROMPT & PARSING HELPERS ---

  String _buildResumePrompt(
      Map<String, String> contactInfo,
      List<Map<String, dynamic>> experiences,
      List<Map<String, dynamic>> education,
      List<Map<String, dynamic>> certificates,
      List<String> skills,
      String templateStyle) {
    final experienceString = experiences.map((e) => """
Company: ${e['company']}
Title: ${e['title']}
Dates: ${e['dates']}
Responsibilities:
${e['responsibilities']}
""").join('\n---\n');

    final educationString = education
        .map((e) =>
            "- ${e['degree']} at ${e['school']}, graduated ${e['grad_date']}")
        .join('\n');

    final certificateString = certificates
        .map((c) => "- ${c['name']} from ${c['organization']}, ${c['date']}")
        .join('\n');

    return """
You are an expert resume writer and formatter. Produce TWO outputs concatenated together in this exact order:

1) A complete, standalone HTML document (ready-to-render) containing the fully formatted resume. The HTML must include an internal <style> block suitable for PDF rendering (no external scripts). Use a clean, print-friendly layout and apply the '$templateStyle' visual style (Modern/Creative/Classic). Make the document self-contained: inline CSS and fonts (you may include a Google Fonts link). The HTML should use the following placeholders where appropriate: {{name}}, {{contact}}, {{summary}}, {{experience}}, {{education}}, {{certificates}}, {{skills}} — but you may also render the content directly into the HTML.

2) After the HTML, output a plain-text structured section delimited exactly by the markers:

-----RESUME_DATA_START-----
[SUMMARY]
A plain-text 2-4 sentence professional summary.
[/SUMMARY]

[EXPERIENCE]
Company: [Company Name]
Title: [Job Title]
Dates: [Dates of Employment]
- [Action-oriented bullet 1]
- [Action-oriented bullet 2]
[/EXPERIENCE]
(Repeat the [EXPERIENCE] block for each job)

[SKILLS]
Hard Skills: [comma-separated]
Soft Skills: [comma-separated]
[/SKILLS]

-----RESUME_DATA_END-----

Notes/constraints:
- The first part (the HTML) must be a valid HTML document (<!doctype html><html>...). Keep CSS inline in a <style> tag in the document head so it can be rendered to PDF by web renderers.
- The second part (between the START/END markers) must be plain text only and follow the exact tag structure above so the client can parse it.
- Do NOT include extra commentary, footers, or explanations outside the HTML and the structured block.
- Rewrite job responsibilities into concise, achievement-focused bullets using the STAR method where possible.
- Spell-check and prefer active verbs. Do not output placeholders; generate concrete text.

--- USER DATA ---
Contact Info: ${contactInfo.toString()}
Experience:
$experienceString
Education:
$educationString
Certificates:
$certificateString
Skills:
${skills.join(', ')}
""";
  }

  Map<String, dynamic> _parseResumeOutput(
      String text,
      List<Map<String, dynamic>> education,
      List<Map<String, dynamic>> certificates) {
    try {
      final summary =
          _extractSection(text, 'SUMMARY').replaceAll('[/SUMMARY]', '').trim();

      final skillsSection = _extractSection(text, 'SKILLS');
      final hardSkills = _extractLine(skillsSection, 'Hard Skills:')
          .split(', ')
          .where((s) => s.isNotEmpty)
          .toList();
      final softSkills = _extractLine(skillsSection, 'Soft Skills:')
          .split(', ')
          .where((s) => s.isNotEmpty)
          .toList();
      final List<Map<String, dynamic>> experiences;
      if (text.contains('[EXPERIENCE]')) {
        experiences = text
            .split('[EXPERIENCE]')
            .sublist(1) // Skip the part before the first tag
            .map((expBlock) {
              final cleanBlock =
                  expBlock.replaceAll('[/EXPERIENCE]', '').trim();
              return {
                'company': _extractLine(cleanBlock, 'Company:'),
                'title': _extractLine(cleanBlock, 'Title:'),
                'dates': _extractLine(cleanBlock, 'Dates:'),
                'bullet_points': cleanBlock
                    .split('\n')
                    .where((line) => line.trim().startsWith('-'))
                    .map((line) => line.trim().substring(1).trim())
                    .toList(),
              };
            })
            .where((e) => (e['company'] as String).isNotEmpty)
            .toList();
      } else {
        experiences = [];
      }

      return {
        'professional_summary': summary,
        'formatted_experience': experiences,
        'skills_section': {
          'hard_skills': hardSkills,
          'soft_skills': softSkills,
        },
        'formatted_education': education,
        'formatted_certificates': certificates,
      };
    } catch (e) {
      // ignore: avoid_print
      print("Error parsing resume output: $e");
      // Return a map with an error message to be displayed in the UI.
      return {
        'professional_summary':
            "Error: Could not parse the AI's response. The raw response was:\n\n$text",
        'formatted_experience': [],
        'skills_section': {'hard_skills': [], 'soft_skills': []},
        'formatted_education': education,
        'formatted_certificates': certificates,
      };
    }
  }

  // PASTE THIS into ai_service.dart

  /// Constructs the prompt for the cover letter generation task.
  String _buildCoverLetterPrompt(String userName, String companyName,
      String hiringManager, String jobDescription, String templateStyle) {
    // This is the new, improved prompt:
    return """
You are an AI assistant that writes professional, concise, and compelling cover letters.
Your task is to write a 3-paragraph cover letter based on the user's information and the provided job description.

- **Use the '$templateStyle' style for the overall tone and format.**
- **Crucially, you must GENERATE the content for the paragraphs.** Do not use placeholders like "[Your Accomplishment]". All generated text must be complete and professional.
- Write a strong opening paragraph that states the position I am applying for.
- Write a body paragraph that highlights my skills and enthusiasm, tailored to the job description.
- Write a confident closing paragraph with a clear call to action.
- **Ensure all text is spell-checked and uses correct grammar.**

Format the output EXACTLY as specified below, using the provided tags.

--- USER DATA ---
My Name: $userName
Company: $companyName
Hiring Manager: ${hiringManager.isNotEmpty ? hiringManager : 'Hiring Team'}
Job Description:
$jobDescription
--- END USER DATA ---

[SALUTATION]
Dear ${hiringManager.isNotEmpty ? hiringManager : 'Hiring Team'},
[/SALUTATION]

[OPENING]
(Generate the opening paragraph here)
[/OPENING]

[BODY]
(Generate the body paragraph here, tailored to the job description)
[/BODY]

[CLOSING_P]
(Generate the closing paragraph here)
[/CLOSING_P]

[CLOSING]
Sincerely,
$userName
[/CLOSING]
""";
  }

  /// Parses the AI's structured text response for a cover letter into a map.
  Map<String, dynamic> _parseCoverLetterOutput(String text) {
    try {
      return {
        'salutation': _extractSection(text, 'SALUTATION'),
        'opening_paragraph': _extractSection(text, 'OPENING'),
        'body_paragraphs': [_extractSection(text, 'BODY')],
        'closing_paragraph': _extractSection(text, 'CLOSING_P'),
        'closing': _extractSection(text, 'CLOSING'),
      };
    } catch (e) {
      // ignore: avoid_print
      print("Error parsing cover letter output: $e");
      return {
        'salutation': 'Dear Hiring Team,',
        'opening_paragraph': 'Error: Could not parse AI response.',
        'body_paragraphs': [],
        'closing_paragraph': 'Please try generating again.',
        'closing': 'Sincerely,',
      };
    }
  }

  /// Constructs the prompt for the study note generation task.
  String _buildStudyNotePrompt(String topic) {
    return """You are an AI assistant that creates very short and simple study notes. For the given topic, provide a concise definition and a simple way to remember it (like a mnemonic or an analogy).

Format the output in Markdown like this:

**Definition:**
[Your one-sentence definition here]

**How to Remember:**
[Your mnemonic or analogy here]

Topic: "$topic"
""";
  }

  /// Constructs the prompt for the flashcard generation task.
  String _buildFlashcardPrompt(
      String topic, int count, String? subjectContext) {
    String contextInstruction = '';
    if (subjectContext != null && subjectContext.isNotEmpty) {
      contextInstruction =
          '\n\nUse the following course material as context when creating the cards:\n$subjectContext';
    }

    return """You are an AI assistant that creates flashcards for studying.
Generate exactly $count flashcards for the topic: "$topic".$contextInstruction
Format the output strictly as follows, with each card separated by '---'. Do not add any extra text or numbering outside the specified tags.

[Q]
Question 1
[/Q]
[A]
Answer 1
[/A]
---
[Q]
Question 2
[/Q]
[A]
Answer 2
[/A]
""";
  }

  /// Parses the AI's structured text response for flashcards into a list of maps.
  List<Map<String, String>> _parseFlashcardOutput(String text) {
    try {
      final cards = <Map<String, String>>[];
      final cardBlocks = text.split('---');
      for (final block in cardBlocks) {
        if (block.contains('[Q]') && block.contains('[A]')) {
          final question = _extractSection(block, 'Q');
          final answer = _extractSection(block, 'A');
          if (question.isNotEmpty && answer.isNotEmpty) {
            cards.add({'question': question, 'answer': answer});
          }
        }
      }
      return cards;
    } catch (e) {
      // ignore: avoid_print
      print("Error parsing flashcard output: $e");
      return [
        {'question': 'Error', 'answer': 'Could not parse AI response.'}
      ];
    }
  }

  // --- PARSING HELPER METHODS ---

  /// Extracts a section of text between [TAG] and [/TAG].
  String _extractSection(String text, String tag) {
    try {
      final startTag = '[$tag]';
      final endTag = '[/$tag]';
      final startIndex = text.indexOf(startTag);
      if (startIndex == -1) return '';
      final endIndex = text.indexOf(endTag, startIndex);
      if (endIndex == -1) return '';
      return text.substring(startIndex + startTag.length, endIndex).trim();
    } catch (e) {
      return '';
    }
  }

  /// Extracts the value from a line that starts with a given key (e.g., "Company: ").
  String _extractLine(String text, String key) {
    try {
      final lines = text.split('\n');
      for (final line in lines) {
        if (line.trim().startsWith(key)) {
          return line.trim().substring(key.length).trim();
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}
