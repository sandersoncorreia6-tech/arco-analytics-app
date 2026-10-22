/// Confiança de uma conclusão conforme o volume de dados por trás dela.
///
/// Regra de produto: resultado com amostra baixa é TENDÊNCIA, não conclusão.
enum SampleLevel { low, medium, high }

extension SampleLevelLabel on SampleLevel {
  String get label => switch (this) {
    SampleLevel.low => 'AMOSTRA BAIXA',
    SampleLevel.medium => 'AMOSTRA MÉDIA',
    SampleLevel.high => 'AMOSTRA ALTA',
  };

  /// Prefixo para frases: "Tendência (amostra baixa): ...".
  String get phrase => switch (this) {
    SampleLevel.low => 'Tendência (amostra baixa, ainda não é conclusão)',
    SampleLevel.medium => 'Indício (amostra média)',
    SampleLevel.high => 'Padrão consistente (amostra alta)',
  };
}

class SampleSize {
  /// Classifica por minutos, posses, jogos e eventos — o que for informado.
  /// Basta um critério forte para subir de nível; jogos limitam o teto
  /// (um único jogo nunca vira "amostra alta").
  static SampleLevel of({double minutes = 0, double possessions = 0, int games = 0, int events = 0}) {
    var level = SampleLevel.low;
    if (possessions >= 40 || minutes >= 15 || events >= 25) level = SampleLevel.medium;
    if (possessions >= 120 || minutes >= 45 || events >= 80) level = SampleLevel.high;
    if (games > 0 && games < 3 && level == SampleLevel.high) level = SampleLevel.medium;
    if (games == 1 && level == SampleLevel.medium && possessions < 60) level = SampleLevel.low;
    return level;
  }
}
