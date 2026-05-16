const BASE = '';

/* ── UTILITIES ── */

function scrollTo(id) {
  document.getElementById(id).scrollIntoView({ behavior: 'smooth' });
}

function showResponse(elId, data, isError) {
  const el = document.getElementById(elId);
  el.textContent = JSON.stringify(data, null, 2);
  el.className = 'response-box visible ' + (isError ? 'error' : 'success');
}

/* ── TAB SWITCHING ── */

function switchTab(tab) {
  ['payment', 'lookup', 'patch'].forEach(t => {
    document.getElementById('tab-' + t).classList.toggle('active', t === tab);
    document.getElementById(t + '-tab').classList.toggle('active', t === tab);
  });
}

/* ── HEALTH CHECK ── */

async function checkHealth() {
  const dot      = document.getElementById('health-dot');
  const txt      = document.getElementById('health-text');
  const badgeTxt = document.getElementById('health-badge-text');

  txt.textContent = 'Checking…';

  try {
    const r  = await fetch(BASE + '/api/health');
    const d  = await r.json();
    const ok = d.api === 'ok' && d.database === 'ok';

    dot.className      = ok ? 'ok' : 'err';
    txt.textContent    = ok ? 'API + DB healthy' : 'Degraded: DB ' + d.database;
    badgeTxt.textContent = ok ? 'API ✓' : 'API ✗';
  } catch (e) {
    dot.className        = 'err';
    txt.textContent      = 'Unreachable';
    badgeTxt.textContent = 'API ✗';
  }
}

/* ── PAYMENT SUBMISSION ── */

async function submitPayment() {
  const pan         = document.getElementById('pan').value.trim();
  const amount      = parseFloat(document.getElementById('amount').value);
  const currency    = document.getElementById('currency').value;
  const merchant_id = document.getElementById('merchant-id').value.trim();
  const btn         = document.getElementById('pay-btn');

  if (!pan || !amount || !merchant_id) {
    showResponse('pay-response', { error: 'Fill all fields before submitting' }, true);
    return;
  }

  btn.disabled    = true;
  btn.textContent = 'Sending…';

  try {
    const r = await fetch(BASE + '/api/payment/', {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify({ pan, amount, currency, merchant_id }),
    });

    const d = await r.json();
    showResponse('pay-response', d, !r.ok);

    if (r.ok && d.token) {
      document.getElementById('lookup-token').value = d.token;
      document.getElementById('patch-token').value  = d.token;
    }
  } catch (e) {
    showResponse('pay-response', { error: 'Network error — is the API reachable?' }, true);
  }

  btn.disabled    = false;
  btn.textContent = 'Submit payment →';
}

/* ── TOKEN LOOKUP ── */

async function lookupTransaction() {
  const token = document.getElementById('lookup-token').value.trim();

  if (!token) {
    showResponse('lookup-response', { error: 'Token is required' }, true);
    return;
  }

  try {
    const r = await fetch(BASE + '/api/transactions/' + token);
    const d = await r.json();
    showResponse('lookup-response', d, !r.ok);
  } catch (e) {
    showResponse('lookup-response', { error: 'Network error' }, true);
  }
}

/* ── STATUS PATCH ── */

async function patchStatus() {
  const token  = document.getElementById('patch-token').value.trim();
  const status = document.getElementById('patch-status').value;

  if (!token) {
    showResponse('patch-response', { error: 'Token is required' }, true);
    return;
  }

  try {
    const r = await fetch(
      BASE + '/api/transactions/' + token + '/status?status=' + status,
      { method: 'PATCH' }
    );
    const d = await r.json();
    showResponse('patch-response', d, !r.ok);
  } catch (e) {
    showResponse('patch-response', { error: 'Network error' }, true);
  }
}

/* ── TRANSACTIONS TABLE ── */

let allTx = [];

async function loadTransactions() {
  const tbody = document.getElementById('tx-tbody');
  tbody.innerHTML = '<tr><td colspan="6" class="tx-empty">Loading…</td></tr>';

  try {
    const r = await fetch(BASE + '/api/transactions/?limit=50');
    const d = await r.json();
    allTx   = Array.isArray(d) ? d : [];
    renderTx(allTx);
  } catch (e) {
    tbody.innerHTML =
      '<tr><td colspan="6" class="tx-empty" style="color:#F87171">' +
      'Failed to reach /api/transactions/ — is the API running?</td></tr>';
  }
}

function renderTx(rows) {
  const tbody = document.getElementById('tx-tbody');

  if (!rows.length) {
    tbody.innerHTML = '<tr><td colspan="6" class="tx-empty">No transactions found</td></tr>';
    return;
  }

  tbody.innerHTML = rows.map(tx => `
    <tr>
      <td style="max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap"
          title="${tx.token}">${tx.token.substring(0, 16)}…</td>
      <td>${tx.merchant_id}</td>
      <td>${parseFloat(tx.amount).toLocaleString('en-NG', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      })}</td>
      <td>${tx.currency}</td>
      <td><span class="status-badge status-${tx.status}">${tx.status}</span></td>
      <td>${new Date(tx.created_at).toLocaleString()}</td>
    </tr>
  `).join('');
}

function filterTx() {
  const q = document.getElementById('tx-filter').value.toLowerCase();
  renderTx(
    allTx.filter(tx =>
      tx.token.includes(q) || tx.merchant_id.toLowerCase().includes(q)
    )
  );
}

/* ── INIT ── */
checkHealth();