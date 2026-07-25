import { Button } from './Button'

interface VoiceInputButtonProps {
  listening: boolean
  supported: boolean
  interim?: string
  onStart: () => void
  onStop: () => void
  label?: string
  compact?: boolean
}

export function VoiceInputButton({
  listening,
  supported,
  interim,
  onStart,
  onStop,
  label = 'Voice',
  compact = false,
}: VoiceInputButtonProps) {
  if (!supported) {
    return (
      <span className="text-xs text-slate-400" title="Voice not supported in this browser">
        🎤 N/A
      </span>
    )
  }

  return (
    <div className="flex flex-col items-center gap-1">
      <button
        type="button"
        onClick={listening ? onStop : onStart}
        className={`flex items-center justify-center gap-2 rounded-full font-semibold transition ${
          compact ? 'h-10 w-10 text-lg' : 'px-4 py-2.5 text-sm'
        } ${
          listening
            ? 'animate-pulse bg-rose-600 text-white shadow-lg shadow-rose-300'
            : 'bg-white text-rose-700 ring-1 ring-rose-200 hover:bg-rose-50'
        }`}
        aria-pressed={listening}
        aria-label={listening ? 'Stop listening' : 'Start voice input'}
      >
        {listening ? '⏹' : '🎤'}
        {!compact && <span>{listening ? 'Listening…' : label}</span>}
      </button>
      {interim && (
        <p className="max-w-xs truncate text-center text-xs italic text-slate-400">
          "{interim}"
        </p>
      )}
    </div>
  )
}
