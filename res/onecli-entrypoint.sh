#!/bin/sh
set -eu

# Start the real OneCLI entrypoint in the background.
# `exec node` inside entrypoint.sh replaces the shell with the Node process,
# but the PID stays the same, so `wait $MAIN_PID` works correctly.
/app/entrypoint.sh &
MAIN_PID=$!

trap 'kill $MAIN_PID 2>/dev/null; wait $MAIN_PID 2>/dev/null' TERM INT

echo 'Waiting for OneCLI to be healthy...'
until wget -qO- http://127.0.0.1:10254/api/health >/dev/null 2>&1 && wget -qO- http://127.0.0.1:10255/healthz >/dev/null 2>&1; do
    sleep 2
done

# Trigger local-admin bootstrap (creates the user, project, and API key).
wget -qO- http://127.0.0.1:10254/api/auth/session >/dev/null 2>&1 || true

PRISMA_CLIENT_DIR="$(find /app/node_modules/.pnpm -maxdepth 5 -name 'default.js' -path '*/@prisma/client/default.js' 2>/dev/null | head -1 | xargs -r dirname)"

ZAI_API_KEY="$ZAI_API_KEY" PRISMA_CLIENT_DIR="$PRISMA_CLIENT_DIR" node - <<-'JS'
	const { PrismaClient } = require(process.env.PRISMA_CLIENT_DIR);
	(async () => {
	    const prisma = new PrismaClient({ log: [] });
	    const row = await prisma.apiKey.findFirst({
	        where: { scope: 'project' },
	        orderBy: { createdAt: 'desc' },
	        select: { key: true },
	    });
	    await prisma.$disconnect();
	    if (!row) { console.error('No project API key found in database'); process.exit(1); }
	
	    const baseUrl = 'http://127.0.0.1:10254/api';
	    const headers = { authorization: `Bearer ${row.key}`, 'content-type': 'application/json' };
	
	    async function request(path, options = {}) {
	        const res = await fetch(`${baseUrl}${path}`, { ...options, headers: { ...headers, ...(options.headers ?? {}) } });
	        if (!res.ok) {
	            const text = await res.text();
	            throw new Error(`${options.method || 'GET'} ${path} failed: ${res.status} ${text}`);
	        }
	        if (res.status === 204) return null;
	        return res.json();
	    }
	
	    const existing = await request('/secrets');
	    for (const secret of existing) {
	        if (secret.hostPattern === 'api.z.ai') {
	            await request(`/secrets/${secret.id}`, { method: 'DELETE' });
	        }
	    }
	
	    const created = await request('/secrets', {
	        method: 'POST',
	        body: JSON.stringify({
	            name: 'Z.ai Anthropic API',
	            type: 'anthropic',
	            value: process.env.ZAI_API_KEY,
	            hostPattern: 'api.z.ai',
	            pathPattern: '*',
	        }),
	    });
	    console.log(`Configured OneCLI secret ${created.name} for ${created.hostPattern}`);
	})();
	JS

wait $MAIN_PID
