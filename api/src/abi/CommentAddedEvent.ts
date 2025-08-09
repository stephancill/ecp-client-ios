export const CommentAddedEvent = {
  type: "event",
  name: "CommentAdded",
  inputs: [
    {
      name: "commentId",
      type: "bytes32",
      indexed: true,
      internalType: "bytes32",
    },
    {
      name: "author",
      type: "address",
      indexed: true,
      internalType: "address",
    },
    {
      name: "app",
      type: "address",
      indexed: true,
      internalType: "address",
    },
    {
      name: "channelId",
      type: "uint256",
      indexed: false,
      internalType: "uint256",
    },
    {
      name: "parentId",
      type: "bytes32",
      indexed: false,
      internalType: "bytes32",
    },
    {
      name: "createdAt",
      type: "uint96",
      indexed: false,
      internalType: "uint96",
    },
    {
      name: "content",
      type: "string",
      indexed: false,
      internalType: "string",
    },
    {
      name: "targetUri",
      type: "string",
      indexed: false,
      internalType: "string",
    },
    {
      name: "commentType",
      type: "uint8",
      indexed: false,
      internalType: "uint8",
    },
    {
      name: "authMethod",
      type: "uint8",
      indexed: false,
      internalType: "uint8",
    },
    {
      name: "metadata",
      type: "tuple[]",
      indexed: false,
      internalType: "struct Metadata.MetadataEntry[]",
      components: [
        {
          name: "key",
          type: "bytes32",
          internalType: "bytes32",
        },
        {
          name: "value",
          type: "bytes",
          internalType: "bytes",
        },
      ],
    },
  ],
  anonymous: false,
} as const;
