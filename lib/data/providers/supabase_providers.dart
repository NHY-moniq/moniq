import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final goTrueClientProvider = Provider<GoTrueClient>(
  (ref) => ref.watch(supabaseClientProvider).auth,
);

final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(goTrueClientProvider).onAuthStateChange,
);
