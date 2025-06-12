import { Server } from 'socket.io';
import { createServer } from 'http';
import jwt from 'jsonwebtoken';
import { Redis } from 'ioredis';

export class WebSocketManager {
  private io: Server;
  private redis: Redis;

  constructor(httpServer: any, redis: Redis) {
    this.redis = redis;
    this.io = new Server(httpServer, {
      cors: {
        origin: process.env.ALLOWED_ORIGINS?.split(',') || ["http://localhost:3000"],
        methods: ["GET", "POST"]
      }
    });

    this.setupAuthentication();
    this.setupEventHandlers();
  }

  private setupAuthentication() {
    this.io.use(async (socket, next) => {
      try {
        const token = socket.handshake.auth.token;
        if (!token) {
          throw new Error('Authentication required');
        }

        const payload: any = jwt.verify(token, process.env.JWT_SECRET || 'secret');
        socket.data.userId = payload.userId;
        next();
      } catch (error) {
        next(new Error('Authentication failed'));
      }
    });
  }

  private setupEventHandlers() {
    this.io.on('connection', (socket) => {
      console.log(`User ${socket.data.userId} connected`);

      // Join auction rooms
      socket.on('joinAuction', (auctionId: string) => {
        socket.join(`auction:${auctionId}`);
        
        // Track active users in auction
        this.redis.sadd(`auction:${auctionId}:users`, socket.data.userId);
        
        // Notify others
        socket.to(`auction:${auctionId}`).emit('userJoined', {
          userId: socket.data.userId,
          timestamp: new Date()
        });
      });

      // Leave auction rooms
      socket.on('leaveAuction', (auctionId: string) => {
        socket.leave(`auction:${auctionId}`);
        
        // Remove from active users
        this.redis.srem(`auction:${auctionId}:users`, socket.data.userId);
        
        // Notify others
        socket.to(`auction:${auctionId}`).emit('userLeft', {
          userId: socket.data.userId,
          timestamp: new Date()
        });
      });

      // Handle real-time bidding
      socket.on('quickBid', async (data: { auctionId: string; amount: number }) => {
        try {
          // This would integrate with the BiddingService
          // For now, emit to auction room
          this.io.to(`auction:${data.auctionId}`).emit('bidUpdate', {
            userId: socket.data.userId,
            amount: data.amount,
            timestamp: new Date()
          });
        } catch (error) {
          socket.emit('bidError', { message: error.message });
        }
      });

      // Handle disconnection
      socket.on('disconnect', async () => {
        console.log(`User ${socket.data.userId} disconnected`);
        
        // Remove from all auction rooms
        const rooms = Array.from(socket.rooms);
        for (const room of rooms) {
          if (room.startsWith('auction:')) {
            const auctionId = room.replace('auction:', '');
            await this.redis.srem(`auction:${auctionId}:users`, socket.data.userId);
          }
        }
      });
    });
  }

  // Method to emit events from GraphQL subscriptions
  public emitToAuction(auctionId: string, event: string, data: any) {
    this.io.to(`auction:${auctionId}`).emit(event, data);
  }

  public async getActiveUsers(auctionId: string): Promise<string[]> {
    return await this.redis.smembers(`auction:${auctionId}:users`);
  }
}
