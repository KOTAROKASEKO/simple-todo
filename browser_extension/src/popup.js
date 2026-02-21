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

const titleInput = document.getElementById('titleInput');
const descInput = document.getElementById('descInput');
const recurringInput = document.getElementById('recurringInput');
const addTaskBtn = document.getElementById('addTaskBtn');
const taskList = document.getElementById('taskList');
const taskSheet = document.getElementById('taskSheet');
const taskSheetBackdrop = document.getElementById('taskSheetBackdrop');
const sheetEditBtn = document.getElementById('sheetEditBtn');
const sheetDeleteBtn = document.getElementById('sheetDeleteBtn');
const sheetCancelBtn = document.getElementById('sheetCancelBtn');

let registerMode = false;
let stopTasksListener = null;
let selectedTask = null;

function dayKey(date) {
  const y = String(date.getFullYear()).padStart(4, '0');
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
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

function renderTasks(docs) {
  taskList.innerHTML = '';
  if (docs.length === 0) {
    const li = document.createElement('li');
    li.className = 'task';
    li.textContent = 'No tasks for today.';
    taskList.appendChild(li);
    return;
  }

  docs.forEach((snap) => {
    const data = snap.data();
    const taskRef = doc(db, snap.ref.path);
    const li = document.createElement('li');
    li.className = `task ${data.isDone ? 'done' : ''}`;
    li.title = 'Click to show options';

    const top = document.createElement('div');
    top.className = 'task-top';

    const left = document.createElement('div');
    left.className = 'task-main';

    const toggleBtn = document.createElement('button');
    toggleBtn.className = 'icon-btn task-toggle';
    toggleBtn.title = data.isDone ? 'Mark as undone' : 'Mark as done';
    toggleBtn.setAttribute('aria-label', toggleBtn.title);
    toggleBtn.textContent = data.isDone ? '↺' : '✓';
    toggleBtn.addEventListener('click', async (event) => {
      event.stopPropagation();
      await updateDoc(taskRef, { isDone: !data.isDone });
    });
    left.appendChild(toggleBtn);

    const title = document.createElement('p');
    title.className = 'task-title';
    title.textContent = data.title ?? 'Untitled task';
    left.appendChild(title);
    top.appendChild(left);

    const kind = document.createElement('small');
    kind.textContent = data.isRecurringDaily ? 'Recurring' : 'One-day';
    top.appendChild(kind);

    li.appendChild(top);

    const desc = document.createElement('p');
    desc.className = 'task-desc';
    desc.textContent = data.description || 'No description';
    li.appendChild(desc);
    li.addEventListener('click', () => {
      openTaskSheet({
        ref: taskRef,
        title: data.title ?? '',
        description: data.description ?? '',
      });
    });
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

async function handleAddTask(user) {
  const title = titleInput.value.trim();
  if (!title) return;

  const today = dayKey(new Date());
  await addDoc(collection(db, 'todo', user.uid, 'tasks'), {
    title,
    description: descInput.value.trim(),
    isDone: false,
    isRecurringDaily: recurringInput.checked,
    dateKey: today,
    lastResetOn: today,
    createdAt: serverTimestamp(),
  });

  titleInput.value = '';
  descInput.value = '';
  recurringInput.checked = false;
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

setLoadingUI();
onAuthStateChanged(auth, (user) => {
  setLoadingUI();
  if (stopTasksListener) {
    stopTasksListener();
    stopTasksListener = null;
  }

  if (!user) {
    closeTaskSheet();
    setSignedInUI(false);
    return;
  }

  setSignedInUI(true);
  const today = dayKey(new Date());
  const q = query(collection(db, 'todo', user.uid, 'tasks'), orderBy('createdAt', 'desc'));
  stopTasksListener = onSnapshot(q, (snapshot) => {
    const docs = snapshot.docs
      .filter((snap) => shouldShowTaskForToday(snap.data(), today))
      .sort((a, b) => {
        const aDone = Boolean(a.data().isDone);
        const bDone = Boolean(b.data().isDone);
        if (aDone !== bDone) return aDone ? 1 : -1;
        const aCreated = a.data().createdAt?.seconds ?? 0;
        const bCreated = b.data().createdAt?.seconds ?? 0;
        return bCreated - aCreated;
      });
    renderTasks(docs);
  });

  addTaskBtn.onclick = () => handleAddTask(user);
  titleInput.onkeydown = (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleAddTask(user);
    }
  };
});
