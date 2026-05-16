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
const tasksView = document.getElementById('tasksView');
const journalView = document.getElementById('journalView');
const tasksTabBtn = document.getElementById('tasksTabBtn');
const journalTabBtn = document.getElementById('journalTabBtn');
const emailInput = document.getElementById('emailInput');
const passwordInput = document.getElementById('passwordInput');
const authSubmitBtn = document.getElementById('authSubmitBtn');
const switchModeBtn = document.getElementById('switchModeBtn');
const authError = document.getElementById('authError');
const logoutBtn = document.getElementById('logoutBtn');
const loadingText = document.getElementById('loadingText');

const titleInput = document.getElementById('titleInput');
const checklistDraftList = document.getElementById('checklistDraftList');
const checklistItemInput = document.getElementById('checklistItemInput');
const dateInput = document.getElementById('dateInput');
const repeatDailyCheckbox = document.getElementById('repeatDailyCheckbox');
const reminderToggle = document.getElementById('reminderToggle');
const composerPanel = document.getElementById('composerPanel');
const composerBackdrop = document.getElementById('composerBackdrop');
const addTaskFab = document.getElementById('addTaskFab');
const closeComposerBtn = document.getElementById('closeComposerBtn');
const composerTitleText = document.getElementById('composerTitleText');
const reminderTimeWrap = document.getElementById('reminderTimeWrap');
const reminderTimeInput = document.getElementById('reminderTimeInput');
const addTaskBtn = document.getElementById('addTaskBtn');
const taskList = document.getElementById('taskList');
const dateStrip = document.getElementById('dateStrip');
const calendarMonthLabel = document.getElementById('calendarMonthLabel');
const calendarPrevBtn = document.getElementById('calendarPrevBtn');
const calendarNextBtn = document.getElementById('calendarNextBtn');
const journalList = document.getElementById('journalList');
const addJournalFab = document.getElementById('addJournalFab');
const journalComposerBackdrop = document.getElementById('journalComposerBackdrop');
const journalComposerPanel = document.getElementById('journalComposerPanel');
const closeJournalComposerBtn = document.getElementById('closeJournalComposerBtn');
const journalTitleInput = document.getElementById('journalTitleInput');
const journalBodyInput = document.getElementById('journalBodyInput');
const saveJournalBtn = document.getElementById('saveJournalBtn');
const taskActionBackdrop = document.getElementById('taskActionBackdrop');
const taskActionSheet = document.getElementById('taskActionSheet');
const taskActionChecklist = document.getElementById('taskActionChecklist');
const taskActionEditBtn = document.getElementById('taskActionEditBtn');
const taskActionDeleteBtn = document.getElementById('taskActionDeleteBtn');
const taskActionCancelBtn = document.getElementById('taskActionCancelBtn');
const journalDetailBackdrop = document.getElementById('journalDetailBackdrop');
const journalDetailSheet = document.getElementById('journalDetailSheet');
const journalDetailDate = document.getElementById('journalDetailDate');
const journalDetailContent = document.getElementById('journalDetailContent');
const journalDetailCloseBtn = document.getElementById('journalDetailCloseBtn');
let registerMode = false;
let stopTasksListener = null;
let stopJournalListener = null;
let pendingTasks = [];
let snapshotTasks = [];
let journalSnapshots = [];
let currentToday = null;
let activeUser = null;
let isRecurringDaily = false;
let hasReminder = false;
let isComposerOpen = false;
let checklistDraftItems = [];
let editingTaskRef = null;
let selectedTaskAction = null;
let activeTab = 'tasks';

function dayKey(date) {
  const y = String(date.getFullYear()).padStart(4, '0');
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function shiftDate(baseDate, diffDays) {
  const next = new Date(baseDate);
  next.setDate(next.getDate() + diffDays);
  return next;
}

function parseDayKey(value) {
  const [yearText, monthText, dayText] = value.split('-');
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  return new Date(year, month - 1, day);
}

function buildDateChipLabel(date) {
  const weekday = date.toLocaleDateString(undefined, { weekday: 'short' });
  const day = String(date.getDate());
  return { weekday, day };
}

function renderDateStrip() {
  if (!dateStrip || !calendarMonthLabel || !currentToday) return;
  const selectedDate = parseDayKey(currentToday);
  calendarMonthLabel.textContent = selectedDate.toLocaleDateString(undefined, {
    month: 'long',
    year: 'numeric',
  });

  dateStrip.innerHTML = '';
  for (let offset = -3; offset <= 3; offset += 1) {
    const chipDate = shiftDate(selectedDate, offset);
    const key = dayKey(chipDate);
    const chip = document.createElement('button');
    chip.type = 'button';
    chip.className = `date-chip${key === currentToday ? ' active' : ''}`;
    chip.setAttribute('role', 'tab');
    chip.setAttribute('aria-selected', String(key === currentToday));
    chip.dataset.dateKey = key;
    const { weekday, day } = buildDateChipLabel(chipDate);
    chip.innerHTML = `<span class="date-chip-weekday">${weekday}</span><span class="date-chip-day">${day}</span>`;
    chip.addEventListener('click', () => {
      currentToday = key;
      dateInput.value = key;
      renderDateStrip();
      renderTasks();
    });
    dateStrip.appendChild(chip);
  }
}

function setComposerVisibility(open) {
  isComposerOpen = open;
  if (composerPanel) composerPanel.hidden = !open;
  if (composerBackdrop) composerBackdrop.hidden = !open;
  if (addTaskFab) addTaskFab.hidden = !activeUser || open;
  if (open) titleInput.focus();
}

function setJournalComposerVisibility(open) {
  if (journalComposerPanel) journalComposerPanel.hidden = !open;
  if (journalComposerBackdrop) journalComposerBackdrop.hidden = !open;
  if (addJournalFab) addJournalFab.hidden = activeTab !== 'journal' || !activeUser || open;
  if (open && journalTitleInput) journalTitleInput.focus();
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
  if (reminderToggle) reminderToggle.checked = hasReminder;
}

function refreshRecurringButton() {
  if (repeatDailyCheckbox) repeatDailyCheckbox.checked = isRecurringDaily;
}

function shouldShowTaskForToday(data, today) {
  const dateKey = data.dateKey ?? null;
  const isRecurringDaily = Boolean(data.isRecurringDaily);
  if (!isRecurringDaily) return dateKey === today;
  if (!dateKey) return true;
  return dateKey <= today;
}

function openAddEditor() {
  editingTaskRef = null;
  titleInput.value = '';
  checklistDraftItems = [];
  renderChecklistDraftItems();
  if (checklistItemInput) checklistItemInput.value = '';
  isRecurringDaily = false;
  hasReminder = false;
  reminderTimeInput.value = '09:00';
  refreshRecurringButton();
  refreshReminderVisibility();
  if (composerTitleText) composerTitleText.textContent = 'Add task';
  if (addTaskBtn) addTaskBtn.textContent = 'Add';
  setComposerVisibility(true);
}

function openEditEditor(task) {
  editingTaskRef = task.ref;
  titleInput.value = task.title ?? '';
  checklistDraftItems = (task.checklist ?? []).map((item) => item.text).filter(Boolean);
  renderChecklistDraftItems();
  if (checklistItemInput) checklistItemInput.value = '';
  isRecurringDaily = Boolean(task.isRecurringDaily);
  hasReminder = Number.isInteger(task.reminderHour) && Number.isInteger(task.reminderMinute);
  if (hasReminder) {
    const h = String(task.reminderHour).padStart(2, '0');
    const m = String(task.reminderMinute).padStart(2, '0');
    reminderTimeInput.value = `${h}:${m}`;
  } else {
    reminderTimeInput.value = '09:00';
  }
  refreshRecurringButton();
  refreshReminderVisibility();
  if (composerTitleText) composerTitleText.textContent = 'Edit task';
  if (addTaskBtn) addTaskBtn.textContent = 'Save';
  setComposerVisibility(true);
}

function closeTaskActionSheet() {
  selectedTaskAction = null;
  if (taskActionSheet) taskActionSheet.hidden = true;
  if (taskActionBackdrop) taskActionBackdrop.hidden = true;
}

async function toggleTaskChecklistItem(itemIndex) {
  if (!selectedTaskAction?.ref || !Array.isArray(selectedTaskAction.checklist)) return;
  const nextChecklist = selectedTaskAction.checklist.map((item, index) => (
    index === itemIndex ? { ...item, isDone: !item.isDone } : item
  ));
  selectedTaskAction = { ...selectedTaskAction, checklist: nextChecklist };
  renderTaskActionChecklist();
  await updateDoc(selectedTaskAction.ref, { checklist: nextChecklist });
}

function renderTaskActionChecklist() {
  if (!taskActionChecklist) return;
  taskActionChecklist.innerHTML = '';
  const checklist = selectedTaskAction?.checklist ?? [];
  if (checklist.length === 0) {
    const li = document.createElement('li');
    li.className = 'sheet-checklist-empty';
    li.textContent = 'No checklist items';
    taskActionChecklist.appendChild(li);
    return;
  }
  checklist.forEach((item, index) => {
    const li = document.createElement('li');
    li.className = 'sheet-checklist-item';
    const label = document.createElement('label');
    label.className = 'sheet-checklist-toggle';
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.checked = Boolean(item.isDone);
    input.addEventListener('change', () => {
      toggleTaskChecklistItem(index);
    });
    const text = document.createElement('span');
    text.textContent = item.text;
    if (item.isDone) text.className = 'done';
    label.appendChild(input);
    label.appendChild(text);
    li.appendChild(label);
    taskActionChecklist.appendChild(li);
  });
}

function openTaskActionSheet(task) {
  selectedTaskAction = task;
  renderTaskActionChecklist();
  if (taskActionSheet) taskActionSheet.hidden = false;
  if (taskActionBackdrop) taskActionBackdrop.hidden = false;
}

function renderJournalEntries() {
  if (!journalList) return;
  journalList.innerHTML = '';
  if (journalSnapshots.length === 0) {
    const empty = document.createElement('li');
    empty.className = 'task empty';
    empty.textContent = 'No journal entries yet.';
    journalList.appendChild(empty);
    return;
  }
  journalSnapshots.forEach((snap) => {
    const data = snap.data();
    const createdAt = data.createdAt?.toDate?.() ?? null;
    const createdAtText = createdAt
      ? createdAt.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
      : '';
    const li = document.createElement('li');
    li.className = 'task';
    const row = document.createElement('div');
    row.className = 'task-row';
    const body = document.createElement('div');
    body.className = 'task-body';
    const date = document.createElement('p');
    date.className = 'journal-date';
    date.textContent = createdAtText || 'No date';
    const preview = document.createElement('p');
    preview.className = 'journal-preview';
    preview.textContent = data.content || '';
    body.appendChild(date);
    body.appendChild(preview);
    row.appendChild(body);
    li.appendChild(row);
    li.addEventListener('click', () => {
      if (journalDetailDate) journalDetailDate.textContent = createdAtText || 'No date';
      if (journalDetailContent) journalDetailContent.textContent = data.content || '';
      if (journalDetailSheet) journalDetailSheet.hidden = false;
      if (journalDetailBackdrop) journalDetailBackdrop.hidden = false;
    });
    journalList.appendChild(li);
  });
}

function setActiveTab(tab) {
  activeTab = tab;
  const isTasks = tab === 'tasks';
  if (tasksView) tasksView.hidden = !isTasks;
  if (journalView) journalView.hidden = isTasks;
  if (tasksTabBtn) tasksTabBtn.classList.toggle('active', isTasks);
  if (journalTabBtn) journalTabBtn.classList.toggle('active', !isTasks);
  if (isTasks) {
    setJournalComposerVisibility(false);
    if (addTaskFab) addTaskFab.hidden = !activeUser || isComposerOpen;
  } else {
    setComposerVisibility(false);
    if (addTaskFab) addTaskFab.hidden = true;
    if (addJournalFab) addJournalFab.hidden = !activeUser;
  }
}

function normalizeSnapshotTask(snap) {
  const data = snap.data();
  const rawChecklist = Array.isArray(data.checklist) ? data.checklist : [];
  const checklist = rawChecklist
    .map((item) => ({
      text: typeof item?.text === 'string' ? item.text.trim() : '',
      isDone: Boolean(item?.isDone),
    }))
    .filter((item) => item.text);
  return {
    id: snap.id,
    ref: doc(db, snap.ref.path),
    title: data.title ?? 'Untitled task',
    isDone: Boolean(data.isDone),
    isRecurringDaily: Boolean(data.isRecurringDaily),
    dateKey: data.dateKey ?? null,
    createdAtSeconds: data.createdAt?.seconds ?? 0,
    checklist,
    reminderHour: data.reminderHour,
    reminderMinute: data.reminderMinute,
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

  let hasRenderedPendingHeader = false;
  let hasRenderedCompletedHeader = false;

  tasks.forEach((task) => {
    if (!task.isDone && !hasRenderedPendingHeader) {
      const header = document.createElement('li');
      header.className = 'task-section-divider';
      header.textContent = 'Pending';
      taskList.appendChild(header);
      hasRenderedPendingHeader = true;
    }
    if (task.isDone && !hasRenderedCompletedHeader) {
      const header = document.createElement('li');
      header.className = 'task-section-divider';
      header.textContent = 'Completed';
      taskList.appendChild(header);
      hasRenderedCompletedHeader = true;
    }

    const li = document.createElement('li');
    li.className = `task ${task.isDone ? 'done' : ''}`;
    li.title = 'Click to show options';

    const row = document.createElement('div');
    row.className = 'task-row';

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
    row.appendChild(toggleBtn);

    const body = document.createElement('div');
    body.className = 'task-body';

    const title = document.createElement('p');
    title.className = 'task-title';
    title.textContent = task.title;
    body.appendChild(title);

    const meta = document.createElement('div');
    meta.className = 'task-meta';

    const kind = document.createElement('span');
    kind.className = `task-kind ${task.isRecurringDaily ? 'daily' : 'one-time'}`;
    kind.textContent = task.isRecurringDaily ? 'Daily' : 'One-time';
    meta.appendChild(kind);

    const secondary = document.createElement('span');
    secondary.className = 'task-secondary';
    secondary.textContent = task.checklist.length > 0
      ? `Checklist: ${task.checklist.filter((item) => item.isDone).length}/${task.checklist.length} done`
      : 'Task';
    meta.appendChild(secondary);

    body.appendChild(meta);
    row.appendChild(body);
    li.appendChild(row);
    if (task.ref) {
      li.addEventListener('click', () => {
        openTaskActionSheet(task);
      });
    }
    taskList.appendChild(li);
  });
}

function renderChecklistDraftItems() {
  if (!checklistDraftList) return;
  checklistDraftList.innerHTML = '';
  if (checklistDraftItems.length === 0) return;
  checklistDraftItems.forEach((item, index) => {
    const row = document.createElement('div');
    row.className = 'checklist-draft-item';
    const text = document.createElement('span');
    text.textContent = item;
    const removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.className = 'checklist-draft-remove';
    removeBtn.textContent = '×';
    removeBtn.setAttribute('aria-label', 'Remove checklist item');
    removeBtn.addEventListener('click', () => {
      checklistDraftItems.splice(index, 1);
      renderChecklistDraftItems();
    });
    row.appendChild(text);
    row.appendChild(removeBtn);
    checklistDraftList.appendChild(row);
  });
}

function addChecklistDraftItem(rawText) {
  const item = (rawText ?? '').trim();
  if (!item) return;
  if (checklistDraftItems.includes(item)) return;
  checklistDraftItems.push(item);
  renderChecklistDraftItems();
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

async function handleAddTask(user) {
  const title = titleInput.value.trim();
  if (!title) return;

  const checklistItems = [...checklistDraftItems];
  const selectedDate = (currentToday && parseDayKey(currentToday)) || parseDateInput(dateInput?.value) || new Date();
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

  if (!editingTaskRef) {
    pendingTasks.push({
      id: `pending-${Date.now()}`,
      ref: null,
      title,
      isDone: false,
      isRecurringDaily,
      dateKey: selectedDayKey,
      createdAtSeconds: Date.now() / 1000,
      checklist: checklistItems.map((text) => ({ text, isDone: false })),
    });
  }

  titleInput.value = '';
  checklistDraftItems = [];
  renderChecklistDraftItems();
  if (checklistItemInput) checklistItemInput.value = '';
  if (dateInput) dateInput.value = today;
  isRecurringDaily = false;
  hasReminder = false;
  reminderTimeInput.value = '09:00';
  refreshRecurringButton();
  refreshReminderVisibility();
  renderTasks();

  const taskData = {
    title,
    isDone: false,
    isRecurringDaily,
    dateKey: selectedDayKey,
    lastResetOn: today,
    createdAt: serverTimestamp(),
  };
  if (checklistItems.length > 0) {
    taskData.checklist = checklistItems.map((itemText) => ({ text: itemText, isDone: false }));
  }

  if (hasValidReminder) {
    taskData.reminderHour = reminderTime.hour;
    taskData.reminderMinute = reminderTime.minute;
    taskData.remindAt = remindAt;
    taskData.reminderPending = true;
  }

  if (editingTaskRef) {
    taskData.reminderHour = hasValidReminder ? reminderTime.hour : null;
    taskData.reminderMinute = hasValidReminder ? reminderTime.minute : null;
    taskData.remindAt = hasValidReminder ? remindAt : null;
    taskData.reminderPending = Boolean(hasValidReminder);
    await updateDoc(editingTaskRef, taskData);
  } else {
    await addDoc(collection(db, 'todo', user.uid, 'tasks'), taskData);
  }
  editingTaskRef = null;
  setComposerVisibility(false);
}

function setSignedInUI(signedIn) {
  loadingText.hidden = true;
  authSection.hidden = signedIn;
  todoSection.hidden = !signedIn;
  logoutBtn.hidden = !signedIn;
  if (!signedIn) {
    setComposerVisibility(false);
  }
}

function setLoadingUI() {
  loadingText.hidden = false;
  authSection.hidden = true;
  todoSection.hidden = true;
  logoutBtn.hidden = true;
}

function setTaskComposerVisibility(open) {
  taskList.hidden = !open;
  if (!open) {
    setComposerVisibility(false);
    return;
  }
  if (addTaskFab && activeUser && !isComposerOpen) {
    addTaskFab.hidden = false;
  }
}

closeComposerBtn.addEventListener('click', () => setComposerVisibility(false));
composerBackdrop.addEventListener('click', () => setComposerVisibility(false));
addTaskFab.addEventListener('click', () => openAddEditor());
taskActionCancelBtn.addEventListener('click', closeTaskActionSheet);
taskActionBackdrop.addEventListener('click', closeTaskActionSheet);
taskActionEditBtn.addEventListener('click', () => {
  if (!selectedTaskAction) return;
  const task = selectedTaskAction;
  closeTaskActionSheet();
  openEditEditor(task);
});
taskActionDeleteBtn.addEventListener('click', async () => {
  if (!selectedTaskAction?.ref) return;
  const taskRef = selectedTaskAction.ref;
  closeTaskActionSheet();
  await deleteDoc(taskRef);
});
journalDetailCloseBtn.addEventListener('click', () => {
  if (journalDetailSheet) journalDetailSheet.hidden = true;
  if (journalDetailBackdrop) journalDetailBackdrop.hidden = true;
});
journalDetailBackdrop.addEventListener('click', () => {
  if (journalDetailSheet) journalDetailSheet.hidden = true;
  if (journalDetailBackdrop) journalDetailBackdrop.hidden = true;
});
tasksTabBtn.addEventListener('click', () => setActiveTab('tasks'));
journalTabBtn.addEventListener('click', () => setActiveTab('journal'));
addJournalFab.addEventListener('click', () => setJournalComposerVisibility(true));
closeJournalComposerBtn.addEventListener('click', () => setJournalComposerVisibility(false));
journalComposerBackdrop.addEventListener('click', () => setJournalComposerVisibility(false));

authSubmitBtn.addEventListener('click', handleAuthSubmit);
switchModeBtn.addEventListener('click', () => {
  registerMode = !registerMode;
  authSubmitBtn.textContent = registerMode ? 'Register' : 'Sign in';
  switchModeBtn.textContent = registerMode ? 'Back to sign in' : 'Create account';
  authError.hidden = true;
});
logoutBtn.addEventListener('click', async () => signOut(auth));
if (repeatDailyCheckbox) {
  repeatDailyCheckbox.addEventListener('change', () => {
    isRecurringDaily = repeatDailyCheckbox.checked;
    refreshRecurringButton();
  });
}
if (reminderToggle) {
  reminderToggle.addEventListener('change', () => {
    hasReminder = reminderToggle.checked;
    if (hasReminder && !parseTimeInput(reminderTimeInput.value)) {
      reminderTimeInput.value = '09:00';
    }
    refreshReminderVisibility();
  });
}
if (checklistItemInput) {
  checklistItemInput.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter') return;
    e.preventDefault();
    addChecklistDraftItem(checklistItemInput.value);
    checklistItemInput.value = '';
  });
}
if (dateInput) {
  dateInput.addEventListener('change', () => {
    const selected = parseDateInput(dateInput.value);
    if (!selected) return;
    currentToday = dayKey(selected);
    renderDateStrip();
    renderTasks();
  });
}
saveJournalBtn.addEventListener('click', async () => {
  if (!activeUser) return;
  const title = (journalTitleInput.value || '').trim();
  const content = (journalBodyInput.value || '').trim();
  if (!title && !content) return;
  await addDoc(collection(db, 'todo', activeUser.uid, 'journal_entries'), {
    title,
    content,
    createdAt: serverTimestamp(),
  });
  journalTitleInput.value = '';
  journalBodyInput.value = '';
  setJournalComposerVisibility(false);
});
calendarPrevBtn.addEventListener('click', () => {
  if (!currentToday) return;
  currentToday = dayKey(shiftDate(parseDayKey(currentToday), -1));
  if (dateInput) dateInput.value = currentToday;
  renderDateStrip();
  renderTasks();
});
calendarNextBtn.addEventListener('click', () => {
  if (!currentToday) return;
  currentToday = dayKey(shiftDate(parseDayKey(currentToday), 1));
  if (dateInput) dateInput.value = currentToday;
  renderDateStrip();
  renderTasks();
});

setLoadingUI();
onAuthStateChanged(auth, (user) => {
  if (stopTasksListener) {
    stopTasksListener();
    stopTasksListener = null;
  }
  if (stopJournalListener) {
    stopJournalListener();
    stopJournalListener = null;
  }
  if (!user) {
    activeUser = null;
    setTaskComposerVisibility(true);
    setSignedInUI(false);
    return;
  }

  setSignedInUI(true);
  activeUser = user;
  currentToday = dayKey(new Date());
  dateInput.value = currentToday;
  renderDateStrip();
  isRecurringDaily = false;
  hasReminder = false;
  refreshRecurringButton();
  refreshReminderVisibility();
  pendingTasks = [];
  journalSnapshots = [];
  setTaskComposerVisibility(true);
  setActiveTab(activeTab);
  const q = query(collection(db, 'todo', user.uid, 'tasks'), orderBy('createdAt', 'desc'));
  stopTasksListener = onSnapshot(q, (snapshot) => {
    snapshotTasks = snapshot.docs;
    renderTasks();
  });
  const jq = query(collection(db, 'todo', user.uid, 'journal_entries'), orderBy('createdAt', 'desc'));
  stopJournalListener = onSnapshot(jq, (snapshot) => {
    journalSnapshots = snapshot.docs;
    renderJournalEntries();
  });
  addTaskBtn.onclick = () => handleAddTask(user);
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
});
