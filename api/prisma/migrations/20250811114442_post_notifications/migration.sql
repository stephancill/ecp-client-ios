-- AlterEnum
ALTER TYPE "public"."NotificationType" ADD VALUE 'post';

-- CreateTable
CREATE TABLE "public"."post_subscriptions" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "targetAuthor" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "post_subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "post_subscriptions_targetAuthor_idx" ON "public"."post_subscriptions"("targetAuthor");

-- CreateIndex
CREATE INDEX "post_subscriptions_userId_idx" ON "public"."post_subscriptions"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "post_subscriptions_userId_targetAuthor_key" ON "public"."post_subscriptions"("userId", "targetAuthor");

-- AddForeignKey
ALTER TABLE "public"."post_subscriptions" ADD CONSTRAINT "post_subscriptions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
