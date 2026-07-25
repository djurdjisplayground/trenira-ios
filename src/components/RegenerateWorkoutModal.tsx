import { useState } from 'react'
import { Button } from './Button'
import type { GymEquipment, SuggestedExercise } from '../types/ai'
import { DEFAULT_GYM_EQUIPMENT } from '../types/ai'

interface RegenerateWorkoutModalProps {
  onGenerate: (
    reason: 'new_gym' | 'bored' | 'plateau',
    equipment: GymEquipment,
  ) => Promise<void>
  onApply: (exercises: SuggestedExercise[]) => Promise<void>
  onClose: () => void
  loading: boolean
  suggestions: SuggestedExercise[] | null
  usedAi: boolean
}

const EQUIPMENT_OPTIONS: Array<{ key: keyof GymEquipment; label: string }> = [
  { key: 'hasBarbell', label: 'Barbell' },
  { key: 'hasDumbbells', label: 'Dumbbells' },
  { key: 'hasCables', label: 'Cables' },
  { key: 'hasMachines', label: 'Machines' },
  { key: 'hasKettlebells', label: 'Kettlebells' },
]

export function RegenerateWorkoutModal({
  onGenerate,
  onApply,
  onClose,
  loading,
  suggestions,
  usedAi,
}: RegenerateWorkoutModalProps) {
  const [reason, setReason] = useState<'new_gym' | 'bored' | 'plateau'>('bored')
  const [equipment, setEquipment] = useState<GymEquipment>({ ...DEFAULT_GYM_EQUIPMENT })

  function toggleEquipment(key: keyof GymEquipment) {
    setEquipment((prev) => ({ ...prev, [key]: !prev[key] }))
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/30 p-4 sm:items-center">
      <div className="flex max-h-[85dvh] w-full max-w-lg flex-col overflow-hidden rounded-2xl bg-white shadow-xl">
        <div className="border-b border-rose-100 p-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-slate-850">✨ Regenerate Workout</h2>
            <button
              type="button"
              onClick={onClose}
              className="rounded-lg px-2 py-1 text-sm text-slate-500 hover:bg-slate-100"
            >
              Close
            </button>
          </div>
          <p className="mt-1 text-sm text-slate-500">
            Swap exercises while keeping your sets, reps, and weights.
          </p>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {!suggestions ? (
            <>
              <fieldset className="mb-4">
                <legend className="mb-2 text-sm font-medium text-slate-700">Why regenerate?</legend>
                <div className="flex flex-col gap-2">
                  {(
                    [
                      ['new_gym', 'New gym', 'Equipment may differ — find alternatives'],
                      ['bored', 'Need variety', 'Fresh exercises, same muscle targets'],
                      ['plateau', 'Hit a plateau', 'Adjust rep schemes to break through'],
                    ] as const
                  ).map(([value, title, desc]) => (
                    <label
                      key={value}
                      className={`flex cursor-pointer items-start gap-3 rounded-xl border-2 p-3 transition ${
                        reason === value
                          ? 'border-rose-400 bg-rose-50'
                          : 'border-rose-100 hover:border-rose-200'
                      }`}
                    >
                      <input
                        type="radio"
                        name="reason"
                        value={value}
                        checked={reason === value}
                        onChange={() => setReason(value)}
                        className="mt-1"
                      />
                      <div>
                        <span className="block text-sm font-semibold text-slate-850">{title}</span>
                        <span className="text-xs text-slate-500">{desc}</span>
                      </div>
                    </label>
                  ))}
                </div>
              </fieldset>

              <fieldset>
                <legend className="mb-2 text-sm font-medium text-slate-700">Available equipment</legend>
                <div className="flex flex-wrap gap-2">
                  {EQUIPMENT_OPTIONS.map(({ key, label }) => (
                    <button
                      key={key}
                      type="button"
                      onClick={() => toggleEquipment(key)}
                      className={`rounded-full px-3 py-1.5 text-sm font-medium transition ${
                        equipment[key]
                          ? 'bg-rose-600 text-white'
                          : 'bg-rose-50 text-rose-400 ring-1 ring-rose-200'
                      }`}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              </fieldset>
            </>
          ) : (
            <div>
              <p className="mb-3 text-sm text-slate-500">
                {usedAi ? 'AI-generated suggestions' : 'Smart local suggestions'} — review before applying:
              </p>
              <ul className="flex flex-col gap-3">
                {suggestions.map((s) => (
                  <li
                    key={s.exerciseId}
                    className="rounded-xl bg-rose-50/60 p-3 ring-1 ring-rose-100"
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <h3 className="font-semibold text-slate-850">{s.exerciseName}</h3>
                        <p className="text-xs text-slate-500">
                          {s.sets} × {s.reps} @ {s.weight} lbs · {s.equipment}
                        </p>
                      </div>
                      {s.replacedExerciseName && (
                        <span className="shrink-0 rounded-full bg-white px-2 py-0.5 text-xs text-rose-600">
                          ↻ from {s.replacedExerciseName}
                        </span>
                      )}
                    </div>
                    <p className="mt-2 text-xs leading-relaxed text-slate-600">{s.rationale}</p>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>

        <div className="border-t border-rose-100 p-4">
          {!suggestions ? (
            <Button fullWidth onClick={() => onGenerate(reason, equipment)} disabled={loading}>
              {loading ? 'Generating…' : 'Generate New Routine'}
            </Button>
          ) : (
            <div className="flex gap-2">
              <Button fullWidth onClick={() => onApply(suggestions)} disabled={loading}>
                Apply to Workout
              </Button>
              <Button variant="ghost" onClick={onClose}>
                Cancel
              </Button>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
