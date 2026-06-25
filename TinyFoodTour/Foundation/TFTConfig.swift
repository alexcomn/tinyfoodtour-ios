import Foundation

// MARK: - App-wide configuration
//
// TO MOVE TO XCCONFIG (before App Store submission):
//   1. Create TinyFoodTour/Config/Secrets.xcconfig (add to .gitignore)
//   2. Add to Secrets.xcconfig:
//        SUPABASE_URL = https://xefehzsclkefebzyqdrh.supabase.co
//        SUPABASE_ANON_KEY = eyJ...
//   3. In Xcode → Project → Info → Configurations, assign Secrets.xcconfig
//   4. In Info.plist, add keys SupabaseURL and SupabaseAnonKey referencing $(SUPABASE_URL) etc.
//   5. Replace the string literals below with:
//        Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as! String
//
// For now, values live here so the build works without xcconfig setup.

enum TFTConfig {
    static let supabaseURL     = "https://xefehzsclkefebzyqdrh.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlZmVoenNjbGtlZmVienlxZHJoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MzU5NTMsImV4cCI6MjA5MDUxMTk1M30.lPR244Zm5Dgrx5zy_tO8v3sQWyQRZF0ZFRjmfnGGl6c"
    static let appBundleID    = "com.tinyfoodtour.app"
    static let teamID         = "9Y98BV3CPZ"
    static let webHost        = "tinyfoodtour.com"
}
