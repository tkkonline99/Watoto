import { BadRequestException, Controller, Get, Param, ParseUUIDPipe, Query, UseGuards } from '@nestjs/common';
import { AgeBand } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CatalogService } from './catalog.service';

const AGE_BAND_PARAM: Record<string, AgeBand> = {
  '0_2': 'b0_2',
  '3_5': 'b3_5',
  '6_8': 'b6_8',
  '9_10': 'b9_10',
};

@Controller('catalog')
@UseGuards(JwtAuthGuard)
export class CatalogController {
  constructor(private readonly catalog: CatalogService) {}

  @Get('subjects')
  listSubjects(@Query('ageBand') ageBand?: string) {
    if (ageBand !== undefined && !(ageBand in AGE_BAND_PARAM)) {
      throw new BadRequestException('ageBand must be one of 0_2, 3_5, 6_8, 9_10');
    }
    return this.catalog.listSubjects(ageBand ? AGE_BAND_PARAM[ageBand] : undefined);
  }

  @Get('courses/:id')
  getCourse(@Param('id', ParseUUIDPipe) id: string) {
    return this.catalog.getCourse(id);
  }

  @Get('lessons/:id')
  getLesson(@Param('id', ParseUUIDPipe) id: string) {
    return this.catalog.getLesson(id);
  }
}
