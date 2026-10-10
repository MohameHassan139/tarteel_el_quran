You are working on my Flutter app "ترتيل القرآن" (package: com.mohamedhassan.tarteel_el_quran). I am about to publish version 2.0.0+3 to Google Play. The version in pubspec.yaml is ALREADY bumped — do not change it, and do NOT change applicationId, namespace, or the signing config.

Please make these changes, one by one, and show me a short summary of what you changed in each file at the end.

1. Remove leftover MainActivity files
   - Keep ONLY android/app/src/main/kotlin/com/mohamedhassan/tarteel_el_quran/MainActivity.kt (it must stay extending AudioServiceActivity).
   - Delete android/app/src/main/kotlin/com/example/ and android/app/src/main/kotlin/com/tarteelapps/ folders (they are unused duplicates).

2. Target API 36
   - Check what flutter.targetSdkVersion resolves to with my installed Flutter version (`flutter --version`).
   - If it is lower than 36, set `targetSdk = 36` (and `compileSdk = 36` if needed) in android/app/build.gradle.kts. Make sure the project still builds.

3. Exact alarm safety (daily wird reminder)
   - Find where flutter_local_notifications schedules the daily reminder (zonedSchedule).
   - Before using AndroidScheduleMode.exactAllowWhileIdle, check `canScheduleExactNotifications()` on AndroidFlutterLocalNotificationsPlugin. If not allowed, fall back to AndroidScheduleMode.inexactAllowWhileIdle so the reminder never fails silently on Android 14+.
   - Do not request the exact-alarm permission aggressively; inexact is acceptable.

4. Notification permission
   - Make sure the app calls `requestNotificationsPermission()` (Android 13+) at a sensible moment (e.g. when the user enables the reminder, or first launch), and handles denial gracefully.

5. In-app account deletion (Google Play requirement)
   - Add a "حذف الحساب" (Delete account) option in the settings/profile screen, with an Arabic confirmation dialog.
   - On confirm: delete the user's Firestore data they own (quran_students/{uid} and its subcollections links, sessions, daily_ward, notes; or quran_teachers/{uid} and their quran_share_codes doc), then call FirebaseAuth.instance.currentUser!.delete().
   - Handle `requires-recent-login` by asking the user to sign in again, then retry.
   - Afterwards sign out and return to the start screen.
   - If a Cloud Function in /functions is a better place for recursive deletion, implement it there instead and call it from the app — tell me which approach you chose.

6. Firestore rules — teacher privacy
   - In firestore.rules, `quran_teachers/{teacherUid}` currently allows read to ANY signed-in user. Check which fields are stored in teacher docs. If any are personal (email, phone, etc.), restrict read to: the teacher themself, or students whose quran_students/{uid}.linkedTeacherIds contains that teacher. Keep share-code lookup working through quran_share_codes.
   - Make sure every existing app flow (student linking by share code, teacher viewing students) still works with the new rules. Don't deploy — tell me the command to deploy.

7. Small cleanup
   - Change pubspec.yaml `description` to "تطبيق ترتيل القرآن" (only that line).
   - Remove or guard any `print(`/debug logs that print user data or tokens (use `kDebugMode` or debugPrint).

8. Verify
   - Run `flutter analyze` and fix any errors (not just warnings I introduced).
   - Run `flutter build appbundle --release` and confirm it succeeds. Report the output .aab path.

Do not change anything else unless it's needed to make the above work. If something is unclear, ask me before guessing.
