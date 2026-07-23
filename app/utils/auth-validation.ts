type ValidationResult<T extends string> = {
  errors: Partial<Record<T, string>>
  firstInvalidId?: string
}

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function result<T extends string>(errors: Partial<Record<T, string>>, ids: Record<T, string>): ValidationResult<T> {
  const field = Object.keys(errors)[0] as T | undefined
  return { errors, firstInvalidId: field ? ids[field] : undefined }
}

export function validateLogin(input: { email: string, password: string }) {
  const errors: Partial<Record<'email' | 'password', string>> = {}
  if (!input.email) errors.email = 'Informe seu e-mail.'
  else if (!emailPattern.test(input.email)) errors.email = 'Informe um e-mail válido.'
  if (!input.password) errors.password = 'Informe sua senha.'
  return result(errors, { email: 'login-email', password: 'login-password' })
}

export function validateSignUp(input: { name: string, email: string, password: string }) {
  const errors: Partial<Record<'name' | 'email' | 'password', string>> = {}
  if (!input.name) errors.name = 'Informe seu nome completo.'
  if (!input.email) errors.email = 'Informe seu e-mail.'
  else if (!emailPattern.test(input.email)) errors.email = 'Informe um e-mail válido.'
  if (!input.password) errors.password = 'Informe uma senha.'
  else if (input.password.length < 8) errors.password = 'A senha deve ter pelo menos 8 caracteres.'
  return result(errors, { name: 'signup-name', email: 'signup-email', password: 'signup-password' })
}

export function validatePasswordReset(input: { email: string }) {
  const errors: Partial<Record<'email', string>> = {}
  if (!input.email) errors.email = 'Informe seu e-mail.'
  else if (!emailPattern.test(input.email)) errors.email = 'Informe um e-mail válido.'
  return result(errors, { email: 'recovery-email' })
}

export function validateNewPassword(input: { password: string, confirmation: string }) {
  const errors: Partial<Record<'password' | 'confirmation', string>> = {}
  if (input.password.length < 8) errors.password = 'A senha deve ter pelo menos 8 caracteres.'
  if (input.password !== input.confirmation) errors.confirmation = 'As senhas não coincidem.'
  return result(errors, { password: 'reset-password', confirmation: 'reset-confirmation' })
}

export function focusFirstInvalidField(firstInvalidId?: string) {
  if (firstInvalidId) document.getElementById(firstInvalidId)?.focus()
}
