import { defineConfig } from 'astro/config';
import { unified } from '@astrojs/markdown-remark';
import { remarkWikiLinks } from './app/src/markdown/remark-wiki-links.mjs';
import { rehypeEscapeRawHtml } from './app/src/markdown/rehype-escape-raw-html.mjs';

export default defineConfig({
  output: 'static',
  srcDir: './app/src',
  outDir: './dist',
  markdown: {
    processor: unified({
      remarkPlugins: [remarkWikiLinks],
      rehypePlugins: [rehypeEscapeRawHtml]
    }),
    shikiConfig: { theme: 'github-dark-default' }
  }
});
