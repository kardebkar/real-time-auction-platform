import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
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
        sellerId: users[1].id, // John Seller
        categoryId: categories[1].id, // Collectibles
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
        sellerId: users[1].id, // John Seller
        categoryId: categories[2].id, // Art & Antiques
      },
    }),
  ]);

  // Create sample bids for active auction
  await Promise.all([
    prisma.bid.create({
      data: {
        amount: 160.00,
        userId: users[2].id, // Jane Bidder
        auctionId: auctions[0].id,
      },
    }),
    prisma.bid.create({
      data: {
        amount: 175.00,
        userId: users[0].id, // Admin
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
  console.log(`Created ${categories.length} categories`);
  console.log(`Created ${users.length} users`);
  console.log(`Created ${auctions.length} auctions`);
  console.log('Sample login credentials:');
  console.log('Admin: admin@auction.com / password123');
  console.log('Seller: seller@auction.com / password123');
  console.log('Bidder: bidder@auction.com / password123');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });