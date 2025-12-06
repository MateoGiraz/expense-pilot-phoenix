const swaggerSpecs = require('../../config/swagger');

describe('Swagger Configuration', () => {
  it('should export swagger specs object', () => {
    expect(swaggerSpecs).toBeDefined();
    expect(typeof swaggerSpecs).toBe('object');
  });

  it('should have required OpenAPI structure', () => {
    expect(swaggerSpecs.openapi).toBe('3.0.0');
    expect(swaggerSpecs.info).toBeDefined();
    expect(swaggerSpecs.info.title).toBe('Auth Service API');
    expect(swaggerSpecs.info.version).toBe('1.0.0');
    expect(swaggerSpecs.info.description).toBe('Authentication microservice API documentation');
  });

  it('should have servers configuration', () => {
    expect(swaggerSpecs.servers).toBeDefined();
    expect(Array.isArray(swaggerSpecs.servers)).toBe(true);
    expect(swaggerSpecs.servers.length).toBeGreaterThan(0);
    expect(swaggerSpecs.servers[0]).toMatchObject({
      url: 'http://localhost:5439',
      description: 'Development server'
    });
  });

  it('should have security schemes configuration', () => {
    expect(swaggerSpecs.components).toBeDefined();
    expect(swaggerSpecs.components.securitySchemes).toBeDefined();
    expect(swaggerSpecs.components.securitySchemes.bearerAuth).toMatchObject({
      type: 'http',
      scheme: 'bearer',
      bearerFormat: 'JWT'
    });
  });

  it('should have paths defined from route files', () => {
    expect(swaggerSpecs.paths).toBeDefined();
    expect(typeof swaggerSpecs.paths).toBe('object');
  });
}); 