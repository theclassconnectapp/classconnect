import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";

// For cost control, limit the number of concurrent function instances
setGlobalOptions({ maxInstances: 10 });

// Initialize Firebase Admin SDK
admin.initializeApp();

// Import and export Cloud Functions
export { deleteAccount } from "./deleteAccount";
