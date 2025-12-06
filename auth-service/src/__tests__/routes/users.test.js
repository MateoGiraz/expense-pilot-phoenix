const request = require('supertest');
const express = require('express');
const bcrypt = require('bcrypt');
const userRoutes = require('../../routes/users');
const { apiKeyAuth } = require('../../middleware/auth');

const app = express();
app.use(express.json());
app.use('/users', apiKeyAuth, userRoutes);

describe('User Routes', () => {
  let mockPrismaClient;

  beforeEach(() => {
    mockPrismaClient = global.mockPrismaClient;
  });

  describe('POST /users', () => {
    it('should create a new user successfully', async () => {
      const userData = {
        email: 'newuser@example.com',
        password: 'password123',
        role: 'member',
        companyId: 1
      };

      const createdUser = {
        id: 1,
        email: userData.email,
        role: userData.role,
        companyId: userData.companyId,
        invited: false,
        createdAt: new Date()
      };

      mockPrismaClient.user.findUnique.mockResolvedValue(null); // No existing user
      mockPrismaClient.user.create.mockResolvedValue(createdUser);

      const response = await request(app)
        .post('/users')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(userData);

      expect(response.status).toBe(201);
      expect(response.body.message).toBe('User created successfully');
      expect(response.body.user).toMatchObject({
        email: userData.email,
        role: userData.role,
        companyId: userData.companyId,
        invited: false
      });
      expect(response.body.user).toHaveProperty('id');
      expect(response.body.user).toHaveProperty('createdAt');
      expect(response.body.user).not.toHaveProperty('passwordHash');

      expect(mockPrismaClient.user.create).toHaveBeenCalledWith({
        data: {
          email: userData.email,
          passwordHash: expect.any(String),
          role: userData.role,
          companyId: userData.companyId,
          invited: false,
          invitationToken: undefined
        }
      });
    });

    it('should create invited user with invitation token', async () => {
      const userData = {
        email: 'invited@example.com',
        password: 'temppass123',
        role: 'member',
        companyId: 1,
        invited: true,
        invitationToken: 'token123'
      };

      const createdUser = {
        id: 2,
        email: userData.email,
        role: userData.role,
        companyId: userData.companyId,
        invited: true,
        invitationToken: 'token123',
        createdAt: new Date()
      };

      mockPrismaClient.user.findUnique.mockResolvedValue(null);
      mockPrismaClient.user.create.mockResolvedValue(createdUser);

      const response = await request(app)
        .post('/users')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(userData);

      expect(response.status).toBe(201);
      expect(response.body.user.invited).toBe(true);
      
      expect(mockPrismaClient.user.create).toHaveBeenCalledWith({
        data: {
          email: userData.email,
          passwordHash: expect.any(String),
          role: userData.role,
          companyId: userData.companyId,
          invited: true,
          invitationToken: 'token123'
        }
      });
    });

    it('should create user with area_id (but not store it)', async () => {
      const userData = {
        email: 'user@example.com',
        password: 'password123',
        role: 'member',
        companyId: 1,
        area_id: 5
      };

      const createdUser = {
        id: 6,
        email: userData.email,
        role: userData.role,
        companyId: userData.companyId,
        invited: false,
        createdAt: new Date()
      };

      mockPrismaClient.user.findUnique.mockResolvedValue(null);
      mockPrismaClient.user.create.mockResolvedValue(createdUser);

      const response = await request(app)
        .post('/users')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(userData);

      expect(response.status).toBe(201);
      expect(response.body.user).not.toHaveProperty('area_id');
    });

    it('should reject creating user with existing email', async () => {
      const userData = {
        email: 'existing@example.com',
        password: 'password123',
        role: 'member',
        companyId: 1
      };

      const existingUser = {
        id: 3,
        email: userData.email,
        passwordHash: await bcrypt.hash(userData.password, 10),
        role: userData.role,
        companyId: userData.companyId
      };

      mockPrismaClient.user.findUnique.mockResolvedValue(existingUser);

      const response = await request(app)
        .post('/users')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(userData);

      expect(response.status).toBe(409);
      expect(response.body.error).toBe('User already exists');
      expect(response.body.details).toBe('A user with this email address already exists');
    });

    it('should reject invalid email format', async () => {
      const userData = {
        email: 'invalid-email',
        password: 'password123',
        role: 'member',
        companyId: 1
      };

      const response = await request(app)
        .post('/users')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(userData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Validation failed');
    });

    it('should reject short password', async () => {
      const userData = {
        email: 'test@example.com',
        password: '123',
        role: 'member',
        companyId: 1
      };

      const response = await request(app)
        .post('/users')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(userData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Validation failed');
    });

    it('should reject invalid role', async () => {
      const userData = {
        email: 'test@example.com',
        password: 'password123',
        role: 'invalid-role',
        companyId: 1
      };

      const response = await request(app)
        .post('/users')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(userData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Validation failed');
    });

    it('should handle database errors during user creation', async () => {
      const userData = {
        email: 'error@example.com',
        password: 'password123',
        role: 'member',
        companyId: 1
      };

      mockPrismaClient.user.findUnique.mockResolvedValue(null);
      mockPrismaClient.user.create.mockRejectedValue(new Error('Database error'));

      const response = await request(app)
        .post('/users')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(userData);

      expect(response.status).toBe(500);
    });
  });

  describe('POST /users/create-superadmin', () => {
    it('should create superadmin successfully', async () => {
      const adminData = {
        email: 'admin@example.com',
        password: 'admin123'
      };

      const createdAdmin = {
        id: 4,
        email: adminData.email,
        role: 'superadmin',
        createdAt: new Date()
      };

      mockPrismaClient.user.create.mockResolvedValue(createdAdmin);

      const response = await request(app)
        .post('/users/create-superadmin')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(adminData);

      expect(response.status).toBe(201);
      expect(response.body.message).toBe('Superadmin created successfully');
      expect(response.body.user).toMatchObject({
        email: adminData.email,
        role: 'superadmin'
      });
      expect(response.body.user).toHaveProperty('id');
      expect(response.body.user).toHaveProperty('createdAt');
      expect(response.body.user).not.toHaveProperty('passwordHash');

      expect(mockPrismaClient.user.create).toHaveBeenCalledWith({
        data: {
          email: adminData.email,
          passwordHash: expect.any(String),
          role: 'superadmin'
        }
      });
    });

    it('should reject invalid email for superadmin', async () => {
      const adminData = {
        email: 'invalid-email',
        password: 'admin123'
      };

      const response = await request(app)
        .post('/users/create-superadmin')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(adminData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Validation failed');
    });

    it('should reject short password for superadmin', async () => {
      const adminData = {
        email: 'admin@example.com',
        password: '123'
      };

      const response = await request(app)
        .post('/users/create-superadmin')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(adminData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Validation failed');
    });

    it('should handle database errors during superadmin creation', async () => {
      const adminData = {
        email: 'admin@example.com',
        password: 'admin123'
      };

      mockPrismaClient.user.create.mockRejectedValue(new Error('Database error'));

      const response = await request(app)
        .post('/users/create-superadmin')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send(adminData);

      expect(response.status).toBe(500);
    });
  });

  describe('PUT /users/:id/password', () => {
    let testUser;

    beforeEach(async () => {
      testUser = {
        id: 5,
        email: 'test@example.com',
        passwordHash: await bcrypt.hash('oldpassword', 10),
        role: 'member',
        companyId: 1
      };
    });

    it('should update password successfully', async () => {
      const newPassword = 'newpassword123';

      mockPrismaClient.user.update.mockResolvedValue({
        ...testUser,
        passwordHash: await bcrypt.hash(newPassword, 10)
      });

      const response = await request(app)
        .put(`/users/${testUser.id}/password`)
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ password: newPassword });

      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Password updated successfully');

      expect(mockPrismaClient.user.update).toHaveBeenCalledWith({
        where: { id: testUser.id },
        data: { passwordHash: expect.any(String) }
      });
    });

    it('should reject short password', async () => {
      const response = await request(app)
        .put(`/users/${testUser.id}/password`)
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ password: '123' });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Validation failed');
    });

    it('should return 404 for non-existent user', async () => {
      const prismaError = new Error('Record not found');
      prismaError.code = 'P2025';
      mockPrismaClient.user.update.mockRejectedValue(prismaError);

      const response = await request(app)
        .put('/users/99999/password')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ password: 'newpassword123' });

      expect(response.status).toBe(404);
      expect(response.body.error).toBe('User not found');
    });

    it('should handle database errors during password update', async () => {
      const genericError = new Error('Database error');
      mockPrismaClient.user.update.mockRejectedValue(genericError);

      const response = await request(app)
        .put('/users/1/password')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ password: 'newpassword123' });

      expect(response.status).toBe(500);
    });
  });

  describe('POST /users/by-ids', () => {
    let users;

    beforeEach(async () => {
      users = [];
      for (let i = 1; i <= 3; i++) {
        const user = {
          id: 10 + i,
          email: `user${i}@example.com`,
          passwordHash: await bcrypt.hash('password123', 10),
          role: 'member',
          companyId: 1,
          invited: i === 2,
          invitationToken: i === 2 ? 'token123' : null,
          createdAt: new Date()
        };
        users.push(user);
      }
    });

    it('should return users by IDs successfully', async () => {
      const ids = [users[0].id, users[1].id];
      const expectedUsers = [users[0], users[1]].map(user => ({
        id: user.id,
        email: user.email,
        role: user.role,
        companyId: user.companyId,
        invited: user.invited,
        invitationToken: user.invitationToken,
        createdAt: user.createdAt
      }));

      mockPrismaClient.user.findMany.mockResolvedValue(expectedUsers);

      const response = await request(app)
        .post('/users/by-ids')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ ids });

      expect(response.status).toBe(200);
      expect(response.body.users).toHaveLength(2);
      expect(response.body.users[0]).toMatchObject({
        id: users[0].id,
        email: users[0].email,
        role: users[0].role,
        companyId: users[0].companyId,
        invited: users[0].invited
      });
      expect(response.body.users[0]).not.toHaveProperty('passwordHash');
    });

    it('should return empty array for invalid IDs', async () => {
      mockPrismaClient.user.findMany.mockResolvedValue([]);

      const response = await request(app)
        .post('/users/by-ids')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ ids: [99999, 'invalid'] });

      expect(response.status).toBe(200);
      expect(response.body.users).toEqual([]);
    });

    it('should return empty array for empty IDs array', async () => {
      const response = await request(app)
        .post('/users/by-ids')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ ids: [] });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Validation failed');
      expect(response.body.details).toBe('ids must be a non-empty array of integers');
    });

    it('should reject non-array IDs', async () => {
      const response = await request(app)
        .post('/users/by-ids')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ ids: 'not-an-array' });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Validation failed');
      expect(response.body.details).toBe('ids must be a non-empty array of integers');
    });

    it('should handle mixed valid and invalid IDs', async () => {
      const ids = [users[0].id, 99999, 'invalid', users[1].id];
      const validUsers = [users[0], users[1]].map(user => ({
        id: user.id,
        email: user.email,
        role: user.role,
        companyId: user.companyId,
        invited: user.invited,
        invitationToken: user.invitationToken,
        createdAt: user.createdAt
      }));

      mockPrismaClient.user.findMany.mockResolvedValue(validUsers);

      const response = await request(app)
        .post('/users/by-ids')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ ids });

      expect(response.status).toBe(200);
      expect(response.body.users).toHaveLength(2);
      expect(response.body.users.map(u => u.id)).toContain(users[0].id);
      expect(response.body.users.map(u => u.id)).toContain(users[1].id);
    });

    it('should handle database errors during by-ids query', async () => {
      mockPrismaClient.user.findMany.mockRejectedValue(new Error('Database error'));

      const response = await request(app)
        .post('/users/by-ids')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ ids: [1, 2, 3] });

      expect(response.status).toBe(500);
    });

    it('should return empty array when no valid IDs are provided', async () => {
      mockPrismaClient.user.findMany.mockResolvedValue([]);

      const response = await request(app)
        .post('/users/by-ids')
        .set('x-api-key', process.env.API_SECRET_KEY)
        .send({ ids: ['invalid', 'also_invalid', -1, 0] }); // All invalid IDs

      expect(response.status).toBe(200);
      expect(response.body.users).toEqual([]);
      
      // Should not call findMany because no valid IDs exist after filtering
      expect(mockPrismaClient.user.findMany).not.toHaveBeenCalled();
    });
  });
}); 