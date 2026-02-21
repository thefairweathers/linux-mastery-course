import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import rehypeRelativeMarkdownLinks from 'astro-rehype-relative-markdown-links';

export default defineConfig({
  site: 'https://thefairweathers.github.io',
  base: '/linux-mastery-course',
  markdown: {
    rehypePlugins: [rehypeRelativeMarkdownLinks],
  },
  integrations: [
    starlight({
      title: 'Linux Mastery',
      description: 'A 17-week hands-on course from zero to production Linux.',
      customCss: ['./src/styles/custom.css'],
      components: {
        Head: './src/components/Head.astro',
      },
      sidebar: [
        { label: 'Home', slug: 'index' },
        {
          label: 'Week 01 — Welcome to Linux',
          items: [
            { slug: 'week-01', label: 'Lesson' },
            { slug: 'week-01/lab-01-ubuntu-vm-setup' },
            { slug: 'week-01/lab-02-rocky-vm-setup' },
          ],
        },
        {
          label: 'Week 02 — The Shell & Filesystem',
          items: [
            { slug: 'week-02', label: 'Lesson' },
            { slug: 'week-02/lab-01-filesystem-exploration' },
            { slug: 'week-02/lab-02-file-operations' },
          ],
        },
        {
          label: 'Week 03 — Text Processing',
          items: [
            { slug: 'week-03', label: 'Lesson' },
            { slug: 'week-03/lab-01-log-analysis' },
            { slug: 'week-03/lab-02-text-pipeline' },
          ],
        },
        {
          label: 'Week 04 — Pipes & Redirection',
          items: [
            { slug: 'week-04', label: 'Lesson' },
            { slug: 'week-04/lab-01-redirection-mastery' },
            { slug: 'week-04/lab-02-pipeline-challenges' },
          ],
        },
        {
          label: 'Week 05 — Users & Permissions',
          items: [
            { slug: 'week-05', label: 'Lesson' },
            { slug: 'week-05/lab-01-user-management' },
            { slug: 'week-05/lab-02-permission-scenarios' },
          ],
        },
        {
          label: 'Week 06 — Package Management',
          items: [
            { slug: 'week-06', label: 'Lesson' },
            { slug: 'week-06/lab-01-package-management' },
            { slug: 'week-06/lab-02-repository-setup' },
          ],
        },
        {
          label: 'Week 07 — Processes & Monitoring',
          items: [
            { slug: 'week-07', label: 'Lesson' },
            { slug: 'week-07/lab-01-process-investigation' },
            { slug: 'week-07/lab-02-resource-monitoring' },
          ],
        },
        {
          label: 'Week 08 — Bash Scripting',
          items: [
            { slug: 'week-08', label: 'Lesson' },
          ],
        },
        {
          label: 'Week 09 — Networking',
          items: [
            { slug: 'week-09', label: 'Lesson' },
            { slug: 'week-09/lab-01-network-diagnostics' },
            { slug: 'week-09/lab-02-ssh-and-firewall' },
          ],
        },
        {
          label: 'Week 10 — Storage & Disks',
          items: [
            { slug: 'week-10', label: 'Lesson' },
            { slug: 'week-10/lab-01-disk-management' },
            { slug: 'week-10/lab-02-lvm-operations' },
          ],
        },
        {
          label: 'Week 11 — Systemd & Services',
          items: [
            { slug: 'week-11', label: 'Lesson' },
            { slug: 'week-11/lab-01-service-management' },
            { slug: 'week-11/lab-02-custom-service' },
          ],
        },
        {
          label: 'Week 12 — Web Servers & DNS',
          items: [
            { slug: 'week-12', label: 'Lesson' },
            { slug: 'week-12/lab-01-web-server-setup' },
            { slug: 'week-12/lab-02-reverse-proxy-and-dns' },
          ],
        },
        {
          label: 'Week 13 — Databases',
          items: [
            { slug: 'week-13', label: 'Lesson' },
            { slug: 'week-13/lab-01-database-server-setup' },
            { slug: 'week-13/lab-02-three-tier-app' },
          ],
        },
        {
          label: 'Week 14 — Advanced Scripting',
          items: [
            { slug: 'week-14', label: 'Lesson' },
          ],
        },
        {
          label: 'Week 15 — Container Fundamentals',
          items: [
            { slug: 'week-15', label: 'Lesson' },
            { slug: 'week-15/lab-01-container-basics' },
            { slug: 'week-15/lab-02-volumes-and-networking' },
          ],
        },
        {
          label: 'Week 16 — Building Images',
          items: [
            { slug: 'week-16', label: 'Lesson' },
            { slug: 'week-16/lab-01-dockerfile-mastery' },
            { slug: 'week-16/lab-02-containerize-three-tier' },
          ],
        },
        {
          label: 'Week 17 — Compose & Capstone',
          items: [
            { slug: 'week-17', label: 'Lesson' },
            { slug: 'week-17/lab-01-compose-three-tier' },
            { slug: 'week-17/lab-02-capstone-deployment' },
          ],
        },
      ],
    }),
  ],
});
