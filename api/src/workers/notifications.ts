import { Worker } from "bullmq";
import { NOTIFICATIONS_QUEUE_NAME } from "../lib/constants";
import {
  sanitizeNotificationData,
  sendNotficationToUser,
} from "../lib/notifications";
import { prisma } from "../lib/prisma";
import { redisQueue } from "../lib/redis";
import { NotificationJobData } from "../types/jobs";

export const notificationsBulkWorker = new Worker<NotificationJobData>(
  NOTIFICATIONS_QUEUE_NAME,
  async (job) => {
    /**
     * The app uses an app address to post on behalf of a user address
     * The app account is also the user's primary id with this backend
     * So for a notification for an author, we need to find their associated app address
     * via the approvals table and then we need to join that with the user id on the notifications table
     */

    let targetUserIds: string[] = [];

    if (job.data.targetUserIds && job.data.targetUserIds.length > 0) {
      // Directly targeted user IDs (e.g., subscribers)
      targetUserIds = Array.from(new Set(job.data.targetUserIds));
    } else {
      // Find app accounts that are approved to post for this author
      const approvals = await prisma.approval.findMany({
        where: {
          author: job.data.author.toLowerCase(),
          deletedAt: null,
          user: { notifications: { some: {} } },
        },
        select: { app: true },
      });
      targetUserIds = Array.from(new Set(approvals.map((a) => a.app)));
    }

    if (targetUserIds.length === 0) {
      console.log(
        `No target users found for notification job for author ${job.data.author} skipping.`
      );
      return;
    }

    // Persist notification events for each target user
    try {
      const sanitized = sanitizeNotificationData(job.data.notification);
      await prisma.notificationEvent.createMany({
        data: targetUserIds.map((userId) => ({
          userId,
          type: (sanitized.data?.type as any) ?? "system",
          originAddress:
            typeof sanitized.data?.actorAddress === "string"
              ? sanitized.data?.actorAddress.toLowerCase()
              : null,
          chainId: (sanitized.data?.chainId as any) ?? null,
          subjectCommentId: (sanitized.data?.commentId as any) ?? null,
          targetCommentId: (sanitized.data?.parentId as any) ?? null,
          parentCommentId: (sanitized.data?.parentId as any) ?? null,
          reactionType:
            sanitized.data?.type === "reaction" ||
            sanitized.data?.type === "like"
              ? (sanitized.data?.type as any)
              : (sanitized.data?.reactionType as any) ?? null,
          groupKey:
            sanitized.data?.type === "reaction"
              ? `reaction:${sanitized.data?.parentId ?? ""}:${
                  sanitized.data?.reactionType ?? sanitized.data?.type
                }`
              : null,
          title: sanitized.title,
          body: sanitized.body,
          badge: sanitized.badge ?? null,
          sound: sanitized.sound ?? null,
          data: sanitized.data ?? undefined,
        })),
      });
    } catch (e) {
      console.error("Failed to persist notification events:", e);
    }

    await Promise.allSettled(
      targetUserIds.map((userId) =>
        sendNotficationToUser({
          userId,
          notification: job.data.notification,
        })
      )
    );

    console.log(
      `Queued notifications for ${targetUserIds.length} app user(s) for author ${job.data.author}`
    );
  },
  {
    connection: redisQueue,
  }
);
