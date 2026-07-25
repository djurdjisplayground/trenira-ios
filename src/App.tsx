import { useEffect, useState } from 'react'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { seedDatabaseIfNeeded } from './db/database'
import { HomePage } from './pages/HomePage'
import { WorkoutEditorPage } from './pages/WorkoutEditorPage'
import { WorkoutSessionPage } from './pages/WorkoutSessionPage'
import { AiPage } from './pages/AiPage'
import { registerSW } from 'virtual:pwa-register'

const updateSW = registerSW({
  onNeedRefresh() {
    if (confirm('New version available. Reload to update?')) {
      updateSW(true)
    }
  },
})

export default function App() {
  const [ready, setReady] = useState(false)

  useEffect(() => {
    seedDatabaseIfNeeded().then(() => setReady(true))
  }, [])

  if (!ready) {
    return (
      <div className="flex min-h-dvh items-center justify-center">
        <p className="text-sm text-slate-500">Loading trenira...</p>
      </div>
    )
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/workout/:id/edit" element={<WorkoutEditorPage />} />
        <Route path="/workout/:id/session" element={<WorkoutSessionPage />} />
        <Route path="/ai" element={<AiPage />} />
      </Routes>
    </BrowserRouter>
  )
}
