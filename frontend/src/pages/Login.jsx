import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  signIn, signUp, confirmSignUp,
  forgotPassword, confirmForgotPassword,
} from '../auth/cognitoClient';
import { useAuth } from '../auth/AuthContext';

const loginBg = {
  display: 'flex', alignItems: 'stretch', flex: 1,
};

const promoPanel = {
  display: 'flex', flexDirection: 'column', alignItems: 'center',
  justifyContent: 'center', gap: 24,
  background: 'linear-gradient(160deg, #92400e 0%, #b45309 60%, #d97706 100%)',
  padding: '60px 48px', flex: '0 0 420px',
};

const formPanel = {
  display: 'flex', flexDirection: 'column', alignItems: 'center',
  justifyContent: 'center', flex: 1,
  background: '#f0f4f8', padding: '40px 24px',
};

const cardStyle = {
  background: 'white', borderRadius: 14, padding: '40px 44px',
  width: '100%', maxWidth: 440, boxShadow: '0 20px 60px rgba(0,0,0,.15)',
};

export default function Login() {
  const [tab, setTab]               = useState('signin');
  const [username, setUsername]     = useState('');
  const [email, setEmail]           = useState('');
  const [phone, setPhone]           = useState('');
  const [password, setPassword]     = useState('');
  const [confirm, setConfirm]       = useState('');
  const [code, setCode]             = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [mfaResolver, setMfaResolver] = useState(null);
  const [mfaType, setMfaType]         = useState('totp'); // 'sms' | 'totp'
  const [loading, setLoading]       = useState(false);
  const [error, setError]           = useState('');
  const [success, setSuccess]       = useState('');

  const { onSignIn } = useAuth();
  const navigate = useNavigate();

  function switchTab(t) { setTab(t); setError(''); setSuccess(''); }

  async function handleSignIn(e) {
    e.preventDefault();
    setError(''); setLoading(true);
    try {
      const result = await signIn(username, password);
      if (result.type === 'success') {
        onSignIn(result.session);
        navigate('/');
      } else {
        // MFA required
        setMfaResolver(() => result.sendMfaCode);
        setMfaType(result.mfaType);
        setCode('');
        switchTab('mfa');
      }
    } catch (err) {
      setError(err.message || 'Sign in failed');
    } finally {
      setLoading(false);
    }
  }

  async function handleMfa(e) {
    e.preventDefault();
    setError(''); setLoading(true);
    try {
      const session = await mfaResolver(code);
      onSignIn(session);
      navigate('/');
    } catch (err) {
      setError(err.message || 'MFA verification failed');
    } finally {
      setLoading(false);
    }
  }

  async function handleRegister(e) {
    e.preventDefault();
    if (password !== confirm) { setError('Passwords do not match'); return; }
    setError(''); setLoading(true);
    try {
      await signUp(username, email, phone, password);
      switchTab('verify');
    } catch (err) {
      setError(err.message || 'Registration failed');
    } finally {
      setLoading(false);
    }
  }

  async function handleVerify(e) {
    e.preventDefault();
    setError(''); setLoading(true);
    try {
      await confirmSignUp(username, code);
      switchTab('signin');
      setSuccess('Account verified — please sign in.');
    } catch (err) {
      setError(err.message || 'Verification failed');
    } finally {
      setLoading(false);
    }
  }

  async function handleForgot(e) {
    e.preventDefault();
    setError(''); setLoading(true);
    try {
      await forgotPassword(username);
      switchTab('reset');
      setSuccess('Reset code sent — check your email or phone.');
    } catch (err) {
      setError(err.message || 'Could not send reset code');
    } finally {
      setLoading(false);
    }
  }

  async function handleReset(e) {
    e.preventDefault();
    setError(''); setLoading(true);
    try {
      await confirmForgotPassword(username, code, newPassword);
      switchTab('signin');
      setSuccess('Password updated — please sign in.');
    } catch (err) {
      setError(err.message || 'Password reset failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={loginBg}>
      {/* ── Promo panel ── */}
      <div className="login-promo" style={promoPanel}>
        <a href="https://www.hilldogs.com" target="_blank" rel="noreferrer"
          style={{ display: 'block', textAlign: 'center' }}>
          <img src="/hilldogs-logo.png" alt="Hill Dogs Consulting"
            style={{ width: 260, maxWidth: '100%', borderRadius: 12,
                     boxShadow: '0 8px 32px rgba(0,0,0,.25)' }} />
        </a>
        <div style={{ textAlign: 'center', color: 'white' }}>
          <p style={{ fontSize: 28, fontWeight: 800, letterSpacing: '.5px', marginBottom: 10 }}>
            Delta Catcher
          </p>
          <p style={{ fontSize: 16, opacity: .8, fontStyle: 'italic' }}>
            Investment modeling tool for quantitative algorithms.
          </p>
        </div>
      </div>

      {/* ── Form panel ── */}
      <div className="login-form-panel" style={formPanel}>
      <div style={cardStyle}>

        {/* Tabs (only show signin/register when not in flow tabs) */}
        {(tab === 'signin' || tab === 'register') && (
          <div style={{ display: 'flex', borderBottom: '2px solid var(--neutral-200)', marginBottom: 24 }}>
            {[['signin','Sign In'],['register','Create Account']].map(([t, label]) => (
              <button key={t} onClick={() => switchTab(t)} style={{
                padding: '8px 20px', fontSize: 14, fontWeight: 600, cursor: 'pointer',
                background: 'none', border: 'none', fontFamily: 'var(--font)',
                color: tab === t ? 'var(--primary)' : 'var(--neutral-500)',
                borderBottom: tab === t ? '3px solid var(--primary)' : '3px solid transparent',
                marginBottom: -2,
              }}>
                {label}
              </button>
            ))}
          </div>
        )}

        {/* Sign In */}
        {tab === 'signin' && (
          <form onSubmit={handleSignIn}>
            <div className="form-group" style={{ marginBottom: 14 }}>
              <label>Username</label>
              <input type="text" value={username} onChange={e => setUsername(e.target.value)}
                placeholder="your_username" required autoFocus autoComplete="username" />
            </div>
            <div className="form-group" style={{ marginBottom: 20 }}>
              <label>Password</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)}
                placeholder="••••••••" required autoComplete="current-password" />
            </div>
            {error && <p className="error-msg">{error}</p>}
            {success && <p className="success-msg">{success}</p>}
            <button type="submit" className="btn btn-primary" disabled={loading}
              style={{ width: '100%', justifyContent: 'center', marginTop: 8 }}>
              {loading ? <span className="spinner" /> : 'Sign In'}
            </button>
            <p style={{ textAlign: 'center', marginTop: 12, fontSize: 12, color: 'var(--neutral-500)' }}>
              <button type="button" onClick={() => switchTab('forgot')}
                style={{ color: 'var(--primary-light)', background: 'none', border: 'none', cursor: 'pointer', fontSize: 12 }}>
                Forgot password?
              </button>
            </p>
          </form>
        )}

        {/* MFA */}
        {tab === 'mfa' && (
          <form onSubmit={handleMfa}>
            <p style={{ fontSize: 15, fontWeight: 700, color: 'var(--primary-dark)', marginBottom: 8 }}>
              Two-Factor Authentication
            </p>
            <p style={{ fontSize: 13, color: 'var(--neutral-700)', marginBottom: 16 }}>
              {mfaType === 'totp'
                ? 'Enter the 6-digit code from your authenticator app.'
                : 'Enter the SMS code sent to your registered phone number.'}
            </p>
            <div className="form-group" style={{ marginBottom: 20 }}>
              <label>{mfaType === 'totp' ? 'Authenticator Code' : 'SMS Code'}</label>
              <input type="text" value={code} onChange={e => setCode(e.target.value)}
                placeholder="6-digit code" required autoFocus inputMode="numeric" />
            </div>
            {error && <p className="error-msg">{error}</p>}
            <button type="submit" className="btn btn-primary" disabled={loading}
              style={{ width: '100%', justifyContent: 'center', marginTop: 8 }}>
              {loading ? <span className="spinner" /> : 'Verify'}
            </button>
            <p style={{ textAlign: 'center', marginTop: 12, fontSize: 12, color: 'var(--neutral-500)' }}>
              <button type="button" onClick={() => switchTab('signin')}
                style={{ color: 'var(--primary-light)', background: 'none', border: 'none', cursor: 'pointer', fontSize: 12 }}>
                Back to Sign In
              </button>
            </p>
          </form>
        )}

        {/* Register */}
        {tab === 'register' && (
          <form onSubmit={handleRegister}>
            <div className="form-group" style={{ marginBottom: 14 }}>
              <label>Username <span style={{ color: 'var(--neutral-500)', fontWeight: 400 }}>(cannot be changed)</span></label>
              <input type="text" value={username} onChange={e => setUsername(e.target.value)}
                placeholder="choose_a_username" required autoFocus autoComplete="username" />
            </div>
            <div className="form-group" style={{ marginBottom: 14 }}>
              <label>Email Address <span style={{ color: 'var(--neutral-500)', fontWeight: 400 }}>(required)</span></label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)}
                placeholder="you@example.com" required autoComplete="email" />
            </div>
            <div className="form-group" style={{ marginBottom: 14 }}>
              <label>Phone Number <span style={{ color: 'var(--neutral-500)', fontWeight: 400 }}>(optional)</span></label>
              <input type="tel" value={phone} onChange={e => setPhone(e.target.value)}
                placeholder="+12125551234" autoComplete="tel" />
              <span className="note">Include country code (e.g. +1 for US). Can be added later in Account Settings.</span>
            </div>
            <div className="form-group" style={{ marginBottom: 14 }}>
              <label>Password</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)}
                placeholder="Min 8 characters" required autoComplete="new-password" />
            </div>
            <div className="form-group" style={{ marginBottom: 20 }}>
              <label>Confirm Password</label>
              <input type="password" value={confirm} onChange={e => setConfirm(e.target.value)}
                placeholder="Repeat password" required autoComplete="new-password" />
            </div>
            {error && <p className="error-msg">{error}</p>}
            <button type="submit" className="btn btn-primary" disabled={loading}
              style={{ width: '100%', justifyContent: 'center', marginTop: 8 }}>
              {loading ? <span className="spinner" /> : 'Create Account'}
            </button>
            <p className="note" style={{ textAlign: 'center', marginTop: 12 }}>
              A verification code will be sent to your email.
            </p>
            <p style={{ textAlign: 'center', marginTop: 10, fontSize: 12, color: 'var(--neutral-500)' }}>
              Already have a code?{' '}
              <button type="button" onClick={() => switchTab('verify')}
                style={{ color: 'var(--primary-light)', background: 'none', border: 'none', cursor: 'pointer', fontSize: 12 }}>
                Enter it here
              </button>
            </p>
          </form>
        )}

        {/* Verify */}
        {tab === 'verify' && (
          <form onSubmit={handleVerify}>
            <p style={{ fontSize: 15, fontWeight: 700, color: 'var(--primary-dark)', marginBottom: 8 }}>
              Verify Your Account
            </p>
            <p style={{ fontSize: 13, color: 'var(--neutral-700)', marginBottom: 16 }}>
              Enter the verification code sent to your email.
            </p>
            <div className="form-group" style={{ marginBottom: 14 }}>
              <label>Username</label>
              <input type="text" value={username} onChange={e => setUsername(e.target.value)}
                placeholder="your_username" required autoComplete="username" />
            </div>
            <div className="form-group" style={{ marginBottom: 20 }}>
              <label>Verification Code</label>
              <input type="text" value={code} onChange={e => setCode(e.target.value)}
                placeholder="6-digit code" required autoFocus inputMode="numeric" />
            </div>
            {error && <p className="error-msg">{error}</p>}
            <button type="submit" className="btn btn-primary" disabled={loading}
              style={{ width: '100%', justifyContent: 'center', marginTop: 8 }}>
              {loading ? <span className="spinner" /> : 'Verify Account'}
            </button>
            <p style={{ textAlign: 'center', marginTop: 12, fontSize: 12, color: 'var(--neutral-500)' }}>
              <button type="button" onClick={() => switchTab('signin')}
                style={{ color: 'var(--primary-light)', background: 'none', border: 'none', cursor: 'pointer', fontSize: 12 }}>
                Back to Sign In
              </button>
            </p>
          </form>
        )}

        {/* Forgot Password */}
        {tab === 'forgot' && (
          <form onSubmit={handleForgot}>
            <p style={{ fontSize: 15, fontWeight: 700, color: 'var(--primary-dark)', marginBottom: 8 }}>
              Reset Password
            </p>
            <p style={{ fontSize: 13, color: 'var(--neutral-700)', marginBottom: 16 }}>
              Enter your username and we'll send a reset code to your email.
            </p>
            <div className="form-group" style={{ marginBottom: 20 }}>
              <label>Username</label>
              <input type="text" value={username} onChange={e => setUsername(e.target.value)}
                placeholder="your_username" required autoFocus autoComplete="username" />
            </div>
            {error && <p className="error-msg">{error}</p>}
            <button type="submit" className="btn btn-primary" disabled={loading}
              style={{ width: '100%', justifyContent: 'center', marginTop: 8 }}>
              {loading ? <span className="spinner" /> : 'Send Reset Code'}
            </button>
            <p style={{ textAlign: 'center', marginTop: 12, fontSize: 12, color: 'var(--neutral-500)' }}>
              <button type="button" onClick={() => switchTab('signin')}
                style={{ color: 'var(--primary-light)', background: 'none', border: 'none', cursor: 'pointer', fontSize: 12 }}>
                Back to Sign In
              </button>
            </p>
          </form>
        )}

        {/* Reset Password */}
        {tab === 'reset' && (
          <form onSubmit={handleReset}>
            <p style={{ fontSize: 15, fontWeight: 700, color: 'var(--primary-dark)', marginBottom: 8 }}>
              Set New Password
            </p>
            {success && <p className="success-msg">{success}</p>}
            <div className="form-group" style={{ marginBottom: 14 }}>
              <label>Username</label>
              <input type="text" value={username} onChange={e => setUsername(e.target.value)}
                placeholder="your_username" required autoComplete="username" />
            </div>
            <div className="form-group" style={{ marginBottom: 14 }}>
              <label>Reset Code</label>
              <input type="text" value={code} onChange={e => setCode(e.target.value)}
                placeholder="6-digit code" required autoFocus inputMode="numeric" />
            </div>
            <div className="form-group" style={{ marginBottom: 20 }}>
              <label>New Password</label>
              <input type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)}
                placeholder="Min 8 characters" required autoComplete="new-password" />
            </div>
            {error && <p className="error-msg">{error}</p>}
            <button type="submit" className="btn btn-primary" disabled={loading}
              style={{ width: '100%', justifyContent: 'center', marginTop: 8 }}>
              {loading ? <span className="spinner" /> : 'Set New Password'}
            </button>
            <p style={{ textAlign: 'center', marginTop: 12, fontSize: 12, color: 'var(--neutral-500)' }}>
              <button type="button" onClick={() => switchTab('forgot')}
                style={{ color: 'var(--primary-light)', background: 'none', border: 'none', cursor: 'pointer', fontSize: 12 }}>
                Resend code
              </button>
            </p>
          </form>
        )}

      </div>
      </div>
    </div>
  );
}
