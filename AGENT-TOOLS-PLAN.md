# Agent Tools Plan — Browser Error Capture & CI Monitor

## Overview

Build two tools that give Claude direct visibility into the running system,
eliminating the need to manually copy-paste errors from the browser or GitHub Actions.

Combined with a 5-attempt autonomous fix loop, Claude can investigate, fix,
deploy, and verify — stopping after 5 attempts if unresolved, then handing back to the user.

---

## Tool 1 — Browser Error Capture (Playwright)

### What It Does
Opens a real browser, navigates to a given URL, and captures:
- Console errors and warnings
- Failed network requests (4xx, 5xx)
- Uncaught JavaScript exceptions
- Page crash / load failures

Returns everything as structured JSON so Claude can read and act on it.

### File
```
tools/
└── browser-check.js       ← Node.js script using Playwright
```

### How Claude Calls It
```bash
node tools/browser-check.js --url http://localhost/shop
node tools/browser-check.js --url http://localhost/admin
```

### Output Format (JSON)
```json
{
  "url": "http://localhost/shop",
  "status": "errors_found",
  "console_errors": [
    {
      "type": "error",
      "message": "TypeError: Cannot read properties of undefined (reading 'map')",
      "location": "main.abc123.js:1:4521"
    }
  ],
  "network_failures": [
    {
      "url": "http://localhost/api/v1/products",
      "status": 500,
      "method": "GET"
    }
  ],
  "page_errors": []
}
```

### Implementation Steps
1. `npm init` a `tools/` folder with Playwright as a dependency
2. Write `browser-check.js`:
   - Accept `--url` argument
   - Launch Chromium headlessly
   - Register listeners: `page.on('console')`, `page.on('pageerror')`, `page.on('requestfailed')`
   - Navigate to the URL and wait for network idle
   - Collect all captured events
   - Print JSON to stdout and exit
3. Test manually against the broken pages
4. Document in README

---

## Tool 2 — GitHub Actions CI Monitor

### What It Does
Watches a GitHub Actions workflow run and waits for it to complete.
If it fails, fetches the failed step logs and returns them so Claude
can understand what went wrong without opening GitHub in the browser.

### File
```
tools/
└── ci-monitor.sh          ← Bash script using gh CLI
```

### How Claude Calls It
```bash
# Watch the most recent run on a branch
./tools/ci-monitor.sh --repo faisal-dilawar/shopizer --branch ai_session

# Watch a specific run ID
./tools/ci-monitor.sh --repo faisal-dilawar/shopizer --run-id 12345678
```

### Output Format
On success:
```
[CI Monitor] Run #12345678 — PASSED (2m 14s)
All steps completed successfully.
```

On failure:
```
[CI Monitor] Run #12345678 — FAILED
Failed step: "Run Tests"
--- LOG OUTPUT ---
[ERROR] Tests run: 12, Failures: 1, Errors: 0
com.salesmanager.test.shop.integration.cart.ShoppingCartAPIIntegrationTest
  expected: 201 but was: 500
  at ShoppingCartAPIIntegrationTest.java:47
-----------------
```

### Implementation Steps
1. Write `ci-monitor.sh`:
   - Accept `--repo`, `--branch`, `--run-id` arguments
   - If no run-id: use `gh run list` to get the latest run on the branch
   - Poll `gh run view <run-id>` every 15 seconds until status is not `in_progress`
   - If passed: print success
   - If failed: use `gh run view <run-id> --log-failed` to fetch failed step logs
   - Print logs to stdout
2. Make executable: `chmod +x tools/ci-monitor.sh`
3. Test against a real failing and passing build
4. Document in README

---

## The Autonomous Fix Loop

### Slash Command
```
~/.claude/commands/fix-and-deploy.md
```

Invoked by typing `/fix-and-deploy` in the chat.

### Loop Logic

```
Max attempts: 5

For each attempt (1 to 5):

  Step 1 — Capture Browser Errors
    node tools/browser-check.js --url <url>
    If no errors → DONE. Report success to user.

  Step 2 — Analyse & Fix
    Read the error. Find the root cause in the code.
    Edit the relevant file(s) to fix it.

  Step 3 — Commit & Push  (requires user confirmation)
    Stage specific files.
    Show proposed commit message → ask user to confirm.
    Push to GitHub → ask user to confirm.

  Step 4 — Wait for CI
    ./tools/ci-monitor.sh --repo <repo> --branch <branch>
    If CI fails → read the logs → go back to Step 2 with CI error.
    If CI passes → continue.

  Step 5 — Deploy
    ./provision-and-deploy.sh
    Wait for deployment to complete.

  Step 6 — Verify
    node tools/browser-check.js --url <url>
    If no errors → DONE. Report success to user.
    If still errors → next attempt.

If attempt 5 ends with errors still present:
  STOP. Report to user:
  - How many attempts were made
  - What was tried each time
  - What the current error still is
  - Suggested next steps
```

### Loop Limit Behaviour
```
Attempt 1 ── fix ── deploy ── verify ── still broken
Attempt 2 ── fix ── deploy ── verify ── still broken
Attempt 3 ── fix ── deploy ── verify ── still broken
Attempt 4 ── fix ── deploy ── verify ── still broken
Attempt 5 ── fix ── deploy ── verify ── still broken
                                              │
                                              ▼
                                    STOP — Hand back to user
                                    "I tried 5 times. Here is
                                     what I found and attempted.
                                     Your input is needed."
```

---

## Deliberate Bugs to Introduce (Stage Setup)

One bug per frontend, on a non-authenticated page, for simplicity.

### React Shop — `shopizer-shop-reactjs`
- **Type:** Bad API call on the homepage
- **How:** Call a non-existent endpoint (e.g., `/api/v1/does-not-exist`)
- **Visible as:** Network error in DevTools + broken UI render

### Angular Admin — `shopizer-admin`
- **Type:** JavaScript reference error on the login/landing page
- **How:** Reference an undefined variable in a component
- **Visible as:** Console error in DevTools + component fails to load

Both errors will be clearly captured by the Playwright tool.

---

## Folder Structure After Implementation

```
tools/
├── package.json            ← Node deps (Playwright)
├── browser-check.js        ← Tool 1: Playwright error capture
└── ci-monitor.sh           ← Tool 2: GitHub Actions monitor

~/.claude/commands/
├── commit-push.md          ← existing
└── fix-and-deploy.md       ← new: the 5-attempt loop command
```

---

## Confirmation Checkpoints (User Stays in Control)

Even inside the autonomous loop, the following always require confirmation:

| Action | Prompt |
|--------|--------|
| Commit | "Confirm commit with these files and message?" |
| Push   | "Ready to push to origin/branch. Confirm?" |
| Deploy | "Ready to run provision-and-deploy.sh. Confirm?" |

After 5 failed attempts, the loop stops completely and waits for the user.
