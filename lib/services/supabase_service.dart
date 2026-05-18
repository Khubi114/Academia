import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  final SupabaseClient client = Supabase.instance.client;

  String get userId {
    final user = client.auth.currentUser;
    if (user == null) {
      // In a real app we'd redirect to login, but for the demo we'll use a dummy UUID if auth isn't fully setup
      // Note: Ideally throw Exception('User not authenticated'); 
      return '00000000-0000-0000-0000-000000000000'; // dummy fallback
    }
    return user.id;
  }
}
