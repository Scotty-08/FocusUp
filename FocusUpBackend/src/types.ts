export interface UserRow {
  id: string;
  apple_sub: string | null;
  email: string | null;
  password_hash: string | null;
  display_name: string | null;
  created_at: Date;
}

export interface TaskRow {
  id: string;
  user_id: string;
  title: string;
  is_completed: boolean;
  due_date: string | null; // Postgres DATE comes back as "YYYY-MM-DD"
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
}

export interface TaskDTO {
  id: string;
  title: string;
  isCompleted: boolean;
  dueDate: string | null;
  isActive: boolean;
}

export function toTaskDTO(row: TaskRow): TaskDTO {
  return {
    id: row.id,
    title: row.title,
    isCompleted: row.is_completed,
    dueDate: row.due_date,
    isActive: row.is_active,
  };
}

export interface AuthUserDTO {
  id: string;
  email: string | null;
  displayName: string | null;
}

export function toAuthUserDTO(row: UserRow): AuthUserDTO {
  return {
    id: row.id,
    email: row.email,
    displayName: row.display_name,
  };
}
