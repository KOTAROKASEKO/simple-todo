# SimpleTodo Browser Extension

Chrome side-panel companion for SimpleTodo (tasks + journal via Firebase).

## Features

- Email/password sign in and register
- Tasks by date, checklists, recurring daily, reminders
- Journal entries list and compose

## Build & package for Chrome Web Store

```bash
npm install
npm run package
```

Produces `simpletodo-extension.zip` — upload this file only.

See **[STORE_CHECKLIST.md](./STORE_CHECKLIST.md)** for listing text, privacy policy, and rejection avoidance.

## Local development

```bash
npm run build
```

Then Chrome → `chrome://extensions` → Developer mode → **Load unpacked** → select this folder.

## Notes

- Uses the same Firebase project as the Flutter app.
- Firestore rules must allow user-scoped access to `todo/{uid}/tasks` and `todo/{uid}/journal_entries`.
- The `webapp/` folder is legacy (Flutter web build); **do not** include it in store uploads.
