import { NotificationData } from "./notifications";

export type NotificationJobData = {
  author: string; // origin author address for context (or unused when targeting explicit users)
  notification: NotificationData;
  targetUserIds?: string[]; // when provided, send directly to these app userIds instead of resolving via approvals
};

export type CommentJobData = {
  commentId: string;
  content?: string;
  parentId?: string;
  commentType?: number;
  chainId: number;
};
