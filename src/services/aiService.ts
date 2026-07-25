import type { Exercise } from '../types'
import type {
  GymEquipment,
  ProgressionSnapshot,
  RegenerateWorkoutRequest,
  RegenerateWorkoutResult,
  SuggestedExercise,
  VoiceGenerationRequest,
  VoiceGenerationResult,
  VoiceLogResult,
} from '../types/ai'
import { getAllExercises } from './workoutService'

const AI_API_KEY = import.meta.env.VITE_AI_API_KEY as string | undefined
const AI_BASE_URL = (import.meta.env.VITE_AI_BASE_URL as string | undefined) ?? 'https://api.openai.com/v1'

function allowedEquipment(equipment: GymEquipment): Set<string> {
  const allowed = new Set<string>(['Bodyweight'])
  if (equipment.hasBarbell) allowed.add('Barbell')
  if (equipment.hasDumbbells) allowed.add('Dumbbell')
  if (equipment.hasCables) allowed.add('Cable')
  if (equipment.hasMachines) allowed.add('Machine')
  if (equipment.hasKettlebells) allowed.add('Kettlebell')
  return allowed
}

export function filterExercisesByEquipment(
  exercises: Exercise[],
  equipment: GymEquipment,
): Exercise[] {
  const allowed = allowedEquipment(equipment)
  return exercises.filter((e) => allowed.has(e.equipment))
}

export function buildProgressionSnapshot(
  exercises: Array<{
    exerciseId: string
    exercise: Exercise
    weight: number
    sets: number
    reps: number
  }>,
): ProgressionSnapshot[] {
  return exercises.map((e) => ({
    exerciseId: e.exerciseId,
    exerciseName: e.exercise.name,
    muscleGroup: e.exercise.muscleGroup,
    equipment: e.exercise.equipment,
    currentWeight: e.weight,
    sets: e.sets,
    reps: e.reps,
  }))
}

function pickAlternative(
  current: ProgressionSnapshot,
  available: Exercise[],
  usedIds: Set<string>,
  reason: RegenerateWorkoutRequest['reason'],
): Exercise | null {
  const currentStillAvailable = available.find((e) => e.id === current.exerciseId)
  const sameMuscle = available.filter(
    (e) => e.muscleGroup === current.muscleGroup && !usedIds.has(e.id),
  )

  if (reason === 'new_gym') {
    if (currentStillAvailable) return currentStillAvailable
    return sameMuscle[0] ?? available.find((e) => !usedIds.has(e.id)) ?? null
  }

  if (reason === 'bored') {
    const different = sameMuscle.filter((e) => e.id !== current.exerciseId)
    if (different.length > 0) return different[0]
    if (currentStillAvailable) return currentStillAvailable
    return sameMuscle[0] ?? null
  }

  // plateau — keep if possible, else variation
  if (currentStillAvailable) return currentStillAvailable
  return sameMuscle[0] ?? null
}

function buildRationale(
  current: ProgressionSnapshot,
  picked: Exercise,
  reason: RegenerateWorkoutRequest['reason'],
  sets: number,
  reps: number,
): string {
  if (picked.id === current.exerciseId) {
    if (reason === 'plateau') {
      return reps !== current.reps
        ? `Same lift with adjusted rep target (${reps} reps) to break through your plateau.`
        : 'Keeping this exercise — your progression weight carries over.'
    }
    return 'Equipment available at your gym; keeping your current exercise and progression.'
  }

  if (reason === 'new_gym') {
    return `${current.exerciseName} needs ${current.equipment}, which isn't available — swapped for ${picked.name}.`
  }
  if (reason === 'bored') {
    return `Fresh ${picked.muscleGroup.toLowerCase()} stimulus with ${picked.name} while preserving your sets and weight.`
  }
  return `Variation swap to ${picked.name} for the same ${picked.muscleGroup.toLowerCase()} focus.`
}

async function regenerateWorkoutLocal(
  request: RegenerateWorkoutRequest,
): Promise<RegenerateWorkoutResult> {
  const allExercises = await getAllExercises()
  const available = filterExercisesByEquipment(allExercises, request.availableEquipment)
  const usedIds = new Set<string>()
  const suggestedExercises: SuggestedExercise[] = []

  for (const prog of request.currentExercises) {
    const picked = pickAlternative(prog, available, usedIds, request.reason)
    if (!picked) continue

    usedIds.add(picked.id)

    let sets = prog.sets
    let reps = prog.reps
    if (request.reason === 'plateau' && picked.id === prog.exerciseId) {
      reps = Math.max(6, prog.reps - 2)
    }

    suggestedExercises.push({
      exerciseId: picked.id,
      exerciseName: picked.name,
      muscleGroup: picked.muscleGroup,
      equipment: picked.equipment,
      sets,
      reps,
      weight: prog.currentWeight,
      rationale: buildRationale(prog, picked, request.reason, sets, reps),
      replacedExerciseName: picked.id !== prog.exerciseId ? prog.exerciseName : undefined,
    })
  }

  return { suggestedExercises, usedAi: false }
}

async function callAiJson<T>(system: string, user: string): Promise<T | null> {
  if (!AI_API_KEY) return null

  try {
    const response = await fetch(`${AI_BASE_URL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${AI_API_KEY}`,
      },
      body: JSON.stringify({
        model: import.meta.env.VITE_AI_MODEL ?? 'gpt-4o-mini',
        temperature: 0.4,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user },
        ],
      }),
    })

    if (!response.ok) return null
    const data = await response.json()
    const content = data.choices?.[0]?.message?.content
    if (!content) return null
    return JSON.parse(content) as T
  } catch {
    return null
  }
}

async function regenerateWorkoutWithAi(
  request: RegenerateWorkoutRequest,
  allExercises: Exercise[],
): Promise<RegenerateWorkoutResult | null> {
  const available = filterExercisesByEquipment(allExercises, request.availableEquipment)
  const exerciseList = available.map((e) => ({
    id: e.id,
    name: e.name,
    muscleGroup: e.muscleGroup,
    equipment: e.equipment,
  }))

  const result = await callAiJson<{ exercises: SuggestedExercise[] }>(
    `You are a strength coach for women. Regenerate workouts preserving progression (sets, reps, weights).
Return JSON: { "exercises": [{ "exerciseId", "exerciseName", "muscleGroup", "equipment", "sets", "reps", "weight", "rationale", "replacedExerciseName?" }] }
Only use exercise IDs from the provided list. Preserve muscle-group balance and weights.`,
    JSON.stringify({
      reason: request.reason,
      currentExercises: request.currentExercises,
      availableExercises: exerciseList,
    }),
  )

  if (!result?.exercises?.length) return null

  const validIds = new Set(available.map((e) => e.id))
  const validated = result.exercises.filter((e) => validIds.has(e.exerciseId))
  if (validated.length === 0) return null

  return { suggestedExercises: validated, usedAi: true }
}

export async function regenerateWorkout(
  request: RegenerateWorkoutRequest,
): Promise<RegenerateWorkoutResult> {
  if (request.currentExercises.length === 0) {
    return { suggestedExercises: [], usedAi: false }
  }

  if (AI_API_KEY) {
    const allExercises = await getAllExercises()
    const aiResult = await regenerateWorkoutWithAi(request, allExercises)
    if (aiResult) return aiResult
  }

  return regenerateWorkoutLocal(request)
}

function normalize(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim()
}

function wordOverlap(a: string, b: string): number {
  const wordsA = new Set(normalize(a).split(' '))
  const wordsB = new Set(normalize(b).split(' '))
  let overlap = 0
  for (const w of wordsA) {
    if (wordsB.has(w) && w.length > 2) overlap++
  }
  return overlap
}

export function parseVoiceTranscript(
  transcript: string,
  exerciseNames: Array<{ id: string; name: string }>,
): VoiceLogResult {
  const raw = transcript.trim()
  const lower = raw.toLowerCase()

  let bestMatch: { id: string; name: string; score: number } | null = null
  for (const ex of exerciseNames) {
    const nameNorm = normalize(ex.name)
    let score = 0
    if (lower.includes(nameNorm)) score += 10
    score += wordOverlap(lower, ex.name) * 2
    if (score > 0 && (!bestMatch || score > bestMatch.score)) {
      bestMatch = { id: ex.id, name: ex.name, score }
    }
  }

  const setMatch =
    lower.match(/set\s*#?\s*(\d+)/) ??
    lower.match(/(\d+)(?:st|nd|rd|th)\s*set/) ??
    lower.match(/finished\s*(?:set\s*)?(\d+)/) ??
    lower.match(/complete[d]?\s*(?:set\s*)?(\d+)/)

  const weightMatch =
    lower.match(/(\d+(?:\.\d+)?)\s*(?:pounds|lbs|lb|kg)/) ??
    lower.match(/at\s*(\d+(?:\.\d+)?)/)

  const repsMatch = lower.match(/(\d+)\s*reps?/)

  const isComplete =
    /done|finished|complete|logged|check/.test(lower) || setMatch !== null

  if (bestMatch && isComplete) {
    return {
      exerciseId: bestMatch.id,
      exerciseName: bestMatch.name,
      setNumber: setMatch ? Number(setMatch[1]) : undefined,
      reps: repsMatch ? Number(repsMatch[1]) : undefined,
      weight: weightMatch ? Number(weightMatch[1]) : undefined,
      action: weightMatch && !setMatch ? 'update_weight' : 'complete_set',
      rawTranscript: raw,
      message: setMatch
        ? `Logged set ${setMatch[1]} for ${bestMatch.name}`
        : `Logged progress for ${bestMatch.name}`,
    }
  }

  if (bestMatch && weightMatch) {
    return {
      exerciseId: bestMatch.id,
      exerciseName: bestMatch.name,
      weight: Number(weightMatch[1]),
      action: 'update_weight',
      rawTranscript: raw,
      message: `Updated ${bestMatch.name} weight to ${weightMatch[1]} lbs`,
    }
  }

  return {
    action: 'unknown',
    rawTranscript: raw,
    message: 'Could not understand — try "Finished set 2 of squats"',
  }
}

export async function generateWorkoutFromVoice(
  transcript: string,
  request: VoiceGenerationRequest,
): Promise<VoiceGenerationResult> {
  const allExercises = await getAllExercises()
  const available = filterExercisesByEquipment(allExercises, request.availableEquipment)

  if (AI_API_KEY) {
    const result = await callAiJson<VoiceGenerationResult>(
      `Create a women's strength workout from voice input. Use only exercises from the list.
Return JSON: { "workoutName": string, "exercises": [{ "exerciseName", "sets", "reps", "startingWeight?" }] }`,
      JSON.stringify({
        transcript,
        goal: request.goal,
        experienceLevel: request.experienceLevel,
        availableExercises: available.map((e) => e.name),
      }),
    )
    if (result?.exercises?.length) {
      return { ...result, rawTranscript: transcript }
    }
  }

  // Local fallback: pick up to 5 exercises across muscle groups
  const groups = ['Legs', 'Glutes', 'Back', 'Chest', 'Shoulders']
  const picked: VoiceGenerationResult['exercises'] = []
  const usedGroups = new Set<string>()

  for (const group of groups) {
    const match = available.find(
      (e) => e.muscleGroup === group && !usedGroups.has(e.muscleGroup),
    )
    if (match) {
      usedGroups.add(match.muscleGroup)
      picked.push({
        exerciseName: match.name,
        sets: request.experienceLevel === 'beginner' ? 3 : 4,
        reps: request.experienceLevel === 'advanced' ? 6 : 10,
        startingWeight: 0,
      })
    }
    if (picked.length >= 4) break
  }

  return {
    workoutName: transcript.slice(0, 40) || 'AI Generated Workout',
    exercises: picked,
    rawTranscript: transcript,
  }
}

export function isAiConfigured(): boolean {
  return Boolean(AI_API_KEY)
}

export function isVoiceSupported(): boolean {
  return (
    typeof window !== 'undefined' &&
    ('SpeechRecognition' in window || 'webkitSpeechRecognition' in window)
  )
}
