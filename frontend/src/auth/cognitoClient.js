import {
  CognitoUserPool,
  CognitoUser,
  AuthenticationDetails,
  CognitoUserAttribute,
} from 'amazon-cognito-identity-js';
import { COGNITO_POOL_ID, COGNITO_CLIENT_ID } from '../config';

const userPool = new CognitoUserPool({
  UserPoolId: COGNITO_POOL_ID,
  ClientId:   COGNITO_CLIENT_ID,
});

// Returns { type: 'success', session } | { type: 'mfa', mfaType, sendMfaCode }
// mfaType: 'sms' | 'totp'
// session shape: { idToken, username, sub }
export function signIn(username, password) {
  return new Promise((resolve, reject) => {
    const user = new CognitoUser({ Username: username, Pool: userPool });
    const auth = new AuthenticationDetails({ Username: username, Password: password });

    function buildMfaResolver(mfaType, challengeName) {
      return {
        type: 'mfa',
        mfaType,
        sendMfaCode: (code) => new Promise((res, rej) => {
          user.sendMFACode(code, {
            onSuccess(session) {
              res({
                idToken: session.getIdToken().getJwtToken(),
                username,
                sub: session.getIdToken().payload.sub,
              });
            },
            onFailure(err) { rej(err); },
          }, challengeName);
        }),
      };
    }

    user.authenticateUser(auth, {
      onSuccess(session) {
        resolve({
          type: 'success',
          session: {
            idToken: session.getIdToken().getJwtToken(),
            username,
            sub: session.getIdToken().payload.sub,
          },
        });
      },
      onFailure(err) { reject(err); },
      mfaRequired()  { resolve(buildMfaResolver('sms',  'SMS_MFA')); },
      totpRequired() { resolve(buildMfaResolver('totp', 'SOFTWARE_TOKEN_MFA')); },
      newPasswordRequired() {
        reject(new Error('Password reset required — contact administrator'));
      },
    });
  });
}

// username, email, password — phone is optional
export function signUp(username, email, phone, password) {
  return new Promise((resolve, reject) => {
    const attrs = [new CognitoUserAttribute({ Name: 'email', Value: email })];
    if (phone) attrs.push(new CognitoUserAttribute({ Name: 'phone_number', Value: phone }));
    userPool.signUp(username, password, attrs, null, (err, result) => {
      if (err) { reject(err); return; }
      resolve({ sub: result.userSub, username });
    });
  });
}

// Confirm sign-up with the emailed verification code
export function confirmSignUp(username, code) {
  return new Promise((resolve, reject) => {
    const user = new CognitoUser({ Username: username, Pool: userPool });
    user.confirmRegistration(code, true, (err) => {
      if (err) { reject(err); return; }
      resolve();
    });
  });
}

// Returns current session info (used for initial auth check on page load)
export function getCurrentSession() {
  return new Promise((resolve) => {
    const user = userPool.getCurrentUser();
    if (!user) { resolve(null); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { resolve(null); return; }
      const payload = session.getIdToken().payload;
      resolve({
        idToken: session.getIdToken().getJwtToken(),
        username: payload['cognito:username'] || user.getUsername(),
        sub: payload.sub,
      });
    });
  });
}

// Returns current IdToken string, silently refreshing if needed
export function getIdToken() {
  return new Promise((resolve, reject) => {
    const user = userPool.getCurrentUser();
    if (!user) { reject(new Error('No authenticated user')); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { reject(err || new Error('Session invalid')); return; }
      resolve(session.getIdToken().getJwtToken());
    });
  });
}

export function signOut() {
  const user = userPool.getCurrentUser();
  if (user) user.signOut();
}

// Sends a password-reset code to the registered email/phone
export function forgotPassword(username) {
  return new Promise((resolve, reject) => {
    const user = new CognitoUser({ Username: username, Pool: userPool });
    user.forgotPassword({
      onSuccess() { resolve(); },
      onFailure(err) { reject(err); },
    });
  });
}

export function confirmForgotPassword(username, code, newPassword) {
  return new Promise((resolve, reject) => {
    const user = new CognitoUser({ Username: username, Pool: userPool });
    user.confirmPassword(code, newPassword, {
      onSuccess() { resolve(); },
      onFailure(err) { reject(err); },
    });
  });
}

// Explicitly request a verification code for an attribute (e.g. 'phone_number').
// Required when the attribute is NOT in the pool's AutoVerifiedAttributes, because
// updateAttributes() alone will not trigger code delivery in that case.
export function getAttributeVerificationCode(attributeName) {
  return new Promise((resolve, reject) => {
    const user = userPool.getCurrentUser();
    if (!user) { reject(new Error('Not authenticated')); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { reject(err || new Error('Session invalid')); return; }
      user.getAttributeVerificationCode(attributeName, {
        onSuccess() { resolve(); },
        onFailure(err2) { reject(err2); },
      });
    });
  });
}

// Update a user attribute (e.g. 'email' or 'phone_number')
export function updateUserAttribute(attributeName, value) {
  return new Promise((resolve, reject) => {
    const user = userPool.getCurrentUser();
    if (!user) { reject(new Error('Not authenticated')); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { reject(err || new Error('Session invalid')); return; }
      const attrs = [new CognitoUserAttribute({ Name: attributeName, Value: value })];
      user.updateAttributes(attrs, (err2) => {
        if (err2) { reject(err2); } else { resolve(); }
      });
    });
  });
}

// Confirm a pending attribute update with the verification code
export function verifyUserAttribute(attributeName, code) {
  return new Promise((resolve, reject) => {
    const user = userPool.getCurrentUser();
    if (!user) { reject(new Error('Not authenticated')); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { reject(err || new Error('Session invalid')); return; }
      user.verifyAttribute(attributeName, code, {
        onSuccess() { resolve(); },
        onFailure(err2) { reject(err2); },
      });
    });
  });
}

// Returns { email, emailVerified, phone, phoneVerified, mfaEnabled } for the current user
export function getUserMfaStatus() {
  return new Promise((resolve, reject) => {
    const user = userPool.getCurrentUser();
    if (!user) { reject(new Error('Not authenticated')); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { reject(err || new Error('Session invalid')); return; }
      user.getUserData((err2, data) => {
        if (err2) { reject(err2); return; }
        const attrs = data.UserAttributes || [];
        const email = attrs.find(a => a.Name === 'email')?.Value || '';
        const emailVerified = attrs.find(a => a.Name === 'email_verified')?.Value === 'true';
        const phone = attrs.find(a => a.Name === 'phone_number')?.Value || '';
        const phoneVerified = attrs.find(a => a.Name === 'phone_number_verified')?.Value === 'true';
        const mfaList = data.UserMFASettingList || [];
        const mfaEnabled  = mfaList.includes('SMS_MFA');
        const totpEnabled = mfaList.includes('SOFTWARE_TOKEN_MFA');
        resolve({ email, emailVerified, phone, phoneVerified, mfaEnabled, totpEnabled });
      }, { bypassCache: true });
    });
  });
}

// Begin TOTP setup — returns the base32 secret key to enter in an authenticator app
export function associateSoftwareToken() {
  return new Promise((resolve, reject) => {
    const user = userPool.getCurrentUser();
    if (!user) { reject(new Error('Not authenticated')); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { reject(err || new Error('Session invalid')); return; }
      user.associateSoftwareToken({
        associateSecretCode(secret) { resolve(secret); },
        onFailure(err2) { reject(err2); },
      });
    });
  });
}

// Verify the TOTP code entered after scanning the secret, completing setup
export function verifySoftwareToken(totpCode) {
  return new Promise((resolve, reject) => {
    const user = userPool.getCurrentUser();
    if (!user) { reject(new Error('Not authenticated')); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { reject(err || new Error('Session invalid')); return; }
      user.verifySoftwareToken(totpCode, 'Delta Catcher', {
        onSuccess() { resolve(); },
        onFailure(err2) { reject(err2); },
      });
    });
  });
}

// Enable or disable TOTP MFA for the current user
export function setTotpMfaPreference(enabled) {
  return new Promise((resolve, reject) => {
    const user = userPool.getCurrentUser();
    if (!user) { reject(new Error('Not authenticated')); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { reject(err || new Error('Session invalid')); return; }
      const totpSettings = { Enabled: enabled, PreferredMfa: enabled };
      user.setUserMfaPreference(null, totpSettings, (err2) => {
        if (err2) { reject(err2); } else { resolve(); }
      });
    });
  });
}

// Enable or disable SMS MFA for the current user
export function setSmsMfaPreference(enabled) {
  return new Promise((resolve, reject) => {
    const user = userPool.getCurrentUser();
    if (!user) { reject(new Error('Not authenticated')); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { reject(err || new Error('Session invalid')); return; }
      const smsMfaSettings = { Enabled: enabled, PreferredMfa: enabled };
      user.setUserMfaPreference(smsMfaSettings, null, (err2) => {
        if (err2) { reject(err2); } else { resolve(); }
      });
    });
  });
}

export function changePassword(oldPassword, newPassword) {
  return new Promise((resolve, reject) => {
    const user = userPool.getCurrentUser();
    if (!user) { reject(new Error('Not authenticated')); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { reject(err || new Error('Session invalid')); return; }
      user.changePassword(oldPassword, newPassword, (err2) => {
        if (err2) { reject(err2); } else { resolve(); }
      });
    });
  });
}
