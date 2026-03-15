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

// Returns { type: 'success', session } or { type: 'mfa', sendMfaCode }
// session shape: { idToken, username, sub }
export function signIn(username, password) {
  return new Promise((resolve, reject) => {
    const user = new CognitoUser({ Username: username, Pool: userPool });
    const auth = new AuthenticationDetails({ Username: username, Password: password });
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
      mfaRequired() {
        resolve({
          type: 'mfa',
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
            });
          }),
        });
      },
      newPasswordRequired() {
        reject(new Error('Password reset required — contact administrator'));
      },
    });
  });
}

// username, email, phone (e.g. +12125551234), password
export function signUp(username, email, phone, password) {
  return new Promise((resolve, reject) => {
    const attrs = [
      new CognitoUserAttribute({ Name: 'email', Value: email }),
      new CognitoUserAttribute({ Name: 'phone_number', Value: phone }),
    ];
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
