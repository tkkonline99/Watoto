import { BadRequestException, Body, Controller, ForbiddenException, Post } from '@nestjs/common';
import { z } from 'zod';
import { loadConfig } from '../../common/config/config';
import { TokenService } from './token.service';

const devTokenSchema = z.object({
  role: z.enum(['child', 'parent', 'teacher', 'admin']),
  userId: z.string().uuid().optional(),
  childId: z.string().uuid().optional(),
});

@Controller('auth')
export class AuthController {
  constructor(private readonly tokens: TokenService) {}

  /**
   * Development-only token mint, active while Firebase is not configured.
   * Production flow (POST /auth/firebase) verifies a Firebase ID token via
   * firebase-admin and is wired in once FIREBASE_SA_B64 is provisioned.
   */
  @Post('dev-token')
  async devToken(@Body() body: unknown): Promise<{ accessToken: string }> {
    const config = loadConfig();
    if (config.nodeEnv === 'production' || config.firebaseSaB64 !== '') {
      throw new ForbiddenException('dev-token is disabled');
    }
    const parsed = devTokenSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException(parsed.error.flatten());
    }
    const { role, userId, childId } = parsed.data;
    const accessToken = await this.tokens.issueAccessToken({
      sub: userId ?? '00000000-0000-0000-0000-000000000001',
      role,
      childId: role === 'child' ? (childId ?? '00000000-0000-0000-0000-000000000002') : undefined,
    });
    return { accessToken };
  }
}
