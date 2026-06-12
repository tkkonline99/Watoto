import { loadConfig, resetConfigForTests } from './config';

describe('loadConfig', () => {
  const env = process.env;

  beforeEach(() => {
    process.env = { ...env };
    resetConfigForTests();
  });

  afterAll(() => {
    process.env = env;
  });

  it('applies development defaults', () => {
    delete process.env.NODE_ENV;
    delete process.env.PORT;
    const cfg = loadConfig();
    expect(cfg.nodeEnv).toBe('development');
    expect(cfg.port).toBe(3000);
  });

  it('rejects the default JWT secret in production', () => {
    process.env.NODE_ENV = 'production';
    delete process.env.JWT_SECRET;
    expect(() => loadConfig()).toThrow(/JWT_SECRET/);
  });

  it('rejects a malformed PORT', () => {
    process.env.PORT = 'not-a-number';
    expect(() => loadConfig()).toThrow();
  });
});
