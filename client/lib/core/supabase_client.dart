import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://gcbgaftpqyhdiizmxpjh.supabase.co', // Production
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdjYmdhZnRwcXloZGlpem14cGpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NzE5NTYsImV4cCI6MjEwMTM0Nzk1Nn0.30qVS5Blqz2TFUlfoT_4svWOL8toGB5jp58j2ASUH8w',
);

Future<void> initSupabase() async {
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
}

SupabaseClient get supabase => Supabase.instance.client;
