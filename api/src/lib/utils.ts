import { fetchComment } from "@ecp.eth/sdk/dist/esm/indexer";

export function truncateAddress(address: string) {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function getCommentAuthorUsername(
  author: Awaited<ReturnType<typeof fetchComment>>["author"]
) {
  return (
    author.ens?.name ??
    author.farcaster?.username ??
    truncateAddress(author.address)
  );
}
