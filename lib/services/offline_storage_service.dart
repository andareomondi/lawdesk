// File: lib/services/offline_storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineStorageService {
  static final OfflineStorageService _instance =
      OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  static const String _casesCacheKey = 'cached_cases';
  static const String _profileCacheKey = 'cached_profile';
  static const String _statsCacheKey = 'cached_stats';
  static const String _documentsCacheKey = 'cached_documents';
  static const String _eventsCacheKey = 'cached_events';
  static const String _notesCacheKey = 'cached_notes';
  static const String _clientsCacheKey = 'cached_clients';
  static const String _billingCacheKey = 'cached_billing';
  static const String _lastSyncKey = 'last_sync_time';

  // Save events to local storage
  Future<void> cacheEvents(List<dynamic> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(events);
      await prefs.setString(_eventsCacheKey, jsonString);
      await _updateLastSyncTime();
      print('Successfully cached ${events.length} events');
    } catch (e) {
      print('Error caching events: $e');
    }
  }

  // Get cached events
  Future<List<dynamic>?> getCachedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_eventsCacheKey);
      if (jsonString != null) {
        return jsonDecode(jsonString) as List<dynamic>;
      }
    } catch (e) {
      print('Error getting cached events: $e');
    }
    return null;
  }

  // Save cases to local storage
  Future<void> cacheCases(List<dynamic> cases) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(cases);
      await prefs.setString(_casesCacheKey, jsonString);
      await _updateLastSyncTime();
      print('Successfully cached ${cases.length} cases');
    } catch (e) {
      print('Error caching cases: $e');
    }
  }

  // Get cached cases
  Future<List<dynamic>?> getCachedCases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_casesCacheKey);
      if (jsonString != null) {
        return jsonDecode(jsonString) as List<dynamic>;
      }
    } catch (e) {
      print('Error getting cached cases: $e');
    }
    return null;
  }

  // Save documents to local storage
  Future<void> cacheDocuments(List<dynamic> documents) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(documents);
      await prefs.setString(_documentsCacheKey, jsonString);
      await _updateLastSyncTime();
      print('Successfully cached ${documents.length} documents');
    } catch (e) {
      print('Error caching documents: $e');
    }
  }

  // Get cached documents
  Future<List<dynamic>?> getCachedDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_documentsCacheKey);
      if (jsonString != null) {
        return jsonDecode(jsonString) as List<dynamic>;
      }
    } catch (e) {
      print('Error getting cached documents: $e');
    }
    return null;
  }

  // Save profile to local storage
  Future<void> cacheProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(profile);
      await prefs.setString(_profileCacheKey, jsonString);
      await _updateLastSyncTime();
    } catch (e) {
      print('Error caching profile: $e');
    }
  }

  // Get cached profile
  Future<Map<String, dynamic>?> getCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_profileCacheKey);
      if (jsonString != null) {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting cached profile: $e');
    }
    return null;
  }

  // Save stats to local storage
  Future<void> cacheStats(Map<String, dynamic> stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(stats);
      await prefs.setString(_statsCacheKey, jsonString);
    } catch (e) {
      print('Error caching stats: $e');
    }
  }

  // Get cached stats
  Future<Map<String, dynamic>?> getCachedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_statsCacheKey);
      if (jsonString != null) {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting cached stats: $e');
    }
    return null;
  }

  // cached notes
  Future<void> cacheNotes(List<dynamic> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(notes);
      await prefs.setString(_notesCacheKey, jsonString);
      await _updateLastSyncTime();
      print('Successfully cached ${notes.length} notes');
    } catch (e) {
      print('Error caching notes: $e');
    }
  }

  // Get cached notes
  Future<List<dynamic>?> getCachedNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_notesCacheKey);
      if (jsonString != null) {
        return jsonDecode(jsonString) as List<dynamic>;
      }
    } catch (e) {
      print('Error getting cached notes: $e');
    }
    return null;
  }

  // cached clients
  Future<void> cacheClients(List<dynamic> clients) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(clients);
      await prefs.setString(_clientsCacheKey, jsonString);
      await _updateLastSyncTime();
      print('Successfully cached ${clients.length} clients');
    } catch (e) {
      print('Error caching clients: $e');
    }
  }

  // Get cached clients
  Future<List<dynamic>?> getCachedClients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_clientsCacheKey);
      if (jsonString != null) {
        return jsonDecode(jsonString) as List<dynamic>;
      }
    } catch (e) {
      print('Error getting cached clients: $e');
    }
    return null;
  }

  // Update last sync time
  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  // Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString(_lastSyncKey);
      if (timeString != null) {
        return DateTime.parse(timeString);
      }
    } catch (e) {
      print('Error getting last sync time: $e');
    }
    return null;
  }

  Future<void> cacheBilling(List<dynamic> billing) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(billing);
      await prefs.setString(_billingCacheKey, jsonString);
      await _updateLastSyncTime();
      print('Successfully cached ${billing.length} billing records');
    } catch (e) {
      print('Error caching billing: $e');
    }
  }

  Future<List<dynamic>?> getCachedBilling() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_billingCacheKey);
      if (jsonString != null) {
        return jsonDecode(jsonString) as List<dynamic>;
      }
    } catch (e) {
      print('Error getting cached billing: $e');
    }
    return null;
  }

  Future<void> synchronizeAllData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      print('Starting full data synchronization...');
      final supabase = Supabase.instance.client;

      // 1. Fetch and Cache Clients
      final clientsResponse = await supabase
          .from('clients')
          .select()
          .eq('user', user.id)
          .order('created_at', ascending: false);
      await cacheClients(clientsResponse);

      // 2. Fetch and Cache All Cases
      final casesResponse = await supabase
          .from('cases')
          .select()
          .eq('user', user.id);
      await cacheCases(casesResponse);

      if (casesResponse.isNotEmpty) {
        final List<int> caseIds = List<int>.from(
          casesResponse.map((c) => c['id']),
        );

        // 3. Fetch and Cache All Events for these cases
        final eventsResponse = await supabase
            .from('events')
            .select()
            .inFilter('case', caseIds);
        await cacheEvents(eventsResponse);

        // 4. Fetch and Cache All Notes for these cases
        final notesResponse = await supabase
            .from('notes')
            .select()
            .inFilter('case', caseIds);
        await cacheNotes(notesResponse);

        // 5. Fetch and Cache All Billing for these cases
        final billingResponse = await supabase
            .from('case_billing')
            .select()
            .inFilter('case_id', caseIds);
        await cacheBilling(billingResponse);

        // 6. Fetch and Cache All Documents for these cases
        final documentsResponse = await supabase
            .from('documents')
            .select()
            .inFilter('case_id', caseIds);
        await cacheDocuments(documentsResponse);
      }

      print('Full synchronization completed successfully.');
    } catch (e) {
      print('Error during synchronization: $e');
    }
  }

  // Clear all cached data
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_casesCacheKey);
    await prefs.remove(_profileCacheKey);
    await prefs.remove(_statsCacheKey);
    await prefs.remove(_documentsCacheKey);
    await prefs.remove(_eventsCacheKey);
    await prefs.remove(_lastSyncKey);
  }
}

final offlineStorage = OfflineStorageService();
