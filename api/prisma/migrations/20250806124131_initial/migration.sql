-- CreateTable
CREATE TABLE "public"."users" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."notifications" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "deviceToken" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."approvals" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "author" TEXT NOT NULL,
    "app" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL,
    "txHash" TEXT NOT NULL,
    "logIndex" INTEGER NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "approvals_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "notifications_userId_idx" ON "public"."notifications"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "notifications_userId_deviceToken_key" ON "public"."notifications"("userId", "deviceToken");

-- CreateIndex
CREATE INDEX "approvals_app_idx" ON "public"."approvals"("app");

-- CreateIndex
CREATE INDEX "approvals_author_idx" ON "public"."approvals"("author");

-- CreateIndex
CREATE INDEX "approvals_chainId_idx" ON "public"."approvals"("chainId");

-- CreateIndex
CREATE UNIQUE INDEX "approvals_author_app_chainId_key" ON "public"."approvals"("author", "app", "chainId");

-- AddForeignKey
ALTER TABLE "public"."notifications" ADD CONSTRAINT "notifications_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."approvals" ADD CONSTRAINT "approvals_app_fkey" FOREIGN KEY ("app") REFERENCES "public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
