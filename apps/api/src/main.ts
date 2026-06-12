import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { loadConfig } from './common/config/config';

async function bootstrap(): Promise<void> {
  const config = loadConfig();
  const app = await NestFactory.create(AppModule);

  app.use(helmet());
  app.setGlobalPrefix('v1');
  app.enableCors({
    origin: config.nodeEnv === 'production' ? ['https://app.watoto.app', 'https://cms.watoto.app'] : true,
  });
  app.enableShutdownHooks();

  await app.listen(config.port);
  // eslint-disable-next-line no-console
  console.log(`Watoto API listening on :${config.port} (${config.nodeEnv})`);
}

void bootstrap();
