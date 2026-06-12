import { Module } from '@nestjs/common';
import { PrismaModule } from './common/prisma/prisma.module';
import { HealthModule } from './modules/health/health.module';
import { AuthModule } from './modules/auth/auth.module';
import { CatalogModule } from './modules/catalog/catalog.module';
import { LearningModule } from './modules/learning/learning.module';
import { SyncModule } from './modules/sync/sync.module';

@Module({
  imports: [PrismaModule, HealthModule, AuthModule, CatalogModule, LearningModule, SyncModule],
})
export class AppModule {}
