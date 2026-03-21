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

// Resolves with the current authenticated user and a valid session, or rejects.
// Used internally to avoid repeating session-retrieval boilerplate in every function.
function withSession() {
  return new Promise((resolve, reject) => {
    const user = userPool.getCurrentUser();
    if (!user) { reject(new Error('Not authenticated')); return; }
    user.getSession((err, session) => {
      if (err || !session?.isValid()) { reject(err || new Error('Session invalid')); return; }
      resolve({ user, session });
    });
  });
}

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
        cognitoUser: user,
        challengeName,
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
  return withSession().then(({ session }) => session.getIdToken().getJwtToken());
}

export function signOut() {
  const user = userPool.getCurrentUser();
  if (user) user.signOut();
}

// Sends a password-reset code to the registered email
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
// Required when the attribute is NOT in AutoVerifiedAttributes — updateAttributes()
// alone will not trigger code delivery in that case.
export function getAttributeVerificationCode(attributeName) {
  return withSession().then(({ user }) => new Promise((resolve, reject) => {
    user.getAttributeVerificationCode(attributeName, {
      onSuccess() { resolve(); },
      onFailure(err) { reject(err); },
    });
  }));
}

// Update a user attribute (e.g. 'email' or 'phone_number')
export function updateUserAttribute(attributeName, value) {
  return withSession().then(({ user }) => new Promise((resolve, reject) => {
    user.updateAttributes(
      [new CognitoUserAttribute({ Name: attributeName, Value: value })],
      (err) => { if (err) reject(err); else resolve(); }
    );
  }));
}

// Confirm a pending attribute update with the verification code
export function verifyUserAttribute(attributeName, code) {
  return withSession().then(({ user }) => new Promise((resolve, reject) => {
    user.verifyAttribute(attributeName, code, {
      onSuccess() { resolve(); },
      onFailure(err) { reject(err); },
    });
  }));
}

// Returns { email, emailVerified, phone, phoneVerified, mfaEnabled, totpEnabled }
export function getUserMfaStatus() {
  return withSession().then(({ user }) => new Promise((resolve, reject) => {
    user.getUserData((err, data) => {
      if (err) { reject(err); return; }
      const attrs = data.UserAttributes || [];
      const get = (name) => attrs.find(a => a.Name === name)?.Value;
      const mfaList = data.UserMFASettingList || [];
      resolve({
        email:         get('email') || '',
        emailVerified: get('email_verified') === 'true',
        phone:         get('phone_number') || '',
        phoneVerified: get('phone_number_verified') === 'true',
        mfaEnabled:    mfaList.includes('SMS_MFA'),
        totpEnabled:   mfaList.includes('SOFTWARE_TOKEN_MFA'),
      });
    }, { bypassCache: true });
  }));
}

// Begin TOTP setup — returns the base32 secret key to enter in an authenticator app
export function associateSoftwareToken() {
  return withSession().then(({ user }) => new Promise((resolve, reject) => {
    user.associateSoftwareToken({
      associateSecretCode(secret) { resolve(secret); },
      onFailure(err) { reject(err); },
    });
  }));
}

// Verify the TOTP code entered after scanning the secret, completing setup
export function verifySoftwareToken(totpCode) {
  return withSession().then(({ user }) => new Promise((resolve, reject) => {
    user.verifySoftwareToken(totpCode, 'Delta Catcher', {
      onSuccess() { resolve(); },
      onFailure(err) { reject(err); },
    });
  }));
}

// Complete MFA sign-in after signIn returns { type: 'mfa', cognitoUser, challengeName }
// Prefer this over the sendMfaCode closure for new code — more composable.
export function completeMfaSignIn(cognitoUser, code, challengeName) {
  return new Promise((resolve, reject) => {
    cognitoUser.sendMFACode(code, {
      onSuccess(session) {
        const payload = session.getIdToken().payload;
        resolve({
          idToken:  session.getIdToken().getJwtToken(),
          username: payload['cognito:username'] || cognitoUser.getUsername(),
          sub:      payload.sub,
        });
      },
      onFailure(err) { reject(err); },
    }, challengeName);
  });
}

// Unified MFA preference setter — pass { totp: bool, sms: bool }
// Mirrors REPL setMfaPreferences signature.
export function setMfaPreferences({ totp, sms }) {
  return withSession().then(({ user }) => new Promise((resolve, reject) => {
    const totpPref = totp != null ? { Enabled: totp, PreferredMfa: totp } : null;
    const smsPref  = sms  != null ? { Enabled: sms,  PreferredMfa: !totp && sms } : null;
    user.setUserMfaPreference(smsPref, totpPref, (err) => {
      if (err) reject(err); else resolve();
    });
  }));
}

// Enable or disable TOTP MFA for the current user
export function setTotpMfaPreference(enabled) {
  return withSession().then(({ user }) => new Promise((resolve, reject) => {
    user.setUserMfaPreference(null, { Enabled: enabled, PreferredMfa: enabled }, (err) => {
      if (err) reject(err); else resolve();
    });
  }));
}

// Enable or disable SMS MFA for the current user
export function setSmsMfaPreference(enabled) {
  return withSession().then(({ user }) => new Promise((resolve, reject) => {
    user.setUserMfaPreference({ Enabled: enabled, PreferredMfa: enabled }, null, (err) => {
      if (err) reject(err); else resolve();
    });
  }));
}

export function changePassword(oldPassword, newPassword) {
  return withSession().then(({ user }) => new Promise((resolve, reject) => {
    user.changePassword(oldPassword, newPassword, (err) => {
      if (err) reject(err); else resolve();
    });
  }));
}
