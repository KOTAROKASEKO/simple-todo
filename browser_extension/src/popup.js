import { initializeApp } from 'firebase/app';
import {
  getAuth,
  onAuthStateChanged,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  getFirestore,
  collection,
  query,
  orderBy,
  onSnapshot,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
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

const authSection = document.getElementById('authSection');
const todoSection = document.getElementById('todoSection');
const emailInput = document.getElementById('emailInput');
const passwordInput = document.getElementById('passwordInput');
const authSubmitBtn = document.getElementById('authSubmitBtn');
const switchModeBtn = document.getElementById('switchModeBtn');
const authError = document.getElementById('authError');
const logoutBtn = document.getElementById('logoutBtn');
const loadingText = document.getElementById('loadingText');
const pomodoroPeekBtn = document.getElementById('pomodoroPeekBtn');

const titleInput = document.getElementById('titleInput');
const descInput = document.getElementById('descInput');
const dateInput = document.getElementById('dateInput');
const alarmBtn = document.getElementById('alarmBtn');
const recurringBtn = document.getElementById('recurringBtn');
const reminderTimeWrap = document.getElementById('reminderTimeWrap');
const reminderTimeInput = document.getElementById('reminderTimeInput');
const addTaskBtn = document.getElementById('addTaskBtn');
const taskList = document.getElementById('taskList');
const focusTimerText = document.getElementById('focusTimerText');
const focusStartPauseBtn = document.getElementById('focusStartPauseBtn');
const focusResetBtn = document.getElementById('focusResetBtn');
const focusDurationInput = document.getElementById('focusDurationInput');
const focusApplyDurationBtn = document.getElementById('focusApplyDurationBtn');
const focusTaskForm = document.getElementById('focusTaskForm');
const focusTaskInput = document.getElementById('focusTaskInput');
const addFocusTaskBtn = document.getElementById('addFocusTaskBtn');
const focusTaskList = document.getElementById('focusTaskList');
const focusSection = document.getElementById('focusSection');
const closeFocusPanelBtn = document.getElementById('closeFocusPanelBtn');
const taskSheet = document.getElementById('taskSheet');
const taskSheetBackdrop = document.getElementById('taskSheetBackdrop');
const sheetEditBtn = document.getElementById('sheetEditBtn');
const sheetDeleteBtn = document.getElementById('sheetDeleteBtn');
const sheetCancelBtn = document.getElementById('sheetCancelBtn');

let registerMode = false;
let stopTasksListener = null;
let stopFocusTasksListener = null;
let selectedTask = null;
let pendingTasks = [];
let snapshotTasks = [];
let focusSnapshotTasks = [];
let currentToday = null;
let activeUser = null;
let isRecurringDaily = false;
let hasReminder = false;
let isPomodoroOpen = false;
let focusDurationMinutes = 25;
let focusSeconds = focusDurationMinutes * 60;
let focusTimerRunning = false;
let focusRefreshId = null;

function dayKey(date) {
  const y = String(date.getFullYear()).padStart(4, '0');
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function parseDateInput(value) {
  if (!value) return null;
  const [yearText, monthText, dayText] = value.split('-');
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  if (!year || !month || !day) return null;
  return new Date(year, month - 1, day);
}

function parseTimeInput(value) {
  if (!value) return null;
  const [hourText, minuteText] = value.split(':');
  const hour = Number(hourText);
  const minute = Number(minuteText);
  if (!Number.isInteger(hour) || !Number.isInteger(minute)) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return { hour, minute };
}

function getNextReminderDate(selectedDate, hour, minute, isRecurringDaily) {
  const reminderDate = new Date(
    selectedDate.getFullYear(),
    selectedDate.getMonth(),
    selectedDate.getDate(),
    hour,
    minute,
    0,
    0
  );
  if (!isRecurringDaily) return reminderDate;

  const now = new Date();
  while (reminderDate <= now) {
    reminderDate.setDate(reminderDate.getDate() + 1);
  }
  return reminderDate;
}

function refreshReminderVisibility() {
  reminderTimeWrap.hidden = !hasReminder;
  alarmBtn.setAttribute('aria-pressed', String(hasReminder));
}

function refreshRecurringButton() {
  recurringBtn.classList.toggle('active', isRecurringDaily);
  recurringBtn.setAttribute('aria-pressed', String(isRecurringDaily));
}

function formatFocusTimer(totalSeconds) {
  const minutes = String(Math.floor(totalSeconds / 60)).padStart(2, '0');
  const seconds = String(totalSeconds % 60).padStart(2, '0');
  return `${minutes}:${seconds}`;
}

function renderFocusTimer() {
  focusTimerText.textContent = formatFocusTimer(focusSeconds);
  focusStartPauseBtn.textContent = focusTimerRunning ? 'Pause' : 'Start';
}

function syncPomodoroFromBackground() {
  if (typeof chrome?.runtime?.sendMessage !== 'function') return;
  chrome.runtime.sendMessage({ action: 'pomodoro_get' }, (res) => {
    if (!res) return;
    focusTimerRunning = res.running;
    focusSeconds = res.remaining ?? 0;
    if (res.durationMinutes != null) focusDurationMinutes = res.durationMinutes;
    renderFocusTimer();
  });
}

function startFocusRefresh() {
  if (focusRefreshId) return;
  focusRefreshId = setInterval(() => {
    syncPomodoroFromBackground();
  }, 1000);
}

function stopFocusRefresh() {
  if (focusRefreshId) {
    clearInterval(focusRefreshId);
    focusRefreshId = null;
  }
}

function toggleFocusTimer() {
  if (typeof chrome?.runtime?.sendMessage !== 'function') return;
  if (focusTimerRunning) {
    chrome.runtime.sendMessage({ action: 'pomodoro_pause' }, () => {
      focusTimerRunning = false;
      syncPomodoroFromBackground();
      stopFocusRefresh();
      renderFocusTimer();
    });
    return;
  }
  if (focusSeconds <= 0) {
    focusSeconds = focusDurationMinutes * 60;
  }
  if (!activeUser) return;
  chrome.runtime.sendMessage({
    action: 'pomodoro_start',
    seconds: focusSeconds,
    durationMinutes: focusDurationMinutes,
    userUid: activeUser.uid,
  }, () => {
    focusTimerRunning = true;
    startFocusRefresh();
    renderFocusTimer();
  });
}

function resetFocusTimer() {
  if (typeof chrome?.runtime?.sendMessage !== 'function') return;
  chrome.runtime.sendMessage({ action: 'pomodoro_reset' }, () => {
    focusTimerRunning = false;
    focusSeconds = focusDurationMinutes * 60;
    stopFocusRefresh();
    renderFocusTimer();
  });
}

function applyFocusDuration() {
  const next = Number(focusDurationInput.value);
  if (!Number.isFinite(next) || next < 1 || next > 180) {
    focusDurationInput.value = String(focusDurationMinutes);
    return;
  }
  focusDurationMinutes = Math.floor(next);
  resetFocusTimer();
}

function renderFocusTasks() {
  focusTaskList.innerHTML = '';
  if (focusSnapshotTasks.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'focus-task-empty';
    empty.textContent = 'No focus-prep tasks yet.';
    focusTaskList.appendChild(empty);
    return;
  }

  focusSnapshotTasks.forEach((task) => {
    const item = document.createElement('li');
    item.className = `focus-task-item ${task.isDone ? 'done' : ''}`;

    const toggle = document.createElement('button');
    toggle.className = 'icon-btn task-toggle';
    toggle.textContent = task.isDone ? '↺' : '✓';
    toggle.title = task.isDone ? 'Mark as undone' : 'Mark as done';
    toggle.setAttribute('aria-label', toggle.title);
    toggle.addEventListener('click', async () => {
      const nextIsDone = !task.isDone;
      await updateDoc(task.ref, { isDone: nextIsDone });
      if (nextIsDone) {
        const hasUncheckedOthers = focusSnapshotTasks
          .filter((other) => other.id !== task.id)
          .some((other) => !other.isDone);
        if (!hasUncheckedOthers && !focusTimerRunning) {
          toggleFocusTimer();
        }
      }
    });

    const text = document.createElement('p');
    text.textContent = task.title;

    const remove = document.createElement('button');
    remove.className = 'icon-btn';
    remove.title = 'Delete focus task';
    remove.setAttribute('aria-label', remove.title);
    remove.textContent = '×';
    remove.addEventListener('click', async () => {
      await deleteDoc(task.ref);
    });

    item.appendChild(toggle);
    item.appendChild(text);
    item.appendChild(remove);
    focusTaskList.appendChild(item);
  });
}

function normalizeFocusSnapshotTask(snap) {
  const data = snap.data();
  return {
    id: snap.id,
    ref: doc(db, snap.ref.path),
    title: data.title ?? 'Untitled',
    isDone: Boolean(data.isDone),
    createdAtSeconds: data.createdAt?.seconds ?? 0,
  };
}

async function handleAddFocusTask(user) {
  const title = focusTaskInput.value.trim();
  if (!title) return;
  try {
    await addDoc(collection(db, 'todo', user.uid, 'focus_tasks'), {
      title,
      isDone: false,
      createdAt: serverTimestamp(),
    });
    focusTaskInput.value = '';
  } catch (e) {
    const message = e?.message ?? 'Failed to add focus task.';
    window.alert(message);
  }
}

function shouldShowTaskForToday(data, today) {
  const dateKey = data.dateKey ?? null;
  const isRecurringDaily = Boolean(data.isRecurringDaily);
  if (!isRecurringDaily) return dateKey === today;
  if (!dateKey) return true;
  return dateKey <= today;
}

function closeTaskSheet() {
  taskSheet.hidden = true;
  taskSheetBackdrop.hidden = true;
  selectedTask = null;
}

function openTaskSheet(task) {
  selectedTask = task;
  taskSheet.hidden = false;
  taskSheetBackdrop.hidden = false;
}

function normalizeSnapshotTask(snap) {
  const data = snap.data();
  return {
    id: snap.id,
    ref: doc(db, snap.ref.path),
    title: data.title ?? 'Untitled task',
    description: data.description ?? '',
    isDone: Boolean(data.isDone),
    isRecurringDaily: Boolean(data.isRecurringDaily),
    dateKey: data.dateKey ?? null,
    createdAtSeconds: data.createdAt?.seconds ?? 0,
  };
}

function getMergedTasks() {
  const today = currentToday;
  if (!today) return [];

  const real = snapshotTasks
    .filter((snap) => shouldShowTaskForToday(snap.data(), today))
    .map(normalizeSnapshotTask);

  const realSet = new Set(real.map((t) => `${t.title}|${t.dateKey}`));
  pendingTasks = pendingTasks.filter((pt) => !realSet.has(`${pt.title}|${pt.dateKey}`));

  const all = [...pendingTasks, ...real];
  all.sort((a, b) => {
    if (a.isDone !== b.isDone) return a.isDone ? 1 : -1;
    return b.createdAtSeconds - a.createdAtSeconds;
  });
  return all;
}

function renderTasks() {
  const tasks = getMergedTasks();
  taskList.innerHTML = '';
  if (tasks.length === 0) {
    const li = document.createElement('li');
    li.className = 'task empty';
    li.textContent = 'No tasks for today.';
    taskList.appendChild(li);
    return;
  }

  tasks.forEach((task) => {
    const li = document.createElement('li');
    li.className = `task ${task.isDone ? 'done' : ''}`;
    li.title = 'Click to show options';

    const top = document.createElement('div');
    top.className = 'task-top';

    const left = document.createElement('div');
    left.className = 'task-main';

    const toggleBtn = document.createElement('button');
    toggleBtn.className = 'icon-btn task-toggle';
    toggleBtn.title = task.isDone ? 'Mark as undone' : 'Mark as done';
    toggleBtn.setAttribute('aria-label', toggleBtn.title);
    toggleBtn.textContent = task.isDone ? '↺' : '✓';
    if (task.ref) {
      toggleBtn.addEventListener('click', async (event) => {
        event.stopPropagation();
        await updateDoc(task.ref, { isDone: !task.isDone });
      });
    } else {
      toggleBtn.disabled = true;
    }
    left.appendChild(toggleBtn);

    const title = document.createElement('p');
    title.className = 'task-title';
    title.textContent = task.title;
    left.appendChild(title);
    top.appendChild(left);

    const kind = document.createElement('small');
    kind.textContent = task.isRecurringDaily ? 'Recurring' : 'One-day';
    top.appendChild(kind);

    li.appendChild(top);

    const desc = document.createElement('p');
    desc.className = 'task-desc';
    desc.textContent = task.description || 'No description';
    li.appendChild(desc);
    if (task.ref) {
      li.addEventListener('click', () => {
        openTaskSheet({
          ref: task.ref,
          title: task.title,
          description: task.description,
        });
      });
    }
    taskList.appendChild(li);
  });
}

async function handleAuthSubmit() {
  authError.hidden = true;
  try {
    if (registerMode) {
      await createUserWithEmailAndPassword(auth, emailInput.value, passwordInput.value);
    } else {
      await signInWithEmailAndPassword(auth, emailInput.value, passwordInput.value);
    }
  } catch (e) {
    authError.textContent = e.message || 'Authentication failed.';
    authError.hidden = false;
  }
}

function handleAddTask(user) {
  const title = titleInput.value.trim();
  if (!title) return;

  const description = descInput.value.trim();
  const selectedDate = parseDateInput(dateInput.value) ?? new Date();
  const selectedDayKey = dayKey(selectedDate);
  const today = dayKey(new Date());
  const reminderTime = parseTimeInput(reminderTimeInput.value);
  const hasValidReminder = hasReminder && reminderTime;
  const remindAt = hasValidReminder
    ? getNextReminderDate(
        selectedDate,
        reminderTime.hour,
        reminderTime.minute,
        isRecurringDaily
      )
    : null;

  pendingTasks.push({
    id: `pending-${Date.now()}`,
    ref: null,
    title,
    description,
    isDone: false,
    isRecurringDaily,
    dateKey: selectedDayKey,
    createdAtSeconds: Date.now() / 1000,
  });

  titleInput.value = '';
  descInput.value = '';
  dateInput.value = today;
  isRecurringDaily = false;
  hasReminder = false;
  reminderTimeInput.value = '09:00';
  refreshRecurringButton();
  refreshReminderVisibility();
  renderTasks();

  const taskData = {
    title,
    description,
    isDone: false,
    isRecurringDaily,
    dateKey: selectedDayKey,
    lastResetOn: today,
    createdAt: serverTimestamp(),
  };

  if (hasValidReminder) {
    taskData.reminderHour = reminderTime.hour;
    taskData.reminderMinute = reminderTime.minute;
    taskData.remindAt = remindAt;
    taskData.reminderPending = true;
  }

  addDoc(collection(db, 'todo', user.uid, 'tasks'), taskData);
}

function setSignedInUI(signedIn) {
  loadingText.hidden = true;
  authSection.hidden = signedIn;
  todoSection.hidden = !signedIn;
  logoutBtn.hidden = !signedIn;
}

function setLoadingUI() {
  loadingText.hidden = false;
  authSection.hidden = true;
  todoSection.hidden = true;
  logoutBtn.hidden = true;
}

function setPomodoroVisibility(open) {
  isPomodoroOpen = open;
  focusSection.hidden = !open;
  taskList.hidden = open;
  pomodoroPeekBtn.hidden = open;
  const composer = document.querySelector('.composer');
  if (composer) {
    composer.hidden = open;
  }
  if (open) {
    syncPomodoroFromBackground();
    startFocusRefresh();
  } else {
    stopFocusRefresh();
  }
}

focusStartPauseBtn.addEventListener('click', toggleFocusTimer);
focusResetBtn.addEventListener('click', resetFocusTimer);
focusApplyDurationBtn.addEventListener('click', applyFocusDuration);
focusDurationInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') {
    e.preventDefault();
    applyFocusDuration();
  }
});
pomodoroPeekBtn.addEventListener('click', () => setPomodoroVisibility(true));
closeFocusPanelBtn.addEventListener('click', () => setPomodoroVisibility(false));

authSubmitBtn.addEventListener('click', handleAuthSubmit);
switchModeBtn.addEventListener('click', () => {
  registerMode = !registerMode;
  authSubmitBtn.textContent = registerMode ? 'Register' : 'Sign in';
  switchModeBtn.textContent = registerMode ? 'Back to sign in' : 'Create account';
  authError.hidden = true;
});
logoutBtn.addEventListener('click', async () => signOut(auth));
sheetCancelBtn.addEventListener('click', closeTaskSheet);
taskSheetBackdrop.addEventListener('click', closeTaskSheet);
sheetEditBtn.addEventListener('click', async () => {
  if (!selectedTask) return;
  const editedTitle = window.prompt('Edit title', selectedTask.title);
  if (editedTitle === null) return;
  const nextTitle = editedTitle.trim();
  if (!nextTitle) return;
  const editedDescription = window.prompt('Edit description', selectedTask.description);
  if (editedDescription === null) return;
  await updateDoc(selectedTask.ref, {
    title: nextTitle,
    description: editedDescription.trim(),
  });
  closeTaskSheet();
});
sheetDeleteBtn.addEventListener('click', async () => {
  if (!selectedTask) return;
  await deleteDoc(selectedTask.ref);
  closeTaskSheet();
});
alarmBtn.addEventListener('click', () => {
  hasReminder = !hasReminder;
  if (hasReminder && !parseTimeInput(reminderTimeInput.value)) {
    reminderTimeInput.value = '09:00';
  }
  refreshReminderVisibility();
  if (hasReminder) {
    if (typeof reminderTimeInput.showPicker === 'function') {
      reminderTimeInput.showPicker();
    } else {
      reminderTimeInput.focus();
    }
  }
});
recurringBtn.addEventListener('click', () => {
  isRecurringDaily = !isRecurringDaily;
  refreshRecurringButton();
});

setLoadingUI();
onAuthStateChanged(auth, (user) => {
  setLoadingUI();
  stopFocusRefresh();
  if (!user && typeof chrome?.runtime?.sendMessage === 'function') {
    chrome.runtime.sendMessage({ action: 'pomodoro_reset' });
  }
  if (stopTasksListener) {
    stopTasksListener();
    stopTasksListener = null;
  }
  if (stopFocusTasksListener) {
    stopFocusTasksListener();
    stopFocusTasksListener = null;
  }

  if (!user) {
    activeUser = null;
    closeTaskSheet();
    focusSnapshotTasks = [];
    renderFocusTasks();
    setPomodoroVisibility(false);
    setSignedInUI(false);
    return;
  }

  setSignedInUI(true);
  activeUser = user;
  currentToday = dayKey(new Date());
  dateInput.value = currentToday;
  isRecurringDaily = false;
  hasReminder = false;
  refreshRecurringButton();
  refreshReminderVisibility();
  pendingTasks = [];
  focusSnapshotTasks = [];
  focusDurationInput.value = String(focusDurationMinutes);
  syncPomodoroFromBackground();
  renderFocusTasks();
  setPomodoroVisibility(false);
  const q = query(collection(db, 'todo', user.uid, 'tasks'), orderBy('createdAt', 'desc'));
  stopTasksListener = onSnapshot(q, (snapshot) => {
    snapshotTasks = snapshot.docs;
    renderTasks();
  });
  const focusQ = query(
    collection(db, 'todo', user.uid, 'focus_tasks'),
    orderBy('createdAt', 'asc')
  );
  stopFocusTasksListener = onSnapshot(focusQ, (snapshot) => {
    focusSnapshotTasks = snapshot.docs.map(normalizeFocusSnapshotTask);
    renderFocusTasks();
  });

  addTaskBtn.onclick = () => handleAddTask(user);
  focusTaskForm.onsubmit = async (e) => {
    e.preventDefault();
    await handleAddFocusTask(user);
  };
  titleInput.onkeypress = null;
  titleInput.onkeydown = (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleAddTask(user);
    }
  };
  titleInput.onkeyup = (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleAddTask(user);
    }
  };
  focusTaskInput.onkeydown = null;
});
