import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://oowtlsxswfunufarhnpn.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vd3Rsc3hzd2Z1bnVmYXJobnBuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1MjU1ODEsImV4cCI6MjA5OTEwMTU4MX0.LGec5R29z1QU9QGL0w0EUrpMeKxS2zKTeoNK1aMFsgc';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;