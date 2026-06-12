import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { loadConfig } from '../../common/config/config';
import { AuthController } from './auth.controller';
import { TokenService } from './token.service';
import { JwtAuthGuard } from './jwt-auth.guard';

const config = loadConfig();

@Module({
  imports: [
    JwtModule.register({
      secret: config.jwtSecret,
      signOptions: { expiresIn: config.jwtAccessTtl },
    }),
  ],
  controllers: [AuthController],
  providers: [TokenService, JwtAuthGuard],
  exports: [TokenService, JwtAuthGuard, JwtModule],
})
export class AuthModule {}
