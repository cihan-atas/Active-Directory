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
