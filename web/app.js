/* global GetParentResourceName */
const app = document.getElementById('app');
const statusLine = document.getElementById('statusLine');
const pointsPill = document.getElementById('pointsPill');
const nodesEl = document.getElementById('nodes');
const linesEl = document.getElementById('lines');
const closeBtn = document.getElementById('closeBtn');
const confirmBtn = document.getElementById('confirmBtn');
const talentsTab = document.getElementById('talentsTab');
const adminTab = document.getElementById('adminTab');
const talentsView = document.getElementById('talentsView');
const adminPanel = document.getElementById('adminPanel');
const adminCloseBtn = document.getElementById('adminCloseBtn');
const adminPlayersEl = document.getElementById('adminPlayers');
const adminTargetEl = document.getElementById('adminTarget');
const adminSummary = document.getElementById('adminSummary');
const adminAddXpBtn = document.getElementById('adminAddXpBtn');
const adminSetXpBtn = document.getElementById('adminSetXpBtn');
const adminSetLevelBtn = document.getElementById('adminSetLevelBtn');
const adminXpInput = document.getElementById('adminXpInput');
const adminLevelInput = document.getElementById('adminLevelInput');
const adminResetTalentsBtn = document.getElementById('adminResetTalentsBtn');
const adminGiveAllTalentsBtn = document.getElementById('adminGiveAllTalentsBtn');
const adminResetAllBtn = document.getElementById('adminResetAllBtn');
const adminSpawnAnimalsBtn = document.getElementById('adminSpawnAnimalsBtn');
const adminClearAnimalsBtn = document.getElementById('adminClearAnimalsBtn');
const adminResetZoneBtn = document.getElementById('adminResetZoneBtn');

let state = {
  open: false,
  level: 1,
  xp: 0,
  nextXp: -1,
  talentPoints: { available: 0, earned: 0, spent: 0 },
  talents: {},
  defs: [],
  isAdmin: false,
  adminPlayers: [],
};

let pending = new Map();
let activeView = 'talents';
let selectedAdminPlayerId = null;

const GRID = {
  colWidth: 275,
  rowHeight: 148,
  offsetX: 54,
  offsetY: 38,
  nodeWidth: 230,
  nodeHeight: 92,
};

function setOpen(open) {
  state.open = open;
  if (open) app.classList.remove('hidden');
  else app.classList.add('hidden');
}

function postNui(eventName, payload) {
  const resource = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'xrb-hunting';
  return fetch(`https://${resource}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload || {}),
  }).catch(() => {});
}

function formatStatus() {
  const lvl = state.level ?? 1;
  const xp = state.xp ?? 0;
  const nextXp = state.nextXp ?? -1;
  if (typeof nextXp === 'number' && nextXp >= 0) {
    return `Level ${lvl} | XP ${xp} | Next in ${Math.max(nextXp - xp, 0)}`;
  }
  return `Level ${lvl} | XP ${xp} | Max level`;
}

function getRank(id) {
  return Number(state.talents?.[id] || 0);
}

function getPendingRank(id) {
  return getRank(id) + Number(pending.get(id) || 0);
}

function availablePoints() {
  return Number(state.talentPoints?.available || 0);
}

function pendingCount() {
  let count = 0;
  for (const value of pending.values()) count += Number(value || 0);
  return count;
}

function meetsReqs(def) {
  const reqs = def.requires || [];
  for (const req of reqs) {
    if (getPendingRank(req.id) < Number(req.rank || 1)) return false;
  }
  return true;
}

function canQueue(def) {
  if (!def?.id) return false;
  if (getPendingRank(def.id) >= Number(def.maxRank || 1)) return false;
  if (!meetsReqs(def)) return false;
  if (pendingCount() >= availablePoints()) return false;
  return true;
}

function setPending(id, on) {
  if (!id) return;
  if (on) pending.set(id, 1);
  else pending.delete(id);
}

function resetPending() {
  pending = new Map();
}

function getSelectedAdminPlayer() {
  return (state.adminPlayers || []).find((player) => Number(player.id) === Number(selectedAdminPlayerId)) || null;
}

function getInputNumber(input, fallbackValue, min = 0) {
  const value = Number(input?.value);
  if (!Number.isFinite(value) || value < min) {
    return Number(fallbackValue ?? min);
  }
  return value;
}

function ensureSelectedAdminPlayer() {
  const players = state.adminPlayers || [];
  if (players.length === 0) {
    selectedAdminPlayerId = null;
    return;
  }
  if (!players.some((player) => Number(player.id) === Number(selectedAdminPlayerId))) {
    selectedAdminPlayerId = players[0].id;
  }
}

function setActiveView(view) {
  const canOpenAdmin = state.isAdmin === true;
  activeView = view === 'admin' && canOpenAdmin ? 'admin' : 'talents';
}

function openAdminView() {
  if (state.isAdmin !== true) return;
  setActiveView('admin');
  postNui('openAdminMenu', {});
  renderAll();
}

function updateTopbar() {
  const available = availablePoints();
  const queued = pendingCount();
  pointsPill.textContent = queued > 0 ? `Points: ${available} | Selected: ${queued}` : `Points: ${available}`;
  confirmBtn.disabled = queued <= 0;
  confirmBtn.textContent = queued > 0 ? `Confirm (${queued})` : 'Confirm';
}

function buildConfirmOrder() {
  const defsById = new Map(state.defs.map((def) => [def.id, def]));
  const ids = Array.from(pending.keys());
  const ordered = [];
  const remaining = new Set(ids);
  const simulated = new Map();

  const simRank = (id) => getRank(id) + Number(simulated.get(id) || 0);
  const simMeetsReqs = (def) => {
    const reqs = def.requires || [];
    for (const req of reqs) {
      if (simRank(req.id) < Number(req.rank || 1)) return false;
    }
    return true;
  };

  let progressed = true;
  while (remaining.size > 0 && progressed) {
    progressed = false;
    for (const id of Array.from(remaining)) {
      const def = defsById.get(id);
      if (!def) {
        remaining.delete(id);
        continue;
      }
      if (!simMeetsReqs(def)) continue;
      ordered.push(id);
      simulated.set(id, (simulated.get(id) || 0) + 1);
      remaining.delete(id);
      progressed = true;
    }
  }

  for (const id of remaining) ordered.push(id);
  return ordered;
}

function nodePos(def) {
  return {
    left: GRID.offsetX + (Number(def.ui?.col || 1) - 1) * GRID.colWidth,
    top: GRID.offsetY + (Number(def.ui?.row || 1) - 1) * GRID.rowHeight,
  };
}

function nodeAnchor(def, side) {
  const pos = nodePos(def);
  const midX = pos.left + GRID.nodeWidth / 2;
  const midY = pos.top + GRID.nodeHeight / 2;
  if (side === 'top') return { x: midX, y: pos.top };
  if (side === 'bottom') return { x: midX, y: pos.top + GRID.nodeHeight };
  if (side === 'left') return { x: pos.left, y: midY };
  if (side === 'right') return { x: pos.left + GRID.nodeWidth, y: midY };
  return { x: midX, y: midY };
}

function linkSides(parent, child) {
  const aPos = nodePos(parent);
  const bPos = nodePos(child);
  const dy = bPos.top - aPos.top;
  const dx = bPos.left - aPos.left;
  if (Math.abs(dy) >= Math.abs(dx)) return dy >= 0 ? { a: 'bottom', b: 'top' } : { a: 'top', b: 'bottom' };
  return dx >= 0 ? { a: 'right', b: 'left' } : { a: 'left', b: 'right' };
}

function renderLines() {
  while (linesEl.firstChild) linesEl.removeChild(linesEl.firstChild);
  const defsById = new Map(state.defs.map((def) => [def.id, def]));
  const svgNS = 'http://www.w3.org/2000/svg';
  linesEl.setAttribute('viewBox', `0 0 ${nodesEl.scrollWidth} ${nodesEl.scrollHeight}`);

  for (const def of state.defs) {
    for (const req of def.requires || []) {
      const parent = defsById.get(req.id);
      if (!parent) continue;
      const sides = linkSides(parent, def);
      const a = nodeAnchor(parent, sides.a);
      const b = nodeAnchor(def, sides.b);
      const path = document.createElementNS(svgNS, 'path');
      let d = '';
      if (sides.a === 'bottom' || sides.a === 'top') {
        const midY = (a.y + b.y) / 2;
        d = `M ${a.x} ${a.y} C ${a.x} ${midY}, ${b.x} ${midY}, ${b.x} ${b.y}`;
      } else {
        const midX = (a.x + b.x) / 2;
        d = `M ${a.x} ${a.y} C ${midX} ${a.y}, ${midX} ${b.y}, ${b.x} ${b.y}`;
      }

      const glow = document.createElementNS(svgNS, 'path');
      glow.setAttribute('d', d);
      glow.setAttribute('class', 'lineGlow');
      linesEl.appendChild(glow);

      path.setAttribute('d', d);
      path.setAttribute('class', `linePath ${(meetsReqs(def) || getRank(def.id) > 0) ? 'unlocked' : 'locked'}`);
      linesEl.appendChild(path);
    }
  }
}

function fitCanvas() {
  let maxCol = 1;
  let maxRow = 1;
  for (const def of state.defs) {
    maxCol = Math.max(maxCol, Number(def.ui?.col || 1));
    maxRow = Math.max(maxRow, Number(def.ui?.row || 1));
  }
  const width = GRID.offsetX + (maxCol - 1) * GRID.colWidth + GRID.nodeWidth + 34;
  const height = GRID.offsetY + (maxRow - 1) * GRID.rowHeight + GRID.nodeHeight + 34;
  nodesEl.style.minWidth = `${Math.max(width, 980)}px`;
  nodesEl.style.minHeight = `${Math.max(height, 540)}px`;
}

function renderNodes() {
  for (const el of nodesEl.querySelectorAll('.node')) el.remove();

  for (const def of state.defs) {
    const baseRank = getRank(def.id);
    const queued = Number(pending.get(def.id) || 0);
    const rank = baseRank + queued;
    const maxRank = Number(def.maxRank || 1);
    const unlocked = rank > 0 || meetsReqs(def);
    const maxed = rank >= maxRank;
    const canBuy = meetsReqs(def) && !maxed && availablePoints() > pendingCount();

    const el = document.createElement('div');
    el.className = 'node';
    if (!unlocked) el.classList.add('locked');
    if (maxed) el.classList.add('maxed');
    if (canBuy) el.classList.add('available');
    if (queued > 0) el.classList.add('selected');

    const pos = nodePos(def);
    el.style.left = `${pos.left}px`;
    el.style.top = `${pos.top}px`;

    const header = document.createElement('div');
    header.className = 'nodeHeader';
    const iconWrap = document.createElement('div');
    iconWrap.className = 'nodeIconWrap';
    const img = document.createElement('img');
    img.className = 'nodeIcon';
    img.alt = '';
    img.draggable = false;
    img.src = def.icon;
    iconWrap.appendChild(img);

    const text = document.createElement('div');
    text.className = 'nodeText';
    const title = document.createElement('div');
    title.className = 'nodeTitle';
    title.textContent = def.name || def.id;
    const desc = document.createElement('div');
    desc.className = 'nodeDesc';
    desc.textContent = def.description || '';
    text.appendChild(title);
    text.appendChild(desc);
    header.appendChild(iconWrap);
    header.appendChild(text);

    const meta = document.createElement('div');
    meta.className = 'nodeMeta';
    const left = document.createElement('div');
    left.textContent = `${rank}/${maxRank}`;
    const right = document.createElement('div');
    right.className = 'badge';
    if (!unlocked) right.textContent = 'Locked';
    else if (maxed) right.textContent = 'Max';
    else if (queued > 0) right.textContent = 'Selected';
    else if (canBuy) right.textContent = 'Select';
    else right.textContent = 'No points';
    meta.appendChild(left);
    meta.appendChild(right);

    el.appendChild(header);
    el.appendChild(meta);
    el.addEventListener('click', () => {
      if (!def.id) return;
      if (pending.get(def.id)) {
        setPending(def.id, false);
        renderAll();
        return;
      }
      if (!canQueue(def)) return;
      setPending(def.id, true);
      renderAll();
    });

    nodesEl.appendChild(el);
  }
}

function renderAdminPanel() {
  const isAdmin = state.isAdmin === true;
  if (!isAdmin) {
    setActiveView('talents');
  }

  adminTab.hidden = !isAdmin;
  adminTab.classList.toggle('active', isAdmin && activeView === 'admin');
  talentsTab.classList.toggle('active', activeView === 'talents');
  talentsView.classList.toggle('hidden', activeView !== 'talents');
  adminPanel.classList.toggle('hidden', !(isAdmin && activeView === 'admin'));

  if (!isAdmin) {
    return;
  }

  ensureSelectedAdminPlayer();
  const players = state.adminPlayers || [];
  adminSummary.textContent = players.length > 0 ? `${players.length} player(s) online` : 'No players online';

  adminPlayersEl.innerHTML = '';
  if (players.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'adminPlayer';
    empty.innerHTML = '<div class="adminPlayerName">No players online</div>';
    adminPlayersEl.appendChild(empty);
  } else {
    for (const player of players) {
      const el = document.createElement('button');
      el.type = 'button';
      el.className = 'adminPlayer';
      if (Number(player.id) === Number(selectedAdminPlayerId)) el.classList.add('active');
      el.innerHTML = `
        <div class="adminPlayerName">${player.name} (${player.id})</div>
        <div class="adminPlayerMeta">Level ${player.level} | XP ${player.xp} | Points ${player.availableTalentPoints || 0}</div>
      `;
      el.addEventListener('click', () => {
        selectedAdminPlayerId = player.id;
        renderAdminPanel();
      });
      adminPlayersEl.appendChild(el);
    }
  }

  const selected = getSelectedAdminPlayer();
  adminTargetEl.textContent = selected
    ? `Selected: ${selected.name} (${selected.id}) | Level ${selected.level} | XP ${selected.xp}`
    : 'No player selected';

  if (selected) {
    if (document.activeElement !== adminXpInput) {
      adminXpInput.value = String(selected.xp ?? 0);
    }
    if (document.activeElement !== adminLevelInput) {
      adminLevelInput.value = String(selected.level ?? 1);
    }
  }

  const hasSelected = !!selected;
  [adminAddXpBtn, adminSetXpBtn, adminSetLevelBtn, adminResetTalentsBtn, adminGiveAllTalentsBtn, adminResetAllBtn]
    .forEach((btn) => { btn.disabled = !hasSelected; });
}

function renderAll() {
  statusLine.textContent = formatStatus();
  updateTopbar();
  fitCanvas();
  renderNodes();
  renderLines();
  renderAdminPanel();
}

function close() {
  setOpen(false);
  resetPending();
  postNui('close', {});
}

window.addEventListener('message', (event) => {
  const msg = event.data || {};
  if (msg.action === 'open') {
    state = { ...state, ...msg.data, open: true };
    resetPending();
    setActiveView('talents');
    setOpen(true);
    renderAll();
  } else if (msg.action === 'update') {
    state = { ...state, ...msg.data };
    if (state.open) renderAll();
  } else if (msg.action === 'adminData') {
    state = { ...state, adminPlayers: msg.data?.players || [] };
    if (state.open) renderAll();
  } else if (msg.action === 'close') {
    close();
  }
});

document.addEventListener('keydown', (e) => {
  if (state.open && e.key === 'Escape') close();
});

document.addEventListener('click', (e) => {
  const action = e.target?.getAttribute?.('data-action');
  if (action === 'close') close();
});

closeBtn.addEventListener('click', close);

adminCloseBtn.addEventListener('click', () => {
  setActiveView('talents');
  renderAll();
});

talentsTab.addEventListener('click', () => {
  setActiveView('talents');
  renderAll();
});

adminTab.addEventListener('click', () => {
  openAdminView();
});

function sendAdminPlayerAction(action, value) {
  const selected = getSelectedAdminPlayer();
  if (!selected) return;
  postNui('adminApplyAction', { targetId: selected.id, action, value });
}

adminAddXpBtn.addEventListener('click', () => {
  const value = getInputNumber(adminXpInput, 100, 1);
  sendAdminPlayerAction('add_xp', value);
});

adminSetXpBtn.addEventListener('click', () => {
  const selected = getSelectedAdminPlayer();
  const value = getInputNumber(adminXpInput, selected?.xp ?? 0, 0);
  sendAdminPlayerAction('set_xp', value);
});

adminSetLevelBtn.addEventListener('click', () => {
  const selected = getSelectedAdminPlayer();
  const value = getInputNumber(adminLevelInput, selected?.level ?? 1, 1);
  sendAdminPlayerAction('set_level', value);
});

adminResetTalentsBtn.addEventListener('click', () => sendAdminPlayerAction('reset_talents', 0));
adminGiveAllTalentsBtn.addEventListener('click', () => sendAdminPlayerAction('give_all_talents', 0));
adminResetAllBtn.addEventListener('click', () => sendAdminPlayerAction('reset_all', 0));

adminSpawnAnimalsBtn.addEventListener('click', () => postNui('adminZoneAction', { action: 'spawn_animals' }));
adminClearAnimalsBtn.addEventListener('click', () => postNui('adminZoneAction', { action: 'clear_animals' }));
adminResetZoneBtn.addEventListener('click', () => postNui('adminZoneAction', { action: 'reset_zone' }));

confirmBtn.addEventListener('click', () => {
  if (!state.open || pendingCount() <= 0) return;
  const ids = buildConfirmOrder();
  confirmBtn.disabled = true;
  postNui('confirmTalents', { ids }).finally(() => {
    resetPending();
    renderAll();
  });
});
