#!/bin/bash

echo "🗄️ Setting up Prisma Schema and Database..."

# Create Prisma schema
cat > services/api-gateway/prisma/schema.prisma << 'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  password  String
  firstName String?
  lastName  String?
  role      UserRole @default(USER)
  isActive  Boolean  @default(true)
  
  phone       String?
  avatar      String?
  dateOfBirth DateTime?
  address     Json?
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  lastLogin DateTime?
  
  auctions Auction[] @relation("AuctionSeller")
  bids     Bid[]
  watchedAuctions AuctionWatcher[]
  
  @@map("users")
}

enum UserRole {
  USER
  ADMIN
  MODERATOR
}

model Category {
  id          String @id @default(cuid())
  name        String @unique
  description String?
  slug        String @unique
  isActive    Boolean @default(true)
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  auctions Auction[]
  
  @@map("categories")
}

model Auction {
  id               String        @id @default(cuid())
  title            String
  description      String
  startingPrice    Float
  currentPrice     Float?
  minimumIncrement Float         @default(1.0)
  buyNowPrice      Float?
  
  startTime DateTime
  endTime   DateTime
  
  status    AuctionStatus @default(DRAFT)
  images    String[]      @default([])
  tags      String[]      @default([])
  
  bidCount     Int @default(0)
  viewCount    Int @default(0)
  watcherCount Int @default(0)
  
  sellerId   String
  seller     User     @relation("AuctionSeller", fields: [sellerId], references: [id], onDelete: Cascade)
  categoryId String?
  category   Category? @relation(fields: [categoryId], references: [id])
  
  bids     Bid[]
  watchers AuctionWatcher[]
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@index([status, startTime, endTime])
  @@index([categoryId])
  @@index([sellerId])
  @@index([currentPrice])
  @@map("auctions")
}

enum AuctionStatus {
  DRAFT
  SCHEDULED
  ACTIVE
  ENDED
  CANCELLED
  SOLD
}

model Bid {
  id        String   @id @default(cuid())
  amount    Float
  timestamp DateTime @default(now())
  isWinning Boolean  @default(false)
  
  userId    String
  user      User    @relation(fields: [userId], references: [id], onDelete: Cascade)
  auctionId String
  auction   Auction @relation(fields: [auctionId], references: [id], onDelete: Cascade)
  
  @@unique([userId, auctionId, amount])
  @@index([auctionId, amount])
  @@index([userId, timestamp])
  @@index([timestamp])
  @@map("bids")
}

model AuctionWatcher {
  id        String   @id @default(cuid())
  createdAt DateTime @default(now())
  
  userId    String
  user      User    @relation(fields: [userId], references: [id], onDelete: Cascade)
  auctionId String
  auction   Auction @relation(fields: [auctionId], references: [id], onDelete: Cascade)
  
  @@unique([userId, auctionId])
  @@map("auction_watchers")
}
EOF

# Create seed file
cat > services/api-gateway/prisma/seed.ts << 'EOF'
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // Create categories
  const categories = await Promise.all([
    prisma.category.upsert({
      where: { slug: 'electronics' },
      update: {},
      create: {
        name: 'Electronics',
        description: 'Electronic devices and gadgets',
        slug: 'electronics',
      },
    }),
    prisma.category.upsert({
      where: { slug: 'collectibles' },
      update: {},
      create: {
        name: 'Collectibles',
        description: 'Rare and collectible items',
        slug: 'collectibles',
      },
    }),
    prisma.category.upsert({
      where: { slug: 'art' },
      update: {},
      create: {
        name: 'Art & Antiques',
        description: 'Fine art and antique items',
        slug: 'art',
      },
    }),
    prisma.category.upsert({
      where: { slug: 'vehicles' },
      update: {},
      create: {
        name: 'Vehicles',
        description: 'Cars, motorcycles, and other vehicles',
        slug: 'vehicles',
      },
    }),
  ]);

  console.log(`✅ Created ${categories.length} categories`);

  // Create users
  const hashedPassword = await bcrypt.hash('password123', 10);
  
  const users = await Promise.all([
    prisma.user.upsert({
      where: { email: 'admin@auction.com' },
      update: {},
      create: {
        email: 'admin@auction.com',
        password: hashedPassword,
        firstName: 'Admin',
        lastName: 'User',
        role: 'ADMIN',
      },
    }),
    prisma.user.upsert({
      where: { email: 'seller@auction.com' },
      update: {},
      create: {
        email: 'seller@auction.com',
        password: hashedPassword,
        firstName: 'John',
        lastName: 'Seller',
        role: 'USER',
      },
    }),
    prisma.user.upsert({
      where: { email: 'bidder@auction.com' },
      update: {},
      create: {
        email: 'bidder@auction.com',
        password: hashedPassword,
        firstName: 'Jane',
        lastName: 'Bidder',
        role: 'USER',
      },
    }),
  ]);

  console.log(`✅ Created ${users.length} users`);

  // Create sample auctions
  const now = new Date();
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const nextWeek = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  const auctions = await Promise.all([
    prisma.auction.create({
      data: {
        title: 'Vintage Camera Collection',
        description: 'Rare 1960s film cameras in excellent condition',
        startingPrice: 150.00,
        currentPrice: 150.00,
        minimumIncrement: 10.00,
        startTime: now,
        endTime: tomorrow,
        status: 'ACTIVE',
        images: [
          'https://images.unsplash.com/photo-1606983340126-99ab4feaa64a',
          'https://images.unsplash.com/photo-1606986628253-b8b20db42b09'
        ],
        tags: ['vintage', 'camera', 'photography', 'collectible'],
        sellerId: users[1].id,
        categoryId: categories[1].id,
      },
    }),
    prisma.auction.create({
      data: {
        title: 'Modern Abstract Painting',
        description: 'Original acrylic painting by emerging artist',
        startingPrice: 500.00,
        currentPrice: 500.00,
        minimumIncrement: 25.00,
        startTime: tomorrow,
        endTime: nextWeek,
        status: 'SCHEDULED',
        images: [
          'https://images.unsplash.com/photo-1578662996442-48f60103fc96'
        ],
        tags: ['art', 'painting', 'original', 'abstract'],
        sellerId: users[1].id,
        categoryId: categories[2].id,
      },
    }),
  ]);

  console.log(`✅ Created ${auctions.length} auctions`);

  // Create sample bids for active auction
  await Promise.all([
    prisma.bid.create({
      data: {
        amount: 160.00,
        userId: users[2].id,
        auctionId: auctions[0].id,
      },
    }),
    prisma.bid.create({
      data: {
        amount: 175.00,
        userId: users[0].id,
        auctionId: auctions[0].id,
      },
    }),
  ]);

  // Update auction current price
  await prisma.auction.update({
    where: { id: auctions[0].id },
    data: {
      currentPrice: 175.00,
      bidCount: 2,
    },
  });

  console.log('✅ Database seeded successfully!');
  console.log('');
  console.log('📝 Sample login credentials:');
  console.log('👤 Admin: admin@auction.com / password123');
  console.log('👤 Seller: seller@auction.com / password123');
  console.log('👤 Bidder: bidder@auction.com / password123');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
EOF

echo "✅ Prisma schema and seed file created!"