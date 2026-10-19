import 'package:flutter/material.dart';

/// Soru Zorluk Düzeyi
enum QuizDifficulty {
  beginner('Başlangıç', 0xFF10B981), // Emerald
  intermediate('Orta (CRTP)', 0xFF3B82F6), // Blue
  advanced('İleri Seviye (CRTE / OSCP)', 0xFFEF4444); // Red

  final String label;
  final int colorHex;
  const QuizDifficulty(this.label, this.colorHex);
}

/// Soru Kategorisi
enum QuizCategory {
  recon('Keşif & LDAP Numaralandırma', 0xFF06B6D4), // Cyan
  initialAccess('İlk Erişim & Parola Püskürtme', 0xFFF97316), // Orange
  credentialAccess('Kimlik Erişimi & LSASS & DPAPI', 0xFFEAB308), // Yellow
  kerberos('Kerberos & Delegation Saldırıları', 0xFFF59E0B), // Amber
  aclGpo('ACL, DACL & GPO İstismarı', 0xFFEC4899), // Pink
  adcs('AD CS & PKI Sertifika Saldırıları (ESC1-8)', 0xFF8B5CF6), // Purple
  relayCoercion('NTLM Relay & Coercion (PetitPotam)', 0xFF6366F1), // Indigo
  lateralMovement('Yanal Hareket (PtH, PtT, WMI, WinRM)', 0xFF14B8A6), // Teal
  dominance('Domain Hakimiyeti (DCSync & Golden Ticket)', 0xFFEF4444), // Red
  blueTeam('Mavi Takım, Log Analizi & Event ID', 0xFF3B82F6), // Blue
  sysAdmin('AD Mimarisi, Replikasyon & FSMO', 0xFF10B981); // Green

  final String label;
  final int colorHex;
  const QuizCategory(this.label, this.colorHex);

  IconData get icon {
    switch (this) {
      case QuizCategory.recon:
        return Icons.search;
      case QuizCategory.initialAccess:
        return Icons.vpn_key_outlined;
      case QuizCategory.credentialAccess:
        return Icons.lock_open;
      case QuizCategory.kerberos:
        return Icons.confirmation_number_outlined;
      case QuizCategory.aclGpo:
        return Icons.security;
      case QuizCategory.adcs:
        return Icons.badge;
      case QuizCategory.relayCoercion:
        return Icons.swap_horiz;
      case QuizCategory.lateralMovement:
        return Icons.send_rounded;
      case QuizCategory.dominance:
        return Icons.military_tech;
      case QuizCategory.blueTeam:
        return Icons.shield;
      case QuizCategory.sysAdmin:
        return Icons.dns;
    }
  }
}

/// Çoktan Seçmeli Test Sorusu
class QuizQuestion {
  final String id;
  final QuizCategory category;
  final QuizDifficulty difficulty;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String mitreId;
  final String? relatedDocPath;

  const QuizQuestion({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.mitreId,
    this.relatedDocPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'difficulty': difficulty.name,
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
    'mitreId': mitreId,
    'relatedDocPath': relatedDocPath,
  };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    id: json['id'] as String? ?? 'q_ai_${DateTime.now().millisecondsSinceEpoch}',
    category: QuizCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => QuizCategory.recon,
    ),
    difficulty: QuizDifficulty.values.firstWhere(
      (d) => d.name == json['difficulty'],
      orElse: () => QuizDifficulty.intermediate,
    ),
    question: json['question'] as String? ?? '',
    options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    correctIndex: json['correctIndex'] as int? ?? 0,
    explanation: json['explanation'] as String? ?? '',
    mitreId: json['mitreId'] as String? ?? 'T1078',
    relatedDocPath: json['relatedDocPath'] as String?,
  );

  QuizQuestion copyWith({
    String? id,
    QuizCategory? category,
    QuizDifficulty? difficulty,
    String? question,
    List<String>? options,
    int? correctIndex,
    String? explanation,
    String? mitreId,
    String? relatedDocPath,
  }) => QuizQuestion(
    id: id ?? this.id,
    category: category ?? this.category,
    difficulty: difficulty ?? this.difficulty,
    question: question ?? this.question,
    options: options ?? this.options,
    correctIndex: correctIndex ?? this.correctIndex,
    explanation: explanation ?? this.explanation,
    mitreId: mitreId ?? this.mitreId,
    relatedDocPath: relatedDocPath ?? this.relatedDocPath,
  );
}

/// Senaryo Bazlı Karar Ağacı Düğümü (Decision Tree Node)
class DecisionNode {
  final String id;
  final String title;
  final String situation;
  final String environmentContext;
  final List<DecisionChoice> choices;

  const DecisionNode({
    required this.id,
    required this.title,
    required this.situation,
    required this.environmentContext,
    required this.choices,
  });
}

/// Karar Seçeneği ve Sonucu
class DecisionChoice {
  final String choiceText;
  final bool isOptimal;
  final String outcomeDescription;
  final String opsecRisk;
  final String? nextNodeId; // null ise terminal sonuç (Başarılı / Başarısız)
  final String commandTip;

  const DecisionChoice({
    required this.choiceText,
    required this.isOptimal,
    required this.outcomeDescription,
    required this.opsecRisk,
    this.nextNodeId,
    required this.commandTip,
  });
}

/// Karar Ağacı Senaryosu
class DecisionTreeScenario {
  final String id;
  final String title;
  final String targetGoal;
  final String startNodeId;
  final Map<String, DecisionNode> nodes;

  const DecisionTreeScenario({
    required this.id,
    required this.title,
    required this.targetGoal,
    required this.startNodeId,
    required this.nodes,
  });
}
