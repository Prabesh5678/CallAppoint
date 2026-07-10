import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://<project-ref>.supabase.co';
const supabaseAnonKey = '<your-anon-key>';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;