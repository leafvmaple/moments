// @ts-check
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://moments.leafvmaple.com',
  trailingSlash: 'never',
  build: {
    format: 'directory',
  },
});
