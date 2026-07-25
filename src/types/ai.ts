export interface GymEquipment {
  hasBarbell: boolean
  hasDumbbells: boolean
  hasCables: boolean
  hasMachines: boolean
  hasKettlebells: boolean
}

export const DEFAULT_GYM_EQUIPMENT: GymEquipment = {
  hasBarbell: true,
  hasDumbbells: true,
  hasCables: true,
  hasMachines: true,
  hasKettlebells: false,
}

export interface ProgressionSnapshot {
  exerciseId: string
  exerciseName: string
  muscleGroup: string
  equipment: string
  currentWeight: number
  sets: number
  reps: number
}

export interface RegenerateWorkoutRequest {
  workoutId: string
  workoutName: string
  currentExercises: ProgressionSnapshot[]
  availableEquipment: GymEquipment
  reason: 'new_gym' | 'bored' | 'plateau'
}

export interface SuggestedExercise {
  exerciseId: string
  exerciseName: string
  muscleGroup: string
  equipment: string
  sets: number
  reps: number
  weight: number
  rationale: string
  replacedExerciseName?: string
}

export interface RegenerateWorkoutResult {
  suggestedExercises: SuggestedExercise[]
  usedAi: boolean
}

export interface VoiceLogResult {
  exerciseName?: string
  exerciseId?: string
  setNumber?: number
  reps?: number
  weight?: number
  action: 'complete_set' | 'update_weight' | 'unknown'
  rawTranscript: string
  message: string
}

export interface VoiceGenerationRequest {
  goal: string
  availableEquipment: GymEquipment
  experienceLevel: 'beginner' | 'intermediate' | 'advanced'
}

export interface VoiceGenerationResult {
  workoutName: string
  exercises: Array<{
    exerciseName: string
    sets: number
    reps: number
    startingWeight?: number
  }>
  rawTranscript: string
}
