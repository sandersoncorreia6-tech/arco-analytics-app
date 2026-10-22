import 'dart:convert';
import 'dart:io';

import 'package:arco_analytics/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app abre, faz login demo e navega pelas abas sem erros', (tester) async {
    // Sem rede no teste: qualquer requisição falha como no aparelho offline.
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      await tester.pumpWidget(const ArcoApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Entrar como Adriano Mião (demo)'), findsOneWidget);
      await tester.tap(find.text('Entrar como Adriano Mião (demo)'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Olá, Adriano'), findsOneWidget);

      for (final tab in ['Ligas', 'Stats', 'Equipe', 'Analytics', 'Mais', 'Home']) {
        await tester.tap(find.text(tab).last);
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.tap(find.text('Ligas').last);
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('FPB •'), findsWidgets);
      expect(find.textContaining('LBC •'), findsWidgets);
    }, () => _OfflineClient());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('jogos da FPB e LBC chegam à agenda e ao painel da equipe', (tester) async {
    SharedPreferences.setMockInitialValues({'coach_logged_in_v1': true});
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      await tester.pumpWidget(const ArcoApp());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Olá, Adriano'), findsOneWidget);
      // O jogo ao vivo da equipe (Tupã, FPB) é destacado na Home.
      await tester.scrollUntilVisible(find.text('Marília'), 200, scrollable: find.byType(Scrollable).hitTestable().first);
      expect(find.text('Tupã'), findsWidgets);

      await tester.tap(find.text('Ligas').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('FPB • 1 jogo • 1 ao vivo'), findsOneWidget);
      expect(find.textContaining('LBC • 1 jogo'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Marília'), 200, scrollable: find.byType(Scrollable).hitTestable().first);
      expect(find.text('AO VIVO'), findsWidgets);

      // Tela da liga abre a partir do cartão de status.
      await tester.scrollUntilVisible(find.textContaining('FPB • 1 jogo'), -200, scrollable: find.byType(Scrollable).hitTestable().first);
      await tester.tap(find.textContaining('FPB • 1 jogo'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      expect(find.text('FPB • jogos'), findsOneWidget);
    }, () => _FakeLeagueClient());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('estatística online: descobre a partida, importa equipes, jogadores e mapa', (tester) async {
    SharedPreferences.setMockInitialValues({'coach_logged_in_v1': true});
    final data = File('test/fixtures/fiba_livestats_data.json').readAsStringSync();
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(const ArcoApp());
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Home mostra a equipe do treinador com estatística importada.
      await tester.scrollUntilVisible(find.text('Associação Tupã Basquete'), 200, scrollable: find.byType(Scrollable).hitTestable().first);
      expect(find.textContaining('1 J • 1V 0D'), findsOneWidget);

      await tester.tap(find.text('Stats').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('2 equipes • 3 jogadores • 1 jogos'), findsOneWidget);

      await tester.tap(find.text('Associação Tupã Basquete').first);
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      expect(find.text('Médias por jogo'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Pedro Almeida'), 300, scrollable: find.byType(Scrollable).hitTestable().first);
      expect(find.textContaining('3 arremessos'), findsOneWidget);
    }, () => _StatsClient(data));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}

class _FakeLeagueClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final host = request.url.host;
    final body = host.contains('lbc')
        ? '<table><tr><td>25/10/2026 20:00</td><td>Monstrinho</td><td>x</td><td>Lins</td><td>Sub 15</td></tr></table>'
        : request.url.path.contains('online')
        ? '<ul><li class="match"><span>Tupã</span><b>45</b><span>Marília</span><b>40</b><i>3º Quarto</i></li></ul>'
        : '<html><body><nav><li>Home</li></nav></body></html>';
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200, headers: {'content-type': 'text/html; charset=utf-8'});
  }
}

class _OfflineClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async => throw http.ClientException('Failed host lookup: ${request.url.host}', request.url);
}

class _StatsClient extends http.BaseClient {
  final String data;
  _StatsClient(this.data);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    final body = url.contains('geniussports.com/data/2512345')
        ? data
        : url.contains('wp-json')
        ? '[]'
        : url.contains('fpb.com.br/online')
        ? '<a href="https://fibalivestats.dcd.shared.geniussports.com/u/FPB/2512345/">Estatística</a>'
        : '<html></html>';
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
  }
}
