import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';

export class AuthService {
  constructor(private prisma: PrismaClient) {}

  async register(input: any): Promise<any> {
    // Check if user already exists
    const existingUser = await this.prisma.user.findFirst({
      where: {
        OR: [
          { email: input.email },
          { username: input.username }
        ]
      }
    });

    if (existingUser) {
      throw new Error(existingUser.email === input.email ? 'Email already exists' : 'Username already exists');
    }

    // Hash password
    const passwordHash = await bcrypt.hash(input.password, 12);

    // Create user
    const user = await this.prisma.user.create({
      data: {
        email: input.email,
        username: input.username,
        firstName: input.firstName,
        lastName: input.lastName,
        passwordHash,
      }
    });

    // Generate tokens with explicit typing
    const token = jwt.sign(
      { userId: user.id }, 
      process.env.JWT_SECRET || 'secret', 
      { expiresIn: (process.env.JWT_EXPIRY || '1h') as any }
    );
    
    const refreshToken = jwt.sign(
      { userId: user.id, type: 'refresh' }, 
      process.env.JWT_REFRESH_SECRET || 'refresh-secret', 
      { expiresIn: (process.env.JWT_REFRESH_EXPIRY || '7d') as any }
    );

    return {
      token,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        firstName: user.firstName,
        lastName: user.lastName,
        avatar: user.avatar,
        role: user.role,
        emailVerified: user.emailVerified,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      }
    };
  }

  async login(input: any): Promise<any> {
    // Find user
    const user = await this.prisma.user.findUnique({
      where: { email: input.email }
    });

    if (!user) {
      throw new Error('Invalid credentials');
    }

    // Verify password
    const isValid = await bcrypt.compare(input.password, user.passwordHash);
    if (!isValid) {
      throw new Error('Invalid credentials');
    }

    // Generate tokens
    const token = jwt.sign(
      { userId: user.id }, 
      process.env.JWT_SECRET || 'secret', 
      { expiresIn: '1h' as any }
    );
    
    const refreshToken = jwt.sign(
      { userId: user.id, type: 'refresh' }, 
      process.env.JWT_REFRESH_SECRET || 'refresh-secret', 
      { expiresIn: '7d' as any }
    );

    return {
      token,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        firstName: user.firstName,
        lastName: user.lastName,
        avatar: user.avatar,
        role: user.role,
        emailVerified: user.emailVerified,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      }
    };
  }

  verifyToken(token: string): { userId: string } {
    try {
      const payload: any = jwt.verify(token, process.env.JWT_SECRET || 'secret');
      return { userId: payload.userId };
    } catch (error) {
      throw new Error('Invalid token');
    }
  }
}