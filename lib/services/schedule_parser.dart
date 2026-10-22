import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Jogo extraído de uma página/texto, ainda sem liga nem id.
class ParsedGame {
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final String competition;
  final String venue;
  final DateTime? scheduledAt;

  /// Dados de fontes estruturadas (vazios em páginas/texto).
  final String sourceId;
  final String competitionId;
  final String competitionName;
  final String homeTeamId;
  final String awayTeamId;
  final String round;

  const ParsedGame({
    required this.homeTeam,
    required this.awayTeam,
    this.homeScore,
    this.awayScore,
    this.status = 'AGENDADO',
    this.competition = '',
    this.venue = '',
    this.scheduledAt,
    this.sourceId = '',
    this.competitionId = '',
    this.competitionName = '',
    this.homeTeamId = '',
    this.awayTeamId = '',
    this.round = '',
  });

  bool get hasScore => homeScore != null && awayScore != null;

  ParsedGame withDate(DateTime when) => _copy(scheduledAt: when);
  ParsedGame withCompetition(String value) => _copy(competition: value);

  ParsedGame _copy({DateTime? scheduledAt, String? competition}) => ParsedGame(
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        homeScore: homeScore,
        awayScore: awayScore,
        status: status,
        competition: competition ?? this.competition,
        venue: venue,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        sourceId: sourceId,
        competitionId: competitionId,
        competitionName: competitionName,
        homeTeamId: homeTeamId,
        awayTeamId: awayTeamId,
        round: round,
      );

  /// Combina dois registros do mesmo jogo, preferindo o dado mais completo.
  ParsedGame merge(ParsedGame other) => ParsedGame(
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        homeScore: hasScore ? homeScore : other.homeScore,
        awayScore: hasScore ? awayScore : other.awayScore,
        status: status == 'AGENDADO' ? other.status : status,
        competition: competition.isNotEmpty ? competition : other.competition,
        venue: venue.isNotEmpty ? venue : other.venue,
        scheduledAt: _richer(scheduledAt, other.scheduledAt),
      );

  static DateTime? _richer(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    final aHasTime = a.hour != 0 || a.minute != 0;
    final bHasTime = b.hour != 0 || b.minute != 0;
    return !aHasTime && bHasTime ? b : a;
  }

  @override
  String toString() => '$homeTeam ${homeScore ?? '-'} x ${awayScore ?? '-'} $awayTeam [$status] $competition ${scheduledAt ?? ''} $venue';
}

enum _Kind { team, score, sep, combined, time, meta }

class _Token {
  final _Kind kind;
  final String text;
  final int? a;
  final int? b;
  const _Token(this.kind, this.text, [this.a, this.b]);
}

/// Interpretação tolerante de agendas/resultados de basquete.
///
/// Não depende de classes CSS específicas: lê dados estruturados (JSON-LD,
/// JSON embutido), linhas de tabela, itens de lista, cards e texto colado,
/// procurando o padrão "equipe — placar/x/horário — equipe".
class ScheduleParser {
  ScheduleParser({DateTime? reference}) : reference = reference ?? DateTime.now();

  final DateTime reference;

  static const _maxSegments = 40;

  // ---------------------------------------------------------------- HTML

  List<ParsedGame> parseHtml(String html) {
    final doc = html_parser.parse(html);
    final out = _Collector();

    for (final script in doc.querySelectorAll('script')) {
      final type = (script.attributes['type'] ?? '').toLowerCase();
      final text = script.text.trim();
      final looksJson = type.contains('json') || text.startsWith('{') || text.startsWith('[');
      if (!looksJson || text.isEmpty) continue;
      try {
        _walkJson(jsonDecode(text), out.add, 0);
      } catch (_) {
        // Script não é JSON puro; ignora.
      }
    }

    for (final e in doc.querySelectorAll('script, style, noscript, svg, template, head')) {
      e.remove();
    }

    final seen = <dom.Element>{};
    final candidates = <dom.Element>[
      ...doc.querySelectorAll('tr, li, article'),
      ...doc.querySelectorAll('[class], [id]').where(_looksLikeGameContainer),
    ];
    for (final el in candidates) {
      if (!seen.add(el)) continue;
      final cells = segmentsOf(el);
      if (cells.isEmpty || cells.length > _maxSegments) continue;
      final game = parseCells(cells);
      if (game != null) out.add(game);
    }
    return out.sorted(reference);
  }

  static final _containerHint = RegExp(
    r'game|jogo|match|partida|event|fixture|confronto|placar|score|resultado|agenda|calend|schedule|card',
    caseSensitive: false,
  );

  static bool _looksLikeGameContainer(dom.Element e) {
    final attrs = '${e.attributes['class'] ?? ''} ${e.attributes['id'] ?? ''}';
    return _containerHint.hasMatch(attrs);
  }

  /// Textos "folha" de um elemento, na ordem de leitura. Diferente de
  /// `element.text`, não cola o conteúdo de células vizinhas
  /// (`<td>Tupã</td><td>78</td>` vira `[Tupã, 78]`, e não `Tupã78`).
  static List<String> segmentsOf(dom.Element root, {int limit = _maxSegments + 1}) {
    final out = <String>[];
    void add(String raw) {
      final t = clean(raw);
      if (t.isEmpty) return;
      if (out.isNotEmpty && out.last == t) return;
      out.add(t);
    }

    void visit(dom.Node node) {
      if (out.length >= limit) return;
      if (node is dom.Text) {
        add(node.text);
      } else if (node is dom.Element) {
        final tag = node.localName;
        if (tag == 'script' || tag == 'style' || tag == 'noscript' || tag == 'svg') return;
        if (tag == 'img') {
          final alt = (node.attributes['alt'] ?? node.attributes['title'] ?? '')
              .replaceAll(RegExp(r'\b(logo|escudo|bras[aã]o|imagem|foto)\b', caseSensitive: false), '');
          add(alt);
          return;
        }
        for (final child in node.nodes) {
          visit(child);
        }
      }
    }

    visit(root);
    return out;
  }

  // ---------------------------------------------------------------- TEXTO

  /// Interpreta texto copiado de um site/planilha/WhatsApp.
  /// Aceita um jogo por linha ("Tupã 78 x 65 Marília") ou um campo por linha.
  List<ParsedGame> parseText(String text) {
    final lines = text.split(RegExp(r'\r?\n')).map(clean).where((l) => l.isNotEmpty).toList();
    final out = _Collector();
    // Cabeçalho de data em notícias/agendas ("Sábado – 28/03"): vale para os jogos abaixo dele.
    String? dateHeader;
    String? competitionHeader;
    var i = 0;
    while (i < lines.length) {
      ParsedGame? found;
      var used = 0;
      for (var k = 1; k <= 8 && i + k <= lines.length; k++) {
        // Um jogo em várias linhas nunca engole uma linha que já é um jogo
        // completo ou um cabeçalho de data.
        if (k > 1) {
          final added = lines[i + k - 1];
          if (_isDateHeader(added) || parseCells(_cellsOf([added])) != null) break;
        }
        final game = _parseWindow(lines.sublist(i, i + k), dateHeader);
        if (game == null) continue;
        found = game;
        used = k;
        // Placar ainda incompleto? Tenta incluir a próxima linha.
        if (!game.hasScore && i + k < lines.length) {
          final longer = _parseWindow(lines.sublist(i, i + k + 1), dateHeader);
          if (longer != null && longer.hasScore && longer.homeTeam == game.homeTeam) {
            found = longer;
            used = k + 1;
          }
        }
        break;
      }
      if (found != null) {
        if (found.competition.isEmpty && competitionHeader != null) found = found.withCompetition(competitionOf(competitionHeader));
        out.add(found);
        i += used;
      } else {
        if (_isDateHeader(lines[i])) dateHeader = lines[i];
        if (competitionOf(lines[i]).isNotEmpty) competitionHeader = lines[i];
        i++;
      }
    }
    return out.sorted(reference);
  }

  ParsedGame? _parseWindow(List<String> lines, String? dateHeader) {
    final cells = _cellsOf(lines);
    final ownDate = dateTimeOf(lines.join(' '), reference) != null;
    if (dateHeader == null || ownDate) return parseCells(cells);
    final game = parseCells(cells);
    if (game == null) return null;
    final when = dateTimeOf('$dateHeader ${lines.join(' ')}', reference);
    return when == null ? game : game.withDate(when);
  }

  bool _isDateHeader(String line) {
    if (line.length > 60 || dateTimeOf(line, reference) == null) return false;
    return RegExp(r'[a-z]').allMatches(normalize(_stripMeta(line))).length < 4;
  }

  /// Converte o corpo de uma notícia/página em linhas de texto e interpreta
  /// (ex.: posts "Programação"/"Resultados" da FPB com um jogo por linha).
  List<ParsedGame> parseArticleHtml(String html) {
    final doc = html_parser.parse(html);
    for (final e in doc.querySelectorAll('script, style, noscript, svg, template')) {
      e.remove();
    }
    final buffer = StringBuffer();
    void visit(dom.Node node) {
      if (node is dom.Text) {
        buffer.write(node.text);
      } else if (node is dom.Element) {
        const blocks = {'p', 'li', 'tr', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'div', 'section', 'article', 'table', 'ul', 'ol', 'blockquote'};
        final tag = node.localName;
        if (tag == 'br') {
          buffer.write('\n');
          return;
        }
        if (tag == 'td' || tag == 'th') buffer.write('\t');
        for (final child in node.nodes) {
          visit(child);
        }
        if (blocks.contains(tag)) buffer.write('\n');
      }
    }

    final body = doc.body;
    if (body != null) visit(body);
    return parseText(buffer.toString());
  }

  static List<String> _cellsOf(List<String> lines) => [
        for (final line in lines)
          ...line.split(RegExp(r'\t|\s{2,}|\s+\|\s+|;')).map(clean).where((c) => c.isNotEmpty),
      ];

  // ---------------------------------------------------------------- CÉLULAS

  /// Interpreta uma sequência de células/segmentos de um único bloco.
  ParsedGame? parseCells(List<String> cells) {
    if (cells.isEmpty) return null;
    final full = clean(cells.join(' '));
    if (full.length < 5) return null;

    final tokens = <_Token>[for (final c in cells) ..._classify(c)];
    return _fromTokens(tokens, full) ?? (cells.length <= 6 ? _fromFlatText(full) : null);
  }

  ParsedGame? _fromTokens(List<_Token> tokens, String full) {
    final teamIdx = [for (var i = 0; i < tokens.length; i++) if (tokens[i].kind == _Kind.team) i];
    if (teamIdx.length < 2) return null;

    // 1) Duas equipes separadas por placar, "x" ou horário.
    for (var n = 0; n + 1 < teamIdx.length; n++) {
      final i = teamIdx[n];
      final j = teamIdx[n + 1];
      final between = tokens.sublist(i + 1, j);
      if (between.isEmpty || between.length > 5) continue;
      if (between.any((t) => t.kind == _Kind.team)) continue;
      final strong = between.any((t) => t.kind == _Kind.sep || t.kind == _Kind.score || t.kind == _Kind.combined || t.kind == _Kind.time);
      if (!strong) continue;
      final scores = <int>[
        for (final t in between)
          if (t.kind == _Kind.score) t.a!
          else if (t.kind == _Kind.combined) ...[t.a!, t.b!],
      ];
      if (scores.length == 1 && j + 1 < tokens.length && tokens[j + 1].kind == _Kind.score) {
        scores.add(tokens[j + 1].a!); // Layout "Equipe 78 | Equipe 65".
      }
      return _build(tokens[i].text, tokens[j].text, scores, full);
    }

    // 2) Bloco pequeno com exatamente duas equipes lado a lado (linha de tabela).
    if (teamIdx.length == 2 && tokens.length <= 10) {
      final i = teamIdx[0];
      final j = teamIdx[1];
      final scores = <int>[
        if (i + 1 < j && tokens[i + 1].kind == _Kind.score) tokens[i + 1].a!,
        for (var k = j + 1; k < tokens.length && k <= j + 2; k++)
          if (tokens[k].kind == _Kind.score) tokens[k].a!
          else if (tokens[k].kind == _Kind.combined) ...[tokens[k].a!, tokens[k].b!],
      ];
      return _build(tokens[i].text, tokens[j].text, scores, full);
    }
    return null;
  }

  ParsedGame? _fromFlatText(String full) {
    var text = full;
    var venue = '';
    final venueMatch = RegExp(r'\b(gin[áa]sio|local:|quadra|arena|est[áa]dio)\b.*$', caseSensitive: false).firstMatch(text);
    if (venueMatch != null && venueMatch.start > 0) {
      venue = clean(venueMatch.group(0)!.replaceFirst(RegExp(r'^local:\s*', caseSensitive: false), ''));
      text = text.substring(0, venueMatch.start);
    }
    text = _stripMeta(text);

    final patterns = <RegExp>[
      RegExp(r'^(.+?)\s+(\d{1,3})\s*[x×]\s*(\d{1,3})\s+(.+)$', caseSensitive: false),
      RegExp(r'^(.+?)\s+(\d{1,3})\s+[-–]\s+(\d{1,3})\s+(.+)$'),
      RegExp(r'^(.+?)\s+(\d{1,3})\s+(.+?)\s+(\d{1,3})$'),
    ];
    for (var p = 0; p < patterns.length; p++) {
      final m = patterns[p].firstMatch(text);
      if (m == null) continue;
      final home = _teamName(m.group(1)!);
      final away = _teamName(p == 2 ? m.group(3)! : m.group(4)!);
      final scores = p == 2
          ? [int.parse(m.group(2)!), int.parse(m.group(4)!)]
          : [int.parse(m.group(2)!), int.parse(m.group(3)!)];
      if (_isTeam(home) && _isTeam(away)) return _build(home, away, scores, full, venue: venue);
    }
    final vs = RegExp(r'^(.+?)\s+(?:x|×|vs\.?|versus)\s+(.+)$', caseSensitive: false).firstMatch(text);
    if (vs != null) {
      final home = _teamName(vs.group(1)!);
      final away = _teamName(vs.group(2)!);
      if (_isTeam(home) && _isTeam(away)) return _build(home, away, const [], full, venue: venue);
    }
    return null;
  }

  ParsedGame? _build(String home, String away, List<int> scores, String full, {String venue = ''}) {
    final h = _teamName(home);
    final a = _teamName(away);
    if (!_isTeam(h) || !_isTeam(a) || normalize(h) == normalize(a)) return null;
    final valid = scores.length >= 2 && scores[0] <= 250 && scores[1] <= 250;
    return ParsedGame(
      homeTeam: h,
      awayTeam: a,
      homeScore: valid ? scores[0] : null,
      awayScore: valid ? scores[1] : null,
      status: statusOf(full, hasScore: valid),
      competition: competitionOf(full),
      venue: venue.isNotEmpty ? venue : venueOf(full),
      scheduledAt: dateTimeOf(full, reference),
    );
  }

  // ---------------------------------------------------------------- TOKENS

  static final _scoreRe = RegExp(r'^\d{1,3}$');
  static final _combinedRe = RegExp(r'^(\d{1,3})\s*[x×]\s*(\d{1,3})$|^(\d{1,3})\s+[-–]\s+(\d{1,3})$', caseSensitive: false);
  static final _sepRe = RegExp(r'^(x|×|vs\.?|versus|-|–|—|@)$', caseSensitive: false);
  static final _timeOnlyRe = RegExp(r'^(?:[01]?\d|2[0-3])\s*(?::|h)\s*(?:[0-5]\d)?\s*(?:h|hs|min|am|pm)?$', caseSensitive: false);

  List<_Token> _classify(String raw) {
    final c = clean(raw);
    if (_scoreRe.hasMatch(c)) {
      final v = int.parse(c);
      return [_Token(v <= 250 ? _Kind.score : _Kind.meta, c, v)];
    }
    final comb = _combinedRe.firstMatch(c);
    if (comb != null) {
      final a = int.parse(comb.group(1) ?? comb.group(3)!);
      final b = int.parse(comb.group(2) ?? comb.group(4)!);
      return [_Token(_Kind.combined, c, a, b)];
    }
    if (_sepRe.hasMatch(c)) return [_Token(_Kind.sep, c)];
    if (_timeOnlyRe.hasMatch(c)) return [_Token(_Kind.time, c)];

    // "Tupã 78" / "78 Tupã": equipe e placar na mesma célula.
    final trailing = RegExp(r'^(.*[^\d\s])\s+(\d{1,3})$').firstMatch(c);
    if (trailing != null && !RegExp(r'\b(sub|u|s|categoria|rodada|round|jogo)[\s-]*$', caseSensitive: false).hasMatch(trailing.group(1)!)) {
      final name = _teamName(trailing.group(1)!);
      if (_isTeam(name)) return [_Token(_Kind.team, name), _Token(_Kind.score, trailing.group(2)!, int.parse(trailing.group(2)!))];
    }
    final leading = RegExp(r'^(\d{1,3})\s+([^\d\s].*)$').firstMatch(c);
    if (leading != null) {
      final name = _teamName(leading.group(2)!);
      if (_isTeam(name)) return [_Token(_Kind.score, leading.group(1)!, int.parse(leading.group(1)!)), _Token(_Kind.team, name)];
    }

    final name = _teamName(c);
    return [_Token(_isTeam(name) ? _Kind.team : _Kind.meta, name)];
  }

  static String _teamName(String raw) =>
      clean(raw).replaceAll(RegExp(r'^[\s\-–—|•·:,;.()]+|[\s\-–—|•·:,;]+$'), '').trim();

  static const _metaPrefixes = [
    'campeonato', 'copa ', 'torneio', 'rodada', 'round', 'fase', 'grupo', 'chave', 'categoria', 'data', 'horario',
    'hora ', 'local', 'ginasio', 'quadra', 'estadio', 'arena ', 'centro esportivo', 'ver ', 'veja', 'assista',
    'clique', 'saiba', 'mais ', 'jogo ', 'partida', 'tabela', 'classificacao', 'resultado', 'placar', 'estatistica',
    'sumula', 'boletim', 'transmissao', 'ao vivo', 'encerrado', 'finalizado', 'final', 'adiado', 'cancelado',
    'agendado', 'intervalo', 'prorrogacao', 'semifinal', 'quartas', 'oitavas', 'turno', 'returno', 'divisao',
    'serie ', 'temporada', 'equipe', 'mandante', 'visitante', 'compartilh', 'inscricao', 'noticia', 'galeria',
    'home', 'inicio', 'contato', 'menu', 'online', 'live', 'em andamento', 'nao iniciado', 'previsto', 'publicado',
  ];

  static const _metaExact = {
    'x', 'vs', 'm', 'f', 'masculino', 'feminino', 'masc', 'fem', 'away', 'casa', 'fora', 'hoje', 'amanha', 'ontem',
    'segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo', 'seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom',
    'janeiro', 'fevereiro', 'marco', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    'q1', 'q2', 'q3', 'q4', 'ot', 'pts', 'vitoria', 'derrota', 'empate', 'wo',
  };

  static bool _isTeam(String s) {
    if (s.length < 2 || s.length > 60) return false;
    if (RegExp(r'[A-Za-zÀ-ÿ]').allMatches(s).length < 2) return false;
    if (s.split(' ').length > 8) return false;
    final n = normalize(s);
    if (_metaExact.contains(n)) return false;
    for (final p in _metaPrefixes) {
      if (n == p.trim() || n.startsWith(p)) return false;
    }
    // Só data/horário/categoria/dia da semana?
    final rest = normalize(_stripMeta(s));
    if (RegExp(r'[a-z]').allMatches(rest).length < 2) return false;
    if (_metaExact.contains(rest)) return false;
    return true;
  }

  static final _monthRe = r'(jan|fev|feb|mar|abr|apr|mai|may|jun|jul|ago|aug|set|sep|out|oct|nov|dez|dec)[a-zç]*\.?';

  /// Remove datas, horários, dias da semana, categorias e status de um texto.
  static String _stripMeta(String text) {
    var t = text;
    final patterns = [
      RegExp(r'\b(20\d{2})-(\d{1,2})-(\d{1,2})(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)?'),
      RegExp(r'\b\d{1,2}[/.]\d{1,2}(?:[/.]\d{2,4})?\b'),
      RegExp('\\b\\d{1,2}\\s*(?:de\\s+)?$_monthRe(?:\\s*(?:de\\s+)?20\\d{2})?', caseSensitive: false),
      RegExp(r'\b(?:[01]?\d|2[0-3])\s*(?::|h)\s*(?:[0-5]\d)?\s*(?:hs|h|min|am|pm)?\b', caseSensitive: false),
      RegExp(r'\b(?:segunda|ter[çc]a|quarta|quinta|sexta)(?:-feira)?\b|\bs[áa]bado\b|\bdomingo\b|\b(?:seg|ter|qua|qui|sex|s[áa]b|dom)\b\.?', caseSensitive: false),
      RegExp(r'\b(?:sub|u|s)\s*-?\s*\d{2}\s*-?\s*(?:masculino|feminino|masc\.?|fem\.?|m|f)?\b', caseSensitive: false),
      RegExp(r'\b(?:adulto|master|mirim|pr[ée]-?mini|mini|infantil|infanto(?:-juvenil)?|cadete|juvenil)\b(?:\s+(?:masculino|feminino|masc|fem|m|f)\b)?', caseSensitive: false),
      RegExp(r'\b(?:ao vivo|em andamento|encerrado|finalizado|final|adiado|cancelado|agendado|intervalo|live|ft)\b', caseSensitive: false),
      RegExp(r'\b[1-4]\s*º?\s*(?:q|quarto|per[ií]odo)\b', caseSensitive: false),
      RegExp(r'\b(?:rodada|round|jogo|grupo|chave)\s*\d+\b', caseSensitive: false),
    ];
    for (final p in patterns) {
      t = t.replaceAll(p, ' ');
    }
    // Conectivos que sobram nas pontas: "Lins - às" → "Lins".
    final dangling = RegExp(r'(?:\s+(?:[àá]s|as|em|dia|no|na|[-–|•]))+\s*$|^\s*(?:(?:[àá]s|em|dia|[-–|•])\s+)+', caseSensitive: false);
    return clean(clean(t).replaceAll(dangling, ''));
  }

  // ---------------------------------------------------------------- METADADOS

  static String statusOf(String text, {required bool hasScore}) {
    final t = normalize(text);
    if (RegExp(r'\b(adiado|adiada|remarcado)\b').hasMatch(t)) return 'ADIADO';
    if (RegExp(r'\b(cancelado|cancelada)\b').hasMatch(t)) return 'CANCELADO';
    if (RegExp(r'\b(ao vivo|live|em andamento|intervalo|prorrogacao|[1-4] ?o? ?(q|quarto|periodo))\b').hasMatch(t)) return 'AO VIVO';
    if (RegExp(r'\b(w ?o)\b').hasMatch(t) && hasScore) return 'FINAL (W.O.)';
    if (hasScore) return 'FINAL';
    return 'AGENDADO';
  }

  static String competitionOf(String text) {
    final t = text.toUpperCase();
    String gender(String? g) {
      if (g == null || g.isEmpty) {
        if (RegExp(r'FEMININO|\bFEM\b').hasMatch(t)) return ' F';
        if (RegExp(r'MASCULINO|\bMASC\b').hasMatch(t)) return ' M';
        return '';
      }
      return g.startsWith('F') ? ' F' : ' M';
    }

    final sub = RegExp(r'\b(?:SUB|U|S)\s*-?\s*(\d{2})\s*-?\s*(MASCULINO|FEMININO|MASC\.?|FEM\.?|M|F)?\b').firstMatch(t);
    if (sub != null) {
      final age = int.parse(sub.group(1)!);
      if (age >= 7 && age <= 23) return 'SUB $age${gender(sub.group(2))}';
    }
    final named = RegExp(r'\b(ADULTO|MASTER|MIRIM|PR[ÉE]-?MINI|MINI|INFANTIL|INFANTO-JUVENIL|INFANTO|CADETE|JUVENIL|NBB|DIVIS[ÃA]O ESPECIAL)\b\s*(MASCULINO|FEMININO|MASC|FEM|M|F)?\b')
        .firstMatch(t);
    if (named != null) return '${named.group(1)}${gender(named.group(2))}';
    final code = RegExp(r'\b(DEM\d?|DEF\d?)\b').firstMatch(t);
    return code?.group(1) ?? '';
  }

  static String venueOf(String text) {
    final m = RegExp(r'\b((?:gin[áa]sio|arena|quadra|est[áa]dio|centro esportivo)\b[^|•·\n]{2,60})', caseSensitive: false).firstMatch(text);
    if (m == null) return '';
    return clean(m.group(1)!.split(RegExp(r'\s{2,}|\s-\s|\b\d{1,2}[/:h]\d{2}')).first);
  }

  static const _months = {
    'jan': 1, 'fev': 2, 'feb': 2, 'mar': 3, 'abr': 4, 'apr': 4, 'mai': 5, 'may': 5, 'jun': 6, 'jul': 7,
    'ago': 8, 'aug': 8, 'set': 9, 'sep': 9, 'out': 10, 'oct': 10, 'nov': 11, 'dez': 12, 'dec': 12,
  };

  /// Data (e horário, se houver) mencionada no texto. Sem data → `null`.
  static DateTime? dateTimeOf(String text, DateTime reference) {
    int? y, mo, d;
    final iso = RegExp(r'\b(20\d{2})-(\d{1,2})-(\d{1,2})(?:[T\s](\d{1,2}):(\d{2})(?::\d{2}(?:\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?)?').firstMatch(text);
    if (iso != null) {
      if (iso.group(6) != null) {
        // Horário com fuso (ex.: JSON-LD "2026-10-25T19:30:00-03:00").
        final parsed = DateTime.tryParse(iso.group(0)!.replaceFirst(' ', 'T'));
        if (parsed != null) return parsed.toLocal();
      }
      y = int.parse(iso.group(1)!);
      mo = int.parse(iso.group(2)!);
      d = int.parse(iso.group(3)!);
      if (iso.group(4) != null) {
        return _safeDate(y, mo, d, int.parse(iso.group(4)!), int.parse(iso.group(5)!));
      }
    } else {
      final br = RegExp(r'\b(\d{1,2})[/.](\d{1,2})(?:[/.](\d{2,4}))?\b').firstMatch(text);
      final named = RegExp('\\b(\\d{1,2})\\s*(?:de\\s+)?$_monthRe(?:\\s*(?:de\\s+)?(20\\d{2}))?', caseSensitive: false).firstMatch(text);
      if (br != null) {
        d = int.parse(br.group(1)!);
        mo = int.parse(br.group(2)!);
        final ys = br.group(3);
        if (ys != null) y = ys.length == 2 ? 2000 + int.parse(ys) : int.parse(ys);
      } else if (named != null) {
        d = int.parse(named.group(1)!);
        mo = _months[named.group(2)!.toLowerCase().substring(0, 3)];
        if (named.group(3) != null) y = int.parse(named.group(3)!);
      }
    }
    if (d == null || mo == null) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    if (y == null) {
      y = reference.year;
      final guess = DateTime(y, mo, d);
      final diff = guess.difference(reference).inDays;
      if (diff > 200) y -= 1;
      if (diff < -200) y += 1;
    }

    final withoutDate = text.replaceAll(RegExp(r'\b\d{1,2}[/.]\d{1,2}(?:[/.]\d{2,4})?\b|\b20\d{2}-\d{1,2}-\d{1,2}'), ' ');
    final ampm = RegExp(r'\b(1[0-2]|[1-9]):([0-5]\d)\s*([AP]M)\b', caseSensitive: false).firstMatch(withoutDate);
    final hhmm = RegExp(r'\b([01]?\d|2[0-3])\s*(?::|h)\s*([0-5]\d)?\b(?!\s*[x×])', caseSensitive: false).firstMatch(withoutDate);
    var hour = 0, minute = 0;
    if (ampm != null) {
      hour = int.parse(ampm.group(1)!) % 12 + (ampm.group(3)!.toUpperCase() == 'PM' ? 12 : 0);
      minute = int.parse(ampm.group(2)!);
    } else if (hhmm != null && (hhmm.group(2) != null || withoutDate.substring(hhmm.start).contains(RegExp(r'^\d{1,2}\s*h', caseSensitive: false)))) {
      hour = int.parse(hhmm.group(1)!);
      minute = int.tryParse(hhmm.group(2) ?? '') ?? 0;
    }
    return _safeDate(y, mo, d, hour, minute);
  }

  static DateTime? _safeDate(int y, int mo, int d, [int h = 0, int mi = 0]) {
    final dt = DateTime(y, mo, d, h, mi);
    return dt.month == mo && dt.day == d ? dt : null;
  }

  // ---------------------------------------------------------------- JSON

  static const _homeKeys = [
    'hometeam', 'home_team', 'home', 'mandante', 'equipemandante', 'equipe_mandante', 'timecasa', 'time_casa',
    'team1', 'teama', 'equipe1', 'time1', 'localteam', 'homename', 'home_name', 'competitor1', 'equipea',
  ];
  static const _awayKeys = [
    'awayteam', 'away_team', 'away', 'visitante', 'equipevisitante', 'equipe_visitante', 'timevisitante',
    'time_visitante', 'team2', 'teamb', 'equipe2', 'time2', 'visitorteam', 'visitor', 'awayname', 'away_name',
    'competitor2', 'equipeb',
  ];
  static const _homeScoreKeys = [
    'homescore', 'home_score', 'placarmandante', 'placar_mandante', 'pontosmandante', 'pontos_mandante', 'scorehome',
    'score_home', 'homepoints', 'score1', 'placar1', 'pontos1', 'scorea', 'resultadomandante',
  ];
  static const _awayScoreKeys = [
    'awayscore', 'away_score', 'placarvisitante', 'placar_visitante', 'pontosvisitante', 'pontos_visitante',
    'scoreaway', 'score_away', 'awaypoints', 'score2', 'placar2', 'pontos2', 'scoreb', 'resultadovisitante',
  ];
  static const _dateKeys = [
    'startdate', 'start_date', 'datetime', 'date_time', 'datahora', 'data_hora', 'scheduledat', 'scheduled',
    'date', 'data', 'inicio', 'start', 'kickoff', 'datajogo', 'data_jogo',
  ];
  static const _timeKeys = ['hora', 'horario', 'time', 'starttime', 'start_time'];
  static const _statusKeys = ['status', 'situacao', 'eventstatus', 'state', 'gamestatus', 'periodo', 'period'];
  static const _competitionKeys = ['competition', 'competicao', 'categoria', 'category', 'league', 'campeonato', 'tournament', 'division'];
  static const _venueKeys = ['location', 'local', 'ginasio', 'venue', 'arena', 'quadra'];

  void _walkJson(dynamic node, void Function(ParsedGame) add, int depth) {
    if (depth > 14) return;
    if (node is List) {
      for (final item in node) {
        _walkJson(item, add, depth + 1);
      }
    } else if (node is Map) {
      final game = _gameFromMap(node);
      if (game != null) {
        add(game);
        return;
      }
      for (final value in node.values) {
        _walkJson(value, add, depth + 1);
      }
    }
  }

  ParsedGame? _gameFromMap(Map<dynamic, dynamic> raw) {
    final m = {for (final e in raw.entries) e.key.toString().toLowerCase(): e.value};
    dynamic pick(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) return v;
      }
      return null;
    }

    String? nameOf(dynamic v) {
      if (v is String) return v;
      if (v is Map) {
        final mm = {for (final e in v.entries) e.key.toString().toLowerCase(): e.value};
        for (final k in ['name', 'nome', 'teamname', 'team_name', 'nomeequipe', 'equipe', 'title', 'shortname', 'sigla']) {
          final n = mm[k];
          if (n is String && n.trim().isNotEmpty) return n;
          if (n is Map) return nameOf(n);
        }
      }
      return null;
    }

    int? scoreOf(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      if (v is Map) {
        final mm = {for (final e in v.entries) e.key.toString().toLowerCase(): e.value};
        for (final k in ['score', 'points', 'pontos', 'placar', 'pts', 'result']) {
          final s = scoreOf(mm[k]);
          if (s != null) return s;
        }
      }
      return null;
    }

    dynamic homeRaw = pick(_homeKeys);
    dynamic awayRaw = pick(_awayKeys);
    final competitors = m['competitor'] ?? m['competitors'] ?? m['teams'] ?? m['equipes'];
    if ((homeRaw == null || awayRaw == null) && competitors is List && competitors.length == 2) {
      homeRaw = competitors[0];
      awayRaw = competitors[1];
    }

    final type = (m['@type'] ?? '').toString().toLowerCase();
    final title = (m['name'] ?? m['title'] ?? m['nome'] ?? '').toString();
    final extra = [
      for (final k in [..._competitionKeys, ..._statusKeys, 'name', 'title', 'description'])
        if (m[k] is String) m[k] as String else if (m[k] is Map) nameOf(m[k]) ?? '',
    ].join(' ');

    String? home = nameOf(homeRaw);
    String? away = nameOf(awayRaw);
    int? hs = scoreOf(pick(_homeScoreKeys)) ?? (homeRaw is Map ? scoreOf(homeRaw) : null);
    int? as = scoreOf(pick(_awayScoreKeys)) ?? (awayRaw is Map ? scoreOf(awayRaw) : null);

    if ((home == null || away == null) && type.contains('event') && title.isNotEmpty) {
      final fromTitle = _fromFlatText(title);
      if (fromTitle != null) {
        home = fromTitle.homeTeam;
        away = fromTitle.awayTeam;
        hs ??= fromTitle.homeScore;
        as ??= fromTitle.awayScore;
      }
    }
    if (home == null || away == null) return null;
    home = _teamName(home);
    away = _teamName(away);
    if (!_isTeam(home) || !_isTeam(away) || normalize(home) == normalize(away)) return null;

    final hasScore = hs != null && as != null && hs <= 250 && as <= 250;
    final statusRaw = pick(_statusKeys);
    var status = statusOf('${statusRaw ?? ''} $extra', hasScore: hasScore);
    if (hasScore && hs == 0 && as == 0 && status == 'FINAL') status = 'AGENDADO';

    DateTime? when;
    final dateRaw = pick(_dateKeys);
    if (dateRaw is num) {
      final v = dateRaw.toInt();
      when = DateTime.fromMillisecondsSinceEpoch(v > 100000000000 ? v : v * 1000);
    } else if (dateRaw != null) {
      final s = dateRaw.toString();
      final iso = DateTime.tryParse(s);
      when = iso != null ? (iso.isUtc ? iso.toLocal() : iso) : dateTimeOf('$s ${pick(_timeKeys) ?? ''}', reference);
      if (iso != null && iso.hour == 0 && iso.minute == 0 && pick(_timeKeys) != null) {
        final t = RegExp(r'(\d{1,2})[:h](\d{2})').firstMatch(pick(_timeKeys).toString());
        if (t != null) when = DateTime(iso.year, iso.month, iso.day, int.parse(t.group(1)!), int.parse(t.group(2)!));
      }
    }

    final venueRaw = pick(_venueKeys);
    final venue = venueRaw is Map ? (nameOf(venueRaw) ?? '') : (venueRaw?.toString() ?? '');

    return ParsedGame(
      homeTeam: home,
      awayTeam: away,
      homeScore: hasScore && status != 'AGENDADO' ? hs : null,
      awayScore: hasScore && status != 'AGENDADO' ? as : null,
      status: status,
      competition: competitionOf(extra),
      venue: clean(venue),
      scheduledAt: when,
    );
  }

  // ---------------------------------------------------------------- UTIL

  static String clean(String input) => input.replaceAll(RegExp(r'[\s ]+'), ' ').trim();

  static const _accents = 'áàâãäåçéèêëíìîïñóòôõöúùûüýÿ';
  static const _plain = 'aaaaaaceeeeiiiinooooouuuuyy';

  /// Minúsculas, sem acentos e sem pontuação: "Tupã/Monstrinho" → "tupa monstrinho".
  static String normalize(String input) {
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      final i = _accents.indexOf(ch);
      buffer.write(i >= 0 ? _plain[i] : ch);
    }
    return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  /// Id estável e idêntico em Android, iOS, desktop e Web.
  static String stableId(String league, List<String> parts) {
    final key = normalize(parts.join('|'));
    var h1 = 7;
    var h2 = 11;
    for (final c in key.codeUnits) {
      h1 = (h1 * 31 + c) % 2147483647;
      h2 = (h2 * 131 + c) % 1000000007;
    }
    return '${league.toLowerCase()}_${h1.toRadixString(36)}${h2.toRadixString(36)}';
  }
}

class _Collector {
  final Map<String, ParsedGame> _byKey = {};

  void add(ParsedGame g) {
    final pair = '${ScheduleParser.normalize(g.homeTeam)}|${ScheduleParser.normalize(g.awayTeam)}';
    final day = g.scheduledAt == null ? '' : '${g.scheduledAt!.year}-${g.scheduledAt!.month}-${g.scheduledAt!.day}';
    final exact = '$pair|$day';
    if (_byKey.containsKey(exact)) {
      _byKey[exact] = _byKey[exact]!.merge(g);
      return;
    }
    // Mesmo confronto, um registro com data e outro sem: é o mesmo jogo.
    final undated = '$pair|';
    if (day.isNotEmpty && _byKey.containsKey(undated)) {
      _byKey[exact] = g.merge(_byKey.remove(undated)!);
      return;
    }
    if (day.isEmpty) {
      final dated = _byKey.keys.where((k) => k.startsWith(undated) && k != undated).toList();
      if (dated.length == 1) {
        _byKey[dated.first] = _byKey[dated.first]!.merge(g);
        return;
      }
    }
    _byKey[exact] = g;
  }

  /// Ao vivo → próximos (mais cedo primeiro) → resultados (mais recentes primeiro) → sem data.
  List<ParsedGame> sorted(DateTime reference) {
    final today = DateTime(reference.year, reference.month, reference.day);
    int bucket(ParsedGame g) {
      if (g.status == 'AO VIVO') return 0;
      final d = g.scheduledAt;
      if (d == null) return 3;
      return d.isBefore(today) || (g.hasScore && !d.isAfter(reference)) ? 2 : 1;
    }

    final list = _byKey.values.toList();
    list.sort((a, b) {
      final ba = bucket(a), bb = bucket(b);
      if (ba != bb) return ba.compareTo(bb);
      if (ba == 1) return a.scheduledAt!.compareTo(b.scheduledAt!);
      if (ba == 2) return b.scheduledAt!.compareTo(a.scheduledAt!);
      return 0;
    });
    return list;
  }
}
