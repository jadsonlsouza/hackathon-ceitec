const fs = require('fs');

const files = [
  'app/pages/app/evento/[eventId]/oficinas/index.vue',
  'app/pages/app/evento/[eventId]/admin/oficinas.vue'
];

for (const file of files) {
  let content = fs.readFileSync(file, 'utf8');
  
  content = content.replace(/var\(--color-gray-950\)/g, '#070b14');
  content = content.replace(/var\(--color-gray-900\)/g, '#111827');
  content = content.replace(/var\(--color-gray-800\)/g, '#334155');
  content = content.replace(/var\(--color-gray-400\)/g, '#94a3b8');
  content = content.replace(/var\(--color-gray-300\)/g, '#cbd5e1');
  content = content.replace(/var\(--color-gray-200\)/g, '#e2e8f0');
  content = content.replace(/var\(--color-white\)/g, '#f8fafc');
  
  content = content.replace(/var\(--color-primary-400\)/g, '#7dd3fc');
  content = content.replace(/var\(--color-primary-600\)/g, '#0284c7');
  content = content.replace(/var\(--color-primary-700\)/g, '#0369a1');
  
  content = content.replace(/var\(--color-green-900\)/g, '#064e3b');
  content = content.replace(/var\(--color-green-800\)/g, '#065f46');
  content = content.replace(/var\(--color-green-400\)/g, '#34d399');
  
  content = content.replace(/var\(--color-red-900\)/g, '#7f1d1d');
  content = content.replace(/var\(--color-red-800\)/g, '#991b1b');
  content = content.replace(/var\(--color-red-400\)/g, '#f87171');
  
  content = content.replace(/var\(--space-1\)/g, '0.25rem');
  content = content.replace(/var\(--space-2\)/g, '0.5rem');
  content = content.replace(/var\(--space-3\)/g, '0.75rem');
  content = content.replace(/var\(--space-4\)/g, '1rem');
  content = content.replace(/var\(--space-6\)/g, '1.5rem');
  content = content.replace(/var\(--space-8\)/g, '2rem');
  
  content = content.replace(/var\(--radius-md\)/g, '0.5rem');
  content = content.replace(/var\(--radius-lg\)/g, '1rem');
  content = content.replace(/var\(--radius-full\)/g, '9999px');
  
  content = content.replace(/class="primary-button"/g, 'class="action-button"');
  content = content.replace(/class="secondary-button"/g, 'class="action-button secondary"');
  content = content.replace(/class="primary-button compact-btn"/g, 'class="action-button compact-btn"');
  content = content.replace(/class="secondary-button compact-btn"/g, 'class="action-button secondary compact-btn"');

  if (!content.includes('.action-button {')) {
    const buttonStyles = `
.action-button { background: #0369a1; border: 0; border-radius: .5rem; color: #fff; cursor: pointer; font-weight: 700; padding: .65rem 1rem; text-decoration: none; display: inline-block; text-align: center; }
.action-button:hover:not(:disabled) { background: #0284c7; }
.action-button:disabled { cursor: wait; opacity: .6; }
.action-button.secondary { background: transparent; border: 1px solid #475569; }
.action-button.secondary:hover:not(:disabled) { background: #1e293b; }
.compact-btn { padding: 0.35rem 0.75rem; font-size: 0.85rem; }
`;
    content = content.replace('</style>', buttonStyles + '</style>');
  }

  content = content.replace(/\.builder-page \{\n\s+max-width: 800px;\n\s+margin: 0 auto;\n\}/g, 
    '.builder-page {\n  max-width: 800px;\n  margin: 0 auto;\n  padding: 3rem 1.5rem 6rem;\n}');
    
  fs.writeFileSync(file, content, 'utf8');
}
console.log("Done");
