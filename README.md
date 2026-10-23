# SoloLvlUp Education

A working, synthetic-data prototype of the student → evidence → educator review → verified progress journey. React/TypeScript/Vite, Zustand, Supabase integration scaffold, and Capacitor configuration.

## Run

```
npm ci
npm run dev
npm test
npm run build
```

## Demonstrate (3 minutes)
1. Student Overview → open **Turn a concept into a real-world solution**.
2. Enter evidence with at least 30 characters; save a device draft or submit.
3. **Explore roles → Subject teacher → Review Queue**.
4. Open the submission, assess all three criteria, add actionable feedback and verify. Alternatively request a revision and resubmit as student.
5. Switch to Student → My Portfolio. Inspect the achievement and export JSON.
6. Class mentor → Interventions → create and complete a support action.
7. Parent → Shared Progress: approved achievements only; no private reflection.
8. Institution leader → Analytics: metrics update from synthetic records.

## What is working
- Five-attribute capability map, related quests and stage explanations.
- Editable learner goals and time availability; rules-based recommendation.
- Text evidence submission, rubric review, revision, verified status, idempotent participation reward.
- Local persistence, portfolio export, mentor interventions, optional challenge participation.
- Synthetic role-specific dashboards, parent summaries, private reflection view, analytics.
- Unit tests for core decision rules.

## Current limitations — read before using real data
- Running demo uses browser storage, not a live cloud database. Demo identities are NOT authentication or security boundaries. All data is synthetic; do not enter personal/sensitive data.
- File selection saves metadata only, not bytes. It is explicitly labelled in the UI.
- Real diagnostic question flow, invitation/onboarding, framework editing, multi-stage competency validation, moderation UI and native secure token storage are not implemented.
- Framework nodes show verified evidence presence; no claim of all five mastery stages being validated.
- UI reads/writes local demo state. Supabase Auth sign-in can be smoke-tested if configured, but cloud repository functions are not yet connected to the main application views.
- No live Gemini calls without the separately deployed function and secrets. No APK or native build has been produced.
- SQL migration is prepared but has not been applied or database-tested. Before using real data, complete integration, run RLS tests with separate identities, and review access policies.

## Supabase setup
Use a dedicated prototype project. Apply `supabase/migrations/202610220001_initial.sql`; it creates an isolated `education` schema, own-record permissions and validated RPC review operations. Enable the `education` schema in the Data API settings. Provision auth accounts, institutions, memberships and explicit relationships through an authorised server management path. No client can grant its own role.

Set public frontend configuration through `.env.local`, using `.env.example`. Never put a service-role key or Gemini key in a `VITE_` variable. The migration deliberately denies direct client writes to verified quest status, reviews and rewards. `review_evidence` atomically checks the assigned reviewer, records the review and issues one reward per quest.

Review and extend private Storage policies before enabling educator downloads: the initial bucket policy permits owner uploads/reads only. Add an evidence-object relationship before granting reviewer access.

Deploy `supabase/functions/recommend` and set `GEMINI_API_KEY`, `GEMINI_MODEL`, `APP_ORIGIN` as server secrets. Function authenticates callers, reads their allowed data, enforces 20 calls per day and validates suggested quest IDs. It falls back to a rules-based recommendation. Test it before connecting frontend.

`src/cloud.ts` provides typed integration entry points for the next integration step.

## Deployment
`npm run build` emits `dist/`. Serve it on a static host. Sites identity is tracked in `.openai/hosting.json`; source is synced to the dedicated site repository. Add a fallback to index.html if adding history-based routes later.

## Android
```
npm run build
npx cap add android
npx cap sync android
npx cap open android
```
Requires Android SDK/JDK/Android Studio. `webDir` is `dist`. Implement native lifecycle, deep-link auth and secure token storage before a real pilot. Preferences plugin is installed but no native persistence adapter is enabled yet.

## Data ownership
PostgreSQL should own shared records; TanStack Query should cache cloud responses; Zustand stores UI preferences only. Synthetic demo state currently has its own versioned local key. Production cloud data must never be merged with it. Clear caches and drafts on account change. Do not cache private reflection/counselling records on disk.

## Framework
Fitness, Intellectual, Emotional, Social and Spiritual form an original prototype framework. No official curriculum approval or institutional pilot outcomes are claimed. Spiritual reflection respects religious and non-religious students. Private feelings and beliefs are never ranked.

## Vercel deployment and Gemini
The repository includes `vercel.json` and a Node.js Vercel Function at `/api/recommend`.

Vercel build: Vite, command `npm run build`, output `dist`.

Set frontend variables `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` before building. Set server-only variables `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `GEMINI_API_KEY`, and `GEMINI_MODEL` in Vercel environment settings. Redeploy after environment changes. Never place private keys in VITE_ variables.

The endpoint requires a real Supabase bearer token, an authorised learner profile, and the database-backed daily budget RPC. Missing setup returns a labelled 503; missing AI secrets uses the rules fallback. It reads only the caller's authorised context and validates model-suggested quest IDs. Private reflections are never sent to Gemini. Live UI integration remains pending project selection; a new API function alone does not enable AI in the local demonstration.
