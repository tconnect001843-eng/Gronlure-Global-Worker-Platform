import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glonlure_platform/main.dart';
import 'package:glonlure_platform/src/api_client.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Login and registration screens are connected', (tester) async {
    await tester.pumpWidget(
      GronlureApp(api: PlatformApi(baseUrl: 'http://localhost/api')),
    );

    expect(find.text('Gronlure'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(
      find.text('I agree to the Terms of Service and Privacy Policy'),
      findsOneWidget,
    );
  });

  testWidgets('Theme preference and password visibility can be changed', (
    tester,
  ) async {
    await tester.pumpWidget(
      GronlureApp(api: PlatformApi(baseUrl: 'http://localhost/api')),
    );
    await tester.tap(find.byTooltip('Switch to dark theme'));
    await tester.pumpAndSettle();

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(
      app.darkTheme!.inputDecorationTheme.fillColor,
      const Color(0xFF202A23),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('gronlure_dark_theme'), isTrue);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    final passwordField = find.byType(TextFormField).at(2);
    final confirmField = find.byType(TextFormField).at(3);
    expect(_isObscured(tester, passwordField), isTrue);
    expect(_isObscured(tester, confirmField), isTrue);

    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(_isObscured(tester, passwordField), isFalse);
    expect(_isObscured(tester, confirmField), isTrue);

    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(_isObscured(tester, confirmField), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      GronlureApp(api: PlatformApi(baseUrl: 'http://localhost/api')),
    );
    await tester.pumpAndSettle();
    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('Successful login opens the profile dashboard without overflow', (
    tester,
  ) async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/login'));
      return http.Response(
        jsonEncode({
          'token': 'a' * 64,
          'profile': {
            'full_name': 'Ada Worker',
            'phone': '+256700000001',
            'role': 'user',
            'public_id': 'UGW-1234ABCD',
            'verification_status': 'pending',
            'completed_jobs': 0,
            'skills': '',
            'location': '',
            'headline': '',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(GronlureApp(api: PlatformApi(client: client)));
    await tester.enterText(find.byType(TextFormField).at(0), '+256700000001');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Ada'), findsOneWidget);
    expect(find.text('Verification pending'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch to dark theme'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Any signed-in user can validate and publish a job', (
    tester,
  ) async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({
            'token': 'test-token',
            'profile': {
              'full_name': 'Ada Worker',
              'phone': '+256700000001',
              'role': 'user',
              'public_id': 'UGW-1234ABCD',
              'verification_status': 'pending',
              'completed_jobs': 0,
              'skills': '',
              'location': '',
              'headline': '',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' && request.url.path.endsWith('/jobs')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'Solar installation');
        expect(body['skill'], 'Solar technician');
        expect(body['location'], 'Kampala');
        expect(body['budget_ugx'], 150000);
        return http.Response(
          jsonEncode({
            'job': {'id': 5},
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/jobs/mine')) {
        return http.Response(
          jsonEncode({
            'jobs': [
              {
                'id': 5,
                'title': 'Solar installation',
                'description': 'Install solar panels at a home.',
                'skill': 'Solar technician',
                'location': 'Kampala',
                'budget_ugx': 150000,
                'status': 'open',
                'application_count': 0,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'jobs': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(GronlureApp(api: PlatformApi(client: client)));
    await tester.enterText(find.byType(TextFormField).at(0), '+256700000001');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Post a job').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post a job').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish job'));
    await tester.pumpAndSettle();
    expect(find.text('Job title is required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('job-title')),
      'Solar installation',
    );
    await tester.enterText(
      find.byKey(const ValueKey('job-skill')),
      'Solar technician',
    );
    await tester.enterText(
      find.byKey(const ValueKey('job-location')),
      'Kampala',
    );
    await tester.enterText(
      find.byKey(const ValueKey('job-description')),
      'Install solar panels at a home.',
    );
    await tester.enterText(find.byKey(const ValueKey('job-budget')), '150000');
    await tester.tap(find.text('Publish job'));
    await tester.pumpAndSettle();

    expect(find.text('Jobs & hires'), findsOneWidget);
    expect(find.text('Solar installation'), findsOneWidget);
    expect(
      requests.any(
        (request) => request.startsWith('POST ') && request.endsWith('/jobs'),
      ),
      isTrue,
    );
    expect(
      requests.any(
        (request) =>
            request.startsWith('GET ') && request.endsWith('/jobs/mine'),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

bool _isObscured(WidgetTester tester, Finder formField) {
  final textField = find.descendant(
    of: formField,
    matching: find.byType(TextField),
  );
  return tester.widget<TextField>(textField).obscureText;
}
