-- CreateEnum
CREATE TYPE "public"."NotificationType" AS ENUM ('reply', 'reaction', 'mention', 'follow', 'system');

-- CreateTable
CREATE TABLE "public"."notification_events" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "badge" INTEGER,
    "sound" TEXT,
    "data" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "chainId" INTEGER,
    "groupKey" TEXT,
    "originAddress" TEXT,
    "parentCommentId" TEXT,
    "reactionType" TEXT,
    "subjectCommentId" TEXT,
    "targetCommentId" TEXT,
    "type" "public"."NotificationType" NOT NULL DEFAULT 'system',

    CONSTRAINT "notification_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "notification_events_userId_createdAt_idx" ON "public"."notification_events"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "notification_events_type_idx" ON "public"."notification_events"("type");

-- CreateIndex
CREATE INDEX "notification_events_originAddress_idx" ON "public"."notification_events"("originAddress");

-- CreateIndex
CREATE INDEX "notification_events_targetCommentId_idx" ON "public"."notification_events"("targetCommentId");

-- CreateIndex
CREATE INDEX "notification_events_targetCommentId_reactionType_idx" ON "public"."notification_events"("targetCommentId", "reactionType");

-- AddForeignKey
ALTER TABLE "public"."notification_events" ADD CONSTRAINT "notification_events_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
