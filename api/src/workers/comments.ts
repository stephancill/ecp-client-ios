import { Worker } from "bullmq";
import {
  COMMENTS_QUEUE_NAME,
  NOTIFICATIONS_QUEUE_NAME,
} from "../lib/constants";
import { fetchCachedComment } from "../lib/ecp";
import { notificationsQueue } from "../lib/queue";
import { redisQueue } from "../lib/redis";
import { getCommentAuthorUsername } from "../lib/utils";
import { CommentJobData } from "../types/jobs";

export const commentWorker = new Worker<CommentJobData>(
  COMMENTS_QUEUE_NAME,
  async (job) => {
    const { commentId, content, parentId, commentType, chainId } = job.data;
    // TODO: Implement comment processing
    console.log(`Processing comment ${commentId}`);

    // Fetch the comment from the ECP hosted API
    const comment = await fetchCachedComment({
      chainId: job.data.chainId,
      commentId: commentId as `0x${string}`,
      options: {
        maxAttempts: 5,
        initialDelayMs: 1000,
      },
    });

    const authorUsername = getCommentAuthorUsername(comment.author);

    if (comment.parentId) {
      // Fetch parent comment
      const parentComment = await fetchCachedComment({
        chainId: job.data.chainId,
        commentId: parentId as `0x${string}`,
        options: {
          maxAttempts: 5,
          initialDelayMs: 1000,
        },
      });

      if (commentType === 1) {
        // Notify parent author if reaction
        await notificationsQueue.add(NOTIFICATIONS_QUEUE_NAME, {
          author: parentComment.author.address,
          notification: {
            title: `@${authorUsername} ${
              comment.content === "like" ? "liked" : "reacted"
            }`,
            body: `"${parentComment.content}"`,
          },
        });
      } else {
        console.log("Notifying parent if reply", parentComment.author.address);
        // Notify parent if reply
        await notificationsQueue.add(NOTIFICATIONS_QUEUE_NAME, {
          author: parentComment.author.address,
          notification: {
            title: `@${authorUsername} replied`,
            body: comment.content,
          },
        });
      }
    }

    // Notify mentioned users
    const mentionedAddresses = comment.references
      .map((reference) => {
        if (reference.type === "ens") {
          return reference.address.toLowerCase();
        } else if (reference.type === "farcaster") {
          return reference.address.toLowerCase();
        }
      })
      .filter((address) => address !== undefined) as string[];

    const uniqueMentionedAddresses = Array.from(new Set(mentionedAddresses));

    for (const address of uniqueMentionedAddresses) {
      await notificationsQueue.add(NOTIFICATIONS_QUEUE_NAME, {
        author: address,
        notification: {
          title: `@${authorUsername} mentioned you`,
          body: comment.content,
        },
      });
    }

    // TODO: Notify followers of author
  },
  {
    connection: redisQueue,
  }
);
