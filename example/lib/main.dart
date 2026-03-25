import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/generated/api.dart';

void main() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://petstore3.swagger.io/api/v3',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        petApiClientProvider.overrideWithValue(PetApiClient(dio)),
      ],
      child: const PetstoreApp(),
    ),
  );
}

class PetstoreApp extends StatelessWidget {
  const PetstoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Florval Petstore Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const PetstoreHomePage(),
    );
  }
}

class PetstoreHomePage extends ConsumerStatefulWidget {
  const PetstoreHomePage({super.key});

  @override
  ConsumerState<PetstoreHomePage> createState() => _PetstoreHomePageState();
}

class _PetstoreHomePageState extends ConsumerState<PetstoreHomePage> {
  final _logBuffer = <String>[];
  bool _isRunning = false;

  void _log(String message) {
    setState(() {
      _logBuffer.add(message);
    });
  }

  Future<void> _runVerification() async {
    setState(() {
      _logBuffer.clear();
      _isRunning = true;
    });

    final client = ref.read(petApiClientProvider);

    // --- Test 1: GET /pet/findByStatus ---
    _log('=== Test 1: GET /pet/findByStatus ===');
    try {
      final findResponse = await client.findPetsByStatus(status: 'available');
      switch (findResponse) {
        case FindPetsByStatusResponseSuccess(:final data):
          _log('SUCCESS: Found ${data.length} pets');
          if (data.isNotEmpty) {
            _log('  First pet: ${data.first.name} (id: ${data.first.id})');
          }
        case FindPetsByStatusResponseBadRequest():
          _log('BAD REQUEST: Invalid status value');
        case FindPetsByStatusResponseUnknown(:final statusCode, :final body):
          _log('UNKNOWN: status=$statusCode body=$body');
      }
    } catch (e) {
      _log('ERROR: $e');
    }

    // --- Test 2: POST /pet ---
    _log('');
    _log('=== Test 2: POST /pet (Add new pet) ===');
    int? createdPetId;
    try {
      final newPet = Pet(
        name: 'Florval Test Dog',
        photoUrls: ['https://example.com/dog.jpg'],
        status: 'available',
      );
      final addResponse = await client.addPet(body: newPet);
      switch (addResponse) {
        case AddPetResponseSuccess(:final data):
          createdPetId = data.id;
          _log('SUCCESS: Created pet "${data.name}" (id: ${data.id})');
        case AddPetResponseBadRequest():
          _log('BAD REQUEST: Invalid input');
        case AddPetResponseUnprocessableEntity():
          _log('UNPROCESSABLE: Validation exception');
        case AddPetResponseUnknown(:final statusCode, :final body):
          _log('UNKNOWN: status=$statusCode body=$body');
      }
    } catch (e) {
      _log('ERROR: $e');
    }

    // --- Test 3: GET /pet/{petId} (success) ---
    _log('');
    _log('=== Test 3: GET /pet/{petId} (existing pet) ===');
    final testPetId = createdPetId ?? 1;
    try {
      final getResponse = await client.getPetById(petId: testPetId);
      switch (getResponse) {
        case GetPetByIdResponseSuccess(:final data):
          _log('SUCCESS: Found pet "${data.name}" (id: ${data.id})');
          _log('  Status: ${data.status ?? "unknown"}');
          _log('  Category: ${data.category?.name ?? "none"}');
        case GetPetByIdResponseBadRequest():
          _log('BAD REQUEST: Invalid ID supplied');
        case GetPetByIdResponseNotFound():
          _log('NOT FOUND: Pet $testPetId does not exist');
        case GetPetByIdResponseUnknown(:final statusCode, :final body):
          _log('UNKNOWN: status=$statusCode body=$body');
      }
    } catch (e) {
      _log('ERROR: $e');
    }

    // --- Test 4: GET /pet/{petId} (404 - non-existent) ---
    _log('');
    _log('=== Test 4: GET /pet/{petId} (non-existent pet) ===');
    try {
      final notFoundResponse = await client.getPetById(petId: 999999999);
      switch (notFoundResponse) {
        case GetPetByIdResponseSuccess(:final data):
          _log('SUCCESS (unexpected): Found pet "${data.name}"');
        case GetPetByIdResponseBadRequest():
          _log('BAD REQUEST: Invalid ID supplied');
        case GetPetByIdResponseNotFound():
          _log('NOT FOUND (expected): Pet 999999999 does not exist');
        case GetPetByIdResponseUnknown(:final statusCode, :final body):
          _log('UNKNOWN: status=$statusCode body=$body');
      }
    } catch (e) {
      _log('ERROR: $e');
    }

    // --- Test 5: DELETE /pet/{petId} ---
    _log('');
    _log('=== Test 5: DELETE /pet/{petId} ===');
    if (createdPetId != null) {
      try {
        final deleteResponse = await client.deletePet(petId: createdPetId);
        switch (deleteResponse) {
          case DeletePetResponseSuccess():
            _log('SUCCESS: Deleted pet $createdPetId');
          case DeletePetResponseBadRequest():
            _log('BAD REQUEST: Invalid pet value');
          case DeletePetResponseNotFound():
            _log('NOT FOUND: Pet $createdPetId already deleted');
          case DeletePetResponseUnknown(:final statusCode, :final body):
            _log('UNKNOWN: status=$statusCode body=$body');
        }
      } catch (e) {
        _log('ERROR: $e');
      }
    } else {
      _log('SKIPPED: No pet was created to delete');
    }

    _log('');
    _log('=== Verification Complete ===');

    setState(() {
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Florval Petstore Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _isRunning ? null : _runVerification,
              child: Text(_isRunning ? 'Running...' : 'Run Verification'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _logBuffer.isEmpty
                        ? 'Press "Run Verification" to start...'
                        : _logBuffer.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
