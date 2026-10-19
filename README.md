# MND CODE — Networking, Cloud & Cybersecurity Academy

**Domain:** MNDCODE.in · **Company:** MND CODE Pvt Ltd · **Tagline:** Connect. Compute. Secure.

This package is the **front-end prototype** of the MND CODE learning platform, delivered as one self-contained file (`index.html`) with embedded CSS and JavaScript. It also includes the files needed to start the production backend (`.env.example`, `schema.sql`).

---

## 1. What's included

| File | Purpose |
|---|---|
| `index.html` | The complete website: 27 routes, 3 courses, 10 lab exercises, student and admin dashboards |
| `README.md` | This guide: setup, deployment, domain configuration, test checklist |
| `.env.example` | Environment variables for the production backend (no real secrets) |
| `schema.sql` | PostgreSQL schema for the production backend |

### Routes

**Public:** `/` · `/about` · `/courses` · `/courses/networking` · `/courses/cloud-computing` · `/courses/ethical-hacking` · `/learning-paths` · `/labs` · `/projects` · `/resources` · `/blog` · `/blog/:slug` · `/faq` · `/contact` · `/privacy` · `/terms`

**Student:** `/login` · `/register` · `/dashboard` · `/dashboard/courses` · `/learn/:course/:lesson` · `/dashboard/progress` · `/dashboard/settings`

**Admin:** `/admin` · `/admin/courses` · `/admin/lessons` · `/admin/students` · `/admin/messages`

Plus a 404 page and an error page. The site uses hash routing (`index.html#/courses/networking`) so it works on any static host with no server rewrites.

### Demo vs production

| Feature | In this prototype | In production |
|---|---|---|
| Accounts & login | Stored in the browser (localStorage); passwords salted + SHA-256 hashed | Server-side auth, Argon2/bcrypt hashing, secure HTTP-only session cookies |
| Route protection | Browser check only | Server enforces roles on every API request |
| Progress, quizzes, bookmarks | Browser storage | PostgreSQL (`lesson_progress`, `quiz_attempts`, `bookmarks`) |
| Contact form | Saved to the browser's admin inbox | `POST /api/contact` → `contact_submissions` + email notification |
| Admin edits | Browser storage + local audit log | API + `audit_events` table |
| Lab results | Computed or simulated locally | Same — labs never contact real systems |

**Demo accounts** (seeded automatically, shown on the sign-in page):
- Student: `student@demo.mndcode.in` / `Student#2026`
- Admin: `admin@demo.mndcode.in` / `Admin#2026`

Remove these before launch (they exist only in the prototype's seed function `seedUsers()`).

---

## 2. Run it locally

No build step is required.

```bash
# Option A: open the file directly
open index.html            # macOS
start index.html           # Windows
xdg-open index.html        # Linux

# Option B: serve it (recommended — mirrors production)
npx serve .                # then visit http://localhost:3000
# or
python3 -m http.server 8080
```

The page loads fonts from Google Fonts; everything else is inline.

---

## 3. Configure site content

All configuration is in the `SITE` object near the top of the `<script>` in `index.html`:

```js
const SITE = {
  contact: { email: null, phone: null, address: null, hours: null },
  social: [],          // e.g. [{ label: "LinkedIn", url: "https://www.linkedin.com/company/…" }]
  announcement: { enabled: true, label: "New", text: "…", link: "/labs", linkText: "Open the lab" }
};
```

- Values left as `null` are **hidden** on the site. Add contact details only once verified.
- Social links appear in the footer only when real URLs are added.
- Course content lives in `BASE_COURSES` (curricula) and `LESSONS` (fully authored lessons). Lessons without an entry in `LESSONS` show as clearly labelled outline lessons.

---

## 4. Deploy the static site

Any static host works. Upload `index.html` as the site root.

**Netlify / Vercel / Cloudflare Pages:** create a new project, drag in the folder (or connect a Git repo containing it). No build command; publish directory = the folder.

**Nginx (VPS):**
```nginx
server {
  listen 443 ssl http2;
  server_name mndcode.in www.mndcode.in;
  root /var/www/mndcode;
  index index.html;
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
  add_header X-Content-Type-Options nosniff;
  add_header Referrer-Policy strict-origin-when-cross-origin;
  location / { try_files $uri /index.html; }
}
```

---

## 5. Configure the domain MNDCODE.in

1. **Choose the canonical host.** Recommended: `https://mndcode.in` with `www` redirecting to it.
2. **At your domain registrar's DNS panel**, add the records your host gives you. Typical patterns:
   - Netlify / Vercel / Cloudflare Pages: `CNAME www → <your-project>.netlify.app` (or the host's target) and an `A`/`ALIAS` record for the apex as instructed by the host.
   - Own server: `A @ → <server IPv4>`, `AAAA @ → <server IPv6>` (if any), `CNAME www → mndcode.in`.
3. **Add the domain in your host's dashboard** and wait for DNS propagation (minutes to a few hours).
4. **Enable HTTPS.** Managed hosts issue certificates automatically. On your own server: `sudo certbot --nginx -d mndcode.in -d www.mndcode.in`.
5. **Set the www → apex redirect** in the host settings or Nginx.
6. **Email (optional):** add `MX`, SPF (`TXT`), DKIM and DMARC records from your email provider before publishing a contact address.
7. **Search engines:** add the site to Google Search Console and Bing Webmaster Tools; submit `https://mndcode.in/sitemap.xml` once the production build generates it.

---

## 6. Production backend plan

Recommended stack (per brief): **Node.js + NestJS**, **PostgreSQL**, REST API, object storage for course assets.

1. Create the database and run `schema.sql` (or port it into your migration tool — Prisma, TypeORM or node-pg-migrate).
2. Copy `.env.example` to `.env` and fill in real values **on the server only**.
3. Implement endpoints (all inputs validated, e.g. with `class-validator` or `zod`):
   - `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/logout`, `GET /api/me`
   - `GET /api/courses`, `GET /api/courses/:slug`, `GET /api/lessons/:id`
   - `POST /api/enrollments`, `DELETE /api/enrollments/:courseId`
   - `PUT /api/progress/:lessonId`, `POST /api/quiz-attempts`, `POST/DELETE /api/bookmarks/:lessonId`
   - `POST /api/contact` (rate-limited)
   - `/api/admin/*` for courses, lessons, students, messages, announcements — guarded by an `admin` role check and writing to `audit_events`.
4. Security checklist: Argon2id password hashing · HTTP-only, `Secure`, `SameSite=Lax` session cookies · CSRF tokens on state-changing requests · rate limiting on auth and contact · parameterized queries only · output encoding · secrets in a secret manager · daily database backups · structured logging.
5. Migrate the front-end from browser storage to the API by replacing the `store`, `currentUser`, `prog`/`saveProg` and admin functions with `fetch` calls. Consider moving to React + TypeScript + Vite (or Next.js) at this stage; the data model, routes and components map one-to-one.
6. Generate per-route `<title>`, meta descriptions, canonical URLs, Open Graph tags, `sitemap.xml` and `robots.txt` at build time (static rendering or SSR), since hash routes are not indexed individually.

---

## 7. Tested checklist

Tested in headless Chromium at 390 px (mobile) and 1366 px (desktop), plus manual review at tablet width.

### Routes (all render with unique titles, no console errors, no horizontal scroll at 390 px)
- [x] All 16 public routes incl. a blog post and pagination
- [x] Course pages: networking, cloud-computing, ethical-hacking
- [x] Lesson player: authored lesson (`/learn/networking/m3-l5`) and outline lesson
- [x] Login, register, all 4 dashboard routes
- [x] All 5 admin routes (as admin); admin routes show an access message to students and signed-out visitors
- [x] 404 for unknown routes

### Forms
- [x] Contact: required fields, email and phone format, minimum lengths, character counter, loading state, success and failure messages, stored in admin inbox
- [x] Register: duplicate email, password strength, confirmation, terms checkbox
- [x] Login: wrong credentials message, 5-attempt lockout (30 s), redirect to `next`
- [x] Settings: profile update, password change with current-password check, reset progress and delete account behind confirmation dialogs
- [x] Admin: announcement (internal-link validation), SEO metadata, course create/edit/delete/restore, lesson add/publish/unpublish/delete, student enroll/remove, message read/unread/delete

### Interactive features
- [x] Search palette (button and Ctrl/⌘ K), keyboard navigation
- [x] Course filters (search, category, level, duration) with empty state and reset
- [x] Curriculum accordions, expand/collapse all, deep links to a module
- [x] Enroll / unenroll, mark lesson complete, bookmarks, quizzes with explanations, progress bars, streak, achievements
- [x] Lab: subnet calculator + practice, OSI explorer + quiz, packet journey (step/auto-play), DNS resolver with cache and NXDOMAIN, Linux terminal (6 tasks), cloud builder (8 checks), firewall first-match evaluation with re-ordering, course quizzes, vulnerability ranking, report-writing review

### Accessibility
- [x] Skip link, landmarks, breadcrumbs with `aria-current`
- [x] Visible focus styles; dropdown and dialogs close with Escape
- [x] Form labels, `aria-invalid` and inline error messages
- [x] Lab tabs use `role="tab"` with arrow-key navigation
- [x] `prefers-reduced-motion` disables animation
- [x] Text contrast meets WCAG AA on the dark palette

### Content integrity
- [x] No invented ratings, learner counts, placement figures, testimonials, partnerships or certifications
- [x] Sample projects, sample activity and simulated lab results are labelled
- [x] Contact details and social links hidden until configured

---

© MND CODE — All Rights Reserved
