const { apiKeyAuth } = require('../../middleware/auth');

describe('Auth Middleware', () => {
  let req, res, next;

  beforeEach(() => {
    req = {
      headers: {}
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
    next = jest.fn();
  });

  describe('apiKeyAuth', () => {
    it('should pass authentication with valid API key', () => {
      req.headers['x-api-key'] = process.env.API_SECRET_KEY;

      apiKeyAuth(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
      expect(res.json).not.toHaveBeenCalled();
    });

    it('should reject when no API key is provided', () => {
      apiKeyAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ error: 'Unauthorized' });
      expect(next).not.toHaveBeenCalled();
    });

    it('should reject when API key is invalid', () => {
      req.headers['x-api-key'] = 'invalid-key';

      apiKeyAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ error: 'Unauthorized' });
      expect(next).not.toHaveBeenCalled();
    });

    it('should reject when API key is empty string', () => {
      req.headers['x-api-key'] = '';

      apiKeyAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ error: 'Unauthorized' });
      expect(next).not.toHaveBeenCalled();
    });

    it('should reject when expected key is not set', () => {
      const originalKey = process.env.API_SECRET_KEY;
      delete process.env.API_SECRET_KEY;
      req.headers['x-api-key'] = 'some-key';

      apiKeyAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ error: 'Unauthorized' });
      expect(next).not.toHaveBeenCalled();

      process.env.API_SECRET_KEY = originalKey;
    });
  });
}); 