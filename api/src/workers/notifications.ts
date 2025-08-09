import { Worker } from "bullmq";
import { NOTIFICATIONS_QUEUE_NAME } from "../lib/constants";
import { NotificationJobData } from "../types/jobs";
import { sendNotficationToUser } from "../lib/notifications";
import { prisma } from "../lib/prisma";
import { redisQueue } from "../lib/redis";
import { getAddress } from "viem";

export const notificationsBulkWorker = new Worker<NotificationJobData>(
  NOTIFICATIONS_QUEUE_NAME,
  async (job) => {
    /**
     * The app uses an app address to post on behalf of a user address
     * The app account is also the user's primary id with this backend
     * So for a notification for an author, we need to find their associated app address
     * via the approvals table and then we need to join that with the user id on the notifications table
     */

    // Find app accounts that are approved to post for this author on this chain
    const approvals = await prisma.approval.findMany({
      where: {
        author: getAddress(job.data.author),
        deletedAt: null,
        // Only include approvals where the related app user has at least one notification record
        user: {
          notifications: {
            some: {},
          },
        },
      },
      select: { app: true },
    });

    const uniqueAppUserIds = Array.from(new Set(approvals.map((a) => a.app)));

    if (uniqueAppUserIds.length === 0) {
      console.log(
        `No approved app accounts found for author ${job.data.author} skipping.`
      );
      return;
    }

    await Promise.allSettled(
      uniqueAppUserIds.map((userId) =>
        sendNotficationToUser({
          userId,
          notification: job.data.notification,
        })
      )
    );

    console.log(
      `Queued notifications for ${uniqueAppUserIds.length} app user(s) for author ${job.data.author}`
    );
  },
  {
    connection: redisQueue,
  }
);
