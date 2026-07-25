import Dexie, { type EntityTable } from 'dexie'
import type { Exercise, ExerciseWeight, Workout, WorkoutExercise } from '../types'
import { SEED_EXERCISES } from './seedExercises'

class IronHerDatabase extends Dexie {
  exercises!: EntityTable<Exercise, 'id'>
  workouts!: EntityTable<Workout, 'id'>
  workoutExercises!: EntityTable<WorkoutExercise, 'id'>
  exerciseWeights!: EntityTable<ExerciseWeight, 'exerciseId'>

  constructor() {
    super('IronHerDB')

    this.version(1).stores({
      exercises: 'id, name, muscleGroup, equipment',
      workouts: 'id, name, updatedAt',
      workoutExercises: 'id, workoutId, exerciseId, order',
      exerciseWeights: 'exerciseId',
    })
  }
}

export const db = new IronHerDatabase()

export async function seedDatabaseIfNeeded(): Promise<void> {
  const count = await db.exercises.count()
  if (count > 0) return

  await db.transaction('rw', db.exercises, async () => {
    await db.exercises.bulkAdd(
      SEED_EXERCISES.map((exercise) => ({
        ...exercise,
        id: crypto.randomUUID(),
      })),
    )
  })
}
