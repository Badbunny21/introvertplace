/**
 * A note settles in a few hours, or the next morning if it is left at night.
 * The recipient does not see it until then, and it stays unopened until they open it.
 */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.QuietNote = api;
})(typeof self !== 'undefined' ? self : this, function () {
  var FOUR_HOURS = 4 * 60 * 60 * 1000;

  function deliverAt(now) {
    var date = now instanceof Date ? new Date(now.getTime()) : new Date();
    if (date.getHours() >= 20) {
      var morning = new Date(date.getTime());
      morning.setDate(morning.getDate() + 1);
      morning.setHours(8, 0, 0, 0);
      return morning.toISOString();
    }
    return new Date(date.getTime() + FOUR_HOURS).toISOString();
  }

  function settlePhrase(now) {
    var date = now instanceof Date ? now : new Date();
    if (date.getHours() >= 20) return 'Your note will be there in the morning.';
    return 'Your note will settle in a few hours.';
  }

  function tellParent() {
    try {
      if (window.parent && window.parent !== window) {
        window.parent.postMessage({ action: 'note-opened' }, window.location.origin);
      }
    } catch (e) {}
  }

  async function send(db, fromId, toId, body) {
    var text = (body || '').trim();
    if (!db || !fromId) return { ok: false, error: 'Sign in to leave a note' };
    if (!toId || toId === fromId) return { ok: false, error: 'A note needs another person' };
    if (!text) return { ok: false, error: 'Write a few words first' };
    if (text.length > 500) return { ok: false, error: 'Keep the note under 500 characters' };
    var now = new Date();
    var { error } = await db.from('quiet_notes').insert({
      from_user_id: fromId,
      to_user_id: toId,
      body: text,
      delivers_at: deliverAt(now)
    });
    if (error) return { ok: false, error: 'Could not leave the note just now' };
    return { ok: true, phrase: settlePhrase(now) };
  }

  async function oldestSettled(db, userId) {
    if (!db || !userId) return null;
    var { data, error } = await db.from('quiet_notes')
      .select('id, body, from_user_id, delivers_at')
      .eq('to_user_id', userId)
      .is('opened_at', null)
      .lte('delivers_at', new Date().toISOString())
      .order('delivers_at', { ascending: true })
      .limit(1);
    if (error || !data || !data.length) return null;
    var note = data[0];
    var name = 'someone';
    try {
      var profile = await db.from('profiles').select('username').eq('id', note.from_user_id).maybeSingle();
      if (profile.data && profile.data.username) name = profile.data.username;
    } catch (e) {}
    note.from_name = name;
    return note;
  }

  async function markOpened(db, noteId) {
    if (!db || !noteId) return false;
    var { error } = await db.rpc('open_quiet_note', { note_id: noteId });
    if (!error) tellParent();
    return !error;
  }

  async function chatUnlocked(db, me, them) {
    if (!db || !me || !them) return false;
    var existing = await db.from('messages')
      .select('id', { count: 'exact', head: true })
      .or('and(sender_id.eq.' + me + ',recipient_id.eq.' + them + '),and(sender_id.eq.' + them + ',recipient_id.eq.' + me + ')');
    if ((existing.count || 0) > 0) return true;
    var sent = await db.from('quiet_notes')
      .select('id', { count: 'exact', head: true })
      .eq('from_user_id', me)
      .eq('to_user_id', them);
    var received = await db.from('quiet_notes')
      .select('id', { count: 'exact', head: true })
      .eq('from_user_id', them)
      .eq('to_user_id', me);
    return (sent.count || 0) > 0 && (received.count || 0) > 0;
  }

  function ensureStyle() {
    if (document.getElementById('quiet-note-style')) return;
    var style = document.createElement('style');
    style.id = 'quiet-note-style';
    style.textContent = [
      '.qn-overlay{position:fixed;inset:0;z-index:10000;background:rgba(5,6,10,0.72);display:flex;align-items:flex-end;justify-content:center;padding:16px;}',
      '@media(min-width:720px){.qn-overlay{align-items:center;}}',
      '.qn-card{width:min(440px,100%);background:#14121c;color:#f0eeeb;border:1px solid rgba(196,161,255,0.28);border-radius:18px;padding:22px 20px 18px;box-shadow:0 20px 60px rgba(0,0,0,0.45);font-family:Inter,DM Sans,sans-serif;}',
      '.qn-card h3{margin:0 0 6px;font-family:Georgia,serif;font-weight:400;font-size:26px;}',
      '.qn-card p{margin:0 0 14px;color:#9ca3af;font-size:14px;line-height:1.5;}',
      '.qn-card textarea{width:100%;min-height:120px;resize:vertical;box-sizing:border-box;border-radius:12px;border:1px solid rgba(255,255,255,0.1);background:#0c0e14;color:#f0eeeb;padding:12px 14px;font:inherit;font-size:16px;}',
      '.qn-card .qn-body{white-space:pre-wrap;font-size:16px;line-height:1.6;margin:0 0 16px;}',
      '.qn-actions{display:flex;justify-content:flex-end;gap:8px;margin-top:12px;}',
      '.qn-actions button{border-radius:999px;padding:8px 14px;font:inherit;font-size:14px;cursor:pointer;}',
      '.qn-ghost{background:transparent;color:#c4a1ff;border:1px solid rgba(196,161,255,0.4);}',
      '.qn-solid{background:#c4a1ff;color:#14121c;border:none;font-weight:600;}'
    ].join('');
    document.head.appendChild(style);
  }

  function overlay(card) {
    ensureStyle();
    var rootEl = document.createElement('div');
    rootEl.className = 'qn-overlay';
    rootEl.appendChild(card);
    rootEl.addEventListener('click', function (event) {
      if (event.target === rootEl) rootEl.remove();
    });
    document.body.appendChild(rootEl);
    return rootEl;
  }

  function openComposer(options) {
    var toName = options.toName || 'them';
    var card = document.createElement('div');
    card.className = 'qn-card';
    var title = document.createElement('h3');
    title.textContent = 'A note for ' + toName;
    var help = document.createElement('p');
    help.textContent = 'It will settle in a few hours, or in the morning if the day is already late. They can answer when they want.';
    var field = document.createElement('textarea');
    field.maxLength = 500;
    field.placeholder = 'A few words is enough.';
    var actions = document.createElement('div');
    actions.className = 'qn-actions';
    var cancel = document.createElement('button');
    cancel.type = 'button';
    cancel.className = 'qn-ghost';
    cancel.textContent = 'Not yet';
    var save = document.createElement('button');
    save.type = 'button';
    save.className = 'qn-solid';
    save.textContent = 'Leave this note';
    actions.appendChild(cancel);
    actions.appendChild(save);
    card.appendChild(title);
    card.appendChild(help);
    card.appendChild(field);
    card.appendChild(actions);
    var layer = overlay(card);
    cancel.addEventListener('click', function () { layer.remove(); });
    save.addEventListener('click', async function () {
      save.disabled = true;
      var result = await send(options.db, options.fromId, options.toId, field.value);
      save.disabled = false;
      if (!result.ok) {
        help.textContent = result.error;
        return;
      }
      layer.remove();
      if (typeof options.onDone === 'function') options.onDone(result);
    });
    setTimeout(function () { field.focus(); }, 30);
  }

  function openReader(note, db, onOpened) {
    var card = document.createElement('div');
    card.className = 'qn-card';
    var title = document.createElement('h3');
    title.textContent = 'A note from ' + (note.from_name || 'someone');
    var body = document.createElement('p');
    body.className = 'qn-body';
    body.textContent = note.body || '';
    var actions = document.createElement('div');
    actions.className = 'qn-actions';
    var close = document.createElement('button');
    close.type = 'button';
    close.className = 'qn-solid';
    close.textContent = 'Keep it';
    actions.appendChild(close);
    card.appendChild(title);
    card.appendChild(body);
    card.appendChild(actions);
    var layer = overlay(card);
    close.addEventListener('click', function () { layer.remove(); });
    markOpened(db, note.id).then(function () {
      if (typeof onOpened === 'function') onOpened();
    });
  }

  return {
    deliverAt: deliverAt,
    settlePhrase: settlePhrase,
    send: send,
    oldestSettled: oldestSettled,
    markOpened: markOpened,
    chatUnlocked: chatUnlocked,
    openComposer: openComposer,
    openReader: openReader
  };
});
