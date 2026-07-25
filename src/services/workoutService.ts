import { db } from '../db/database'
import type {
  Exercise,
  ExerciseWeight,
  Workout,
  WorkoutExercise,
  WorkoutExerciseWithDetails,
  WorkoutWithExercises,
} from '../types'

export async function getAllWorkouts(): Promise<Workout[]> {
  return db.workouts.orderBy('updatedAt').reverse().toArray()
}

export async function getWorkoutWithExercises(workoutId: string): Promise<WorkoutWithExercises | null> {
  const workout = await db.workouts.get(workoutId)
  if (!workout) return null

  const exercises = await hydrateWorkoutExercises(workoutId)
  return { ...workout, exercises }
}

async function hydrateWorkoutExercises(workoutId: string): Promise<WorkoutExerciseWithDetails[]> {
  const rows = await db.workoutExercises.where('workoutId').equals(workoutId).sortBy('order')
  const exerciseIds = [...new Set(rows.map((r) => r.exerciseId))]
  const [exercises, weights] = await Promise.all([
    db.exercises.bulkGet(exerciseIds),
    db.exerciseWeights.bulkGet(exerciseIds),
  ])

  const exerciseMap = new Map(exercises.filter(Boolean).map((e) => [e!.id, e!]))
  const weightMap = new Map(weights.filter(Boolean).map((w) => [w!.exerciseId, w!.weight]))

  return rows
    .map((row) => {
      const exercise = exerciseMap.get(row.exerciseId)
      if (!exercise) return null
      return {
        ...row,
        exercise,
        weight: weightMap.get(row.exerciseId) ?? 0,
      }
    })
    .filter((row): row is WorkoutExerciseWithDetails => row !== null)
}

export async function createWorkout(name: string): Promise<Workout> {
  const now = Date.now()
  const workout: Workout = {
    id: crypto.randomUUID(),
    name: name.trim(),
    createdAt: now,
    updatedAt: now,
  }
  await db.workouts.add(workout)
  return workout
}

export async function updateWorkoutName(workoutId: string, name: string): Promise<void> {
  await db.workouts.update(workoutId, { name: name.trim(), updatedAt: Date.now() })
}

export async function deleteWorkout(workoutId: string): Promise<void> {
  await db.transaction('rw', db.workouts, db.workoutExercises, async () => {
    await db.workoutExercises.where('workoutId').equals(workoutId).delete()
    await db.workouts.delete(workoutId)
  })
}

export async function addExerciseToWorkout(
  workoutId: string,
  exerciseId: string,
  sets: number,
  reps: number,
  startingWeight: number,
): Promise<WorkoutExercise> {
  const existing = await db.workoutExercises.where('workoutId').equals(workoutId).count()
  const existingWeight = await db.exerciseWeights.get(exerciseId)

  if (!existingWeight && startingWeight > 0) {
    await setExerciseWeight(exerciseId, startingWeight)
  } else if (!existingWeight) {
    await setExerciseWeight(exerciseId, startingWeight)
  }

  const entry: WorkoutExercise = {
    id: crypto.randomUUID(),
    workoutId,
    exerciseId,
    sets,
    reps,
    order: existing,
    completedSets: [],
  }

  await db.transaction('rw', db.workoutExercises, db.workouts, async () => {
    await db.workoutExercises.add(entry)
    await db.workouts.update(workoutId, { updatedAt: Date.now() })
  })

  return entry
}

export async function updateWorkoutExercise(
  id: string,
  updates: Pick<WorkoutExercise, 'sets' | 'reps'>,
): Promise<void> {
  const row = await db.workoutExercises.get(id)
  if (!row) return

  await db.transaction('rw', db.workoutExercises, db.workouts, async () => {
    await db.workoutExercises.update(id, { ...updates, completedSets: [] })
    await db.workouts.update(row.workoutId, { updatedAt: Date.now() })
  })
}

export async function removeExerciseFromWorkout(id: string): Promise<void> {
  const row = await db.workoutExercises.get(id)
  if (!row) return

  await db.transaction('rw', db.workoutExercises, db.workouts, async () => {
    await db.workoutExercises.delete(id)
    await db.workouts.update(row.workoutId, { updatedAt: Date.now() })
  })
}

export async function getExerciseWeight(exerciseId: string): Promise<number> {
  const record = await db.exerciseWeights.get(exerciseId)
  return record?.weight ?? 0
}

/** Updates weight globally for an exercise across all workouts */
export async function setExerciseWeight(exerciseId: string, weight: number): Promise<void> {
  const record: ExerciseWeight = { exerciseId, weight }
  await db.exerciseWeights.put(record)
}

export async function toggleSetComplete(
  workoutExerciseId: string,
  setIndex: number,
): Promise<number[]> {
  const row = await db.workoutExercises.get(workoutExerciseId)
  if (!row) return []

  const completed = new Set(row.completedSets)
  if (completed.has(setIndex)) {
    completed.delete(setIndex)
  } else {
    completed.add(setIndex)
  }

  const completedSets = [...completed].sort((a, b) => a - b)
  await db.workoutExercises.update(workoutExerciseId, { completedSets })
  return completedSets
}

export async function resetWorkoutSession(workoutId: string): Promise<void> {
  const rows = await db.workoutExercises.where('workoutId').equals(workoutId).toArray()
  await db.transaction('rw', db.workoutExercises, async () => {
    for (const row of rows) {
      await db.workoutExercises.update(row.id, { completedSets: [] })
    }
  })
}

export async function searchExercises(query: string): Promise<Exercise[]> {
  const q = query.trim().toLowerCase()
  if (!q) return db.exercises.orderBy('name').toArray()

  const all = await db.exercises.toArray()
  return all.filter(
    (e) =>
      e.name.toLowerCase().includes(q) ||
      e.muscleGroup.toLowerCase().includes(q) ||
      e.equipment.toLowerCase().includes(q),
  )
}

export async function getAllExercises(): Promise<Exercise[]> {
  return db.exercises.orderBy('name').toArray()
}

export function suggestNextWeight(currentWeight: number, adjustment: 'increase' | 'decrease' | 'keep'): number {
  if (adjustment === 'keep') return currentWeight
  const increment = currentWeight >= 40 ? 5 : currentWeight >= 20 ? 2.5 : 2.5
  if (adjustment === 'increase') return currentWeight + increment
  return Math.max(0, currentWeight - increment)
}

export async function replaceWorkoutExercises(
  workoutId: string,
  replacements: Array<{ exerciseId: string; sets: number; reps: number; weight: number }>,
): Promise<void> {
  await db.transaction('rw', db.workoutExercises, db.exerciseWeights, db.workouts, async () => {
    await db.workoutExercises.where('workoutId').equals(workoutId).delete()

    for (let i = 0; i < replacements.length; i++) {
      const { exerciseId, sets, reps, weight } = replacements[i]
      await setExerciseWeight(exerciseId, weight)
      await db.workoutExercises.add({
        id: crypto.randomUUID(),
        workoutId,
        exerciseId,
        sets,
        reps,
        order: i,
        completedSets: [],
      })
    }

    await db.workouts.update(workoutId, { updatedAt: Date.now() })
  })
}

export async function markSetCompleteByIndex(
  workoutExerciseId: string,
  setIndex: number,
): Promise<number[]> {
  const row = await db.workoutExercises.get(workoutExerciseId)
  if (!row || setIndex < 0 || setIndex >= row.sets) return row?.completedSets ?? []

  const completed = new Set(row.completedSets)
  completed.add(setIndex)
  const completedSets = [...completed].sort((a, b) => a - b)
  await db.workoutExercises.update(workoutExerciseId, { completedSets })
  return completedSets
}

export async function createWorkoutFromExercises(
  name: string,
  exercises: Array<{ exerciseId: string; sets: number; reps: number; weight: number }>,
): Promise<Workout> {
  const workout = await createWorkout(name)
  for (const ex of exercises) {
    await addExerciseToWorkout(workout.id, ex.exerciseId, ex.sets, ex.reps, ex.weight)
  }
  return workout
}
