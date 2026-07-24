const fs = require('fs');

const file = 'app/pages/app/evento/[eventId]/oficinas/index.vue';
let content = fs.readFileSync(file, 'utf8');

// Update tData query to select id
content = content.replace(
  ".select('id, leader_id, members:team_members(user_id, name, status)')",
  ".select('id, leader_id, members:team_members(id, user_id, name, status)')"
);

// Update eData query to fetch member_id instead of user_id
content = content.replace(
  ".select('workshop_id, user_id')",
  ".select('workshop_id, member_id')"
);

// Update Type
content = content.replace(
  "let enrollments: Array<{ workshop_id: string, user_id: string }> = []",
  "let enrollments: Array<{ workshop_id: string, member_id: string }> = []"
);

// Update isEnrolled function
content = content.replace(
  "function isEnrolled(workshopId: string, userId: string) {",
  "function isEnrolled(workshopId: string, memberId: string) {"
);
content = content.replace(
  "return enrollments.value.some(e => e.workshop_id === workshopId && e.user_id === userId)",
  "return enrollments.value.some(e => e.workshop_id === workshopId && e.member_id === memberId)"
);

// Update enroll function
content = content.replace(
  "async function enroll(workshopId: string, userId: string) {",
  "async function enroll(workshopId: string, memberId: string) {"
);
content = content.replace(
  "p_user_id: userId",
  "p_member_id: memberId"
);

// Update unenroll function
content = content.replace(
  "async function unenroll(workshopId: string, userId: string) {",
  "async function unenroll(workshopId: string, memberId: string) {"
);
content = content.replace(
  "p_user_id: userId",
  "p_member_id: memberId"
);

// Update the template loops
content = content.replace(
  "v-if=\"isEnrolled(w.id, member.user_id!)\"",
  "v-if=\"isEnrolled(w.id, member.id!)\""
);
content = content.replace(
  "@click=\"unenroll(w.id, member.user_id!)\"",
  "@click=\"unenroll(w.id, member.id!)\""
);
content = content.replace(
  ":disabled=\"saving || getAvailableSeats(w) === 0 || member.status !== 'active' || !member.user_id\"",
  ":disabled=\"saving || getAvailableSeats(w) === 0\""
);
content = content.replace(
  "@click=\"if (member.user_id) enroll(w.id, member.user_id)\"",
  "@click=\"enroll(w.id, member.id!)\""
);
content = content.replace(
  ":title=\"member.status !== 'active' ? 'Membro precisa aceitar o convite e criar conta primeiro' : ''\"",
  ""
);
content = content.replace(
  "<span v-else-if=\"member.status !== 'active'\" style=\"color: #fca5a5; font-size: 0.8rem; margin-left: 0.5rem;\">(Pendente)</span>",
  ""
);

fs.writeFileSync(file, content, 'utf8');
console.log("Done");
