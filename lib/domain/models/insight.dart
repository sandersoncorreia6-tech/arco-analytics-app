enum InsightLevel { positive, warning, neutral }

class Insight {
  final String title;
  final String description;
  final InsightLevel level;
  final String evidence;

  const Insight({required this.title, required this.description, required this.level, required this.evidence});
}
