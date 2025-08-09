import { fetchComment } from "@ecp.eth/sdk/dist/esm/indexer";

export function truncateAddress(address: string) {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export type EcpAuthor = Awaited<ReturnType<typeof fetchComment>>["author"];

export function getAuthorDisplayName(author: EcpAuthor) {
  return (
    author.ens?.name ??
    author.farcaster?.username ??
    truncateAddress(author.address)
  );
}

export function getCommentAuthorUsername(author: EcpAuthor) {
  return getAuthorDisplayName(author);
}
