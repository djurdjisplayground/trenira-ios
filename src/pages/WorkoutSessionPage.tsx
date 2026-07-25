import { useCallback, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Layout } from '../components/Layout'
import { Button } from '../components/Button'
import { WeightSuggestionModal } from '../components/WeightSuggestionModal'
import { VoiceInputButton } from '../components/VoiceInputButton'
import { useVoiceRecognition } from '../hooks/useVoiceRecognition'
import { parseVoiceTranscript } from '../services/aiService'
import {
  getWorkoutWithExercises,
  markSetCompleteByIndex,
  resetWorkoutSession,
  setExerciseWeight,
  suggestNextWeight,
  toggleSetComplete,
} from '../services/workoutService'
import type { WeightAdjustment, WorkoutExerciseWithDetails, WorkoutWithExercises } from '../types'
import type { VoiceLogResult } from '../types/ai'

export function WorkoutSessionPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [workout, setWorkout] = useState<WorkoutWithExercises | null>(null)
  const [weightModal, setWeightModal] = useState<WorkoutExerciseWithDetails | null>(null)
  const [voiceFeedback, setVoiceFeedback] = useState<string | null>(null)

  async function reload() {
    if (!id) return
    const data = await getWorkoutWithExercises(id)
    if (!data) {
      navigate('/')
      return
    }
    setWorkout(data)
  }

  const applyVoiceResult = useCallback(
    async (result: VoiceLogResult, currentWorkout: WorkoutWithExercises) => {
      if (result.action === 'unknown' || !result.exerciseId) {
        setVoiceFeedback(result.message)
        return
      }

      const row = currentWorkout.exercises.find((e) => e.exerciseId === result.exerciseId)
      if (!row) {
        setVoiceFeedback(`"${result.exerciseName}" is not in this workout`)
        return
      }

      if (result.action === 'update_weight' && result.weight !== undefined) {
        await setExerciseWeight(result.exerciseId, result.weight)
        setVoiceFeedback(result.message)
        await reload()
        return
      }

      const setIndex = result.setNumber ? result.setNumber - 1 : row.completedSets.length
      if (setIndex < 0 || setIndex >= row.sets) {
        setVoiceFeedback(`Set ${result.setNumber} is out of range for ${row.exercise.name}`)
        return
      }

      const completedSets = await markSetCompleteByIndex(row.id, setIndex)
      setVoiceFeedback(result.message)
      await reload()

      const allComplete = completedSets.length === row.sets
      const wasComplete = row.completedSets.length === row.sets
      if (allComplete && !wasComplete) {
        const updated = await getWorkoutWithExercises(id!)
        const exercise = updated?.exercises.find((e) => e.id === row.id)
        if (exercise) setWeightModal(exercise)
      }
    },
    [id],
  )

  const handleVoiceTranscript = useCallback(
    (transcript: string) => {
      if (!workout) return
      const exerciseNames = workout.exercises.map((e) => ({
        id: e.exerciseId,
        name: e.exercise.name,
      }))
      const result = parseVoiceTranscript(transcript, exerciseNames)
      applyVoiceResult(result, workout)
    },
    [workout, applyVoiceResult],
  )

  const { supported, listening, interim, start, stop } = useVoiceRecognition({
    onResult: handleVoiceTranscript,
    onError: (err) => setVoiceFeedback(err),
  })

  async function handleToggleSet(row: WorkoutExerciseWithDetails, setIndex: number) {
    const completedSets = await toggleSetComplete(row.id, setIndex)
    await reload()

    const allComplete = completedSets.length === row.sets
    const wasComplete = row.completedSets.length === row.sets
    if (allComplete && !wasComplete) {
      const updated = await getWorkoutWithExercises(id!)
      const exercise = updated?.exercises.find((e) => e.id === row.id)
      if (exercise) setWeightModal(exercise)
    }
  }

  async function handleWeightConfirm(_adjustment: WeightAdjustment, newWeight: number) {
    if (!weightModal) return
    await setExerciseWeight(weightModal.exerciseId, newWeight)
    setWeightModal(null)
    reload()
  }

  async function handleReset() {
    if (!id || !confirm('Reset all set checkboxes for this session?')) return
    await resetWorkoutSession(id)
    reload()
  }

  if (!workout) {
    return (
      <Layout backTo="/" title="Loading...">
        <p className="text-center text-slate-500">Loading session...</p>
      </Layout>
    )
  }

  if (workout.exercises.length === 0) {
    return (
      <Layout backTo={`/workout/${id}/edit`} title={workout.name}>
        <div className="rounded-2xl bg-white/90 p-6 text-center ring-1 ring-rose-100">
          <p className="text-sm text-slate-500">Add exercises before starting a session.</p>
          <Button className="mt-4" onClick={() => navigate(`/workout/${id}/edit`)}>
            Edit Workout
          </Button>
        </div>
      </Layout>
    )
  }

  const totalSets = workout.exercises.reduce((sum, e) => sum + e.sets, 0)
  const completedSets = workout.exercises.reduce((sum, e) => sum + e.completedSets.length, 0)
  const allDone = completedSets === totalSets

  return (
    <Layout
      backTo="/"
      title={workout.name}
      action={
        <Button variant="ghost" onClick={handleReset}>
          Reset
        </Button>
      }
    >
      <div className="mb-6">
        <div className="mb-2 flex items-center justify-between text-sm">
          <span className="text-slate-500">Session progress</span>
          <span className="font-semibold text-rose-700">
            {completedSets} / {totalSets} sets
          </span>
        </div>
        <div className="h-2 overflow-hidden rounded-full bg-rose-100">
          <div
            className="h-full rounded-full bg-rose-500 transition-all duration-300"
            style={{ width: `${totalSets ? (completedSets / totalSets) * 100 : 0}%` }}
          />
        </div>
        {allDone && (
          <p className="mt-3 text-center text-sm font-medium text-rose-700">
            Workout complete — you crushed it! 💪
          </p>
        )}
      </div>

      <ul className="flex flex-col gap-4">
        {workout.exercises.map((row) => {
          const exerciseDone = row.completedSets.length === row.sets
          return (
            <li
              key={row.id}
              className={`rounded-2xl p-4 shadow-sm ring-1 transition ${
                exerciseDone ? 'bg-rose-50/80 ring-rose-200' : 'bg-white/90 ring-rose-100'
              }`}
            >
              <div className="mb-3 flex items-start justify-between gap-2">
                <div>
                  <h3 className="font-semibold text-slate-850">{row.exercise.name}</h3>
                  <p className="text-sm text-slate-500">
                    {row.sets} × {row.reps} reps @ {row.weight} lbs
                  </p>
                </div>
                {exerciseDone && (
                  <span className="rounded-full bg-rose-200 px-2 py-0.5 text-xs font-semibold text-rose-800">
                    Done
                  </span>
                )}
              </div>

              <div className="flex flex-wrap gap-2">
                {Array.from({ length: row.sets }, (_, i) => {
                  const checked = row.completedSets.includes(i)
                  return (
                    <button
                      key={i}
                      type="button"
                      onClick={() => handleToggleSet(row, i)}
                      className={`flex h-12 min-w-[4.5rem] flex-col items-center justify-center rounded-xl border-2 text-sm font-medium transition ${
                        checked
                          ? 'border-rose-500 bg-rose-500 text-white'
                          : 'border-rose-200 bg-white text-slate-600 hover:border-rose-300 hover:bg-rose-50'
                      }`}
                      aria-pressed={checked}
                      aria-label={`Set ${i + 1}, ${row.reps} reps at ${row.weight} lbs`}
                    >
                      <span className="text-xs opacity-80">Set {i + 1}</span>
                      <span>{row.reps} reps</span>
                    </button>
                  )
                })}
              </div>
            </li>
          )
        })}
      </ul>

      <div className="mt-8 rounded-2xl bg-white/90 p-4 text-center ring-1 ring-rose-100">
        <p className="mb-3 text-sm font-medium text-slate-700">Hands-free logging</p>
        <VoiceInputButton
          listening={listening}
          supported={supported}
          interim={interim}
          onStart={start}
          onStop={stop}
          label="Log a set"
        />
        <p className="mt-3 text-xs text-slate-400">
          Try: &ldquo;Finished set 2 of squats&rdquo; or &ldquo;Done with hip thrust set 1&rdquo;
        </p>
        {voiceFeedback && (
          <p className="mt-2 text-sm font-medium text-rose-600">{voiceFeedback}</p>
        )}
      </div>

      {weightModal && (
        <WeightSuggestionModal
          exerciseName={weightModal.exercise.name}
          currentWeight={weightModal.weight}
          suggestedIncrease={suggestNextWeight(weightModal.weight, 'increase')}
          suggestedDecrease={suggestNextWeight(weightModal.weight, 'decrease')}
          onConfirm={handleWeightConfirm}
          onClose={() => setWeightModal(null)}
        />
      )}
    </Layout>
  )
}
