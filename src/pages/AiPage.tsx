import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Layout } from '../components/Layout'
import { Button } from '../components/Button'
import { VoiceInputButton } from '../components/VoiceInputButton'
import { useVoiceRecognition } from '../hooks/useVoiceRecognition'
import {
  generateWorkoutFromVoice,
  isAiConfigured,
  isVoiceSupported,
} from '../services/aiService'
import { createWorkoutFromExercises, getAllExercises } from '../services/workoutService'
import { DEFAULT_GYM_EQUIPMENT, type GymEquipment } from '../types/ai'

export function AiPage() {
  const navigate = useNavigate()
  const [equipment, setEquipment] = useState<GymEquipment>({ ...DEFAULT_GYM_EQUIPMENT })
  const [experience, setExperience] = useState<'beginner' | 'intermediate' | 'advanced'>(
    'intermediate',
  )
  const [generating, setGenerating] = useState(false)
  const [feedback, setFeedback] = useState<string | null>(null)
  const [lastTranscript, setLastTranscript] = useState<string | null>(null)

  const { supported, listening, interim, start, stop } = useVoiceRecognition({
    onResult: handleVoiceGenerate,
    onError: (err) => setFeedback(err),
    continuous: false,
  })

  async function handleVoiceGenerate(transcript: string) {
    setLastTranscript(transcript)
    setGenerating(true)
    setFeedback(null)

    try {
      const result = await generateWorkoutFromVoice(transcript, {
        goal: transcript,
        availableEquipment: equipment,
        experienceLevel: experience,
      })

      const allExercises = await getAllExercises()
      const nameToId = new Map(allExercises.map((e) => [e.name.toLowerCase(), e.id]))

      const resolved = result.exercises
        .map((e) => {
          const id = nameToId.get(e.exerciseName.toLowerCase())
          if (!id) return null
          return {
            exerciseId: id,
            sets: e.sets,
            reps: e.reps,
            weight: e.startingWeight ?? 0,
          }
        })
        .filter(Boolean) as Array<{
        exerciseId: string
        sets: number
        reps: number
        weight: number
      }>

      if (resolved.length === 0) {
        setFeedback('Could not match exercises — try being more specific.')
        return
      }

      const workout = await createWorkoutFromExercises(result.workoutName, resolved)
      setFeedback(`Created "${result.workoutName}" with ${resolved.length} exercises!`)
      setTimeout(() => navigate(`/workout/${workout.id}/edit`), 1200)
    } catch {
      setFeedback('Something went wrong generating the workout.')
    } finally {
      setGenerating(false)
    }
  }

  function toggleEquipment(key: keyof GymEquipment) {
    setEquipment((prev) => ({ ...prev, [key]: !prev[key] }))
  }

  return (
    <Layout backTo="/" title="AI & Voice">
      <div className="space-y-4">
        <section className="rounded-2xl bg-gradient-to-br from-rose-600 to-rose-500 p-5 text-white shadow-md">
          <h2 className="font-display text-xl font-bold">Create a workout by voice</h2>
          <p className="mt-2 text-sm text-rose-100">
            Describe what you want — e.g. &ldquo;Upper body push day with dumbbells, 4 exercises&rdquo;
          </p>
          <div className="mt-4 flex justify-center">
            <VoiceInputButton
              listening={listening}
              supported={supported}
              interim={interim}
              onStart={start}
              onStop={stop}
              label={generating ? 'Generating…' : 'Describe workout'}
            />
          </div>
          {lastTranscript && (
            <p className="mt-3 text-center text-sm italic text-rose-100">
              &ldquo;{lastTranscript}&rdquo;
            </p>
          )}
          {feedback && (
            <p className="mt-2 text-center text-sm font-medium text-white">{feedback}</p>
          )}
        </section>

        <section className="rounded-2xl bg-white/90 p-5 shadow-sm ring-1 ring-rose-100">
          <h2 className="font-semibold text-slate-850">Preferences</h2>
          <label className="mt-3 block">
            <span className="text-sm text-slate-600">Experience level</span>
            <select
              value={experience}
              onChange={(e) =>
                setExperience(e.target.value as 'beginner' | 'intermediate' | 'advanced')
              }
              className="mt-1 w-full rounded-xl border border-rose-200 bg-rose-50/50 px-3 py-2 text-sm"
            >
              <option value="beginner">Beginner</option>
              <option value="intermediate">Intermediate</option>
              <option value="advanced">Advanced</option>
            </select>
          </label>

          <p className="mt-4 text-sm text-slate-600">Available equipment</p>
          <div className="mt-2 flex flex-wrap gap-2">
            {(
              [
                ['hasBarbell', 'Barbell'],
                ['hasDumbbells', 'Dumbbells'],
                ['hasCables', 'Cables'],
                ['hasMachines', 'Machines'],
                ['hasKettlebells', 'Kettlebells'],
              ] as const
            ).map(([key, label]) => (
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
        </section>

        <section className="rounded-2xl bg-white/90 p-5 shadow-sm ring-1 ring-rose-100">
          <h2 className="font-semibold text-slate-850">Regenerate existing workouts</h2>
          <p className="mt-2 text-sm leading-relaxed text-slate-600">
            Open any workout and tap <strong>✨ Regenerate</strong> to swap exercises when you change
            gyms, want variety, or hit a plateau — your weights and progression carry over.
          </p>
        </section>

        <section className="rounded-2xl bg-white/90 p-5 shadow-sm ring-1 ring-rose-100">
          <h2 className="font-semibold text-slate-850">Voice logging in sessions</h2>
          <p className="mt-2 text-sm leading-relaxed text-slate-600">
            During a workout session, use the microphone button to log sets hands-free. Say things
            like &ldquo;Finished set 2 of squats&rdquo; or &ldquo;Done with bench press set 3.&rdquo;
          </p>
          {!isVoiceSupported() && (
            <p className="mt-2 text-sm text-amber-600">
              Voice input requires Chrome or Safari on a device with a microphone.
            </p>
          )}
        </section>

        <section className="rounded-2xl bg-rose-50/80 p-5 ring-1 ring-rose-100">
          <h2 className="font-semibold text-slate-850">AI provider (optional)</h2>
          <p className="mt-2 text-sm text-slate-600">
            {isAiConfigured()
              ? '✅ AI provider connected — smarter regeneration and voice generation enabled.'
              : 'Smart local algorithms work out of the box. Add an API key for enhanced AI suggestions.'}
          </p>
          {!isAiConfigured() && (
            <div className="mt-3 rounded-xl bg-white p-3 text-xs text-slate-500">
              <p>Create a <code className="rounded bg-rose-100 px-1">.env</code> file:</p>
              <pre className="mt-2 overflow-x-auto rounded-lg bg-slate-850 p-2 text-rose-100">
{`VITE_AI_API_KEY=your-key-here
VITE_AI_MODEL=gpt-4o-mini
VITE_AI_BASE_URL=https://api.openai.com/v1`}
              </pre>
            </div>
          )}
        </section>

        <Button variant="ghost" fullWidth onClick={() => navigate('/')}>
          ← Back to workouts
        </Button>
      </div>
    </Layout>
  )
}
