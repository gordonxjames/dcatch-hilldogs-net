import { useState, useEffect } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { useAuth } from '../auth/AuthContext';
import InfoTip from '../components/InfoTip';
import {
  updateUserAttribute,
  verifyUserAttribute,
  getAttributeVerificationCode,
  changePassword,
  getUserMfaStatus,
  associateSoftwareToken,
  verifySoftwareToken,
  setTotpMfaPreference,
} from '../auth/cognitoClient';

function Section({ title, children }) {
  return (
    <div className="card" style={{ maxWidth: 560 }}>
      <p className="card-title">{title}</p>
      {children}
    </div>
  );
}

function Field({ label, children }) {
  return (
    <div className="form-group" style={{ marginBottom: 8 }}>
      <label>{label}</label>
      {children}
    </div>
  );
}

export default function Settings() {
  const { session } = useAuth();

  // MFA status
  const [mfaStatus, setMfaStatus]     = useState(null); // { email, phone, phoneVerified, mfaEnabled, totpEnabled }
  const [mfaLoading, setMfaLoading]   = useState(false);
  const [mfaError, setMfaError]       = useState('');
  const [mfaSuccess, setMfaSuccess]   = useState('');

  // TOTP setup — 'idle' | 'setup' | 'verify'
  const [totpStep, setTotpStep]       = useState('idle');
  const [totpSecret, setTotpSecret]   = useState('');
  const [totpCode, setTotpCode]       = useState('');
  const [totpLoading, setTotpLoading] = useState(false);
  const [totpError, setTotpError]     = useState('');

  // Email section
  const [email, setEmail]             = useState('');
  const [emailCode, setEmailCode]     = useState('');
  const [emailStep, setEmailStep]     = useState('edit');
  const [emailLoading, setEmailLoading] = useState(false);
  const [emailError, setEmailError]   = useState('');
  const [emailSuccess, setEmailSuccess] = useState('');

  // Phone section — 'idle' | 'change' | 'verify'
  const [phone, setPhone]             = useState('');
  const [phoneCode, setPhoneCode]     = useState('');
  const [phoneStep, setPhoneStep]     = useState('idle');
  const [phoneLoading, setPhoneLoading] = useState(false);
  const [phoneError, setPhoneError]   = useState('');
  const [phoneSuccess, setPhoneSuccess] = useState('');

  // Password section
  const [oldPw, setOldPw]             = useState('');
  const [newPw, setNewPw]             = useState('');
  const [confirmPw, setConfirmPw]     = useState('');
  const [pwLoading, setPwLoading]     = useState(false);
  const [pwError, setPwError]         = useState('');
  const [pwSuccess, setPwSuccess]     = useState('');

  useEffect(() => {
    getUserMfaStatus().then(setMfaStatus).catch(() => {});
  }, []);

  function refreshMfaStatus() {
    getUserMfaStatus().then(setMfaStatus).catch(() => {});
  }

  async function handleTotpSetup() {
    setTotpError(''); setTotpLoading(true);
    try {
      const secret = await associateSoftwareToken();
      setTotpSecret(secret);
      setTotpCode('');
      setTotpStep('setup');
    } catch (err) {
      setTotpError(err.message || 'Failed to start authenticator setup');
    } finally {
      setTotpLoading(false);
    }
  }

  async function handleTotpVerify(e) {
    e.preventDefault();
    setTotpError(''); setTotpLoading(true);
    try {
      await verifySoftwareToken(totpCode);
      await setTotpMfaPreference(true);
      setTotpStep('idle');
      setTotpSecret(''); setTotpCode('');
      setMfaSuccess('Authenticator app set up and TOTP MFA enabled.');
      refreshMfaStatus();
    } catch (err) {
      setTotpError(err.message || 'Verification failed — check the code and try again');
    } finally {
      setTotpLoading(false);
    }
  }

  async function handleDisableTotp() {
    setMfaError(''); setMfaSuccess(''); setMfaLoading(true);
    try {
      await setTotpMfaPreference(false);
      setMfaSuccess('TOTP MFA disabled.');
      refreshMfaStatus();
    } catch (err) {
      setMfaError(err.message || 'Failed to disable MFA');
    } finally {
      setMfaLoading(false);
    }
  }

  async function handleEmailUpdate(e) {
    e.preventDefault();
    setEmailError(''); setEmailLoading(true);
    try {
      await updateUserAttribute('email', email);
      setEmailStep('verify');
      setEmailSuccess('Verification code sent to new email address.');
    } catch (err) {
      setEmailError(err.message || 'Failed to update email');
    } finally {
      setEmailLoading(false);
    }
  }

  async function handleEmailVerify(e) {
    e.preventDefault();
    setEmailError(''); setEmailLoading(true);
    try {
      await verifyUserAttribute('email', emailCode);
      setEmailStep('edit');
      setEmail(''); setEmailCode('');
      setEmailSuccess('Email updated successfully.');
    } catch (err) {
      setEmailError(err.message || 'Verification failed');
    } finally {
      setEmailLoading(false);
    }
  }

  // Send SMS code to the existing phone number on file
  async function handleSendCodeToCurrentPhone() {
    setPhoneError(''); setPhoneSuccess(''); setPhoneLoading(true);
    try {
      await getAttributeVerificationCode('phone_number');
      setPhoneStep('verify');
      setPhoneSuccess('SMS code sent to your current phone number.');
    } catch (err) {
      setPhoneError(err.message || 'Failed to send SMS code');
    } finally {
      setPhoneLoading(false);
    }
  }

  // Update to a new phone number then send SMS code
  async function handlePhoneUpdate(e) {
    e.preventDefault();
    setPhoneError(''); setPhoneLoading(true);
    try {
      await updateUserAttribute('phone_number', phone);
      // phone_number is not in AutoVerifiedAttributes, so we must explicitly request the code
      await getAttributeVerificationCode('phone_number');
      setPhoneStep('verify');
      setPhoneSuccess('SMS code sent to new number.');
    } catch (err) {
      setPhoneError(err.message || 'Failed to update phone');
    } finally {
      setPhoneLoading(false);
    }
  }

  async function handlePhoneVerify(e) {
    e.preventDefault();
    setPhoneError(''); setPhoneLoading(true);
    try {
      await verifyUserAttribute('phone_number', phoneCode);
      // Automatically enable MFA once phone is verified
setPhoneStep('idle');
      setPhone(''); setPhoneCode('');
      setPhoneSuccess('Phone verified and SMS MFA enabled.');
      refreshMfaStatus();
    } catch (err) {
      setPhoneError(err.message || 'Verification failed');
    } finally {
      setPhoneLoading(false);
    }
  }

  async function handlePasswordChange(e) {
    e.preventDefault();
    if (newPw !== confirmPw) { setPwError('New passwords do not match'); return; }
    setPwError(''); setPwLoading(true);
    try {
      await changePassword(oldPw, newPw);
      setOldPw(''); setNewPw(''); setConfirmPw('');
      setPwSuccess('Password changed successfully.');
    } catch (err) {
      setPwError(err.message || 'Password change failed');
    } finally {
      setPwLoading(false);
    }
  }

  return (
    <div className="page">
      <h1 className="page-title">Account Settings</h1>

      {/* Username — read-only */}
      <Section title="Username">
        <Field label={<>Username <InfoTip content="Username cannot be changed." /></>}>
          <input type="text" value={session?.username || ''} disabled />
        </Field>
      </Section>

      {/* Two-Factor Authentication */}
      <Section title="Two-Factor Authentication">
        {mfaStatus === null ? (
          <p style={{ color: 'var(--neutral-500)', fontSize: 13 }}>Loading…</p>
        ) : mfaStatus.totpEnabled ? (
          <div>
            <p style={{ fontSize: 13, color: 'var(--success)', fontWeight: 600, marginBottom: 8 }}>
              ✓ Authenticator app MFA is active
            </p>
            <p style={{ fontSize: 13, color: 'var(--neutral-700)', marginBottom: 12 }}>
              A code from your authenticator app is required each time you sign in.
            </p>
            {mfaError && <p className="error-msg">{mfaError}</p>}
            {mfaSuccess && <p className="success-msg">{mfaSuccess}</p>}
            <button className="btn btn-outline btn-sm" disabled={mfaLoading}
              onClick={handleDisableTotp}>
              {mfaLoading ? <span className="spinner" style={{ borderTopColor: 'var(--primary)' }} /> : 'Disable MFA'}
            </button>
          </div>
        ) : totpStep === 'idle' ? (
          <div>
            <p style={{ fontSize: 13, color: 'var(--neutral-700)', marginBottom: 12 }}>
              MFA is not active. Set up an authenticator app (Google Authenticator, Authy, etc.)
              to require a code each time you sign in.
            </p>
            {mfaError && <p className="error-msg">{mfaError}</p>}
            {mfaSuccess && <p className="success-msg">{mfaSuccess}</p>}
            {totpError && <p className="error-msg">{totpError}</p>}
            <button className="btn btn-primary btn-sm" disabled={totpLoading}
              onClick={handleTotpSetup}>
              {totpLoading ? <span className="spinner" /> : 'Set Up Authenticator App'}
            </button>
          </div>
        ) : (
          <form onSubmit={handleTotpVerify}>
            <p style={{ fontSize: 13, color: 'var(--neutral-700)', marginBottom: 12 }}>
              Scan this QR code with your authenticator app (Google Authenticator, Authy, etc.),
              then enter the 6-digit code to confirm.
            </p>
            <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 12 }}>
              <div style={{ padding: 12, background: '#fff', border: '1px solid var(--neutral-200)', borderRadius: 8, display: 'inline-block' }}>
                <QRCodeSVG
                  value={`otpauth://totp/Delta%20Catcher:${encodeURIComponent(session?.username || '')}?secret=${totpSecret}&issuer=Delta%20Catcher`}
                  size={180}
                />
              </div>
            </div>
            <details style={{ marginBottom: 12 }}>
              <summary style={{ fontSize: 12, color: 'var(--neutral-500)', cursor: 'pointer' }}>
                Can't scan? Enter the key manually
              </summary>
              <div style={{
                fontFamily: 'monospace', fontSize: 13, fontWeight: 700, letterSpacing: 2,
                background: 'var(--neutral-100)', border: '1px solid var(--neutral-200)',
                borderRadius: 6, padding: '10px 14px', marginTop: 8,
                wordBreak: 'break-all', userSelect: 'all',
              }}>
                {totpSecret}
              </div>
              <p className="note" style={{ marginTop: 6 }}>Account name: <strong>Delta Catcher</strong></p>
            </details>
            <div className="form-group" style={{ marginBottom: 8 }}>
              <label>Confirmation Code</label>
              <input type="text" value={totpCode} onChange={e => setTotpCode(e.target.value)}
                placeholder="6-digit code" required autoFocus inputMode="numeric" />
            </div>
            {totpError && <p className="error-msg">{totpError}</p>}
            <div style={{ display: 'flex', gap: 8 }}>
              <button type="submit" className="btn btn-primary btn-sm" disabled={totpLoading}>
                {totpLoading ? <span className="spinner" style={{ borderTopColor: 'white' }} /> : 'Confirm & Enable MFA'}
              </button>
              <button type="button" className="btn btn-outline btn-sm"
                onClick={() => { setTotpStep('idle'); setTotpError(''); setTotpSecret(''); }}>
                Cancel
              </button>
            </div>
          </form>
        )}
      </Section>

      {/* Email */}
      <Section title="Email Address">
        {emailStep === 'edit' ? (
          <div>
            {mfaStatus?.email && (
              <p style={{ fontSize: 13, color: 'var(--neutral-700)', marginBottom: 12 }}>
                Current email: <strong>{mfaStatus.email}</strong>
                {mfaStatus.emailVerified
                  ? <span style={{ color: 'var(--success)', marginLeft: 8 }}>✓ verified</span>
                  : <span style={{ color: 'var(--neutral-500)', marginLeft: 8 }}>not verified</span>}
              </p>
            )}
            <form onSubmit={handleEmailUpdate}>
              <Field label="New Email Address">
                <input type="email" value={email} onChange={e => setEmail(e.target.value)}
                  placeholder="new@example.com" required />
              </Field>
              {emailError && <p className="error-msg">{emailError}</p>}
              {emailSuccess && !emailLoading && <p className="success-msg">{emailSuccess}</p>}
              <button type="submit" className="btn btn-primary btn-sm" disabled={emailLoading}>
                {emailLoading ? <span className="spinner" style={{ borderTopColor: 'white' }} /> : 'Update Email'}
              </button>
            </form>
          </div>
        ) : (
          <form onSubmit={handleEmailVerify}>
            {emailSuccess && <p className="success-msg">{emailSuccess}</p>}
            <Field label="Verification Code">
              <input type="text" value={emailCode} onChange={e => setEmailCode(e.target.value)}
                placeholder="6-digit code" required autoFocus inputMode="numeric" />
            </Field>
            {emailError && <p className="error-msg">{emailError}</p>}
            <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
              <button type="submit" className="btn btn-primary btn-sm" disabled={emailLoading}>
                {emailLoading ? <span className="spinner" style={{ borderTopColor: 'white' }} /> : 'Confirm'}
              </button>
              <button type="button" className="btn btn-outline btn-sm"
                onClick={() => { setEmailStep('edit'); setEmailError(''); setEmailSuccess(''); }}>
                Cancel
              </button>
            </div>
          </form>
        )}
      </Section>

      {/* Phone */}
      <Section title="Phone Number">
        {phoneStep === 'idle' && (
          <div>
            {mfaStatus?.phone && (
              <p style={{ fontSize: 13, color: 'var(--neutral-700)', marginBottom: 12 }}>
                Current number: <strong>{mfaStatus.phone}</strong>
                {mfaStatus.phoneVerified
                  ? <span style={{ color: 'var(--success)', marginLeft: 8 }}>✓ verified</span>
                  : <span style={{ color: 'var(--neutral-500)', marginLeft: 8 }}>not verified</span>}
              </p>
            )}
            {phoneError && <p className="error-msg">{phoneError}</p>}
            {phoneSuccess && <p className="success-msg">{phoneSuccess}</p>}
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              {!mfaStatus?.phoneVerified && mfaStatus?.phone && (
                <button className="btn btn-primary btn-sm" disabled title="SMS verification not yet available (DCATCH-23)">
                  Send Code to Verify Current Number
                </button>
              )}
              <button className="btn btn-outline btn-sm"
                onClick={() => { setPhoneStep('change'); setPhoneError(''); setPhoneSuccess(''); }}>
                {mfaStatus?.phone ? 'Change Number' : 'Add Phone Number'}
              </button>
            </div>
          </div>
        )}

        {phoneStep === 'change' && (
          <form onSubmit={handlePhoneUpdate}>
            <Field label="New Phone Number">
              <input type="tel" value={phone} onChange={e => setPhone(e.target.value)}
                placeholder="+12125551234" required autoFocus />
            </Field>
            <p className="note" style={{ marginBottom: 12 }}>
              Include country code (e.g. +1 for US). An SMS code will be sent to confirm.
            </p>
            {phoneError && <p className="error-msg">{phoneError}</p>}
            <div style={{ display: 'flex', gap: 8 }}>
              <button type="submit" className="btn btn-primary btn-sm" disabled={phoneLoading}>
                {phoneLoading ? <span className="spinner" style={{ borderTopColor: 'white' }} /> : 'Send Code'}
              </button>
              <button type="button" className="btn btn-outline btn-sm"
                onClick={() => { setPhoneStep('idle'); setPhoneError(''); }}>
                Cancel
              </button>
            </div>
          </form>
        )}

        {phoneStep === 'verify' && (
          <form onSubmit={handlePhoneVerify}>
            {phoneSuccess && <p className="success-msg">{phoneSuccess}</p>}
            <Field label="SMS Verification Code">
              <input type="text" value={phoneCode} onChange={e => setPhoneCode(e.target.value)}
                placeholder="6-digit code" required autoFocus inputMode="numeric" />
            </Field>
            <p className="note" style={{ marginBottom: 12 }}>
              Confirming this code will verify your phone and enable SMS MFA.
            </p>
            {phoneError && <p className="error-msg">{phoneError}</p>}
            <div style={{ display: 'flex', gap: 8 }}>
              <button type="submit" className="btn btn-primary btn-sm" disabled={phoneLoading}>
                {phoneLoading ? <span className="spinner" style={{ borderTopColor: 'white' }} /> : 'Verify & Enable MFA'}
              </button>
              <button type="button" className="btn btn-outline btn-sm"
                onClick={() => { setPhoneStep('idle'); setPhoneError(''); setPhoneSuccess(''); }}>
                Cancel
              </button>
            </div>
          </form>
        )}
      </Section>

      {/* Password */}
      <Section title="Change Password">
        <form onSubmit={handlePasswordChange}>
          <Field label="Current Password">
            <input type="password" value={oldPw} onChange={e => setOldPw(e.target.value)}
              placeholder="••••••••" required autoComplete="current-password" />
          </Field>
          <Field label="New Password">
            <input type="password" value={newPw} onChange={e => setNewPw(e.target.value)}
              placeholder="Min 8 characters" required autoComplete="new-password" />
          </Field>
          <Field label="Confirm New Password">
            <input type="password" value={confirmPw} onChange={e => setConfirmPw(e.target.value)}
              placeholder="Repeat new password" required autoComplete="new-password" />
          </Field>
          {pwError && <p className="error-msg">{pwError}</p>}
          {pwSuccess && <p className="success-msg">{pwSuccess}</p>}
          <button type="submit" className="btn btn-primary btn-sm" disabled={pwLoading}
            style={{ marginTop: 4 }}>
            {pwLoading ? <span className="spinner" style={{ borderTopColor: 'white' }} /> : 'Change Password'}
          </button>
        </form>
      </Section>
    </div>
  );
}
