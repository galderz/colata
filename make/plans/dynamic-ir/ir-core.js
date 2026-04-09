// ══════════════════════════════════════════════
//  C2 IR Core — pure functions (no DOM dependencies)
//  Shared by index.html and test.html
// ══════════════════════════════════════════════

// ── Node color classification ──
function nodeColorClass(type) {
  if (type === 'Root' || type === 'Start') return 'c-frame';
  if (type === 'Return' || type === 'Rethrow') return 'c-return';
  if (type === 'Parm' || type === 'Proj' || type === 'Phi' || type === 'PhiD' ||
      type.startsWith('Cast') || type.startsWith('CheckCast')) return 'c-proj';
  if (type.startsWith('Add') || type.startsWith('Sub') || type.startsWith('Mul') ||
      type.startsWith('Div') || type.startsWith('Mod') || type.startsWith('Neg') ||
      type.startsWith('LShift') || type.startsWith('RShift') || type.startsWith('URShift') ||
      type.startsWith('And') || type.startsWith('Or') || type.startsWith('Xor') ||
      type.startsWith('Abs') || type.startsWith('Conv') || type.startsWith('Sqrt') ||
      type.startsWith('Min') || type.startsWith('Max')) return 'c-arith';
  if (type.startsWith('Cmp') || type === 'Bool') return 'c-cmp';
  if (type.startsWith('Con')) return 'c-const';
  if (type.startsWith('Load') || type.startsWith('Store') || type.startsWith('MemBar')) return 'c-mem';
  if (type.startsWith('Call') || type.startsWith('Allocate')) return 'c-call';
  if (type === 'If' || type === 'IfTrue' || type === 'IfFalse' || type === 'Region' ||
      type === 'Loop' || type === 'CountedLoop' || type === 'CountedLoopEnd' ||
      type === 'Jump' || type === 'Halt' || type === 'SafePoint' || type === 'NeverBranch' ||
      type === 'RangeCheck' || type === 'Catch' || type === 'CatchProj') return 'c-control';
  return 'c-default';
}

// ── IR Parser ──
function parseIR(text) {
  const nodes = {};
  for (const rawLine of text.split('\n')) {
    const line = rawLine.trim();
    const m = line.match(/^(\d+)\s+(\w+)\s+===\s+(.*?)\s*\[\[\s*(.*?)\s*\]\]\s*(.*)?$/);
    if (!m) continue;
    const id = +m[1], type = m[2], extra = (m[5] || '').trim();

    // Parse inputs, tracking 'returns' position
    const inTokens = m[3].trim().split(/\s+/);
    const inputs = []; let returnValIdx = -1, afterReturns = false;
    for (const t of inTokens) {
      if (t === 'returns') { afterReturns = true; continue; }
      if (t === '_') { inputs.push(null); continue; } // placeholder
      if (/^\d+$/.test(t)) { if (afterReturns && returnValIdx < 0) returnValIdx = inputs.length; inputs.push(+t); }
    }
    const inputIds = inputs.filter(x => x !== null);

    const outputs = m[4].trim().split(/\s+/).filter(t => /^\d+$/.test(t)).map(Number);

    // Sublabel
    let sublabel = '';
    if (type === 'Parm') {
      const pm = extra.match(/^(Control|I_O|Memory|FramePtr|ReturnAdr)/);
      if (pm) sublabel = pm[1].replace('I_O', 'I/O');
      else { const pm2 = extra.match(/^Parm(\d+):\s*(\w+)/); if (pm2) sublabel = `Parm${pm2[1]} (${pm2[2]})`; }
    } else if (type.startsWith('Con')) {
      const cm = extra.match(/#(?:\w+:)?(-?[\d.]+|top)/); if (cm) sublabel = `#${cm[1]}`;
    }

    // Java line
    const jlm = extra.match(/\(line (\d+)\)/);
    const javaLine = jlm ? +jlm[1] : null;

    // Method name
    const mm = extra.match(/!jvms:\s*(\S+)/);
    const method = mm ? mm[1] : null;

    nodes[id] = { id, type, inputIds, inputs, outputs, extra, sublabel, javaLine, method, returnValIdx, line };
  }
  return nodes;
}

// ── Structural edge detection ──
function isStructural(fromId, toId, nodes) {
  if (fromId === toId) return true;
  const ft = nodes[fromId]?.type, tt = nodes[toId]?.type;
  if (ft === 'Root' && tt === 'Start') return true;
  if (ft === 'Start' && tt === 'Root') return true;
  if (ft === 'Root' && tt.startsWith('Con')) return true;
  return false;
}

// ── Edge builder ──
function buildEdges(nodes) {
  const edges = [], seen = new Set();
  for (const node of Object.values(nodes)) {
    for (const inId of node.inputIds) {
      if (inId === node.id) continue;
      if (!nodes[inId]) continue;
      const key = `${inId}->${node.id}`;
      if (seen.has(key)) continue;
      seen.add(key);
      edges.push({ from: inId, to: node.id, key, structural: isStructural(inId, node.id, nodes) });
    }
  }
  return edges;
}

// ── Topological sort by levels ──
function topoLevels(nodes, edges) {
  const ids = Object.keys(nodes).map(Number);
  const inDeg = {}, adj = {};
  for (const id of ids) { inDeg[id] = 0; adj[id] = []; }
  for (const e of edges) {
    if (e.structural) continue;
    adj[e.from].push(e.to);
    inDeg[e.to]++;
  }
  const levels = [];
  let q = ids.filter(id => inDeg[id] === 0);
  const visited = new Set();
  while (q.length > 0) {
    levels.push([...q]);
    q.forEach(id => visited.add(id));
    const nq = [];
    for (const id of q) {
      for (const nb of adj[id]) {
        inDeg[nb]--;
        if (inDeg[nb] === 0) nq.push(nb);
      }
    }
    q = nq;
  }
  // Nodes in cycles: add remaining
  const remaining = ids.filter(id => !visited.has(id));
  if (remaining.length) levels.push(remaining);
  return levels;
}

// ── Parameter detection ──
function detectParams(nodes) {
  const params = [];
  for (const n of Object.values(nodes)) {
    if (n.type !== 'Parm') continue;
    const m = n.extra.match(/^Parm(\d+):\s*(\w+)/);
    if (m) params.push({ nodeId: n.id, index: +m[1], type: m[2] });
  }
  params.sort((a, b) => a.index - b.index);
  return params;
}

// ── Value computation ──
function computeValue(node, dataInputValues, paramValues) {
  const t = node.type;
  if (t === 'Start') return '{...}';
  if (t === 'Root') return 'done';
  if (t === 'Parm') {
    const m = node.extra.match(/^Parm(\d+)/);
    if (m) return paramValues[+m[1]] ?? '?';
    if (node.extra.startsWith('Control')) return 'ctrl';
    if (node.extra.startsWith('I_O')) return 'io';
    if (node.extra.startsWith('Memory')) return 'mem';
    if (node.extra.startsWith('FramePtr')) return 'fp';
    if (node.extra.startsWith('ReturnAdr')) return 'ra';
    return node.sublabel || '?';
  }
  if (t.startsWith('Con')) {
    const m = node.extra.match(/#(?:\w+:)?(-?[\d.]+)/);
    return m ? +m[1] : node.sublabel || '#?';
  }
  if (t === 'Return') {
    // Last numeric input (the return value)
    const ri = node.returnValIdx >= 0 ? node.returnValIdx : node.inputIds.length - 1;
    const rv = dataInputValues[ri];
    return rv !== undefined ? `ret ${rv}` : 'ret ?';
  }

  // Arithmetic (binary)
  const nums = dataInputValues.filter(v => typeof v === 'number');
  if (nums.length >= 2) {
    switch (t) {
      case 'AddI': case 'AddL': return nums[0] + nums[1];
      case 'SubI': case 'SubL': return nums[0] - nums[1];
      case 'MulI': case 'MulL': return nums[0] * nums[1];
      case 'DivI': case 'DivL': return nums[1] ? Math.trunc(nums[0]/nums[1]) : '÷0';
      case 'ModI': case 'ModL': return nums[1] ? nums[0]%nums[1] : '%0';
      case 'LShiftI': case 'LShiftL': return nums[0] << nums[1];
      case 'RShiftI': case 'RShiftL': return nums[0] >> nums[1];
      case 'URShiftI': case 'URShiftL': return nums[0] >>> nums[1];
      case 'AndI': case 'AndL': return nums[0] & nums[1];
      case 'OrI': case 'OrL': return nums[0] | nums[1];
      case 'XorI': case 'XorL': return nums[0] ^ nums[1];
    }
  }
  if (nums.length >= 2 && t.startsWith('Cmp')) {
    const d = nums[0] - nums[1];
    return d < 0 ? '<' : d > 0 ? '>' : '=';
  }
  // Unary
  if (nums.length >= 1) {
    switch (t) {
      case 'NegI': case 'NegL': return -nums[0];
      case 'AbsI': case 'AbsL': return Math.abs(nums[0]);
      case 'ConvI2L': case 'ConvL2I': case 'CastII': case 'CastLL': return nums[0];
    }
  }
  // Pass-through for projections with single numeric input
  if (nums.length === 1 && (t === 'Proj' || t === 'Phi' || t.startsWith('CheckCast'))) return nums[0];
  return null;
}

// ── Execution step builder ──
function buildSteps(nodes, edges, levels, paramValues) {
  const steps = [];
  const completedNodes = new Set(), completedEdges = new Set();
  const nodeValues = {};

  // Step 0: initial
  steps.push({ name: 'Initial', desc: 'Graph structure. Press \u2192 to begin execution.', activeNodes: [], activeEdges: [], completedNodes: new Set(), completedEdges: new Set(), values: {} });

  for (const level of levels) {
    // Compute values for this level
    const activeEdges = new Set();
    for (const id of level) {
      const node = nodes[id];
      // Gather input values in order of node.inputs (the original input list, including nulls for '_')
      const inputVals = node.inputs.map(inId => {
        if (inId === null) return undefined;
        return nodeValues[inId];
      });

      const val = computeValue(node, inputVals, paramValues);
      if (val !== null && val !== undefined) nodeValues[id] = val;

      // Active edges: data edges coming into this node
      for (const e of edges) {
        if (e.to === id && !e.structural) activeEdges.add(e.key);
      }
    }

    const levelName = level.length === 1 ? `${nodes[level[0]].type} #${level[0]}` :
      level.length <= 4 ? level.map(id => `${nodes[id].type}#${id}`).join(', ') :
      `${nodes[level[0]].type} \u00d7${level.length}`;

    const levelDesc = level.map(id => {
      const n = nodes[id];
      const v = nodeValues[id];
      return v !== null && v !== undefined ? `#${id} ${n.type} = ${v}` : `#${id} ${n.type}`;
    }).join(' | ');

    steps.push({
      name: levelName,
      desc: levelDesc,
      activeNodes: [...level],
      activeEdges: activeEdges,
      completedNodes: new Set(completedNodes),
      completedEdges: new Set(completedEdges),
      values: { ...nodeValues },
      javaLines: level.map(id => nodes[id].javaLine).filter(Boolean)
    });

    level.forEach(id => completedNodes.add(id));
    activeEdges.forEach(k => completedEdges.add(k));
    // Also add edges between completed nodes
    for (const e of edges) {
      if (!e.structural && completedNodes.has(e.from) && completedNodes.has(e.to)) completedEdges.add(e.key);
    }
  }
  return steps;
}

// ── Graph bounds ──
function calcBounds(positions) {
  let x1=Infinity, y1=Infinity, x2=-Infinity, y2=-Infinity;
  for (const p of Object.values(positions)) {
    x1 = Math.min(x1, p.x - p.w/2); y1 = Math.min(y1, p.y - p.h/2);
    x2 = Math.max(x2, p.x + p.w/2); y2 = Math.max(y2, p.y + p.h/2);
  }
  const pad = 50;
  return { x: x1-pad, y: y1-pad, w: x2-x1+pad*2, h: y2-y1+pad*2+20 };
}

// ── SVG path helper ──
function pointsToPath(pts) {
  if (!pts || pts.length < 2) return '';
  if (pts.length === 2) return `M${pts[0].x} ${pts[0].y} L${pts[1].x} ${pts[1].y}`;
  // Smooth curve through points
  let d = `M${pts[0].x} ${pts[0].y}`;
  if (pts.length === 3) {
    d += ` Q${pts[1].x} ${pts[1].y} ${pts[2].x} ${pts[2].y}`;
  } else {
    for (let i = 1; i < pts.length; i++) d += ` L${pts[i].x} ${pts[i].y}`;
  }
  return d;
}

// ── Exception path classification ──
function classifyExceptionNodes(nodes, edges) {
  // Backward walk from a set of seed node IDs through data edges.
  // Skips walking through Root/Start since they are structural framework nodes
  // that connect to both happy and exception exit paths.
  function backwardReachable(seedIds) {
    const reached = new Set();
    const stack = [...seedIds];
    while (stack.length > 0) {
      const id = stack.pop();
      if (reached.has(id)) continue;
      reached.add(id);
      const node = nodes[id];
      if (!node) continue;
      if (node.type === 'Root' || node.type === 'Start') continue;
      for (const inId of node.inputIds) {
        if (inId === id) continue; // skip self-loop
        if (!nodes[inId]) continue;
        if (!reached.has(inId)) stack.push(inId);
      }
    }
    return reached;
  }

  const returnIds = Object.values(nodes).filter(n => n.type === 'Return').map(n => n.id);
  const rethrowIds = Object.values(nodes).filter(n => n.type === 'Rethrow').map(n => n.id);

  if (rethrowIds.length === 0) return new Set();

  const happyPath = backwardReachable(returnIds);
  const exceptionPath = backwardReachable(rethrowIds);

  const exceptionOnly = new Set();
  for (const id of exceptionPath) {
    if (!happyPath.has(id)) exceptionOnly.add(id);
  }
  return exceptionOnly;
}

// ── Level filtering ──
function filterLevels(levels, excludeIds) {
  if (!excludeIds || excludeIds.size === 0) return levels;
  const result = [];
  for (const level of levels) {
    const filtered = level.filter(id => !excludeIds.has(id));
    if (filtered.length > 0) result.push(filtered);
  }
  return result;
}

// ── HTML escaping ──
function escapeHtml(s) {
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

// ── Theme ──
function setTheme(theme, onAfterSet) {
  document.documentElement.setAttribute('data-theme', theme);
  const btn = document.getElementById('theme-toggle');
  if (btn) btn.textContent = theme === 'dark' ? '\u263E' : '\u2600';
  try { localStorage.setItem('c2ir-theme', theme); } catch {}
  if (onAfterSet) onAfterSet(theme);
}

function initTheme(onAfterSet) {
  const saved = (() => { try { return localStorage.getItem('c2ir-theme'); } catch { return null; } })();
  setTheme(saved || 'dark', onAfterSet);
  const btn = document.getElementById('theme-toggle');
  if (btn) {
    btn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme') || 'dark';
      setTheme(current === 'dark' ? 'light' : 'dark', onAfterSet);
    });
  }
}
