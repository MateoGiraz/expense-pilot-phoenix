require('dotenv').config({ path: '.env.test' });

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-jwt-secret-key-for-testing-only';
process.env.API_SECRET_KEY = process.env.API_SECRET_KEY || 'test-api-secret-key-for-testing-only';
process.env.PORT = process.env.PORT || '5440';
process.env.DATABASE_URL = process.env.DATABASE_URL || 'postgresql://mock:mock@localhost:5432/mock_db';

// Mock Prisma Client
const mockPrismaClient = {
  $connect: jest.fn().mockResolvedValue(undefined),
  $disconnect: jest.fn().mockResolvedValue(undefined),
  user: {
    deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
    findUnique: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
};

// Mock the PrismaClient before any imports
jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn(() => mockPrismaClient)
}));

// Reset all mocks before each test
beforeEach(() => {
  jest.clearAllMocks();
  
  // Reset mock implementations to default state
  mockPrismaClient.user.findUnique.mockReset();
  mockPrismaClient.user.findMany.mockReset();
  mockPrismaClient.user.create.mockReset();
  mockPrismaClient.user.update.mockReset();
  mockPrismaClient.user.deleteMany.mockResolvedValue({ count: 0 });
});

// Make mock client available globally for tests
global.mockPrismaClient = mockPrismaClient; 