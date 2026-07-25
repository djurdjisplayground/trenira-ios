import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Layout } from '../components/Layout'
import { Button } from '../components/Button'
import { WorkoutCard } from '../components/WorkoutCard'
import { db } from '../db/database'
import { createWorkout, deleteWorkout, getAllWorkouts } from '../services/workoutService'
import type { Workout } from '../types'

export function HomePage() {
  const navigate = useNavigate()
  const [workouts, setWorkouts] = useState<Workout[]>([])
  const [exerciseCounts, setExerciseCounts] = useState<Record<string, number>>({})
  const [creating, setCreating] = useState(false)
  const [newName, setNewName] = useState('')

  async function loadWorkouts() {
    const list = await getAllWorkouts()
    setWorkouts(list)

    const counts: Record<string, number> = {}
    await Promise.all(
      list.map(async (w) => {
        counts[w.id] = await db.workoutExercises.where('workoutId').equals(w.id).count()
      }),
    )
    setExerciseCounts(counts)
  }

  useEffect(() => {
    loadWorkouts()
  }, [])

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault()
    if (!newName.trim()) return
    const workout = await createWorkout(newName)
    setNewName('')
    setCreating(false)
    navigate(`/workout/${workout.id}/edit`)
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this workout? This cannot be undone.')) return
    await deleteWorkout(id)
    loadWorkouts()
  }

  return (
    <Layout
      action={
        !creating ? (
          <Button variant="secondary" onClick={() => setCreating(true)}>
            + New
          </Button>
        ) : undefined
      }
    >
      <section className="mb-8">
        <h1 className="font-display text-3xl font-bold text-slate-850">Your Workouts</h1>
        <p className="mt-2 text-slate-500">
          Build your routine, track your sets, and grow stronger every session.
        </p>
      </section>

      {creating && (
        <form
          onSubmit={handleCreate}
          className="mb-6 rounded-2xl bg-white/90 p-4 shadow-sm ring-1 ring-rose-100"
        >
          <label className="mb-2 block text-sm font-medium text-slate-700">Workout name</label>
          <input
            type="text"
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            placeholder="e.g. Lower Body Power"
            className="mb-3 w-full rounded-xl border border-rose-200 bg-rose-50/50 px-4 py-2.5 text-sm outline-none focus:border-rose-400 focus:ring-2 focus:ring-rose-200"
            autoFocus
          />
          <div className="flex gap-2">
            <Button type="submit" disabled={!newName.trim()}>
              Create Workout
            </Button>
            <Button type="button" variant="ghost" onClick={() => setCreating(false)}>
              Cancel
            </Button>
          </div>
        </form>
      )}

      {workouts.length === 0 ? (
        <div className="rounded-2xl bg-white/70 p-8 text-center ring-1 ring-rose-100">
          <p className="text-4xl">💪</p>
          <p className="mt-3 font-medium text-slate-700">No workouts yet</p>
          <p className="mt-1 text-sm text-slate-500">
            Create your first workout to start tracking your lifts.
          </p>
          {!creating && (
            <Button className="mt-4" onClick={() => setCreating(true)}>
              Create Your First Workout
            </Button>
          )}
        </div>
      ) : (
        <ul className="flex flex-col gap-3">
          {workouts.map((workout) => (
            <li key={workout.id}>
              <WorkoutCard
                workout={workout}
                exerciseCount={exerciseCounts[workout.id] ?? 0}
                onDelete={handleDelete}
              />
            </li>
          ))}
        </ul>
      )}

      <footer className="mt-10 rounded-2xl bg-gradient-to-br from-rose-50 to-white p-4 ring-1 ring-rose-100">
        <p className="text-xs font-semibold uppercase tracking-wide text-rose-400">Coming soon</p>
        <p className="mt-1 text-sm text-slate-600">
          AI workout regeneration & voice logging —{' '}
          <Link to="/ai" className="font-medium text-rose-600 underline-offset-2 hover:underline">
            learn more
          </Link>
        </p>
      </footer>
    </Layout>
  )
}
