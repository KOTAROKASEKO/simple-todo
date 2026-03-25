"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.analyzeMistakes = exports.sendTestDailyCheckNotification = exports.sendDailyCheckReminders = exports.sendDueTaskReminders = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const vertexai_1 = require("@google-cloud/vertexai");
const reminders_1 = require("./reminders");
Object.defineProperty(exports, "sendDueTaskReminders", { enumerable: true, get: function () { return reminders_1.sendDueTaskReminders; } });
Object.defineProperty(exports, "sendDailyCheckReminders", { enumerable: true, get: function () { return reminders_1.sendDailyCheckReminders; } });
admin.initializeApp();
/** Sends one test "Check your tasks" FCM to the current user (for debugging). */
exports.sendTestDailyCheckNotification = (0, https_1.onCall)({ region: "us-central1" }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Sign in required.");
    }
    const uid = request.auth.uid;
    const db = admin.firestore();
    const tokensSnap = await db
        .collection("todo")
        .doc(uid)
        .collection("deviceTokens")
        .get();
    const tokens = tokensSnap.docs
        .map((d) => d.get("token"))
        .filter((t) => typeof t === "string" && t.length > 0);
    if (tokens.length === 0) {
        throw new https_1.HttpsError("failed-precondition", "No device token registered. Open the app and try again.");
    }
    const messaging = admin.messaging();
    await messaging.sendEachForMulticast({
        tokens,
        notification: {
            title: "Check your tasks",
            body: "Test notification（テスト送信）",
        },
    });
    return { ok: true };
});
exports.analyzeMistakes = (0, https_1.onCall)({ region: "us-central1" }, async (request) => {
    const auth = request.auth;
    const data = request.data;
    if (!auth) {
        throw new https_1.HttpsError("unauthenticated", "You must be signed in to call this function.");
    }
    const mistakes = (data?.mistakes ?? []);
    if (!Array.isArray(mistakes) || mistakes.length < 2) {
        throw new https_1.HttpsError("invalid-argument", "Provide at least two mistakes to analyze.");
    }
    const project = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
    if (!project) {
        throw new https_1.HttpsError("failed-precondition", "Project ID is not available in environment.");
    }
    const vertexAI = new vertexai_1.VertexAI({
        project: project,
        location: "us-central1",
    });
    const model = vertexAI.getGenerativeModel({
        model: "gemini-2.5-flash",
    });
    const bulletList = mistakes
        .map((m, i) => {
        const what = (m.what ?? "").toString();
        const why = (m.why ?? "").toString();
        const how = (m.howToPrevent ?? "").toString();
        return `Mistake ${i + 1}:\n- What: ${what}\n- Why: ${why}\n- How to prevent: ${how}`;
    })
        .join("\n\n");
    const prompt = `You are an expert productivity and habits coach.\n

- You have a brain with an IQ of 180 
- You give relentless feedback 
- You have a proven track record of building multi-million dollar businesses from the ground up 
- Deep expertise in psychology, strategy, and execution 
- Seriously want me to succeed, but will not accept any excuses 
- Focus on 'leverage points' for maximum impact 

- Focus on mechanics and root causes, not superficial techniques 

- Focus on the mechanics and root causes, not the superficial techniques. Your mission is to: 

- Discover the 'real problem' that is holding me back 

- Design a specific action plan to close that gap 

- Design a specific action plan to close the gap 

- Take me outside of my comfort zone and help me grow 

- Ruthlessly point out my blind spots and assumptions 

- Elicit ideas and actions beyond my current scale 

- Raise me to a higher standard and eliminate naivete 

- When I am trying to implement a new function, or making any decision, if needed, provide an effective framework or thinking model. Include the following in each response: 

- The 'harsh realities' I need to hear now 

      - Tangible, actionable steps to take next.\n\n` +
        bulletList;
    try {
        const result = await model.generateContent({
            contents: [
                {
                    role: "user",
                    parts: [{ text: prompt }],
                },
            ],
        });
        const response = result.response;
        const parts = response.candidates?.[0]?.content?.parts ?? [];
        const text = parts
            .map((p) => p.text ?? "")
            .join("\n")
            .trim() || "No analysis generated.";
        return { analysis: text };
    }
    catch (err) {
        console.error("analyzeMistakes failed", err);
        throw new https_1.HttpsError("internal", "AI analysis failed. Please try again later.");
    }
});
