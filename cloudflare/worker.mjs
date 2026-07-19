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
		const large_game_files = {
			"/index.pck": "application/octet-stream",
			"/index.side.wasm": "application/wasm",
		};
		if (large_game_files.hasOwnProperty(url.pathname)) {
			const key = url.pathname.slice(1);
			const asset = await env.GAME_ASSETS.get(key);
			if (!asset) {
				return new Response("Game data is unavailable.", { status: 404 });
			}

			const headers = new Headers();
			asset.writeHttpMetadata(headers);
			headers.set("Content-Type", large_game_files[url.pathname]);
			headers.set("Content-Length", String(asset.size));
			headers.set("ETag", asset.httpEtag);
			headers.set("Cache-Control", "public, max-age=31536000, immutable");
			return with_isolation_headers(new Response(asset.body, { headers }));
		}

		return with_isolation_headers(await env.ASSETS.fetch(request));
	},
};
