const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Cloud Function triggered automatically whenever a teacher writes a note for a student.
 * Sends a high-priority FCM notification to the student's device token.
 * This guarantees delivery even when the student's app is closed or when their device reconnects to the internet.
 */
exports.onTeacherNoteCreated = onDocumentCreated(
  "quran_students/{studentUid}/notes/{noteId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log("No document snapshot found in event");
      return;
    }

    const note = snap.data();
    const studentUid = event.params.studentUid;
    const noteId = event.params.noteId;

    try {
      // 1. Fetch student's profile to retrieve their FCM device token
      const studentDoc = await admin
        .firestore()
        .collection("quran_students")
        .doc(studentUid)
        .get();

      if (!studentDoc.exists) {
        console.log(`Student document for ${studentUid} does not exist`);
        return;
      }

      const fcmToken = studentDoc.data()?.fcmToken;
      if (!fcmToken || typeof fcmToken !== "string" || fcmToken.trim() === "") {
        console.log(`Student ${studentUid} has no registered FCM token`);
        return;
      }

      const teacherName = note.fromTeacherName || "معلمك";
      const noteText = note.text || "أرسل لك معلمك ملاحظة جديدة";

      // 2. Build the FCM message payload
      const message = {
        token: fcmToken,
        notification: {
          title: `رسالة من ${teacherName}`,
          body: noteText,
        },
        data: {
          type: "teacher_note",
          studentUid: studentUid,
          noteId: noteId,
          fromTeacherUid: note.fromTeacherUid || "",
          fromTeacherName: teacherName,
          text: noteText,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "teacher_note_channel",
            sound: "default",
            defaultSound: true,
            defaultVibrateTimings: true,
            priority: "max",
            visibility: "public",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      console.log(`Successfully sent note notification to student ${studentUid}:`, response);
    } catch (error) {
      console.error(`Error sending FCM note notification for student ${studentUid}:`, error);
    }
  }
);
