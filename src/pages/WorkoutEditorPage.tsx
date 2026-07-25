import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Layout } from '../components/Layout'
import { Button } from '../components/Button'
import { ExercisePicker } from '../components/ExercisePicker'
import { RegenerateWorkoutModal } from '../components/RegenerateWorkoutModal'
import { buildProgressionSnapshot, regenerateWorkout } from '../services/aiService'
import {
  addExerciseToWorkout,
  getExerciseWeight,
  getWorkoutWithExercises,
  removeExerciseFromWorkout,
  replaceWorkoutExercises,
  setExerciseWeight,
  updateWorkoutExercise,
  updateWorkoutName,
} from '../services/workoutService'
import type { Exercise, WorkoutExerciseWithDetails, WorkoutWithExercises } from '../types'
import type { GymEquipment, SuggestedExercise } from '../types/ai'

export function WorkoutEditorPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [workout, setWorkout] = useState<WorkoutWithExercises | null>(null)
  const [name, setName] = useState('')
  const [showPicker, setShowPicker] = useState(false)
  const [showRegenerate, setShowRegenerate] = useState(false)
  const [regenLoading, setRegenLoading] = useState(false)
  const [suggestions, setSuggestions] = useState<SuggestedExercise[] | null>(null)
  const [usedAi, setUsedAi] = useState(false)
  const [pendingExercise, setPendingExercise] = useState<Exercise | null>(null)
  const [formSets, setFormSets] = useState(3)
  const [formReps, setFormReps] = useState(10)
  const [formWeight, setFormWeight] = useState(0)

  async function reload() {
    if (!id) return
    const data = await getWorkoutWithExercises(id)
    if (!data) {
      navigate('/')
      return
    }
    setWorkout(data)
    setName(data.name)
  }

  useEffect(() => {
    reload()
  }, [id])

  async function handleSaveName() {
    if (!id || !name.trim()) return
    await updateWorkoutName(id, name)
    reload()
  }

  async function handleSelectExercise(exercise: Exercise) {
    setShowPicker(false)
    const existingWeight = await getExerciseWeight(exercise.id)
    setPendingExercise(exercise)
    setFormSets(3)
    setFormReps(10)
    setFormWeight(existingWeight)
  }

  async function handleAddExercise(e: React.FormEvent) {
    e.preventDefault()
    if (!id || !pendingExercise) return
    await addExerciseToWorkout(id, pendingExercise.id, formSets, formReps, formWeight)
    setPendingExercise(null)
    reload()
  }

  async function handleUpdateExercise(row: WorkoutExerciseWithDetails, sets: number, reps: number) {
    await updateWorkoutExercise(row.id, { sets, reps })
    reload()
  }

  async function handleWeightChange(exerciseId: string, weight: number) {
    await setExerciseWeight(exerciseId, weight)
    reload()
  }

  async function handleRemove(rowId: string) {
    if (!confirm('Remove this exercise from the workout?')) return
    await removeExerciseFromWorkout(rowId)
    reload()
  }

  async function handleGenerate(
    reason: 'new_gym' | 'bored' | 'plateau',
    equipment: GymEquipment,
  ) {
    if (!id || !workout) return
    setRegenLoading(true)
    try {
      const result = await regenerateWorkout({
        workoutId: id,
        workoutName: workout.name,
        currentExercises: buildProgressionSnapshot(workout.exercises),
        availableEquipment: equipment,
        reason,
      })
      setSuggestions(result.suggestedExercises)
      setUsedAi(result.usedAi)
    } finally {
      setRegenLoading(false)
    }
  }

  async function handleApplyRegeneration(exercises: SuggestedExercise[]) {
    if (!id) return
    setRegenLoading(true)
    try {
      await replaceWorkoutExercises(
        id,
        exercises.map((e) => ({
          exerciseId: e.exerciseId,
          sets: e.sets,
          reps: e.reps,
          weight: e.weight,
        })),
      )
      setShowRegenerate(false)
      setSuggestions(null)
      reload()
    } finally {
      setRegenLoading(false)
    }
  }

  if (!workout) {
    return (
      <Layout backTo="/" title="Loading...">
        <p className="text-center text-slate-500">Loading workout...</p>
      </Layout>
    )
  }

  return (
    <Layout
      backTo="/"
      title="Edit Workout"
      action={
        workout.exercises.length > 0 ? (
          <Button variant="secondary" onClick={() => navigate(`/workout/${id}/session`)}>
            Start
          </Button>
        ) : undefined
      }
    >
      <div className="mb-6 rounded-2xl bg-white/90 p-4 shadow-sm ring-1 ring-rose-100">
        <label className="mb-2 block text-sm font-medium text-slate-700">Workout name</label>
        <div className="flex gap-2">
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="flex-1 rounded-xl border border-rose-200 bg-rose-50/50 px-4 py-2.5 text-sm outline-none focus:border-rose-400 focus:ring-2 focus:ring-rose-200"
          />
          <Button variant="secondary" onClick={handleSaveName}>
            Save
          </Button>
        </div>
      </div>

      <div className="mb-4 flex items-center justify-between gap-2">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-500">Exercises</h2>
        <div className="flex gap-2">
          {workout.exercises.length > 0 && (
            <Button
              variant="ghost"
              onClick={() => {
                setSuggestions(null)
                setShowRegenerate(true)
              }}
            >
              ✨ Regenerate
            </Button>
          )}
          <Button variant="secondary" onClick={() => setShowPicker(true)}>
            + Add
          </Button>
        </div>
      </div>

      {workout.exercises.length === 0 ? (
        <div className="rounded-2xl bg-white/70 p-6 text-center ring-1 ring-rose-100">
          <p className="text-sm text-slate-500">Add exercises from the database to build this workout.</p>
        </div>
      ) : (
        <ul className="flex flex-col gap-3">
          {workout.exercises.map((row) => (
            <li
              key={row.id}
              className="rounded-2xl bg-white/90 p-4 shadow-sm ring-1 ring-rose-100"
            >
              <div className="flex items-start justify-between gap-2">
                <div>
                  <h3 className="font-semibold text-slate-850">{row.exercise.name}</h3>
                  <p className="text-xs text-slate-500">
                    {row.exercise.muscleGroup} · {row.exercise.equipment}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => handleRemove(row.id)}
                  className="text-xs text-red-400 hover:text-red-600"
                >
                  Remove
                </button>
              </div>

              <div className="mt-3 grid grid-cols-3 gap-2">
                <label className="block">
                  <span className="mb-1 block text-xs text-slate-500">Sets</span>
                  <input
                    type="number"
                    min={1}
                    max={20}
                    value={row.sets}
                    onChange={(e) =>
                      handleUpdateExercise(row, Number(e.target.value), row.reps)
                    }
                    className="w-full rounded-lg border border-rose-200 px-2 py-1.5 text-sm outline-none focus:border-rose-400"
                  />
                </label>
                <label className="block">
                  <span className="mb-1 block text-xs text-slate-500">Reps</span>
                  <input
                    type="number"
                    min={1}
                    max={100}
                    value={row.reps}
                    onChange={(e) =>
                      handleUpdateExercise(row, row.sets, Number(e.target.value))
                    }
                    className="w-full rounded-lg border border-rose-200 px-2 py-1.5 text-sm outline-none focus:border-rose-400"
                  />
                </label>
                <label className="block">
                  <span className="mb-1 block text-xs text-slate-500">Weight (lbs)</span>
                  <input
                    type="number"
                    min={0}
                    step={2.5}
                    value={row.weight}
                    onChange={(e) => handleWeightChange(row.exerciseId, Number(e.target.value))}
                    className="w-full rounded-lg border border-rose-200 px-2 py-1.5 text-sm outline-none focus:border-rose-400"
                  />
                </label>
              </div>
              <p className="mt-2 text-xs text-slate-400">
                Weight is shared across all workouts using this exercise.
              </p>
            </li>
          ))}
        </ul>
      )}

      {showPicker && (
        <ExercisePicker onSelect={handleSelectExercise} onClose={() => setShowPicker(false)} />
      )}

      {showRegenerate && (
        <RegenerateWorkoutModal
          loading={regenLoading}
          suggestions={suggestions}
          usedAi={usedAi}
          onGenerate={handleGenerate}
          onApply={handleApplyRegeneration}
          onClose={() => {
            setShowRegenerate(false)
            setSuggestions(null)
          }}
        />
      )}

      {pendingExercise && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4">
          <form
            onSubmit={handleAddExercise}
            className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl"
          >
            <h2 className="text-lg font-semibold text-slate-850">{pendingExercise.name}</h2>
            <p className="text-sm text-slate-500">
              {pendingExercise.muscleGroup} · {pendingExercise.equipment}
            </p>

            <div className="mt-4 grid grid-cols-3 gap-2">
              <label className="block">
                <span className="mb-1 block text-xs text-slate-500">Sets</span>
                <input
                  type="number"
                  min={1}
                  value={formSets}
                  onChange={(e) => setFormSets(Number(e.target.value))}
                  className="w-full rounded-lg border border-rose-200 px-2 py-1.5 text-sm"
                />
              </label>
              <label className="block">
                <span className="mb-1 block text-xs text-slate-500">Reps</span>
                <input
                  type="number"
                  min={1}
                  value={formReps}
                  onChange={(e) => setFormReps(Number(e.target.value))}
                  className="w-full rounded-lg border border-rose-200 px-2 py-1.5 text-sm"
                />
              </label>
              <label className="block">
                <span className="mb-1 block text-xs text-slate-500">Weight</span>
                <input
                  type="number"
                  min={0}
                  step={2.5}
                  value={formWeight}
                  onChange={(e) => setFormWeight(Number(e.target.value))}
                  className="w-full rounded-lg border border-rose-200 px-2 py-1.5 text-sm"
                />
              </label>
            </div>

            {formWeight > 0 && (
              <p className="mt-2 text-xs text-slate-400">
                Using existing weight for this exercise across workouts.
              </p>
            )}

            <div className="mt-5 flex gap-2">
              <Button type="submit" fullWidth>
                Add to Workout
              </Button>
              <Button type="button" variant="ghost" onClick={() => setPendingExercise(null)}>
                Cancel
              </Button>
            </div>
          </form>
        </div>
      )}
    </Layout>
  )
}
