import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@Controller()
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  /** Liveness: process is up. */
  @Get('health')
  health(): { status: string } {
    return { status: 'ok' };
  }

  /** Readiness: dependencies reachable (used by ALB/ECS health checks). */
  @Get('ready')
  async ready(): Promise<{ status: string; db: string }> {
    const db = await this.prisma.isHealthy();
    return { status: db ? 'ok' : 'degraded', db: db ? 'ok' : 'down' };
  }
}
