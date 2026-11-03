const els = {
    code: document.getElementById('code'),
    port: document.getElementById('port'),
    send: document.getElementById('send'),
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
            sccAuthCookieValue: await read('https://security.microsoft.com', 'sccauth'),
            xsrfToken: await read('https://security.microsoft.com', 'XSRF-TOKEN'),
            estsAuthCookieValue: await read('https://login.microsoftonline.com', 'ESTSAUTH'),
        };

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

        // Prefer a store that has the Defender portal session cookie (sccauth) - that's the
        // direct path that avoids Entra's silent SSO re-exchange. Otherwise take the last
        // candidate with an ESTSAUTH cookie (getAllCookieStores lists the default store
        // first, so a later one is the Incognito store).
        const chosen = candidates.find((c) => c.sccAuthCookieValue) || candidates[candidates.length - 1];

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

        els.status.textContent = chosen.sccAuthCookieValue
            ? 'Found Defender portal session; relaying to container...'
            : 'Found Entra sign-in cookie (portal cookie not present); relaying to container...';

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

        els.status.textContent = 'Session relayed. Check the container - it should now be connected.';
    } catch (err) {
        els.status.textContent = `Failed: ${err.message}`;
    } finally {
        els.send.disabled = false;
    }
});
