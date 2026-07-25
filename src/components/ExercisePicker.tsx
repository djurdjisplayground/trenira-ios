import { useEffect, useState } from 'react'
import type { Exercise } from '../types'
import { searchExercises } from '../services/workoutService'

interface ExercisePickerProps {
  onSelect: (exercise: Exercise) => void
  onClose: () => void
}

export function ExercisePicker({ onSelect, onClose }: ExercisePickerProps) {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Exercise[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    searchExercises(query).then((data) => {
      if (!cancelled) {
        setResults(data)
        setLoading(false)
      }
    })
    return () => {
      cancelled = true
    }
  }, [query])

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/30 p-4 sm:items-center">
      <div className="flex max-h-[80dvh] w-full max-w-lg flex-col rounded-2xl bg-white shadow-xl">
        <div className="border-b border-rose-100 p-4">
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-slate-850">Choose Exercise</h2>
            <button
              type="button"
              onClick={onClose}
              className="rounded-lg px-2 py-1 text-sm text-slate-500 hover:bg-slate-100"
            >
              Close
            </button>
          </div>
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search by name, muscle, or equipment..."
            className="w-full rounded-xl border border-rose-200 bg-rose-50/50 px-4 py-2.5 text-sm outline-none focus:border-rose-400 focus:ring-2 focus:ring-rose-200"
            autoFocus
          />
        </div>
        <ul className="flex-1 overflow-y-auto p-2">
          {loading ? (
            <li className="p-4 text-center text-sm text-slate-500">Loading...</li>
          ) : results.length === 0 ? (
            <li className="p-4 text-center text-sm text-slate-500">No exercises found</li>
          ) : (
            results.map((exercise) => (
              <li key={exercise.id}>
                <button
                  type="button"
                  onClick={() => onSelect(exercise)}
                  className="w-full rounded-xl px-3 py-3 text-left transition hover:bg-rose-50"
                >
                  <span className="block font-medium text-slate-850">{exercise.name}</span>
                  <span className="mt-0.5 block text-xs text-slate-500">
                    {exercise.muscleGroup} · {exercise.equipment}
                  </span>
                </button>
              </li>
            ))
          )}
        </ul>
      </div>
    </div>
  )
}
