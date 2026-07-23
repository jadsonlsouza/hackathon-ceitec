import { describe, expect, it } from 'vitest'
import {
  validateLogin,
  validateNewPassword,
  validatePasswordReset,
  validateSignUp,
} from '../../app/utils/auth-validation'

describe('auth form validation', () => {
  it('returns field errors and first focus target for an empty login', () => {
    expect(validateLogin({ email: '', password: '' })).toEqual({
      errors: {
        email: 'Informe seu e-mail.',
        password: 'Informe sua senha.',
      },
      firstInvalidId: 'login-email',
    })
  })

  it('validates every required sign-up field before authentication is called', () => {
    expect(validateSignUp({ name: '', email: 'invalid', password: '' })).toEqual({
      errors: {
        name: 'Informe seu nome completo.',
        email: 'Informe um e-mail válido.',
        password: 'Informe uma senha.',
      },
      firstInvalidId: 'signup-name',
    })
  })

  it('rejects malformed recovery email with an associated field error', () => {
    expect(validatePasswordReset({ email: 'email-inválido' })).toEqual({
      errors: { email: 'Informe um e-mail válido.' },
      firstInvalidId: 'recovery-email',
    })
  })

  it('rejects a short or mismatched replacement password', () => {
    expect(validateNewPassword({ password: '123', confirmation: '456' })).toEqual({
      errors: {
        password: 'A senha deve ter pelo menos 8 caracteres.',
        confirmation: 'As senhas não coincidem.',
      },
      firstInvalidId: 'reset-password',
    })
  })
})
