import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import {
  getFirestore,
  collection,
  addDoc,
  serverTimestamp,
} from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyAbISGd3eTjRfClz8HuszJZDL6WvwQtSs0',
  appId: '1:512858444455:web:d26bb2777511d92eb28182',
  messagingSenderId: '512858444455',
  projectId: 'simpletodo-19a48',
  authDomain: 'simpletodo-19a48.firebaseapp.com',
  storageBucket: 'simpletodo-19a48.firebasestorage.app',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const POMODORO_ALARM = 'pomodoro';
const STORAGE_KEY = 'pomodoroState';

function dayKey(date) {
  const d = date || new Date();
  const y = String(d.getFullYear()).padStart(4, '0');
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

async function addFocusedWorkLogTask(uid, durationMinutes) {
  const today = dayKey(new Date());
  const title = `${durationMinutes} minutes focused work`;
  await addDoc(collection(db, 'todo', uid, 'tasks'), {
    title,
    isDone: true,
    isRecurringDaily: false,
    dateKey: today,
    lastResetOn: today,
    createdAt: serverTimestamp(),
  });
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.action === 'pomodoro_start') {
    const { seconds, durationMinutes, userUid } = msg;
    const endTime = Date.now() + seconds * 1000;
    chrome.storage.local.set({
      [STORAGE_KEY]: {
        endTime,
        durationMinutes,
        userUid,
      },
    });
    chrome.alarms.create(POMODORO_ALARM, { when: endTime });
    sendResponse({ ok: true });
  } else if (msg.action === 'pomodoro_pause') {
    chrome.alarms.clear(POMODORO_ALARM);
    chrome.storage.local.get(STORAGE_KEY, (data) => {
      const state = data[STORAGE_KEY];
      if (state) {
        const remaining = Math.max(0, Math.floor((state.endTime - Date.now()) / 1000));
        chrome.storage.local.set({
          [STORAGE_KEY]: { ...state, pausedSeconds: remaining, endTime: null },
        });
      }
      sendResponse({ ok: true });
    });
    return true;
  } else if (msg.action === 'pomodoro_reset') {
    chrome.alarms.clear(POMODORO_ALARM);
    chrome.storage.local.remove(STORAGE_KEY);
    sendResponse({ ok: true });
  } else if (msg.action === 'pomodoro_get') {
    chrome.alarms.get(POMODORO_ALARM).then((alarm) => {
      chrome.storage.local.get(STORAGE_KEY, (data) => {
        const state = data[STORAGE_KEY];
        const running = !!alarm && !!state;
        const remaining = running && state.endTime
          ? Math.max(0, Math.floor((state.endTime - Date.now()) / 1000))
          : (state?.pausedSeconds ?? 0);
        sendResponse({
          running: !!alarm,
          remaining,
          durationMinutes: state?.durationMinutes ?? 25,
          userUid: state?.userUid ?? null,
        });
      });
    });
    return true;
  }
  return false;
});

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name !== POMODORO_ALARM) return;
  const { [STORAGE_KEY]: state } = await chrome.storage.local.get(STORAGE_KEY);
  chrome.storage.local.remove(STORAGE_KEY);
  if (state?.userUid && state?.durationMinutes != null) {
    try {
      await addFocusedWorkLogTask(state.userUid, state.durationMinutes);
    } catch (e) {
      console.error('Pomodoro: failed to add focus log', e);
    }
  }
});
