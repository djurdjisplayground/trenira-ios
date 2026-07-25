export interface Exercise {
  id: string
  name: string
  muscleGroup: string
  equipment: string
}

export interface Workout {
  id: string
  name: string
  createdAt: number
  updatedAt: number
}

export interface WorkoutExercise {
  id: string
  workoutId: string
  exerciseId: string
  sets: number
  reps: number
  order: number
  /** Set indices completed in the current session (0-based) */
  completedSets: number[]
}

export interface ExerciseWeight {
  exerciseId: string
  weight: number
}

export interface WorkoutExerciseWithDetails extends WorkoutExercise {
  exercise: Exercise
  weight: number
}

export interface WorkoutWithExercises extends Workout {
  exercises: WorkoutExerciseWithDetails[]
}

export type WeightAdjustment = 'increase' | 'decrease' | 'keep'
