import { BadRequestException, Body, Controller, ForbiddenException, Headers, Post, Req, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthedRequest, JwtAuthGuard } from '../auth/jwt-auth.guard';
import { SyncService, syncOpSchema } from './sync.service';

const batchSchema = z.object({
  ops: z.array(syncOpSchema).min(1).max(200),
});

@Controller('sync')
@UseGuards(JwtAuthGuard)
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  @Post('batch')
  async batch(
    @Req() req: AuthedRequest,
    @Body() body: unknown,
    @Headers('x-device-id') deviceId = 'unknown',
  ) {
    const childId = req.principal.childId;
    if (req.principal.role !== 'child' || !childId) {
      throw new ForbiddenException('Only child sessions sync learning ops');
    }
    const parsed = batchSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException(parsed.error.flatten());
    }
    const results = await this.sync.applyBatch(childId, deviceId, parsed.data.ops);
    return { results, serverTime: new Date().toISOString() };
  }
}
