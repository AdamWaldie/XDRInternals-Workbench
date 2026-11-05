const els = {
    code: document.getElementById('code'),
    port: document.getElementById('port'),
    send: document.getElementById('send'),
    save: document.getElementById('save'),
    status: document.getElementById('status'),
};

chrome.storage.local.get(['xdrRelayPort'], (data) => {
    if (data.xdrRelayPort) {
        els.port.value = data.xdrRelayPort;
    }
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
    const code = els.code.value.trim();
    const port = parseInt(els.port.value, 10) || 8787;

    els.status.textContent = '';

    if (!code) {
        els.status.textContent = 'Enter the pairing code shown by Connect-XdrByBrowserExtension.';
        return;
    }

    chrome.storage.local.set({ xdrRelayPort: port });

    els.send.disabled = true;
    els.status.textContent = 'Reading session cookie...';

    try {
        const candidates = await gatherSessionCandidates();

        if (!candidates.length) {
            throw new Error('No Defender XDR or Entra sign-in cookies found in any cookie store. Sign in to security.microsoft.com (preferably in an Incognito window), and make sure "Allow in Incognito" is enabled for this extension if you did.');
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

        const response = await fetch(`http://127.0.0.1:${port}/relay`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${code}`,
            },
            body: JSON.stringify(payload),
        });

        if (!response.ok) {
            throw new Error(`Container rejected the relay (HTTP ${response.status}). Check the pairing code and port, then re-run Connect-XdrByBrowserExtension for a fresh code.`);
        }

        els.status.textContent = `Session relayed from ${where}${mtoNote}. Check the PowerShell window: confirm the tenant it prints is the customer you meant.`;
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
            throw new Error('No Defender portal session found. Sign in to security.microsoft.com in an Incognito window and wait for the portal to load (and check "Allow in Incognito" is on for this extension).');
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
        els.status.textContent = `Session from ${where} offered for saving. Save it in <repo>\\.xdr-agent, then tell Claude.`;
    } catch (err) {
        els.status.textContent = `Failed: ${err.message}`;
    } finally {
        els.save.disabled = false;
    }
});
