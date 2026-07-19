const ISOLATION_HEADERS = {
	"Cross-Origin-Embedder-Policy": "require-corp",
	"Cross-Origin-Opener-Policy": "same-origin",
	"Cross-Origin-Resource-Policy": "same-origin",
};

function with_isolation_headers(response) {
	const headers = new Headers(response.headers);
	for (const [name, value] of Object.entries(ISOLATION_HEADERS)) {
		headers.set(name, value);
	}
	return new Response(response.body, {
		status: response.status,
		statusText: response.statusText,
		headers,
	});
}

export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		if (url.pathname === "/index.pck") {
			const pack = await env.GAME_ASSETS.get("index.pck");
			if (!pack) {
				return new Response("Game data is unavailable.", { status: 404 });
			}

			const headers = new Headers();
			pack.writeHttpMetadata(headers);
			headers.set("Content-Type", "application/octet-stream");
			headers.set("Content-Length", String(pack.size));
			headers.set("ETag", pack.httpEtag);
			headers.set("Cache-Control", "public, max-age=31536000, immutable");
			return with_isolation_headers(new Response(pack.body, { headers }));
		}

		return with_isolation_headers(await env.ASSETS.fetch(request));
	},
};
