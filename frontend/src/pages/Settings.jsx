import { useState } from 'react';
import { useAuth } from '../auth/AuthContext';
import {
  updateUserAttribute,
  verifyUserAttribute,
  changePassword,
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
    <div className="form-group" style={{ marginBottom: 12 }}>
      <label>{label}</label>
      {children}
    </div>
  );
}

export default function Settings() {
  const { session } = useAuth();

  // Email section
  const [email, setEmail]             = useState('');
  const [emailCode, setEmailCode]     = useState('');
  const [emailStep, setEmailStep]     = useState('edit'); // edit | verify
  const [emailLoading, setEmailLoading] = useState(false);
  const [emailError, setEmailError]   = useState('');
  const [emailSuccess, setEmailSuccess] = useState('');

  // Phone section
  const [phone, setPhone]             = useState('');
  const [phoneCode, setPhoneCode]     = useState('');
  const [phoneStep, setPhoneStep]     = useState('edit'); // edit | verify
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
      setEmail('');
      setEmailCode('');
      setEmailSuccess('Email updated successfully.');
    } catch (err) {
      setEmailError(err.message || 'Verification failed');
    } finally {
      setEmailLoading(false);
    }
  }

  async function handlePhoneUpdate(e) {
    e.preventDefault();
    setPhoneError(''); setPhoneLoading(true);
    try {
      await updateUserAttribute('phone_number', phone);
      setPhoneStep('verify');
      setPhoneSuccess('Verification code sent via SMS to new number.');
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
      setPhoneStep('edit');
      setPhone('');
      setPhoneCode('');
      setPhoneSuccess('Phone number updated successfully.');
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
        <Field label="Username">
          <input type="text" value={session?.username || ''} disabled />
        </Field>
        <p className="note">Username is permanent and cannot be changed.</p>
      </Section>

      {/* Email */}
      <Section title="Email Address">
        {emailStep === 'edit' ? (
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
        {phoneStep === 'edit' ? (
          <form onSubmit={handlePhoneUpdate}>
            <Field label="New Phone Number">
              <input type="tel" value={phone} onChange={e => setPhone(e.target.value)}
                placeholder="+12125551234" required />
            </Field>
            <p className="note" style={{ marginBottom: 12 }}>Include country code. Used for MFA.</p>
            {phoneError && <p className="error-msg">{phoneError}</p>}
            {phoneSuccess && !phoneLoading && <p className="success-msg">{phoneSuccess}</p>}
            <button type="submit" className="btn btn-primary btn-sm" disabled={phoneLoading}>
              {phoneLoading ? <span className="spinner" style={{ borderTopColor: 'white' }} /> : 'Update Phone'}
            </button>
          </form>
        ) : (
          <form onSubmit={handlePhoneVerify}>
            {phoneSuccess && <p className="success-msg">{phoneSuccess}</p>}
            <Field label="SMS Verification Code">
              <input type="text" value={phoneCode} onChange={e => setPhoneCode(e.target.value)}
                placeholder="6-digit code" required autoFocus inputMode="numeric" />
            </Field>
            {phoneError && <p className="error-msg">{phoneError}</p>}
            <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
              <button type="submit" className="btn btn-primary btn-sm" disabled={phoneLoading}>
                {phoneLoading ? <span className="spinner" style={{ borderTopColor: 'white' }} /> : 'Confirm'}
              </button>
              <button type="button" className="btn btn-outline btn-sm"
                onClick={() => { setPhoneStep('edit'); setPhoneError(''); setPhoneSuccess(''); }}>
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
