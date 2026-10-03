// Each attempt uses an isolated document so GIS initializes exactly once.
window.mhpGoogleAuthenticate = async function (clientId, nonce) {
  if (window.mhpGooglePending) return JSON.stringify({error:'google_busy'});
  window.mhpGooglePending = true;
  try {
    return await new Promise(resolve => {
      let finished = false, timer;
      const dialog = document.createElement('dialog');
      dialog.setAttribute('aria-label', 'Sign in with Google');
      dialog.style.cssText = 'border:1px solid #ddd;border-radius:16px;padding:24px;background:#fbf8f3;color:#111827;max-width:90vw';
      const title = document.createElement('h2'); title.textContent = 'Continue with Google';
      const frame = document.createElement('iframe');
      frame.title = 'Google sign-in button';
      frame.src = 'google_auth_frame.html';
      frame.style.cssText = 'border:0;width:300px;height:70px;max-width:100%';
      const cancel = document.createElement('button'); cancel.textContent = 'Cancel';
      cancel.style.cssText = 'display:block;margin:20px auto 0;padding:10px 20px';
      const finish = value => {
        if (finished) return;
        finished = true; clearTimeout(timer); dialog.remove(); resolve(JSON.stringify(value));
      };
      cancel.onclick = () => finish({error:'google_canceled'});
      dialog.addEventListener('cancel', event => {event.preventDefault(); finish({error:'google_canceled'});});
      frame.onload = () => {
        if (finished) return;
        try {frame.contentWindow.mhpInitializeGoogle(clientId, nonce, finish);}
        catch (_) {finish({error:'google_unavailable'});}
      };
      dialog.append(title, frame, cancel); document.body.append(dialog); dialog.showModal(); cancel.focus();
      timer = setTimeout(() => finish({error:'google_canceled'}), 270000);
    });
  } finally {window.mhpGooglePending = false;}
};
