const els = {
    code: document.getElementById('code'),
    port: document.getElementById('port'),
    send: document.getElementById('send'),
    save: document.getElementById('save'),
    status: document.getElementById('status'),
    listener: document.getElementById('listener'),
};

// The standup's listener (Connect-XdrByBrowserExtension) takes the first free port in this range
// and binds to 127.0.0.1 (older standups bound "+" or "localhost"). Both hosts are tried.
const DEFAULT_PORTS = Array.from({ length: 10 }, (_, i) => 8787 + i);
const HOSTS = ['127.0.0.1', 'localhost'];
const PAIRING_CODE = /^[0-9a-f]{12}$/;

const NOTHING_LISTENING = 'Nothing on this computer is waiting for a relay. ' +
    'Run ./tools/agent/Start-XdrWorkbench.ps1 in PowerShell 7 on this computer, keep that window open, and relay within 5 minutes of the code appearing. ' +
    'If the standup is waiting, open the health URL it prints (http://127.0.0.1:<port>/health) in a Chrome tab: if that shows xdr-workbench-relay, Chrome is blocking the extension, otherwise the listener is not answering. ' +
    'If Claude runs in the cloud (claude.ai/code or the Claude app without a connected computer), a relay can never reach it: use Claude Code on this computer.';

// Turns a failed probe into a short reason, so "nothing is waiting" says what actually happened.
function probeError(err) {
    if (err && err.name === 'AbortError') { return 'no answer within 2.5 s'; }
    const msg = err && err.message ? err.message : String(err);
    return msg === 'Failed to fetch' ? 'connection refused or blocked (Failed to fetch)' : msg;
}

function portList(ports) {
    const sorted = [...ports].sort((a, b) => a - b);
    const contiguous = sorted.every((p, i) => i === 0 || p === sorted[i - 1] + 1);
    return contiguous && sorted.length > 2 ? `${sorted[0]}-${sorted[sorted.length - 1]}` : sorted.join(', ');
}

// "127.0.0.1: connection refused or blocked (Failed to fetch) on 8787-8796; localhost: ..."
function summarizeErrors(errors) {
    const groups = new Map();
    for (const e of errors) {
        const key = `${e.host}\u0000${e.reason}`;
        if (!groups.has(key)) { groups.set(key, { host: e.host, reason: e.reason, ports: [] }); }
        groups.get(key).ports.push(e.port);
    }
    return [...groups.values()].map((g) => `${g.host}: ${g.reason} on ${portList(g.ports)}`).join('; ');
}

function manualPort() {
    const value = parseInt(els.port.value, 10);
    return Number.isInteger(value) && value >= 1024 && value <= 65535 ? value : null;
}

async function fetchWithTimeout(url, options = {}, ms = 2500) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), ms);
    try {
        return await fetch(url, { ...options, signal: controller.signal });
    } finally {
        clearTimeout(timer);
    }
}

// Finds every waiting standup listener. Only endpoints whose /health identifies the Workbench relay
// count, so the session is never posted to an unrelated local service on one of these ports. A port
// typed into the popup is also accepted when it answers at all, for listeners older than /health.
async function findListeners() {
    const typed = manualPort();
    const ports = typed ? [typed] : DEFAULT_PORTS;
    const probes = [];
    const errors = [];
    for (const port of ports) {
        for (const host of HOSTS) {
            probes.push((async () => {
                const url = `http://${host}:${port}/health`;
                try {
                    const res = await fetchWithTimeout(url);
                    if (res.ok) {
                        const body = await res.json().catch(() => null);
                        if (body && body.service === 'xdr-workbench-relay') {
                            return { host, port, secondsLeft: body.secondsLeft, legacy: false };
                        }
                    }
                    if (typed && res.status === 404) {
                        return { host, port, secondsLeft: null, legacy: true };
                    }
                    errors.push({ host, port, reason: res.ok ? 'answered, but not the Workbench relay' : `HTTP ${res.status}` });
                } catch (err) {
                    errors.push({ host, port, reason: probeError(err) });
                    console.debug(`Relay probe ${url} failed:`, err);
                }
                return null;
            })());
        }
    }
    // A waiting standup answers within milliseconds, but on Windows a closed port takes about
    // 2 s to refuse (and localhost tries ::1 first). So don't wait for every refusal: once one
    // standup has answered, give any others a moment to answer too, then stop looking.
    const found = [];
    await new Promise((resolve) => {
        let remaining = probes.length;
        let grace = null;
        for (const probe of probes) {
            probe.then((listener) => {
                if (listener) {
                    found.push(listener);
                    if (!grace) { grace = setTimeout(resolve, 200); }
                }
                if (--remaining === 0) { resolve(); }
            });
        }
    });
    // One entry per port: the same listener can answer on both hosts.
    const byPort = new Map();
    for (const l of found) {
        if (!byPort.has(l.port)) { byPort.set(l.port, l); }
    }
    return { listeners: [...byPort.values()], errors };
}

// A single probe round can miss a standup that is busy with another request, so try a few
// times before telling the analyst nothing is waiting.
async function findListenersWithRetry(attempts = 3, delayMs = 700) {
    let result = await findListeners();
    for (let i = 1; i < attempts && !result.listeners.length; i++) {
        await new Promise((resolve) => setTimeout(resolve, delayMs));
        result = await findListeners();
    }
    return result;
}

// Set after a relay is accepted: the standup stops listening then, which is expected.
let relayedToPort = null;

function describeListeners({ listeners, errors }) {
    if (!listeners.length && relayedToPort !== null) {
        return { ok: true, text: `Relayed to port ${relayedToPort}. The standup has stopped listening, as expected; carry on in PowerShell.` };
    }
    if (!listeners.length) {
        const detail = errors.length ? ` Checked: ${summarizeErrors(errors)}.` : '';
        return { ok: false, text: `No standup is waiting on this computer. Run Start-XdrWorkbench.ps1 in PowerShell 7 here first.${detail}` };
    }
    const parts = listeners.map((l) => {
        if (l.secondsLeft === null || l.secondsLeft === undefined) { return `port ${l.port}`; }
        const m = Math.floor(l.secondsLeft / 60);
        const sec = String(l.secondsLeft % 60).padStart(2, '0');
        return `port ${l.port} (${m}:${sec} left)`;
    });
    return { ok: true, text: `Standup waiting on ${parts.join(', ')}.` };
}

let refreshing = false;
async function refreshListenerState() {
    if (refreshing) { return; }
    refreshing = true;
    try {
        const state = describeListeners(await findListeners());
        els.listener.textContent = state.text;
        els.listener.className = state.ok ? 'listener ok' : 'listener none';
    } finally {
        refreshing = false;
    }
}

chrome.storage.local.get(['xdrRelayPort'], (data) => {
    // Only a port the analyst set by hand is remembered; blank means "find it".
    if (data.xdrRelayPort && data.xdrRelayPort !== 8787) {
        els.port.value = data.xdrRelayPort;
    }
    // Chrome only shows the popup once its page has loaded and painted. Starting 20 port probes
    // during that kept the toolbar icon lit for seconds before the popup appeared, so the probes
    // wait until the popup is on screen.
    const start = () => setTimeout(() => {
        refreshListenerState();
        setInterval(refreshListenerState, 3000);
    }, 100);
    if (document.readyState === 'complete') { start(); } else { window.addEventListener('load', start, { once: true }); }
});

// Two credentials matter, in priority order:
//   1. sccauth (+ XSRF-TOKEN) on security.microsoft.com - the Defender portal session
//      cookie, minted after sign-in already passed. Replayed directly, so it does NOT
//      re-run Entra's silent SSO and does NOT hit error 50058.
//      The multi-tenant portal (mto.security.microsoft.com) keeps its own sign-in. When that
//      tab has been opened in the same window, its sccauth/XSRF-TOKEN are relayed as well, so
//      MTO hunting doesn't answer "440 Session timeout". Optional: absent means not signed in there.
//   2. ESTSAUTH on login.microsoftonline.com - only a bootstrap; the container has to
//      re-exchange it via silent SSO, which frequently fails with "session information
//      is not sufficient for single-sign-on". Kept as a fallback.
//
// chrome.cookies.get() without a storeId only looks in the calling context's own cookie
// store, which depends on exactly which window (regular vs. Incognito) this popup happened
// to be opened from. That's fragile, so search every store Chrome grants access to (the
// Incognito store only appears once "Allow in Incognito" is enabled for this extension).
async function gatherSessionCandidates() {
    const stores = await chrome.cookies.getAllCookieStores();
    const candidates = [];
    // The store of the window this popup was opened from. Each store lists its tab IDs.
    let currentTabId = null;
    try {
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        currentTabId = tab ? tab.id : null;
    } catch (err) {
        currentTabId = null;
    }

    for (const store of stores) {
        const read = async (url, name) => {
            try {
                const cookie = await chrome.cookies.get({ url, name, storeId: store.id });
                return cookie && cookie.value ? cookie.value : null;
            } catch (err) {
                return null;
            }
        };

        const candidate = {
            storeId: store.id,
            fromThisWindow: currentTabId !== null && (store.tabIds || []).includes(currentTabId),
            // Chrome's regular profile store is "0"; Incognito stores have other IDs.
            incognito: store.id !== '0',
            sccAuthCookieValue: await read('https://security.microsoft.com', 'sccauth'),
            xsrfToken: await read('https://security.microsoft.com', 'XSRF-TOKEN'),
            estsAuthCookieValue: await read('https://login.microsoftonline.com', 'ESTSAUTH'),
            mtoSccAuthCookieValue: await read('https://mto.security.microsoft.com', 'sccauth'),
            mtoXsrfToken: await read('https://mto.security.microsoft.com', 'XSRF-TOKEN'),
        };
        // A parent-domain cookie would read back as the same value; only a distinct one is the MTO sign-in.
        if (candidate.mtoSccAuthCookieValue && candidate.mtoSccAuthCookieValue === candidate.sccAuthCookieValue) {
            candidate.mtoSccAuthCookieValue = null;
            candidate.mtoXsrfToken = null;
        }

        if (candidate.sccAuthCookieValue || candidate.estsAuthCookieValue) {
            candidates.push(candidate);
        }
    }

    return candidates;
}

els.send.addEventListener('click', async () => {
    // Pasted codes often carry spaces, quotes or a trailing period from the terminal.
    const code = els.code.value.replace(/[^0-9a-fA-F]/g, '').toLowerCase();
    els.code.value = code;

    els.status.textContent = '';

    if (!code) {
        els.status.textContent = 'Paste the pairing code that Start-XdrWorkbench.ps1 printed in PowerShell.';
        return;
    }
    if (!PAIRING_CODE.test(code)) {
        els.status.textContent = 'That is not a pairing code: it should be 12 characters, 0-9 and a-f. Copy it again from the PowerShell window.';
        return;
    }

    chrome.storage.local.set({ xdrRelayPort: manualPort() || 8787 });

    els.send.disabled = true;
    els.status.textContent = 'Looking for the standup on this computer...';

    try {
        // Find the listener before touching any cookie, so a missing standup is named as such
        // rather than surfacing as the browser's bare "Failed to fetch".
        const { listeners, errors } = await findListenersWithRetry();
        if (!listeners.length) {
            throw new Error(`${NOTHING_LISTENING} Checked: ${summarizeErrors(errors)}.`);
        }

        els.status.textContent = 'Reading session cookie...';
        const candidates = await gatherSessionCandidates();

        if (!candidates.length) {
            throw new Error('No Defender XDR or Entra sign-in cookies found. Sign in to security.microsoft.com in the Chrome window the standup opened and wait for the portal to load, then relay again.');
        }

        // Pick the session the analyst means: the window the popup was opened from, then an
        // Incognito window, then anything else. Within that order, prefer the Defender portal
        // cookie (sccauth), which avoids Entra's silent SSO re-exchange. Taking the first store
        // with sccauth used to relay a regular window's session (often another customer's
        // tenant) even when the analyst had signed in to the right one in Incognito.
        const rank = (c) => (c.fromThisWindow ? 0 : c.incognito ? 1 : 2) * 2 + (c.sccAuthCookieValue ? 0 : 1);
        const chosen = candidates.slice().sort((a, b) => rank(a) - rank(b))[0];
        const where = chosen.fromThisWindow ? 'this window' : chosen.incognito ? 'an Incognito window' : 'a regular window';

        const payload = {
            // Sent so the container can match the browser's User-Agent when it has to fall
            // back to the ESTS bootstrap path (Entra can bind session validity to it).
            userAgent: navigator.userAgent,
        };
        if (chosen.sccAuthCookieValue) {
            payload.sccAuthCookieValue = chosen.sccAuthCookieValue;
        }
        if (chosen.xsrfToken) {
            payload.xsrfToken = chosen.xsrfToken;
        }
        if (chosen.estsAuthCookieValue) {
            payload.estsAuthCookieValue = chosen.estsAuthCookieValue;
        }
        if (chosen.mtoSccAuthCookieValue) {
            payload.mtoSccAuthCookieValue = chosen.mtoSccAuthCookieValue;
            if (chosen.mtoXsrfToken) {
                payload.mtoXsrfToken = chosen.mtoXsrfToken;
            }
        }
        const mtoNote = chosen.mtoSccAuthCookieValue ? ' (with multi-tenant portal session)' : ' (no multi-tenant portal session: open mto.security.microsoft.com in this window for MTO hunting)';

        els.status.textContent = chosen.sccAuthCookieValue
            ? `Found Defender portal session in ${where}; relaying...`
            : `Found Entra sign-in cookie in ${where} (portal cookie not present); relaying...`;

        // A listener only accepts its own pairing code (401 otherwise, without using it up), so with
        // more than one standup waiting, offer the session to each until one accepts it.
        let accepted = null;
        let lastFailure = null;
        for (const listener of listeners) {
            let response;
            try {
                response = await fetchWithTimeout(`http://${listener.host}:${listener.port}/relay`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${code}`,
                    },
                    body: JSON.stringify(payload),
                }, 15000);
            } catch (err) {
                lastFailure = `the standup on port ${listener.port} stopped answering (its window may have closed or timed out)`;
                continue;
            }
            if (response.ok) {
                accepted = listener;
                break;
            }
            lastFailure = response.status === 401
                ? 'the pairing code does not match the waiting standup. Copy the latest code from the PowerShell window; a code stops working when the standup restarts'
                : `the standup on port ${listener.port} answered HTTP ${response.status}`;
        }

        if (!accepted) {
            throw new Error(`Relay not accepted: ${lastFailure}.`);
        }

        relayedToPort = accepted.port;
        els.status.textContent = `Session relayed from ${where} to port ${accepted.port}${mtoNote}. Check the PowerShell window: confirm the tenant it prints is the customer you meant.`;
        refreshListenerState();
    } catch (err) {
        els.status.textContent = `Failed: ${err.message}`;
    } finally {
        els.send.disabled = false;
    }
});

// File handoff for the Workbench: no listener, no pairing code. Saves only the Defender portal
// session (sccauth + XSRF-TOKEN) from the preferred window, never the Entra ESTSAUTH cookie,
// which would carry the analyst's sign-in to every app and customer tenant.
els.save.addEventListener('click', async () => {
    els.save.disabled = true;
    els.status.textContent = 'Reading session cookie...';
    try {
        const candidates = (await gatherSessionCandidates()).filter((c) => c.sccAuthCookieValue);
        if (!candidates.length) {
            throw new Error('No Defender portal session found. Sign in to security.microsoft.com in this window and wait for the portal to load, then save again.');
        }
        const rank = (c) => (c.fromThisWindow ? 0 : c.incognito ? 1 : 2);
        const chosen = candidates.slice().sort((a, b) => rank(a) - rank(b))[0];
        const where = chosen.fromThisWindow ? 'this window' : chosen.incognito ? 'an Incognito window' : 'a regular window';
        const drop = {
            kind: 'xdr-session-drop',
            version: 2,
            sccAuth: chosen.sccAuthCookieValue,
            xsrf: chosen.xsrfToken || null,
            mtoSccAuth: chosen.mtoSccAuthCookieValue || null,
            mtoXsrf: chosen.mtoSccAuthCookieValue ? (chosen.mtoXsrfToken || null) : null,
            userAgent: navigator.userAgent,
            source: where,
            savedAtUtc: new Date().toISOString(),
        };
        const url = 'data:application/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(drop));
        // saveAs lets the analyst pick the repo's .xdr-agent folder; Chrome remembers it next time.
        await chrome.downloads.download({ url, filename: 'xdr-session-drop.json', saveAs: true, conflictAction: 'overwrite' });
        els.status.textContent = `Session from ${where} offered for saving. Save it in <repo>\\.xdr-agent on this computer, then tell Claude. Never upload or paste this file into a chat: it is a live portal session.`;
    } catch (err) {
        els.status.textContent = `Failed: ${err.message}`;
    } finally {
        els.save.disabled = false;
    }
});
