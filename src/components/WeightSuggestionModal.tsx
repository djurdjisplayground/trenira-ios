import type { WeightAdjustment } from '../types'
import { Button } from './Button'

interface WeightSuggestionModalProps {
  exerciseName: string
  currentWeight: number
  suggestedIncrease: number
  suggestedDecrease: number
  onConfirm: (adjustment: WeightAdjustment, newWeight: number) => void
  onClose: () => void
}

export function WeightSuggestionModal({
  exerciseName,
  currentWeight,
  suggestedIncrease,
  suggestedDecrease,
  onConfirm,
  onClose,
}: WeightSuggestionModalProps) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4">
      <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
        <div className="mb-1 text-center text-2xl">🎉</div>
        <h2 className="text-center text-lg font-semibold text-slate-850">All sets complete!</h2>
        <p className="mt-2 text-center text-sm text-slate-500">
          You finished every set of <span className="font-medium text-slate-700">{exerciseName}</span>.
          Ready to adjust your weight for next time?
        </p>

        <p className="mt-4 text-center text-sm text-slate-500">
          Current weight: <span className="font-semibold text-rose-700">{currentWeight} lbs</span>
        </p>

        <div className="mt-5 flex flex-col gap-2">
          <Button fullWidth onClick={() => onConfirm('increase', suggestedIncrease)}>
            Increase to {suggestedIncrease} lbs
          </Button>
          <Button variant="secondary" fullWidth onClick={() => onConfirm('keep', currentWeight)}>
            Keep at {currentWeight} lbs
          </Button>
          <Button variant="secondary" fullWidth onClick={() => onConfirm('decrease', suggestedDecrease)}>
            Decrease to {suggestedDecrease} lbs
          </Button>
          <Button variant="ghost" fullWidth onClick={onClose}>
            Decide later
          </Button>
        </div>

        <p className="mt-4 text-center text-xs text-slate-400">
          Weight updates apply to this exercise in all your workouts.
        </p>
      </div>
    </div>
  )
}
