# Chrome Web Store release checklist

## 1. Build upload zip (required)

From `browser_extension/`:

```bash
npm install
npm run package
```

Upload **`simpletodo-extension.zip`** only (~1 MB).  
Never upload the whole folder (excludes `node_modules/`, `webapp/`, `src/`).

## 2. Store listing (Developer Dashboard)

| Field | Suggestion |
|-------|------------|
| **Single purpose** | Side-panel todo list and journal synced with the SimpleTodo mobile app. |
| **Permission justification** | `storage` — keep sign-in session; `sidePanel` — show tasks in the browser side panel. |
| **Privacy policy** | Public URL to your privacy policy (required for sign-in / Firebase). Example: host `website/privacy-policy.html` on Firebase Hosting. |
| **Screenshots** | 1280×800 or 640×400 — side panel with tasks + journal tab. |
| **Icon** | 128×128 PNG (use `icons/icon-128.png`) |

## 3. Common rejection reasons (avoid)

- **Remote code** — Do not load scripts from CDN or embed Flutter web in iframe.
- **Extra permissions** — Do not request `alarms`, `tabs`, `host_permissions` unless the UI uses them.
- **Duplicate manifest** — Do not include `webapp/` in the zip (old Flutter build had its own manifest).
- **Vague description** — Avoid “connected to Firebase”; describe user-facing features.
- **Non-functional listing** — Test sign-in, add task, journal on a clean Chrome profile before submit.

## 4. Resubmission after rejection

1. Read the rejection email (policy vs. technical).
2. Fix code, bump `version` in `manifest.json`.
3. `npm run package` and upload the new zip.
4. Reply in Dashboard if they asked for clarification.

## 5. Review time

- First submission: often 1–3 business days (sometimes longer).
- Updates to same extension: usually faster.
- Rejections with clear fixes + short note in “Notes to reviewer” speed resubmission.
