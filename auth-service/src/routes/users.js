const express = require('express');
const bcrypt = require('bcrypt');
const { body, validationResult } = require('express-validator');
const { PrismaClient } = require('@prisma/client');

const router = express.Router();
const prisma = new PrismaClient();

// Validation middleware
const validateUser = [
  body('email').isEmail(),
  body('password').isLength({ min: 6 }).trim(),
  body('role').isIn(['member', 'admin']),
  body('companyId').optional().isInt(),
  body('invited').optional().isBoolean(),
  body('invitationToken').optional().isString(),
  body('area_id').optional().isInt()
];

const validateSuperadmin = [
  body('email').isEmail(),
  body('password').isLength({ min: 4 }).trim()
];

const validatePassword = [
  body('password').isLength({ min: 6 }).trim()
];

/**
 * @swagger
 * /users:
 *   post:
 *     summary: Create a new user
 *     tags: [Users]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *               - role
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: newuser@example.com
 *               password:
 *                 type: string
 *                 format: password
 *                 example: temp_password
 *               role:
 *                 type: string
 *                 enum: [member, admin]
 *                 example: member
 *               companyId:
 *                 type: integer
 *                 example: 1
 *               invited:
 *                 type: boolean
 *                 example: true
 *               invitationToken:
 *                 type: string
 *                 example: invitation_token
 *               area_id:
 *                 type: integer
 *                 example: 1
 *                 description: Optional area/department ID (used by Phoenix service)
 *     responses:
 *       201:
 *         description: User created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: integer
 *                       example: 1
 *                     email:
 *                       type: string
 *                       example: newuser@example.com
 *                     role:
 *                       type: string
 *                       example: member
 *                     companyId:
 *                       type: integer
 *                       example: 1
 *                     invited:
 *                       type: boolean
 *                       example: true
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *                 message:
 *                   type: string
 *                   example: User created successfully
 *       400:
 *         description: Validation error
 */
router.post('/', validateUser, async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const { email, password, role, companyId, invited, invitationToken, area_id } = req.body;

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email }
    });

    if (existingUser) {
      return res.status(409).json({ 
        error: 'User already exists',
        details: 'A user with this email address already exists'
      });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Create user (area_id is not stored in auth service, only in Phoenix)
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        role,
        companyId,
        invited: invited || false,
        invitationToken
      }
    });

    // Return user data without password
    const userResponse = {
      id: user.id,
      email: user.email,
      role: user.role,
      companyId: user.companyId,
      invited: user.invited,
      createdAt: user.createdAt
    };

    res.status(201).json({
      user: userResponse,
      message: 'User created successfully'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /users/create-superadmin:
 *   post:
 *     summary: Create a superadmin user
 *     tags: [Users]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: admin@example.com
 *               password:
 *                 type: string
 *                 format: password
 *                 example: admin_password
 *     responses:
 *       201:
 *         description: Superadmin created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: integer
 *                       example: 1
 *                     email:
 *                       type: string
 *                       example: admin@example.com
 *                     role:
 *                       type: string
 *                       example: superadmin
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *                 message:
 *                   type: string
 *                   example: Superadmin created successfully
 *       400:
 *         description: Validation error
 */
router.post('/create-superadmin', validateSuperadmin, async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const { email, password } = req.body;

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Create superadmin
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        role: 'superadmin'
      }
    });

    // Return user data without password
    const userResponse = {
      id: user.id,
      email: user.email,
      role: user.role,
      createdAt: user.createdAt
    };

    res.status(201).json({
      user: userResponse,
      message: 'Superadmin created successfully'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /users/{id}/password:
 *   put:
 *     summary: Update user password
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: User ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - password
 *             properties:
 *               password:
 *                 type: string
 *                 format: password
 *                 example: new_password_here
 *     responses:
 *       200:
 *         description: Password updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Password updated successfully
 *       400:
 *         description: Validation error
 *       404:
 *         description: User not found
 */
router.put('/:id/password', validatePassword, async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const { id } = req.params;
    const { password } = req.body;

    // Hash new password
    const passwordHash = await bcrypt.hash(password, 10);

    // Update user password
    await prisma.user.update({
      where: { id: parseInt(id) },
      data: { passwordHash }
    });

    res.json({ message: 'Password updated successfully' });
  } catch (error) {
    if (error.code === 'P2025') {
      return res.status(404).json({ error: 'User not found' });
    }
    next(error);
  }
});

/**
 * @swagger
 * /users/by-ids:
 *   post:
 *     summary: Get users by their IDs
 *     tags: [Users]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - ids
 *             properties:
 *               ids:
 *                 type: array
 *                 items:
 *                   type: integer
 *                 example: [1, 2, 3]
 *     responses:
 *       200:
 *         description: Users retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 users:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                         example: 1
 *                       email:
 *                         type: string
 *                         example: user@example.com
 *                       role:
 *                         type: string
 *                         example: member
 *                       companyId:
 *                         type: integer
 *                         example: 1
 *                       invited:
 *                         type: boolean
 *                         example: false
 *                       invitationToken:
 *                         type: string
 *                         nullable: true
 *                         example: "invitation_token_here"
 *                       createdAt:
 *                         type: string
 *                         format: date-time
 *       400:
 *         description: Validation error
 */
router.post('/by-ids', async (req, res, next) => {
  try {
    const { ids } = req.body;

    if (!Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({ 
        error: 'Validation failed',
        details: 'ids must be a non-empty array of integers'
      });
    }

    // Convert to integers and filter out invalid values
    const validIds = ids.filter(id => Number.isInteger(id) && id > 0);

    if (validIds.length === 0) {
      return res.json({ users: [] });
    }

    // Get users by IDs
    const users = await prisma.user.findMany({
      where: {
        id: {
          in: validIds
        }
      },
      select: {
        id: true,
        email: true,
        role: true,
        companyId: true,
        invited: true,
        invitationToken: true,
        createdAt: true
      }
    });

    res.json({ users });
  } catch (error) {
    next(error);
  }
});

module.exports = router;