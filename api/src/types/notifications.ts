export interface NotificationData {
  title: string;
  body: string;
  badge?: number;
  sound?: string;
  data?: Record<string, any>;
}
