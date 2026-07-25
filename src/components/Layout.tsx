import { Link } from 'react-router-dom'

interface LayoutProps {
  children: React.ReactNode
  title?: string
  backTo?: string
  action?: React.ReactNode
}

export function Layout({ children, title, backTo, action }: LayoutProps) {
  return (
    <div className="mx-auto flex min-h-dvh max-w-lg flex-col px-4 pb-8 pt-6">
      <header className="mb-6 flex items-center justify-between gap-3">
        <div className="flex min-w-0 items-center gap-3">
          {backTo ? (
            <Link
              to={backTo}
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white/80 text-rose-600 shadow-sm ring-1 ring-rose-100 transition hover:bg-rose-50"
              aria-label="Go back"
            >
              ←
            </Link>
          ) : (
            <Link to="/" className="shrink-0">
              <span className="font-display text-2xl font-bold tracking-tight text-rose-700">
                trenira
              </span>
            </Link>
          )}
          {title && (
            <h1 className="truncate text-xl font-semibold text-slate-850">{title}</h1>
          )}
        </div>
        {action && <div className="shrink-0">{action}</div>}
      </header>
      <main className="flex-1">{children}</main>
    </div>
  )
}
