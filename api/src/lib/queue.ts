import { Queue } from "bullmq";
import { COMMENTS_QUEUE_NAME, NOTIFICATIONS_QUEUE_NAME } from "./constants";
import { redisQueue } from "./redis";
import { CommentJobData, NotificationJobData } from "../types/jobs";

export const notificationsQueue = new Queue<NotificationJobData>(
  NOTIFICATIONS_QUEUE_NAME,
  {
    connection: redisQueue,
  }
);

export const commentsQueue = new Queue<CommentJobData>(COMMENTS_QUEUE_NAME, {
  connection: redisQueue,
});
