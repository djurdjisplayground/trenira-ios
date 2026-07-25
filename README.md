<<<<<<< HEAD
# trenira-ios
=======
# trenira

A simple strength-training tracker. Create custom workouts, log sets and reps, and get smart weight suggestions — all stored locally in your browser.

## Features

- **Workout management** — Create, edit, and delete named workouts
- **Exercise database** — 30+ common lifts searchable by name, muscle group, or equipment
- **Set tracking** — Tap to check off each set during a live session
- **Progressive overload** — When all sets are complete, the app prompts you to increase, decrease, or keep your weight
- **Global weight sync** — Changing an exercise's weight in one workout updates it everywhere that exercise appears
- **Offline-first** — All data stored locally via IndexedDB (no account required)
- **AI-ready** — Stubs for workout regeneration and voice input (see `src/services/aiService.ts`)

## Getting Started

```bash
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) in your browser.

## How It Works

1. **Create a workout** and give it a name (e.g. "Push Day")
2. **Add exercises** from the built-in database with sets, reps, and starting weight
3. **Start a session** and check off sets as you complete them
4. **Adjust weight** when prompted — the new weight applies to that exercise in all workouts

## Project Structure

```
src/
  db/           IndexedDB schema and exercise seed data
  services/     Workout logic and AI extension stubs
  components/   Reusable UI components
  pages/        Home, editor, session, and AI placeholder
  types/        TypeScript interfaces
```

## Future: AI & Voice

See `src/services/aiService.ts` for interfaces to implement:

- **Workout regeneration** when changing gyms or refreshing a routine
- **Progression preservation** so AI swaps exercises without losing gains
- **Voice logging** via Web Speech API or a speech-to-text provider

## Tech Stack

- React 19 + TypeScript + Vite
- Tailwind CSS 4
- Dexie (IndexedDB)
- React Router

## Build

```bash
npm run build
npm run preview
```
>>>>>>> fac575e (Save latest trenira changes before GitHub sync)
