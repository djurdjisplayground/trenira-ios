import { useEffect, useState } from 'react'
import { Button } from './Button'

interface InstallPromptProps {
  compact?: boolean
}

interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

export function InstallPrompt({ compact = false }: InstallPromptProps) {
  const [deferredPrompt, setDeferredPrompt] = useState<BeforeInstallPromptEvent | null>(null)
  const [installed, setInstalled] = useState(false)
  const [dismissed, setDismissed] = useState(false)

  useEffect(() => {
    const isStandalone =
      window.matchMedia('(display-mode: standalone)').matches ||
      (window.navigator as Navigator & { standalone?: boolean }).standalone === true

    if (isStandalone) {
      setInstalled(true)
      return
    }

    function handleBeforeInstall(e: Event) {
      e.preventDefault()
      setDeferredPrompt(e as BeforeInstallPromptEvent)
    }

    function handleInstalled() {
      setInstalled(true)
      setDeferredPrompt(null)
    }

    window.addEventListener('beforeinstallprompt', handleBeforeInstall)
    window.addEventListener('appinstalled', handleInstalled)
    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstall)
      window.removeEventListener('appinstalled', handleInstalled)
    }
  }, [])

  async function handleInstall() {
    if (!deferredPrompt) return
    await deferredPrompt.prompt()
    const { outcome } = await deferredPrompt.userChoice
    if (outcome === 'accepted') setInstalled(true)
    setDeferredPrompt(null)
  }

  if (installed || dismissed || !deferredPrompt) return null

  if (compact) {
    return (
      <button
        type="button"
        onClick={handleInstall}
        className="rounded-full bg-rose-600 px-3 py-1 text-xs font-semibold text-white shadow-sm"
      >
        Install app
      </button>
    )
  }

  return (
    <div className="rounded-2xl bg-gradient-to-r from-rose-600 to-rose-500 p-4 text-white shadow-md">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-semibold">Add trenira to your home screen</p>
          <p className="mt-1 text-sm text-rose-100">
            Install for offline access and a full-screen gym experience.
          </p>
        </div>
        <button
          type="button"
          onClick={() => setDismissed(true)}
          className="shrink-0 text-rose-200 hover:text-white"
          aria-label="Dismiss"
        >
          ✕
        </button>
      </div>
      <Button
        variant="secondary"
        className="mt-3 !bg-white !text-rose-700 !ring-0 hover:!bg-rose-50"
        onClick={handleInstall}
      >
        Install trenira
      </Button>
    </div>
  )
}
