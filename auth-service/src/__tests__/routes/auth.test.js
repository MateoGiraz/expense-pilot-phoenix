const request = require('supertest');
const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const authRoutes = require('../../routes/auth');
const { apiKeyAuth } = require('../../middleware/auth');

const app = express();
app.use(express.json());
app.use('/auth', apiKeyAuth, authRoutes);

describe('Auth Routes', () => {
  let mockPrismaClient;

  beforeEach(() => {
    mockPrismaClient = global.mockPrismaClient;
  });

  describe('POST /auth/validate-token', () => {
    it('should validate a valid token successfully', async () => {
      const userData = {
        userId: 1,
        email: 'test@example.com',
        role: 'member',
        companyId: 1
      };
      const token = jwt.sign(userData, process.env.JWT_SECRET, { expiresIn: '24h' });

      const response = await request(app)
        .post('/auth/validate-token')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ token });

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        valid: true,
        user: {
          id: userData.userId,
          email: userData.email,
          role: userData.role,
          companyId: userData.companyId
        }
      });
    });

    it('should reject when no token is provided', async () => {
      const response = await request(app)
        .post('/auth/validate-token')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({});

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        valid: false,
        error: 'No token provided'
      });
    });

    it('should reject invalid token', async () => {
      const response = await request(app)
        .post('/auth/validate-token')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ token: 'invalid-token' });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        valid: false,
        error: 'Invalid token'
      });
    });

    it('should reject expired token', async () => {
      const userData = {
        userId: 1,
        email: 'test@example.com',
        role: 'member',
        companyId: 1
      };
      const expiredToken = jwt.sign(userData, process.env.JWT_SECRET, { expiresIn: '-1h' });

      const response = await request(app)
        .post('/auth/validate-token')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ token: expiredToken });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        valid: false,
        error: 'Invalid token'
      });
    });
  });

  describe('POST /auth/login', () => {
    let testUser;

    beforeEach(async () => {
      const passwordHash = await bcrypt.hash('password123', 10);
      testUser = {
        id: 1,
        email: 'test@example.com',
        passwordHash,
        role: 'member',
        companyId: 1,
        invited: false,
        invitationAcceptedAt: null
      };
    });

    it('should login successfully with valid credentials', async () => {
      mockPrismaClient.user.findUnique.mockResolvedValue(testUser);

      const response = await request(app)
        .post('/auth/login')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({
          email: 'test@example.com',
          password: 'password123'
        });

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('token');
      expect(response.body).toHaveProperty('user');
      expect(response.body).toHaveProperty('message', 'Login successful');
      expect(response.body.user).toEqual({
        id: testUser.id,
        email: testUser.email,
        role: testUser.role,
        companyId: testUser.companyId,
        invited: testUser.invited
      });

      const decoded = jwt.verify(response.body.token, process.env.JWT_SECRET);
      expect(decoded.userId).toBe(testUser.id);
      expect(decoded.email).toBe(testUser.email);
      
      expect(mockPrismaClient.user.findUnique).toHaveBeenCalledWith({
        where: { email: 'test@example.com' }
      });
    });

    it('should update invitation status on first login', async () => {
      const passwordHash = await bcrypt.hash('password123', 10);
      const invitedUser = {
        id: 2,
        email: 'invited@example.com',
        passwordHash,
        role: 'member',
        companyId: 1,
        invited: true,
        invitationAcceptedAt: null
      };

      const updatedUser = {
        ...invitedUser,
        invited: false,
        invitationAcceptedAt: new Date()
      };

      mockPrismaClient.user.findUnique.mockResolvedValue(invitedUser);
      mockPrismaClient.user.update.mockResolvedValue(updatedUser);

      const response = await request(app)
        .post('/auth/login')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({
          email: 'invited@example.com',
          password: 'password123'
        });

      expect(response.status).toBe(200);
      expect(response.body.user.invited).toBe(true); // User data returned before update

      expect(mockPrismaClient.user.update).toHaveBeenCalledWith({
        where: { id: invitedUser.id },
        data: {
          invited: false,
          invitationAcceptedAt: expect.any(Date)
        }
      });
    });

    it('should reject login with invalid email', async () => {
      mockPrismaClient.user.findUnique.mockResolvedValue(null);

      const response = await request(app)
        .post('/auth/login')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({
          email: 'nonexistent@example.com',
          password: 'password123'
        });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({ error: 'Invalid credentials' });
    });

    it('should reject login with invalid password', async () => {
      mockPrismaClient.user.findUnique.mockResolvedValue(testUser);

      const response = await request(app)
        .post('/auth/login')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({
          email: 'test@example.com',
          password: 'wrongpassword'
        });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({ error: 'Invalid credentials' });
    });

    it('should reject login with invalid email format', async () => {
      const response = await request(app)
        .post('/auth/login')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({
          email: 'invalid-email',
          password: 'password123'
        });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Validation failed');
      expect(response.body.details).toBeDefined();
    });

    it('should reject login with empty password', async () => {
      const response = await request(app)
        .post('/auth/login')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({
          email: 'test@example.com',
          password: ''
        });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Validation failed');
      expect(response.body.details).toBeDefined();
    });

    it('should reject login without API key', async () => {
      const response = await request(app)
        .post('/auth/login')
        .send({
          email: 'test@example.com',
          password: 'password123'
        });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({ error: 'Unauthorized' });
    });

    it('should handle database errors during login', async () => {
      mockPrismaClient.user.findUnique.mockRejectedValue(new Error('Database error'));

      const response = await request(app)
        .post('/auth/login')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({
          email: 'test@example.com',
          password: 'password123'
        });

      expect(response.status).toBe(500);
    });
  });
}); 