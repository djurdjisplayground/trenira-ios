import type { ButtonHTMLAttributes } from 'react'

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  fullWidth?: boolean
}

const variants: Record<Variant, string> = {
  primary:
    'bg-rose-600 text-white shadow-md shadow-rose-200 hover:bg-rose-700 active:bg-rose-800',
  secondary:
    'bg-white text-rose-700 ring-1 ring-rose-200 hover:bg-rose-50 active:bg-rose-100',
  ghost: 'bg-transparent text-rose-600 hover:bg-rose-50 active:bg-rose-100',
  danger: 'bg-red-50 text-red-600 ring-1 ring-red-200 hover:bg-red-100',
}

export function Button({
  variant = 'primary',
  fullWidth,
  className = '',
  disabled,
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      className={`inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold transition disabled:cursor-not-allowed disabled:opacity-50 ${variants[variant]} ${fullWidth ? 'w-full' : ''} ${className}`}
      disabled={disabled}
      {...props}
    >
      {children}
    </button>
  )
}
