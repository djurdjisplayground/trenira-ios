import { Link } from 'react-router-dom'
import { Layout } from '../components/Layout'

export function AiPlaceholderPage() {
  return (
    <Layout backTo="/" title="AI Features">
      <div className="space-y-4">
        <section className="rounded-2xl bg-white/90 p-5 shadow-sm ring-1 ring-rose-100">
          <h2 className="font-semibold text-slate-850">Smart Workout Regeneration</h2>
          <p className="mt-2 text-sm leading-relaxed text-slate-600">
            When you switch gyms or want a fresh routine, trenira will regenerate your workout
            using exercises available at your new gym — while preserving your progression targets
            (sets, reps, and current weights).
          </p>
        </section>

        <section className="rounded-2xl bg-white/90 p-5 shadow-sm ring-1 ring-rose-100">
          <h2 className="font-semibold text-slate-850">Voice Input</h2>
          <p className="mt-2 text-sm leading-relaxed text-slate-600">
            Log sets hands-free during your workout. Say things like &ldquo;Finished set 2 of
            squats at 95 pounds&rdquo; and the app will update your session automatically.
          </p>
        </section>

        <section className="rounded-2xl bg-gradient-to-br from-rose-50 to-white p-5 ring-1 ring-rose-100">
          <h2 className="font-semibold text-slate-850">How to enable</h2>
          <ol className="mt-3 list-decimal space-y-2 pl-5 text-sm text-slate-600">
            <li>Add your AI provider API key to <code className="rounded bg-rose-100 px-1">.env</code> as <code className="rounded bg-rose-100 px-1">VITE_AI_API_KEY</code></li>
            <li>Implement <code className="rounded bg-rose-100 px-1">src/services/aiService.ts</code></li>
            <li>Hook up the Web Speech API or a speech-to-text provider for voice logging</li>
          </ol>
          <p className="mt-4 text-xs text-slate-400">
            Stubs are already in place — see <code className="rounded bg-rose-100 px-1">aiService.ts</code> for the interfaces.
          </p>
        </section>

        <Link
          to="/"
          className="block text-center text-sm font-medium text-rose-600 hover:underline"
        >
          ← Back to workouts
        </Link>
      </div>
    </Layout>
  )
}
