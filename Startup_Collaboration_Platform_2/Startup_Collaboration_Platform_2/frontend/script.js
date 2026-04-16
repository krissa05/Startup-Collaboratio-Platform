// ============================================================
//   STARTUP COLLABORATION PLATFORM — Global JS Utilities
//   File: script.js
// ============================================================

const API = 'http://127.0.0.1:5000/api';

// Auth helpers
function getUserId()  { return localStorage.getItem('user_id'); }
function getUserRole(){ return localStorage.getItem('role'); }
function requireAuth(){ if (!getUserId()) window.location.href = 'index.html'; }
function logout()     { localStorage.clear(); window.location.href = 'index.html'; }

// Alert helper
function showAlert(containerId, msg, type) {
  const el = document.getElementById(containerId);
  if (!el) return;
  el.textContent = msg;
  el.className   = `alert alert-${type} show`;
  setTimeout(() => el.className = 'alert', 3500);
}

// API helper
async function apiFetch(endpoint, options = {}) {
  const defaults = {
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include'
  };
  const config = { ...defaults, ...options, headers: { ...defaults.headers, ...(options.headers || {}) } };
  const res  = await fetch(`${API}${endpoint}`, config);
  return res.json();
}

// Format date
function formatDate(dateStr) {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString('en-IN', { day:'numeric', month:'short', year:'numeric' });
}

// Domain badge color
function domainBadge(domain) {
  return `<span class="badge badge-purple">${domain || 'Other'}</span>`;
}

// Skills as tags
function skillTags(skillStr) {
  if (!skillStr) return '';
  return (skillStr).split(',').map(s => `<span class="tag">${s.trim()}</span>`).join('');
}

// Progress bar HTML
function progressBar(pct) {
  return `<div class="progress-bar"><div class="progress-fill" style="width:${pct}%"></div></div>`;
}