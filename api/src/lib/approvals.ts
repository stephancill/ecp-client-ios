import { prisma } from "./prisma";

type SyncApprovalsParams = {
  appAddress: string;
  chainId?: number;
};

type SyncApprovalsResult = {
  approved: boolean;
  approvalsCount: number;
};

/**
 * Fetch approvals for an app from the ECP API, upsert them into the database,
 * and return whether the app currently has an active approval (deletedAt null).
 *
 * Best-effort: network or DB errors are handled and the function will still
 * return an answer based on whatever data is available locally.
 */
export async function syncApprovalsForApp(
  params: SyncApprovalsParams
): Promise<SyncApprovalsResult> {
  const chainId = params.chainId ?? 8453;
  const app = params.appAddress.toLowerCase();

  // Ensure the app user exists
  try {
    await prisma.user.upsert({
      where: { id: app },
      update: {},
      create: { id: app },
    });
  } catch (error) {
    console.error("syncApprovalsForApp: failed to upsert user:", error);
    // Continue anyway; approvals upsert may still succeed if FK is not required
  }

  // Try to fetch and upsert approvals from remote API
  try {
    const apiUrl = `https://api.ethcomments.xyz/api/approvals?app=${app}&chainId=${chainId}&limit=50&offset=0`;
    const response = await fetch(apiUrl);

    if (response.ok) {
      const data = await response.json();
      if (data?.results && Array.isArray(data.results) && data.results.length) {
        await Promise.all(
          data.results.map((approval: any) =>
            prisma.approval.upsert({
              where: {
                author_app_chainId: {
                  author: approval.author.toLowerCase(),
                  app,
                  chainId: approval.chainId,
                },
              },
              update: {
                id: approval.id,
                txHash: approval.txHash,
                logIndex: approval.logIndex,
                updatedAt: new Date(approval.updatedAt),
                deletedAt: approval.deletedAt
                  ? new Date(approval.deletedAt)
                  : null,
              },
              create: {
                id: approval.id,
                author: approval.author.toLowerCase(),
                app,
                chainId: approval.chainId,
                txHash: approval.txHash,
                logIndex: approval.logIndex,
                createdAt: new Date(approval.createdAt),
                updatedAt: new Date(approval.updatedAt),
                deletedAt: approval.deletedAt
                  ? new Date(approval.deletedAt)
                  : null,
              },
            })
          )
        );
      }
    }
  } catch (error) {
    console.error(
      "syncApprovalsForApp: failed to fetch/upsert approvals:",
      error
    );
  }

  // Determine approval status from DB (fallbacks to local data if network fails)
  try {
    const approvalsCount = await prisma.approval.count({
      where: {
        app,
        chainId,
        deletedAt: null,
      },
    });

    return { approved: approvalsCount > 0, approvalsCount };
  } catch (error) {
    console.error(
      "syncApprovalsForApp: failed to check approval status:",
      error
    );
    return { approved: false, approvalsCount: 0 };
  }
}
