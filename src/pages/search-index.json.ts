import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

export const GET: APIRoute = async () => {
  const posts = await getCollection('posts');
  const index = posts.map((p) => ({
    slug: p.id,
    title: p.data.title,
    excerpt: p.data.excerpt ?? '',
    tags: p.data.tags,
    date: p.data.date.toISOString(),
  }));
  return new Response(JSON.stringify(index), {
    headers: { 'Content-Type': 'application/json' },
  });
};
