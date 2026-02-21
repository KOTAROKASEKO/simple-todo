# SimpleTodo Browser Extension

This extension provides a popup UI for your Firebase-backed todos.

## Features
- Email/password sign in and register
- Add today's task
- Toggle done/undone
- Delete task
- Done items sorted to bottom

## Build

From `browser_extension/`:

```bash
npm install
npm run build
```

This generates `popup.js`.

## Load in Chrome

1. Open `chrome://extensions`
2. Enable **Developer mode**
3. Click **Load unpacked**
4. Select this `browser_extension` folder

## Notes

- Uses the same Firebase project as your app.
- Firestore rules must allow user-scoped access to `todo/{uid}/tasks`.
