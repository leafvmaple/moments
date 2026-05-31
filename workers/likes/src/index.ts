interface Env {
  LIKES: KVNamespace;
}

const SLUG_RE = /^[a-zA-Z0-9/_-]{1,128}$/;

function corsHeaders(origin: string | null): Record<string, string> {
  return {
    'access-control-allow-origin': origin ?? '*',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
    'access-control-max-age': '86400',
    'vary': 'origin',
  };
}

function json(data: unknown, status: number, origin: string | null): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      ...corsHeaders(origin),
    },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const origin = request.headers.get('origin');

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    if (url.pathname !== '/likes') {
      return json({ error: 'not found' }, 404, origin);
    }

    const slug = url.searchParams.get('slug');
    if (!slug || !SLUG_RE.test(slug)) {
      return json({ error: 'invalid slug' }, 400, origin);
    }

    const key = `like:${slug}`;

    if (request.method === 'GET') {
      const raw = await env.LIKES.get(key);
      return json({ count: raw ? parseInt(raw, 10) : 0 }, 200, origin);
    }

    if (request.method === 'POST') {
      const raw = await env.LIKES.get(key);
      const next = (raw ? parseInt(raw, 10) : 0) + 1;
      await env.LIKES.put(key, String(next));
      return json({ count: next }, 200, origin);
    }

    return json({ error: 'method not allowed' }, 405, origin);
  },
};
