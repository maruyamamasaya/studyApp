import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const normalizeList = (values: string[]) => [...new Set(values.map((value) => value.trim()).filter(Boolean))];
const localDateTime = z.preprocess(
  (value) => value instanceof Date && !Number.isNaN(value.valueOf())
    ? value.toISOString().slice(0, 19).replace('T', ' ')
    : value,
  z.string().regex(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/u)
);

const notes = defineCollection({
  loader: glob({
    pattern: '**/*.md',
    base: './content/notes',
    generateId: ({ entry }) => entry.replace(/\.md$/u, '')
  }),
  schema: z.object({
    id: z.string().regex(/^\d{8}-\d{6}$/u),
    title: z.union([z.string(), z.null()]).optional().transform((value) => {
      const normalized = typeof value === 'string' ? value.trim() : '';
      return normalized || null;
    }),
    type: z.string().trim().min(1),
    tags: z.array(z.string()).transform(normalizeList),
    created: localDateTime,
    updated: z.union([localDateTime, z.null()]).optional(),
    aliases: z.array(z.string()).optional().default([]).transform(normalizeList)
  }).transform((data) => ({
    ...data,
    aliases: data.aliases.filter((alias) => alias !== data.title)
  }))
});

export const collections = { notes };
