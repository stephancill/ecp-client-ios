import { NotificationData } from "./notifications";

export type NotificationJobData = {
  author: string;
  notification: NotificationData;
};

export type CommentJobData = {
  commentId: string;
  content?: string;
  parentId?: string;
  commentType?: number;
  chainId: number;
};
