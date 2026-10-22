import 'package:arco_analytics/services/schedule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = ScheduleParser(reference: DateTime(2026, 10, 22, 12));

  test('linhas de tabela com células separadas', () {
    const html = '''
      <table>
        <tr><th>Data</th><th>Mandante</th><th>Placar</th><th>Visitante</th></tr>
        <tr><td>22/10/2026 19:30</td><td>Tupã</td><td>78 x 65</td><td>Marília</td></tr>
        <tr><td>25/10</td><td>Bauru</td><td>x</td><td>Monstrinho Sub 17</td></tr>
      </table>''';
    final games = parser.parseHtml(html);
    expect(games, hasLength(2));
    final played = games.firstWhere((g) => g.homeTeam == 'Tupã');
    expect(played.awayTeam, 'Marília');
    expect(played.homeScore, 78);
    expect(played.awayScore, 65);
    expect(played.status, 'FINAL');
    expect(played.scheduledAt, DateTime(2026, 10, 22, 19, 30));
    final next = games.firstWhere((g) => g.homeTeam == 'Bauru');
    expect(next.awayTeam, 'Monstrinho Sub 17');
    expect(next.hasScore, isFalse);
    expect(next.status, 'AGENDADO');
    expect(next.competition, 'SUB 17');
    expect(next.scheduledAt, DateTime(2026, 10, 25));
  });

  test('cards com placar em elementos separados e logos', () {
    const html = '''
      <div class="game-card">
        <span class="category">SUB 17 M</span>
        <div class="team"><img alt="Logo Tupã" src="t.png"><span>Tupã</span></div>
        <div class="score">78</div><div class="score">65</div>
        <div class="team"><img alt="Marília"><span>Marília</span></div>
        <span class="status">Final</span>
      </div>''';
    final games = parser.parseHtml(html);
    expect(games, hasLength(1));
    expect(games.single.homeTeam, 'Tupã');
    expect(games.single.awayTeam, 'Marília');
    expect(games.single.homeScore, 78);
    expect(games.single.awayScore, 65);
    expect(games.single.competition, 'SUB 17 M');
  });

  test('placar ao lado de cada equipe', () {
    const html = '<ul><li class="match"><span>Sesi Franca</span><b>45</b><span>Paulistano</span><b>40</b><i>2º Quarto</i></li></ul>';
    final g = parser.parseHtml(html).single;
    expect(g.homeTeam, 'Sesi Franca');
    expect(g.awayTeam, 'Paulistano');
    expect(g.homeScore, 45);
    expect(g.awayScore, 40);
    expect(g.status, 'AO VIVO');
  });

  test('jogo ao vivo em texto corrido', () {
    final g = parser.parseHtml('<li>Sesi Franca 45 - 2º Quarto - Paulistano 40</li>').single;
    expect(g.homeTeam, 'Sesi Franca');
    expect(g.awayTeam, 'Paulistano');
    expect(g.homeScore, 45);
    expect(g.awayScore, 40);
    expect(g.status, 'AO VIVO');
  });

  test('JSON-LD schema.org SportsEvent', () {
    const html = '''
      <script type="application/ld+json">[{"@context":"https://schema.org","@type":"SportsEvent",
        "name":"Tupã x Marília - Sub 15 Feminino","startDate":"2026-10-25T19:30:00",
        "homeTeam":{"@type":"SportsTeam","name":"Tupã"},"awayTeam":{"name":"Marília"},
        "location":{"name":"Ginásio Municipal de Tupã"}}]</script>''';
    final g = parser.parseHtml(html).single;
    expect(g.homeTeam, 'Tupã');
    expect(g.awayTeam, 'Marília');
    expect(g.scheduledAt, DateTime(2026, 10, 25, 19, 30));
    expect(g.venue, 'Ginásio Municipal de Tupã');
    expect(g.competition, 'SUB 15 F');
    expect(g.status, 'AGENDADO');
  });

  test('JSON embutido de aplicativos (Next.js/APIs)', () {
    const html = '''
      <script id="__NEXT_DATA__" type="application/json">{"props":{"pageProps":{"jogos":[
        {"mandante":{"nome":"Lins"},"visitante":{"nome":"Tupã"},"placarMandante":70,"placarVisitante":72,
         "data":"21/10/2026","hora":"20:00","categoria":"Sub 19 Masculino","status":"Encerrado"}]}}}</script>''';
    final g = parser.parseHtml(html).single;
    expect(g.homeTeam, 'Lins');
    expect(g.awayTeam, 'Tupã');
    expect(g.homeScore, 70);
    expect(g.awayScore, 72);
    expect(g.competition, 'SUB 19 M');
    expect(g.scheduledAt, DateTime(2026, 10, 21, 20));
  });

  test('formatos do widget de resultados da FPB (Final / Round)', () {
    const html = '''
      <div class="game">Paulistano 78 Final Pinheiros 65</div>
      <div class="fixture"><div>Sesi Franca</div><div>Bauru Basket</div><div>Round 5</div><div>7:00 PM</div></div>''';
    final games = parser.parseHtml(html);
    expect(games, hasLength(2));
    final done = games.firstWhere((g) => g.homeTeam == 'Paulistano');
    expect(done.awayTeam, 'Pinheiros');
    expect(done.homeScore, 78);
    expect(done.awayScore, 65);
    expect(done.status, 'FINAL');
    final next = games.firstWhere((g) => g.homeTeam == 'Sesi Franca');
    expect(next.awayTeam, 'Bauru Basket');
    expect(next.status, 'AGENDADO');
  });

  test('não confunde menus e textos com jogos', () {
    const html = '''
      <ul><li>Home</li><li>Notícias</li><li>Contato</li><li>Classificação Sub 17 2026</li></ul>
      <p>O jogo terminou 78 a 65.</p>
      <div class="event">Inscrições abertas para 2027</div>''';
    expect(parser.parseHtml(html), isEmpty);
  });

  test('texto colado com um campo por linha', () {
    const text = '''
Campeonato Paulista Sub 17 Masculino
Rodada 3 - 22/10/2026
Tupã
78
x
65
Marília

Bauru Basket x Lins - 25/10 às 20h
22/10 19h30 Marília 50 x 61 Monstrinho Ginásio Municipal
''';
    final games = parser.parseText(text);
    expect(games, hasLength(3));
    final tupa = games.firstWhere((g) => g.homeTeam == 'Tupã');
    expect(tupa.awayTeam, 'Marília');
    expect(tupa.homeScore, 78);
    expect(tupa.awayScore, 65);
    expect(tupa.competition, 'SUB 17 M');
    final bauru = games.firstWhere((g) => g.homeTeam == 'Bauru Basket');
    expect(bauru.awayTeam, 'Lins');
    expect(bauru.scheduledAt, DateTime(2026, 10, 25, 20));
    final mar = games.firstWhere((g) => g.homeTeam == 'Marília');
    expect(mar.awayTeam, 'Monstrinho');
    expect(mar.homeScore, 50);
    expect(mar.awayScore, 61);
    expect(mar.venue, 'Ginásio Municipal');
  });

  test('ordenação: ao vivo, próximos, resultados', () {
    const text = '''
Tupã 70 x 60 Lins 10/10/2026
Bauru x Marília 30/10/2026
Franca x Tupã 24/10/2026
Sesi 30 x 28 Pinheiros ao vivo
''';
    final games = parser.parseText(text);
    expect(games.map((g) => g.homeTeam).toList(), ['Sesi', 'Franca', 'Bauru', 'Tupã']);
  });

  test('id estável e independente de acento/placar', () {
    final a = ScheduleParser.stableId('FPB', ['SUB 17', 'Tupã', 'Marília', '2026-10-22']);
    final b = ScheduleParser.stableId('FPB', ['SUB 17', 'Tupa', 'Marilia', '2026-10-22']);
    expect(a, b);
    expect(a.startsWith('fpb_'), isTrue);
  });

  test('notícia de programação/resultados da FPB (data no cabeçalho)', () {
    final p = ScheduleParser(reference: DateTime(2026, 4, 20));
    const html = '''
      <article><h2>Resultados disponíveis: confira os jogos da base</h2>
      <p><strong>Sábado – 18/04</strong></p>
      <p>S14F ATB – ASSOCIAÇÃO TUPÃ BASQUETE 91 x 23 APAGEBASK / GUARULHOS<br>
      S13M Double Votorantim Basket 40 x 64 Luso/Bauru</p>
      <p><strong>Domingo – 19/04</strong></p>
      <p>15:00 – S16M – Tupã x Sorocaba</p></article>''';
    final games = p.parseArticleHtml(html);
    expect(games, hasLength(3));
    final tupa = games.firstWhere((g) => g.awayTeam == 'APAGEBASK / GUARULHOS');
    expect(tupa.homeTeam, 'ATB – ASSOCIAÇÃO TUPÃ BASQUETE');
    expect(tupa.homeScore, 91);
    expect(tupa.awayScore, 23);
    expect(tupa.competition, 'SUB 14 F');
    expect(tupa.scheduledAt, DateTime(2026, 4, 18));
    final next = games.firstWhere((g) => g.awayTeam == 'Sorocaba');
    expect(next.homeTeam, 'Tupã');
    expect(next.competition, 'SUB 16 M');
    expect(next.scheduledAt, DateTime(2026, 4, 19, 15));
    expect(next.status, 'AGENDADO');
  });
}
