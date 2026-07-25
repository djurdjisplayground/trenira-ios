import { useCallback, useEffect, useRef, useState } from 'react'
import { isVoiceSupported } from '../services/aiService'

interface UseVoiceRecognitionOptions {
  onResult: (transcript: string) => void
  onError?: (error: string) => void
  continuous?: boolean
}

export function useVoiceRecognition({
  onResult,
  onError,
  continuous = false,
}: UseVoiceRecognitionOptions) {
  const [listening, setListening] = useState(false)
  const [interim, setInterim] = useState('')
  const recognitionRef = useRef<SpeechRecognition | null>(null)
  const supported = isVoiceSupported()

  const stop = useCallback(() => {
    recognitionRef.current?.stop()
    setListening(false)
    setInterim('')
  }, [])

  const start = useCallback(() => {
    if (!supported) {
      onError?.('Voice input is not supported in this browser. Try Chrome or Safari.')
      return
    }

    const SpeechRecognitionCtor =
      window.SpeechRecognition ?? window.webkitSpeechRecognition
    const recognition = new SpeechRecognitionCtor()
    recognition.lang = 'en-US'
    recognition.interimResults = true
    recognition.continuous = continuous
    recognition.maxAlternatives = 1

    recognition.onstart = () => {
      setListening(true)
      setInterim('')
    }

    recognition.onresult = (event: SpeechRecognitionEvent) => {
      let finalTranscript = ''
      let interimTranscript = ''

      for (let i = event.resultIndex; i < event.results.length; i++) {
        const result = event.results[i]
        if (result.isFinal) {
          finalTranscript += result[0].transcript
        } else {
          interimTranscript += result[0].transcript
        }
      }

      setInterim(interimTranscript)
      if (finalTranscript.trim()) {
        onResult(finalTranscript.trim())
        if (!continuous) stop()
      }
    }

    recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
      if (event.error !== 'aborted') {
        onError?.(`Voice error: ${event.error}`)
      }
      setListening(false)
      setInterim('')
    }

    recognition.onend = () => {
      setListening(false)
      setInterim('')
    }

    recognitionRef.current = recognition
    recognition.start()
  }, [supported, continuous, onResult, onError, stop])

  useEffect(() => {
    return () => {
      recognitionRef.current?.abort()
    }
  }, [])

  return { supported, listening, interim, start, stop }
}
