import {
  fetchComment,
  IndexerAPICommentWithRepliesSchemaType,
} from "@ecp.eth/sdk/indexer";
import { redisCache, withCache } from "./redis";

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export async function fetchCommentWithRetries(params: {
  chainId: number;
  commentId: `0x${string}`;
  maxAttempts?: number;
  initialDelayMs?: number;
}) {
  const { chainId, commentId, maxAttempts = 5, initialDelayMs = 1000 } = params;

  console.log("fetching comment", { commentId, maxAttempts, initialDelayMs });

  let lastError: unknown = undefined;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      console.log("fetching comment attempt", attempt);
      const comment = await fetchComment({ chainId, commentId });
      console.log("fetched comment");
      return comment;
    } catch (error) {
      lastError = error;
      // Exponential backoff: 1s, 2s, 4s, 8s, ...
      const shouldRetry = attempt < maxAttempts;
      if (!shouldRetry) break;

      const backoffMs = initialDelayMs * 2 ** (attempt - 1);
      await delay(backoffMs);
    }
  }

  console.error("Failed to fetch comment after retries", !!lastError);

  throw lastError ?? new Error("Failed to fetch comment after retries");
}

export async function fetchCachedComment(params: {
  chainId: number;
  commentId: `0x${string}`;
  options?: {
    ttl?: number;
    maxAttempts?: number;
    initialDelayMs?: number;
  };
}) {
  const { chainId, commentId, options } = params;

  const result = await withCache(
    `ecp:comment:${chainId}:${commentId}`,
    () =>
      fetchCommentWithRetries({
        chainId,
        commentId,
        maxAttempts: options?.maxAttempts,
        initialDelayMs: options?.initialDelayMs,
      }),
    {
      ttl: options?.ttl ?? 60 * 60 * 24 * 2, // 2 days
    }
  );

  return result;
}

export async function cacheUserData(params: {
  author: `0x${string}`;
  profile: IndexerAPICommentWithRepliesSchemaType["author"];
}) {
  const { author, profile } = params;

  await redisCache.setex(
    `ecp:author:${author.toLowerCase()}`,
    60 * 60 * 24 * 2, // 7 days
    JSON.stringify(profile)
  );
}

export async function fetchBatchCachedUserData(params: {
  authors: `0x${string}`[];
}) {
  const { authors } = params;
  const profiles = await redisCache.mget(
    authors.map((author) => `ecp:author:${author.toLowerCase()}`)
  );

  return profiles.reduce((acc, profile, index) => {
    if (profile) {
      acc[authors[index]] = JSON.parse(profile);
    }
    return acc;
  }, {} as Record<`0x${string}`, IndexerAPICommentWithRepliesSchemaType["author"]>);
}
