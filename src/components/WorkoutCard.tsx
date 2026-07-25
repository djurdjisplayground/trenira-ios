import { Link } from 'react-router-dom'
import type { Workout } from '../types'

interface WorkoutCardProps {
  workout: Workout
  exerciseCount: number
  onDelete: (id: string) => void
}

export function WorkoutCard({ workout, exerciseCount, onDelete }: WorkoutCardProps) {
  return (
    <div className="group rounded-2xl bg-white/90 p-4 shadow-sm ring-1 ring-rose-100 transition hover:shadow-md">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <h2 className="truncate text-lg font-semibold text-slate-850">{workout.name}</h2>
          <p className="mt-1 text-sm text-slate-500">
            {exerciseCount} {exerciseCount === 1 ? 'exercise' : 'exercises'}
          </p>
        </div>
        <button
          type="button"
          onClick={() => onDelete(workout.id)}
          className="rounded-lg px-2 py-1 text-xs font-medium text-red-400 opacity-0 transition group-hover:opacity-100 hover:bg-red-50 hover:text-red-600"
          aria-label={`Delete ${workout.name}`}
        >
          Delete
        </button>
      </div>
      <div className="mt-4 flex gap-2">
        <Link
          to={`/workout/${workout.id}/edit`}
          className="flex-1 rounded-xl bg-rose-50 py-2 text-center text-sm font-semibold text-rose-700 transition hover:bg-rose-100"
        >
          Edit
        </Link>
        <Link
          to={`/workout/${workout.id}/session`}
          className="flex-1 rounded-xl bg-rose-600 py-2 text-center text-sm font-semibold text-white shadow-sm transition hover:bg-rose-700"
        >
          Start
        </Link>
      </div>
    </div>
  )
}
