import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const posts = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/posts' }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    tags: z.array(z.string()).default([]),
    excerpt: z.string().optional(),
    cover: z.string().optional(),
    trip: z.string().optional(),
  }),
});

const trips = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/trips' }),
  schema: z.object({
    name: z.string(),
    startDate: z.coerce.date(),
    endDate: z.coerce.date(),
    country: z.string(),
    excerpt: z.string().optional(),
    cover: z.string().optional(),
  }),
});

export const collections = { posts, trips };
