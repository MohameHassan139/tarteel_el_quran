/// Configuration for Firebase Cloud Messaging Direct Sender.
///
/// To get your Firebase Legacy Server Key:
/// 1. Go to Firebase Console: https://console.firebase.google.com
/// 2. Open project "whatsapp-b25d2"
/// 3. Go to Project Settings (gear icon ⚙️) -> "Cloud Messaging" tab
/// 4. Under "Cloud Messaging API (Legacy)", find "Server key"
///    (If disabled, click the 3 dots -> "Manage API in Google Cloud Console" -> click "Enable", then refresh).
/// 5. Copy the Server key and paste it below.
class FcmConfig {
  static const String serverKey = 'PASTE_YOUR_SERVER_KEY_HERE';
}
