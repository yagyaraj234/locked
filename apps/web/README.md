# Web

Marketing site for Locked: one statically rendered Next.js page.

```sh
cd apps/web
pnpm install
pnpm dev      # http://localhost:3000
pnpm build
```

Set `NEXT_PUBLIC_SITE_URL` to the deployed origin (for example `https://locked.example.com`) before building. The canonical link, sitemap, robots file and social image URLs are built from it.

Copy lives in `app/page.tsx` and `app/site.ts` (title, description, FAQ). The FAQ list also feeds the FAQ structured data, so edit it in one place.
