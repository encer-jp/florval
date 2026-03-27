import type { User } from "../schemas/user.js";
import type { Task } from "../schemas/task.js";
import type { Project } from "../schemas/project.js";
import type { Notification } from "../schemas/notification.js";

// --- Users (25) ---
const userNames = [
  "Alice Johnson", "Bob Smith", "Charlie Brown", "Diana Prince", "Eve Davis",
  "Frank Miller", "Grace Lee", "Henry Wilson", "Iris Chen", "Jack Taylor",
  "Kate Anderson", "Leo Martinez", "Mia Thomas", "Noah Jackson", "Olivia White",
  "Paul Harris", "Quinn Clark", "Rosa Lewis", "Sam Robinson", "Tina Walker",
  "Uma Hall", "Victor Young", "Wendy King", "Xavier Wright", "Yuki Lopez",
];

const roles: User["role"][] = [
  "admin", "admin",
  "member", "member", "member", "member", "member", "member", "member", "member",
  "member", "member", "member", "member", "member", "member", "member", "member",
  "member", "member",
  "viewer", "viewer", "viewer", "viewer", "viewer",
];

function makeUUID(index: number): string {
  const hex = index.toString(16).padStart(12, "0");
  return `00000000-0000-4000-8000-${hex}`;
}

export const users: User[] = userNames.map((name, i) => ({
  id: makeUUID(i + 1),
  name,
  email: name.toLowerCase().replace(/ /g, ".") + "@example.com",
  avatar_url: i % 3 === 0 ? `https://api.dicebear.com/7.x/avataaars/svg?seed=${name.replace(/ /g, "")}` : null,
  role: roles[i],
  created_at: new Date(2025, 0, 1 + i).toISOString(),
}));

// --- Tasks (15) ---
const statuses: Task["status"][] = ["todo", "todo", "todo", "todo", "todo", "in_progress", "in_progress", "in_progress", "in_progress", "in_progress", "done", "done", "done", "done", "done"];
const priorities: Task["priority"][] = ["low", "low", "low", "medium", "medium", "medium", "medium", "high", "high", "high", "high", "urgent", "urgent", "urgent", "urgent"];
const taskTitles = [
  "Set up project structure", "Design database schema", "Implement user auth",
  "Create API endpoints", "Write unit tests", "Add input validation",
  "Set up CI/CD pipeline", "Write API documentation", "Implement search feature",
  "Add pagination support", "Fix login bug", "Optimize database queries",
  "Add error handling", "Create admin dashboard", "Deploy to production",
];

export const tasks: Task[] = taskTitles.map((title, i) => {
  const assigneeId = i < 10 ? users[i % 5].id : null;
  return {
    id: makeUUID(100 + i),
    title,
    description: i % 2 === 0 ? `Description for: ${title}` : null,
    status: statuses[i],
    priority: priorities[i],
    assignee_id: assigneeId,
    assignee: assigneeId ? users.find((u) => u.id === assigneeId) ?? null : null,
    tags: i % 3 === 0 ? ["backend", "api"] : i % 3 === 1 ? ["frontend"] : ["devops"],
    due_date: i % 4 === 0 ? new Date(2025, 6, 1 + i).toISOString() : null,
    created_at: new Date(2025, 1, 1 + i).toISOString(),
    updated_at: new Date(2025, 1, 10 + i).toISOString(),
  };
});

// --- Projects (3) ---
export const projects: Project[] = [
  {
    id: makeUUID(200),
    name: "florval",
    description: "OpenAPI code generator for Flutter",
    owner: users[0],
    members: [users[0], users[1], users[2], users[3], users[4]],
    task_count: 8,
    created_at: new Date(2025, 0, 1).toISOString(),
    updated_at: new Date(2025, 2, 1).toISOString(),
  },
  {
    id: makeUUID(201),
    name: "demo-api",
    description: "Demo API server for florval",
    owner: users[1],
    members: [users[1], users[5], users[6]],
    task_count: 5,
    created_at: new Date(2025, 1, 1).toISOString(),
    updated_at: new Date(2025, 2, 15).toISOString(),
  },
  {
    id: makeUUID(202),
    name: "mobile-app",
    description: null,
    owner: users[2],
    members: [users[2], users[7], users[8], users[9]],
    task_count: 2,
    created_at: new Date(2025, 2, 1).toISOString(),
    updated_at: new Date(2025, 3, 1).toISOString(),
  },
];

// --- Notifications (10) ---
export const notifications: Notification[] = [
  {
    id: makeUUID(300),
    type: "task_assigned",
    payload: { type: "task_assigned", task_id: tasks[0].id, task_title: tasks[0].title, assigned_by: users[0].name },
    created_at: new Date(2025, 2, 1).toISOString(),
    is_read: true,
  },
  {
    id: makeUUID(301),
    type: "comment_added",
    payload: { type: "comment_added", task_id: tasks[1].id, task_title: tasks[1].title, comment_text: "Looks good to me!", commented_by: users[1].name },
    created_at: new Date(2025, 2, 2).toISOString(),
    is_read: true,
  },
  {
    id: makeUUID(302),
    type: "project_invited",
    payload: { type: "project_invited", project_id: projects[0].id, project_name: projects[0].name, invited_by: users[0].name },
    created_at: new Date(2025, 2, 3).toISOString(),
    is_read: false,
  },
  {
    id: makeUUID(303),
    type: "task_assigned",
    payload: { type: "task_assigned", task_id: tasks[2].id, task_title: tasks[2].title, assigned_by: users[2].name },
    created_at: new Date(2025, 2, 4).toISOString(),
    is_read: false,
  },
  {
    id: makeUUID(304),
    type: "comment_added",
    payload: { type: "comment_added", task_id: tasks[3].id, task_title: tasks[3].title, comment_text: "Please review this PR", commented_by: users[3].name },
    created_at: new Date(2025, 2, 5).toISOString(),
    is_read: true,
  },
  {
    id: makeUUID(305),
    type: "project_invited",
    payload: { type: "project_invited", project_id: projects[1].id, project_name: projects[1].name, invited_by: users[1].name },
    created_at: new Date(2025, 2, 6).toISOString(),
    is_read: false,
  },
  {
    id: makeUUID(306),
    type: "task_assigned",
    payload: { type: "task_assigned", task_id: tasks[5].id, task_title: tasks[5].title, assigned_by: users[4].name },
    created_at: new Date(2025, 2, 7).toISOString(),
    is_read: false,
  },
  {
    id: makeUUID(307),
    type: "comment_added",
    payload: { type: "comment_added", task_id: tasks[6].id, task_title: tasks[6].title, comment_text: "Merged!", commented_by: users[5].name },
    created_at: new Date(2025, 2, 8).toISOString(),
    is_read: true,
  },
  {
    id: makeUUID(308),
    type: "project_invited",
    payload: { type: "project_invited", project_id: projects[2].id, project_name: projects[2].name, invited_by: users[2].name },
    created_at: new Date(2025, 2, 9).toISOString(),
    is_read: false,
  },
  {
    id: makeUUID(309),
    type: "task_assigned",
    payload: { type: "task_assigned", task_id: tasks[8].id, task_title: tasks[8].title, assigned_by: users[6].name },
    created_at: new Date(2025, 2, 10).toISOString(),
    is_read: false,
  },
];
