import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String _database = '(default)';
const String _generalType = 'general';
const String _advisorRole = 'advisor';

Future<void> main(List<String> args) async {
  final _Options options = _Options.parse(args);
  if (options.help) {
    _printUsage();
    return;
  }

  final String projectId = options.projectId ?? _projectIdFromFirebaseRc();
  if (projectId.isEmpty) {
    stderr.writeln(
      'Missing Firebase project id. Pass --project-id=<id> or configure .firebaserc.',
    );
    exitCode = 64;
    return;
  }

  final String accessToken =
      options.accessToken ??
      Platform.environment['GOOGLE_OAUTH_ACCESS_TOKEN'] ??
      '';
  if (accessToken.isEmpty) {
    stderr.writeln(
      'Missing OAuth token. Set GOOGLE_OAUTH_ACCESS_TOKEN or pass --access-token=<token>.',
    );
    exitCode = 64;
    return;
  }

  final _FirestoreRest firestore = _FirestoreRest(
    projectId: projectId,
    accessToken: accessToken,
  );
  final List<_Doc> colleges = await firestore.listDocuments('colleges');
  var changed = 0;
  var skipped = 0;

  stdout.writeln(
    'Scanning ${colleges.length} college(s) in project "$projectId" '
    '${options.apply ? 'with writes enabled.' : 'as a dry run.'}',
  );

  for (final _Doc college in colleges) {
    final List<_Doc> groups = await firestore.listDocuments(
      'colleges/${college.id}/groups',
    );
    for (final _Doc group in groups) {
      if (group.stringField('type') != _generalType) continue;

      final String dept = group.stringField('dept');
      final String batch = group.stringField('batch');
      if (dept.isEmpty || batch.isEmpty) {
        skipped++;
        stdout.writeln(
          'SKIP ${group.path}: missing dept/batch, admins=${group.stringArrayField('admins')}',
        );
        continue;
      }

      final List<_Doc> advisors = await firestore.findUsers(
        collegeId: college.id,
        role: _advisorRole,
        dept: dept,
        batch: batch,
      );
      if (advisors.isEmpty) {
        skipped++;
        stdout.writeln(
          'SKIP ${group.path}: no advisor user found for dept="$dept", batch="$batch".',
        );
        continue;
      }
      if (advisors.length > 1) {
        skipped++;
        stdout.writeln(
          'SKIP ${group.path}: multiple advisors found for dept="$dept", batch="$batch": '
          '${advisors.map((_Doc advisor) => advisor.id).join(', ')}.',
        );
        continue;
      }

      final List<String> oldAdmins = group.stringArrayField('admins');
      final List<String> newAdmins = <String>[advisors.single.id];
      if (_sameStringList(oldAdmins, newAdmins)) continue;

      changed++;
      stdout.writeln(
        '${options.apply ? 'UPDATE' : 'DRY-RUN'} ${group.path}: '
        'admins $oldAdmins -> $newAdmins',
      );
      if (options.apply) {
        await firestore.updateAdmins(group.path, newAdmins);
      }
    }
  }

  stdout.writeln(
    'Done. ${options.apply ? 'Changed' : 'Would change'} $changed group(s); '
    'skipped $skipped group(s).',
  );
}

bool _sameStringList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _projectIdFromFirebaseRc() {
  final File file = File('.firebaserc');
  if (!file.existsSync()) return '';
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) return '';
  final Object? projects = decoded['projects'];
  if (projects is! Map<String, dynamic>) return '';
  return projects['default'] as String? ?? '';
}

void _printUsage() {
  stdout.writeln('''
Repairs corrupted admins arrays on General groups.

Dry run:
  GOOGLE_OAUTH_ACCESS_TOKEN="\$(gcloud auth print-access-token)" dart run tool/repair_general_group_admins.dart

Apply:
  GOOGLE_OAUTH_ACCESS_TOKEN="\$(gcloud auth print-access-token)" dart run tool/repair_general_group_admins.dart --apply

Options:
  --project-id=<id>       Firebase project id. Defaults to .firebaserc projects.default.
  --access-token=<token>  OAuth token. Defaults to GOOGLE_OAUTH_ACCESS_TOKEN.
  --apply                 Write changes. Without this, the script only logs changes.
  --help                  Show this help.

The script skips groups with zero advisors or multiple advisor users for the same dept/batch.
It only updates the admins field and leaves mutedMembers and all other fields untouched.
''');
}

class _Options {
  const _Options({
    required this.apply,
    required this.help,
    this.projectId,
    this.accessToken,
  });

  final bool apply;
  final bool help;
  final String? projectId;
  final String? accessToken;

  factory _Options.parse(List<String> args) {
    var apply = false;
    var help = false;
    String? projectId;
    String? accessToken;

    for (final String arg in args) {
      if (arg == '--apply') {
        apply = true;
      } else if (arg == '--help' || arg == '-h') {
        help = true;
      } else if (arg.startsWith('--project-id=')) {
        projectId = arg.substring('--project-id='.length);
      } else if (arg.startsWith('--access-token=')) {
        accessToken = arg.substring('--access-token='.length);
      } else {
        stderr.writeln('Unknown option: $arg');
        help = true;
      }
    }

    return _Options(
      apply: apply,
      help: help,
      projectId: projectId,
      accessToken: accessToken,
    );
  }
}

class _FirestoreRest {
  _FirestoreRest({
    required this.projectId,
    required this.accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String projectId;
  final String accessToken;
  final http.Client _client;

  String get _base =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/$_database/documents';

  Future<List<_Doc>> listDocuments(String parentPath) async {
    final List<_Doc> docs = <_Doc>[];
    String? pageToken;
    do {
      final Uri uri = Uri.parse('$_base/$parentPath').replace(
        queryParameters: <String, String>{
          'pageSize': '300',
          'pageToken': ?pageToken,
        },
      );
      final Map<String, dynamic> body = await _getJson(uri);
      final Object? documents = body['documents'];
      if (documents is List<dynamic>) {
        docs.addAll(
          documents.whereType<Map<String, dynamic>>().map(
            _Doc.fromRestDocument,
          ),
        );
      }
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return docs;
  }

  Future<List<_Doc>> findUsers({
    required String collegeId,
    required String role,
    required String dept,
    required String batch,
  }) async {
    final Uri uri = Uri.parse('$_base/colleges/$collegeId:runQuery');
    final Map<String, dynamic> response = await _postJson(
      uri,
      <String, dynamic>{
        'structuredQuery': <String, dynamic>{
          'from': <Map<String, dynamic>>[
            <String, dynamic>{'collectionId': 'users'},
          ],
          'where': <String, dynamic>{
            'compositeFilter': <String, dynamic>{
              'op': 'AND',
              'filters': <Map<String, dynamic>>[
                _equalFilter('role', role),
                _equalFilter('dept', dept),
                _equalFilter('batch', batch),
              ],
            },
          },
        },
      },
    );

    final Object? rows = response['rows'];
    if (rows is! List<dynamic>) return <_Doc>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> row) => row['document'])
        .whereType<Map<String, dynamic>>()
        .map(_Doc.fromRestDocument)
        .toList();
  }

  Future<void> updateAdmins(String documentPath, List<String> admins) async {
    final Uri uri = Uri.parse('$_base/$documentPath').replace(
      queryParameters: <String, String>{'updateMask.fieldPaths': 'admins'},
    );
    await _patchJson(uri, <String, dynamic>{
      'fields': <String, dynamic>{
        'admins': <String, dynamic>{
          'arrayValue': <String, dynamic>{
            'values': admins
                .map((String uid) => <String, dynamic>{'stringValue': uid})
                .toList(),
          },
        },
      },
    });
  }

  Map<String, dynamic> _equalFilter(String field, String value) {
    return <String, dynamic>{
      'fieldFilter': <String, dynamic>{
        'field': <String, dynamic>{'fieldPath': field},
        'op': 'EQUAL',
        'value': <String, dynamic>{'stringValue': value},
      },
    };
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response = await _client.get(uri, headers: _headers);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final http.Response response = await _client.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    return <String, dynamic>{'rows': _decodeArray(response)};
  }

  Future<void> _patchJson(Uri uri, Map<String, dynamic> body) async {
    final http.Response response = await _client.patch(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    _checkSuccess(response);
  }

  Map<String, String> get _headers => <String, String>{
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  Map<String, dynamic> _decodeObject(http.Response response) {
    _checkSuccess(response);
    if (response.body.isEmpty) return <String, dynamic>{};
    final Object? decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('Expected JSON object from ${response.request?.url}');
  }

  List<dynamic> _decodeArray(http.Response response) {
    _checkSuccess(response);
    if (response.body.isEmpty) return <dynamic>[];
    final Object? decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) return decoded;
    throw FormatException('Expected JSON array from ${response.request?.url}');
  }

  void _checkSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw HttpException(
      'Firestore REST request failed (${response.statusCode}): ${response.body}',
      uri: response.request?.url,
    );
  }
}

class _Doc {
  const _Doc({required this.path, required this.fields});

  final String path;
  final Map<String, dynamic> fields;

  String get id => path.split('/').last;

  factory _Doc.fromRestDocument(Map<String, dynamic> document) {
    final String name = document['name'] as String? ?? '';
    final String marker = '/documents/';
    final int markerIndex = name.indexOf(marker);
    final String path = markerIndex == -1
        ? name
        : name.substring(markerIndex + marker.length);
    return _Doc(
      path: path,
      fields:
          (document['fields'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  String stringField(String field) {
    final Object? value = fields[field];
    if (value is! Map<String, dynamic>) return '';
    return value['stringValue'] as String? ?? '';
  }

  List<String> stringArrayField(String field) {
    final Object? value = fields[field];
    if (value is! Map<String, dynamic>) return <String>[];
    final Object? arrayValue = value['arrayValue'];
    if (arrayValue is! Map<String, dynamic>) return <String>[];
    final Object? values = arrayValue['values'];
    if (values is! List<dynamic>) return <String>[];
    return values
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> item) => item['stringValue'] as String?)
        .whereType<String>()
        .toList();
  }
}
