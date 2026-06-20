import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";

/**
 * Cloud Function: deleteAccount
 * Callable function to delete a user account and their profile data.
 *
 * Request:
 *   - auth context (verified by Firebase Auth)
 *   - data.collegeId: string (passed by client, who knows their own collegeId)
 *
 * Steps:
 *   1. Auth check: verify user is authenticated
 *   2. Fetch collegeId from request data
 *   3. Delete user profile from Firestore: colleges/{collegeId}/users/{uid}
 *   4. Delete Firebase Auth account
 *   5. Return success
 */
export const deleteAccount = onCall(async (request) => {
  // Step 1: AUTH CHECK
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "User must be authenticated to delete their account."
    );
  }

  const uid = request.auth.uid;

  // Step 2: FETCH collegeId FROM REQUEST
  const { collegeId } = request.data as { collegeId?: string };

  if (!collegeId || typeof collegeId !== "string" || collegeId.trim() === "") {
    throw new HttpsError(
      "invalid-argument",
      "Missing or invalid collegeId. Client must provide collegeId in request."
    );
  }

  const db = admin.firestore();

  try {
    // Step 3: DELETE PROFILE
    // User profile is stored at: colleges/{collegeId}/users/{uid}
    const userDocRef = db.collection("colleges").doc(collegeId).collection("users").doc(uid);
    await userDocRef.delete();
    console.log(`Deleted user profile: colleges/${collegeId}/users/${uid}`);

    // TODO: anonymize messages/files in groups referencing this uid
    // This requires:
    //   - Query all groups where this user is a member
    //   - Find all messages/files authored by this uid
    //   - Replace author info with anonymous/deleted user placeholder
    //   - This will be added in a future iteration once group/message schema is finalized
  } catch (error) {
    console.error(`Error deleting user profile: ${error}`);
    // Continue to auth account deletion regardless (user wants account gone)
  }

  // Step 4: DELETE AUTH ACCOUNT (last step - point of no return)
  try {
    await admin.auth().deleteUser(uid);
    console.log(`Deleted Firebase Auth account: ${uid}`);
  } catch (error) {
    console.error(`Error deleting Firebase Auth account: ${error}`);
    throw new HttpsError(
      "internal",
      "Failed to delete authentication account. Please contact support."
    );
  }

  // Step 5: RETURN SUCCESS
  return { success: true, message: "Account deleted successfully." };
});
