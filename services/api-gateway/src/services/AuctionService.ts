import { PrismaClient } from '@prisma/client';

export class AuctionService {
  constructor(private prisma: PrismaClient) {}

  async getAuctions(filters: any = {}) {
    const where: any = {};
    
    if (filters.status) where.status = filters.status;
    if (filters.categoryId) where.categoryId = filters.categoryId;
    
    return await this.prisma.auction.findMany({
      where,
      include: {
        seller: true,
        category: true,
        bids: {
          orderBy: { amount: 'desc' },
          take: 1,
          include: { bidder: true }
        },
        _count: {
          select: { bids: true, watchers: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });
  }

  async getAuctionById(id: string) {
    return await this.prisma.auction.findUnique({
      where: { id },
      include: {
        seller: true,
        category: true,
        bids: {
          orderBy: { timestamp: 'desc' },
          include: { bidder: true }
        },
        watchers: { include: { user: true } }
      }
    });
  }
}